#!/usr/bin/env python3
"""Analysis-only, per-frame material color comparison against one matte master.

Writes JSON/CSV, neutral-background contact sheets and inspectable material-mask
overlays. Never alters source PNGs. Heuristics are color proxies, not semantic
segmentation; authored masks can replace them. See docs/oichi-v27-color-qa.md.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import io
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

MATERIALS = ['skin','white_cloth','red_skirt','hair']
COLORS = {'skin':(0,220,240), 'white_cloth':(70,120,255), 'red_skirt':(255,210,0), 'hair':(220,70,250)}
QUANTILES = [.10,.25,.50,.75,.90,.95]
LIMITS = {'median_L':4.0, 'p90_L':5.0, 'median_C':5.0, 'p90_C':7.0, 'median_delta_E76':7.0}
BACKGROUND = (104,104,104,255)
EXPECTED_CLIPS = {'idle','walk','run','light1','light2','light3','heavy1','heavy2','charged_upper','charged_slam','air_heavy','air_light','rising','low_sweep','dash_heavy','dash_strike','jump','hurt','down','recovering','launched','stunned','guard','throw','special','victory'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(path):
    data=path.read_bytes()
    image=Image.open(io.BytesIO(data));image.load()
    return image,hashlib.sha256(data).hexdigest()


def srgb_to_lab(rgb):
    """IEC sRGB -> CIE XYZ D65 -> CIELAB, float64, no display/background sampling."""
    rgb = np.asarray(rgb,dtype=np.float64) / 255
    linear = np.where(rgb <= .04045,rgb / 12.92,((rgb+.055)/1.055)**2.4)
    xyz = linear @ np.array([[.4124564,.3575761,.1804375],
                             [.2126729,.7151522,.0721750],
                             [.0193339,.1191920,.9503041]]).T
    xyz /= np.array([.95047,1.0,1.08883])
    delta = 6/29
    f = np.where(xyz > delta**3,np.cbrt(xyz),xyz/(3*delta**2)+4/29)
    return np.stack((116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])),axis=-1)


def hsv(rgb):
    c = rgb.astype(np.float64)/255
    high, low = c.max(axis=-1), c.min(axis=-1)
    chroma = high-low
    safe = np.where(chroma > 0,chroma,1)
    hue = np.zeros_like(high)
    for channel, offset in [(0,0),(1,2),(2,4)]:
        mask = (high == c[...,channel]) & (chroma > 0)
        hue[mask] = ((c[...,(channel+1)%3]-c[...,(channel+2)%3])/safe+offset)[mask]
    return (hue*60)%360, np.divide(chroma,high,out=np.zeros_like(high),where=high>0), high


def material_masks(rgba, lab, eligible=None):
    rgb = rgba[...,:3].astype(float)
    opaque = rgba[...,3] > 245  # Never sample hidden RGB or alpha-blended edges.
    if eligible is not None:
        if eligible.shape != opaque.shape: raise ValueError('Analysis eligibility mask dimensions differ from source')
        opaque &= eligible
    hue,saturation,value = hsv(rgb)
    lightness = lab[...,0]
    chroma = np.hypot(lab[...,1],lab[...,2])
    skin = opaque & (hue>=16) & (hue<=52) & (saturation>=.15) & (saturation<=.68) & (lightness>=35) & (rgb[...,0]>rgb[...,1]*1.06) & (rgb[...,1]>rgb[...,2]*1.04)
    white = opaque & (lightness>=55) & (chroma<=17) & ((rgb.max(axis=-1)-rgb.min(axis=-1))<=42)
    red = opaque & ((hue<=16)|(hue>=345)) & (saturation>=.38) & (lab[...,1]>=18) & (lightness>=12) & (lightness<=75)
    # Largest nearby red cluster is normally the skirt/obi. Closing bridges
    # painted black fold lines; masks still sample ONLY original red pixels.
    # This excludes disconnected sandal straps and hair beads. It is a review
    # proxy, not proof of garment identity, especially in occluded/prone poses.
    radius=max(1,round(min(rgba.shape[:2])*.008))
    connected=ndimage.binary_dilation(red,iterations=radius)
    labels,_=ndimage.label(connected)
    red_skirt=np.zeros_like(red)
    if labels.max():
        sizes=np.bincount(labels[red].ravel())
        sizes[0]=0
        red_skirt=red & (labels==int(sizes.argmax()))
    # Hair is a conservative top-of-figure dark-material proxy. For prone or
    # rotating poses this ROI is unreliable; use an authored mask or review it.
    hair_roi = np.zeros(opaque.shape,dtype=bool)
    yy,xx = np.where(opaque)
    if yy.size:
        limit = int(yy.min()+.34*(yy.max()-yy.min()+1))
        hair_roi[:limit] = True
    hair = opaque & hair_roi & (lightness>=7) & (lightness<=42) & (chroma<=23) & (saturation<=.55)
    return {'skin':skin,'white_cloth':white,'red_skirt':red_skirt,'hair':hair}


def stats(rgba, lab, mask, minimum):
    n = int(mask.sum())
    if n < minimum:
        return {'status':'insufficient_samples','samples':n,'minimum_samples':minimum}
    sampled = lab[mask]
    chroma = np.hypot(sampled[:,1],sampled[:,2])
    q = lambda values: {f'p{round(p*100):02d}':round(float(v),4) for p,v in zip(QUANTILES,np.quantile(values,QUANTILES))}
    return {'status':'measured','samples':n,
            'median_RGB':np.round(np.median(rgba[...,:3][mask],axis=0),2).tolist(),
            'median_Lab':np.round(np.median(sampled,axis=0),4).tolist(),
            'L':q(sampled[:,0]), 'C':q(chroma),
            'a':q(sampled[:,1]), 'b':q(sampled[:,2])}


def differences(value, reference):
    if value['status'] != 'measured' or reference['status'] != 'measured':
        return {'status':'review_sampling','flags':['insufficient_material_samples']}
    deltas = {'median_L':value['L']['p50']-reference['L']['p50'],
              'p90_L':value['L']['p90']-reference['L']['p90'],
              'median_C':value['C']['p50']-reference['C']['p50'],
              'p90_C':value['C']['p90']-reference['C']['p90'],
              'median_delta_E76':float(np.linalg.norm(np.array(value['median_Lab'])-reference['median_Lab']))}
    flags = [key for key,delta in deltas.items() if abs(delta)>LIMITS[key]]
    return {'status':'review_outlier' if flags else 'within_diagnostic_limits',
            'deltas':{key:round(value,4) for key,value in deltas.items()}, 'flags':flags}


def neutral(image):
    background = Image.new('RGBA',image.size,BACKGROUND)
    background.alpha_composite(image)
    return background.convert('RGB')


def preview(image, masks, target, heading, material_stats, comparison=None):
    base = neutral(image)
    overlay = np.asarray(base).copy()
    for name in MATERIALS:
        mask = masks[name]
        overlay[mask] = (.22*overlay[mask]+.78*np.array(COLORS[name])).astype('uint8')
    overlay_image = Image.fromarray(overlay)
    width,height = 760,650
    page = Image.new('RGB',(width,height),(39,39,39))
    draw = ImageDraw.Draw(page)
    draw.text((14,12),heading,fill=(245,245,245))
    for col,im in enumerate([base,overlay_image]):
        im.thumbnail((358,440))
        page.paste(im,(14+col*374+(358-im.width)//2,38+(440-im.height)//2))
    draw.text((14,484),'Original alpha on neutral gray',fill=(235,235,235))
    draw.text((388,484),'Heuristic sampled pixels (alpha > 245)',fill=(235,235,235))
    for index,name in enumerate(MATERIALS):
        item=material_stats[name]
        label=f'{name}: n={item["samples"]}'
        if item['status']=='measured':
            label+=f'   L50/90={item["L"]["p50"]:.1f}/{item["L"]["p90"]:.1f}   C50={item["C"]["p50"]:.1f}'
        if comparison and comparison[name].get('flags'):
            short={'median_L':'L50','p90_L':'L90','median_C':'C50','p90_C':'C90','median_delta_E76':'dE','insufficient_material_samples':'samples'}
            label+='  REVIEW: '+','.join(short[key] for key in comparison[name]['flags'])
        draw.text((14,514+index*28),label,fill=COLORS[name])
    page.save(target)
    return page


def analyze(image, mask_path=None, minimum=80, eligible=None):
    rgba=np.asarray(image)
    lab=srgb_to_lab(rgba[...,:3])
    masks=material_masks(rgba,lab,eligible)
    mode='heuristic_material_color_proxy'
    if mask_path is not None:
        authored=np.asarray(Image.open(mask_path).convert('L'))
        if authored.shape != rgba.shape[:2]:
            raise ValueError(f'{mask_path}: mask dimensions must match native source frame/region')
        if not set(np.unique(authored)).issubset({0,1,2,3,4}):
            raise ValueError(f'{mask_path}: authored labels must be 0..4')
        masks={name:(authored==index+1)&(rgba[...,3]>245) for index,name in enumerate(MATERIALS)}
        if eligible is not None:masks={name:mask&eligible for name,mask in masks.items()}
        mode='authored_material_labels'
    return masks,{name:stats(rgba,lab,masks[name],minimum) for name in MATERIALS},mode


def selected_component_mask(image, frame_spec, region):
    """Analysis inclusion only. Original image, RGB and alpha stay untouched."""
    if 'clip_component' not in frame_spec:return None
    spec=importlib.util.spec_from_file_location('oichi_native_registration',Path(__file__).with_name('register-oichi-v27.py'))
    registration=importlib.util.module_from_spec(spec);spec.loader.exec_module(registration)
    alpha=np.asarray(image.getchannel('A'))
    review=registration.component_review(image,alpha,frame_spec.get('component_count',6))
    selected=review['components'][frame_spec['clip_component']]['label']
    labels,_=ndimage.label(alpha>32)
    x,y,w,h=region
    return labels[y:y+h,x:x+w]==selected


def regions(image, frames=None):
    if frames:
        return [frame.get('source_region',[index%3*image.width//3,index//3*image.height//2,image.width//3,image.height//2]) for index,frame in enumerate(frames)]
    if image.width%3 or image.height%2:
        raise ValueError('Sprite source must divide into 3 x 2 cells, or supply pose source_regions')
    return [[index%3*image.width//3,index//3*image.height//2,image.width//3,image.height//2] for index in range(6)]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--master',type=Path,required=True,help='Single accepted matte reference PNG, true RGBA')
    parser.add_argument('--master-mask',type=Path)
    parser.add_argument('--enemy-rois',type=Path,help='JSON list of {name,file,regions:[[x,y,w,h],...]} for face/arms skin comparisons')
    parser.add_argument('--source-dir',type=Path,required=True)
    parser.add_argument('--poses',type=Path,help='Optional anchors JSON with explicit source_regions')
    parser.add_argument('--mask-dir',type=Path,help='Optional authored labels: <clip>-01.png ... <clip>-06.png')
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--minimum-samples',type=int,default=80)
    parser.add_argument('--clips',help='Comma-separated subset; otherwise every PNG in source-dir')
    parser.add_argument('--fail-on-outlier',action='store_true')
    args=parser.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    master,master_sha=snapshot(args.master)
    if master.mode!='RGBA': raise ValueError('Master must be native RGBA; no conversion or background sampling')
    master_masks,master_stats,master_mode=analyze(master,args.master_mask,args.minimum_samples)
    preview(master,master_masks,args.out/'master-material-review.png','Matte master / reference sampling',master_stats)
    poses=json.loads(args.poses.read_text())['clips'] if args.poses else {}
    names=args.clips.split(',') if args.clips else [p.stem for p in sorted(args.source_dir.glob('*.png')) if p.stem in EXPECTED_CLIPS]
    if not names: raise ValueError('No source PNGs found; no color coverage established')
    report={'schema_version':1,'analysis_only':True,'master':{'file':str(args.master),'sha256':master_sha,'sampling':master_mode,'materials':master_stats},
            'color_space':'CIELAB D65, IEC sRGB linearization, CIE76 distance of median Lab vectors',
            'sample_filter':'native alpha > 245; hidden RGB and antialiased edge pixels excluded',
            'diagnostic_limits':LIMITS,
            'limitations':['Color heuristics are not anatomical material segmentation. Skin can include similarly colored ornaments; red_skirt is the largest nearby red cluster, which can include the attached obi/top trim but excludes disconnected sandals and hair beads.',
                          'White cloth proxy includes white top and tabi; dark folds may be excluded. Hair is a top-34%-of-figure dark-material proxy and requires mask review in rotated/prone poses.',
                          'Bright/dark color shifts can change heuristic membership. Review masks and use authored labels for final acceptance; no numerical pass proves visual consistency.',
                          'Flags are conservative review triggers, not permission to recolor. View individual materials/frame against master, not global sheet histograms.',
                          'Neutral previews auto-fit source regions for color inspection; they are not anatomical-scale or anchor approval.'],
            'clips':{}}
    report['enemy_skin_references']=[]
    if args.enemy_rois:
        for enemy in json.loads(args.enemy_rois.read_text()):
            path=Path(enemy['file'])
            im,source_sha=snapshot(path)
            if im.mode!='RGBA': raise ValueError(f'{path}: enemy reference must be native RGBA')
            rgba=np.asarray(im);lab=srgb_to_lab(rgba[...,:3])
            masks=material_masks(rgba,lab)
            roi=np.zeros(rgba.shape[:2],dtype=bool)
            for x,y,w,h in enemy['regions']:
                if not (0<=x<x+w<=im.width and 0<=y<y+h<=im.height):raise ValueError('Enemy ROI outside image')
                roi[y:y+h,x:x+w]=True
            masks={name:(mask&roi if name=='skin' else np.zeros_like(mask)) for name,mask in masks.items()}
            measured={name:stats(rgba,lab,mask,args.minimum_samples) for name,mask in masks.items()}
            preview(im,masks,args.out/f'enemy-{enemy["name"]}-skin-review.png',f'Enemy skin ROI: {enemy["name"]}',measured)
            report['enemy_skin_references'].append({'name':enemy['name'],'file':str(path),'source_sha256':source_sha,
                                                   'regions':enemy['regions'],'skin':measured['skin'],
                                                   'master_minus_enemy':differences(master_stats['skin'],measured['skin'])})
    csv_rows=[]
    for name in names:
        path=args.source_dir/(name+'.png')
        image,source_sha=snapshot(path)
        if image.mode!='RGBA': raise ValueError(f'{name}: native RGBA required')
        entry={'source':str(path),'source_sha256':source_sha,'frames':[]}
        cards=[]
        neutral_sheet=Image.new('RGB',(3*340,2*390),(51,51,51))
        neutral_draw=ImageDraw.Draw(neutral_sheet)
        for index,region in enumerate(regions(image,poses.get(name,{}).get('frames'))):
            x,y,w,h=region
            frame_image=image
            frame_spec={}
            frame_file=name+'.png'
            frame_sha=source_sha
            if name in poses and index < len(poses[name].get('frames',[])):
                frame_spec=poses[name]['frames'][index]
                frame_file=frame_spec.get('file',frame_file)
                if frame_file != name+'.png':frame_image,frame_sha=snapshot(args.source_dir/frame_file)
            if not (0<=x<x+w<=frame_image.width and 0<=y<y+h<=frame_image.height):raise ValueError(f'{name}/{index+1}: color source_region outside native source')
            frame=frame_image.crop((x,y,x+w,y+h))
            mask_path=args.mask_dir/f'{name}-{index+1:02}.png' if args.mask_dir else None
            if mask_path and not mask_path.exists(): mask_path=None
            eligible=selected_component_mask(frame_image,frame_spec,region)
            masks,material_stats,mode=analyze(frame,mask_path,args.minimum_samples,eligible)
            comparison={material:differences(material_stats[material],master_stats[material]) for material in MATERIALS}
            expected_sha=frame_spec.get('source_sha256',poses.get(name,{}).get('source_sha256'))
            frame_report={'frame':index+1,'source_file':frame_file,'source_sha256':frame_sha,'source_region':region,'sampling':mode,'materials':material_stats,'comparison':comparison,
                          'selected_component_only':eligible is not None,'anchor_binding_matches':None if expected_sha is None else expected_sha==frame_sha}
            entry['frames'].append(frame_report)
            labelmask=np.zeros((h,w),dtype='uint8')
            for material_index,material in enumerate(MATERIALS):
                labelmask[masks[material]]=material_index+1
                row={'clip':name,'frame':index+1,'material':material,'samples':material_stats[material]['samples'],'status':comparison[material]['status'],
                     'flags':';'.join(comparison[material]['flags'])}
                row.update(comparison[material].get('deltas',{}))
                if material_stats[material]['status']=='measured':
                    row.update(L50=material_stats[material]['L']['p50'],L90=material_stats[material]['L']['p90'],C50=material_stats[material]['C']['p50'],C90=material_stats[material]['C']['p90'])
                csv_rows.append(row)
            Image.fromarray(labelmask).save(args.out/f'{name}-{index+1:02}-sample-labels.png')
            card=preview(frame,masks,args.out/f'{name}-{index+1:02}-material-review.png',f'{name} / frame {index+1}',material_stats,comparison)
            cards.append(card)
            small=neutral(frame);small.thumbnail((324,350))
            px,py=(index%3)*340,(index//3)*390
            neutral_sheet.paste(small,(px+(340-small.width)//2,py+25+(350-small.height)//2))
            neutral_draw.text((px+10,py+7),f'{name} / {index+1}',fill=(240,240,240))
        contact=Image.new('RGB',(3*760,2*650))
        for index,card in enumerate(cards):contact.paste(card,((index%3)*760,(index//3)*650))
        contact.save(args.out/f'{name}-material-contact.jpg',quality=92)
        neutral_sheet.save(args.out/f'{name}-neutral-contact.png')
        entry['material_summary']={}
        for material in MATERIALS:
            measured=[f['materials'][material] for f in entry['frames'] if f['materials'][material]['status']=='measured']
            summary={'measured_frames':len(measured),
                     'review_frames':[f['frame'] for f in entry['frames'] if f['comparison'][material]['status']!='within_diagnostic_limits']}
            if measured:
                ls=[f['L']['p50'] for f in measured];cs=[f['C']['p50'] for f in measured]
                summary.update(L50_range=[min(ls),max(ls)],C50_range=[min(cs),max(cs)],
                               median_frame_L50=round(float(np.median(ls)),4),median_frame_C50=round(float(np.median(cs)),4),
                               within_action_L50_spread=round(max(ls)-min(ls),4),within_action_C50_spread=round(max(cs)-min(cs),4))
                summary['within_action_review']=(max(ls)-min(ls)>LIMITS['median_L'] or max(cs)-min(cs)>LIMITS['median_C'])
            entry['material_summary'][material]=summary
        report['clips'][name]=entry
    flagged=[row for row in csv_rows if row['status']=='review_outlier']
    insufficient=[row for row in csv_rows if row['status']=='review_sampling']
    report['summary']={'clips':len(names),'frames':len(names)*6,'material_samples':len(csv_rows),'outlier_material_frames':len(flagged),'insufficient_material_frames':len(insufficient),
                       'coverage_complete':set(names)==EXPECTED_CLIPS,'missing_clips':sorted(EXPECTED_CLIPS-set(names)),
                       'noncanonical_clips':sorted(set(names)-EXPECTED_CLIPS)}
    (args.out/'color-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    fields=['clip','frame','material','samples','status','flags','L50','L90','C50','C90',*LIMITS]
    with (args.out/'color-audit.csv').open('w',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=fields);writer.writeheader();writer.writerows(csv_rows)
    print(json.dumps(report['summary']))
    for row in flagged:
        print(f'REVIEW {row["clip"]}/{row["frame"]} {row["material"]}: {row["flags"]}; dL50={row.get("median_L",0):+.2f}, dC50={row.get("median_C",0):+.2f}')
    if args.fail_on_outlier and (flagged or insufficient):raise SystemExit(1)


if __name__=='__main__':main()
