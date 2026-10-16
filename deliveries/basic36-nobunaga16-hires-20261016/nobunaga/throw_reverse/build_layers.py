"""Lossless visible-pixel partition of the approved reverse throw. No repainting or movement.

Run from any cwd. Input defaults to the approved source beside this package.
This is NOT amodal segmentation: hidden sword and hidden body pixels do not exist.
Polygon ownership is binary, so source anti-aliasing is retained verbatim, not re-matted.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import argparse, hashlib, json, math
import numpy as np
from scipy import ndimage
D=Path(__file__).resolve().parent
DEFAULT_SOURCE=D.parent.parent/'nobunaga_impact_v4/throw_reverse_planted_v2'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def polygon_mask(polygons,size):
    m=Image.new('L',size,0);d=ImageDraw.Draw(m)
    for p in polygons:d.polygon([tuple(x) for x in p],fill=255)
    return np.array(m)>0

def save_rgba(a,p):Image.fromarray(a,'RGBA').save(p)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,default=DEFAULT_SOURCE);args=ap.parse_args();S=args.source.resolve()
    source_rows=json.loads((S/'frame-manifest.json').read_text());annotations=json.loads((D/'segmentation-annotations.json').read_text())
    for sub in ['layers/body','layers/weapon-visible','layers/hand-foreground','masks/body','masks/weapon-visible','masks/hand-foreground','qa/ownership','qa/recomposed','qa/layers']:(D/sub).mkdir(parents=True,exist_ok=True)
    rows=[];tests=[];tiles=[];overview=[]
    for r,ann in zip(source_rows,annotations['frames']):
        k=r['frame'];assert k==ann['frame'];name=f'{k:03}.png';src=S/'frames-native'/name
        im=Image.open(src).convert('RGBA');a=np.array(im);assert im.size==(1800,1700)
        assert sha(src)==r['rgba_sha256']
        # Snap broad hand-drawn blade envelope to actual low-chroma steel pixels.
        rgb=a[:,:,:3].astype('float32');lo=rgb.min(2);hi=rgb.max(2);chroma=hi-lo
        envelope=ndimage.binary_dilation(polygon_mask([ann['weapon_polygons'][0]],im.size),iterations=35 if k==5 else 14)
        steel=envelope&(chroma<(80 if k==5 else 45))&(chroma<hi*(.65 if k==5 else .22))&(hi>(115 if k==11 else 80 if k in [14,15] else 35 if k==5 else 50))&(a[:,:,3]>0)
        labels,n=ndimage.label(steel);cts=np.bincount(labels.ravel());good=cts>50;good[0]=False
        steel=good[labels]
        # Fill dark engravings/interior between the same blade's two measured edges.
        # The dominant-axis scan never grows past the bright/grey envelope extremes.
        bv=np.array(ann['visible_blade_tip_native'])-np.array(ann['blade_base_native'])
        scan=steel if abs(bv[1])>=abs(bv[0]) else steel.T
        for line in scan:
            hits=np.flatnonzero(line)
            if len(hits)>1:line[hits[0]:hits[-1]+1]=True
        steel=ndimage.binary_fill_holes(ndimage.binary_closing(steel,iterations=1))
        steel=ndimage.binary_dilation(steel,iterations=1)&envelope
        hardware=polygon_mask(ann['weapon_polygons'][1:],im.size)
        if k==14:hardware[:,1042:]=False  # Do not assign the adjacent ear/face to the guard.
        hand_envelope=ndimage.binary_dilation(polygon_mask(ann['hand_polygons'],im.size),iterations=3 if k>=12 else 8)
        skin=(rgb[:,:,0]>75)&(rgb[:,:,1]>35)&(rgb[:,:,2]>15)&(rgb[:,:,0]>rgb[:,:,1]*1.07)&(rgb[:,:,1]>rgb[:,:,2]*1.04)&(rgb[:,:,2]>rgb[:,:,1]*.40)&(rgb[:,:,1]>rgb[:,:,0]*.37)
        h=hand_envelope&skin&(a[:,:,3]>0)
        h=ndimage.binary_fill_holes(ndimage.binary_closing(h,iterations=2))
        hl,hn=ndimage.label(h);hc=np.bincount(hl.ravel());keep=np.zeros(len(hc),dtype=bool)
        keep[1+np.argsort(hc[1:])[-len(ann['hand_polygons']):]]=True;h=keep[hl]
        h=ndimage.binary_dilation(h,iterations=1)&hand_envelope&(a[:,:,3]>0)
        w=(steel|hardware)&(a[:,:,3]>0)
        w&=~h;b=~(w|h)
        masks={'body':b,'weapon-visible':w,'hand-foreground':h};parts={};paths={};counts={}
        for key,mask in masks.items():
            layer=np.zeros_like(a);layer[mask]=a[mask];parts[key]=layer
            p=D/'layers'/key/name;save_rgba(layer,p);Image.fromarray(mask.astype('uint8')*255).save(D/'masks'/key/name)
            paths[key]={'path':str(p.relative_to(D)),'sha256':sha(p),'visible_pixels':int(np.count_nonzero(mask&(a[:,:,3]>0))),'alpha_bbox':Image.fromarray(layer).getchannel('A').getbbox()};counts[key]=paths[key]['visible_pixels']
        # Body stores RGB under zero alpha, too. Initialize from it to retain those irrelevant bytes.
        rec=Image.fromarray(parts['body']).copy()
        rec.alpha_composite(Image.fromarray(parts['weapon-visible']));rec.alpha_composite(Image.fromarray(parts['hand-foreground']))
        reconstructed=np.array(rec);diff=np.abs(reconstructed.astype('int16')-a.astype('int16'))
        assert np.array_equal(reconstructed,a),f'RGBA mismatch in {k}'
        assert np.array_equal(sum(x.astype('uint16') for x in parts.values()),a)
        assert np.all(sum(x.astype('uint8') for x in masks.values())==1)
        rec.save(D/'qa/recomposed'/name)
        # Category ownership preview, preserving the source silhouette and alpha.
        colors={'body':(62,153,220),'weapon-visible':(255,197,57),'hand-foreground':(244,90,146)}
        own=np.zeros_like(a)
        for key,mask in masks.items():own[mask,:3]=colors[key];own[mask,3]=a[mask,3]
        save_rgba(own,D/'qa/ownership'/name)
        bg=Image.new('RGBA',im.size,(35,39,47,255));bg.alpha_composite(im)
        mini=bg.convert('RGB').resize((360,340),Image.Resampling.LANCZOS)
        draw=ImageDraw.Draw(mini);draw.text((6,5),f'{k:03} | {k*50}-{(k+1)*50} ms',fill='white');overview.append(mini)
        row=Image.new('RGB',(1200,300),(35,39,47))
        for j,(key,arr) in enumerate([('approved',a),('body',parts['body']),('weapon-visible',parts['weapon-visible']),('hand-foreground',parts['hand-foreground'])]):
            z=Image.new('RGBA',im.size,(35,39,47,255));z.alpha_composite(Image.fromarray(arr));z=z.convert('RGB').resize((300,283),Image.Resampling.LANCZOS);row.paste(z,(j*300,17));ImageDraw.Draw(row).text((j*300+5,3),f'{k:03} {key}',fill='white')
        row.save(D/f'qa/layers/{k:03}.jpg',quality=95);tiles.append(row)
        crop_file=D/'qa/crop-boxes.json'
        if crop_file.exists():
            box=json.loads(crop_file.read_text())[k];cw=box[2]-box[0];ch=box[3]-box[1]
            cc=Image.new('RGB',(cw*3,ch+20),(55,65,78))
            for j,key in enumerate(masks):
                ci=Image.fromarray(parts[key]).crop(box);cb=Image.new('RGBA',ci.size,(55,65,78,255));cb.alpha_composite(ci);cc.paste(cb.convert('RGB'),(j*cw,20));ImageDraw.Draw(cc).text((j*cw+4,4),key,fill='white')
            cc.save(D/f'qa/crop-layers-{k:03}.jpg',quality=97)
        base=np.array(ann['blade_base_native'],float);tip=np.array(ann['visible_blade_tip_native'],float);v=tip-base
        angle=round(math.degrees(math.atan2(v[1],v[0])),6)
        rows.append({'frame':k,'start_ms':r['start_ms'],'duration_ms':r['duration_ms'],'end_ms':r['end_ms'],'canvas':[1800,1700],
            'approved_source':str(src),'approved_source_sha256':sha(src),'root_anchor_native':r['root_anchor_native'],'fixed_sole_contacts_native':r['fixed_sole_contacts_native'],
            'grip_palm_centers_native':r['manual_palm_centers_native_after_warp'],
            'grip_status':'Inherited manual anatomical palm centers; not calibrated runtime sockets. Coordinates are unchanged.',
            'weapon_axis':{'blade_base_native':ann['blade_base_native'],'visible_tip_native':ann['visible_blade_tip_native'],'angle_screen_clockwise_degrees':angle,'angle_math_counterclockwise_degrees':-angle,'axis_definition':'Base to visible tip; image +x right and +y down. Curved blade chord, not rigid transform.','status':'Manual image annotation; advisory only','tip_clipped':ann.get('tip_clipped',False),'occluded_between_grip_and_blade':ann.get('occluded_between_grip_and_blade',False)},
            'layer_paths':paths,'layer_order':['body','weapon-visible','hand-foreground'],'transforms':{key:[1,0,0,0,1,0] for key in masks},'notes':ann.get('notes',[])})
        tests.append({'frame':k,'source_sha256_matches_frozen_manifest':True,'recomposed_rgba_pixel_equal':bool(np.array_equal(reconstructed,a)),'max_channel_error':int(diff.max()),'different_pixels':int(np.count_nonzero(diff.any(2))),'disjoint_complete_ownership':True,'visible_pixel_counts':counts,'transparent_rgb_pixel_count':int(np.count_nonzero((a[:,:,3]==0)&a[:,:,:3].any(2)))})
    sheet=Image.new('RGB',(1440,1360),(35,39,47))
    for k,tile in enumerate(overview):sheet.paste(tile,((k%4)*360,(k//4)*340))
    sheet.save(D/'qa/approved-contact-sheet.jpg',quality=95)
    for page in range(4):
        sheet=Image.new('RGB',(1200,1200),(35,39,47))
        for j in range(4):sheet.paste(tiles[page*4+j],(0,j*300))
        sheet.save(D/f'qa/layer-contact-sheet-{page+1}.jpg',quality=95)
    ownsheet=Image.new('RGB',(1440,1360),(35,39,47))
    for k in range(16):
        own=Image.open(D/f'qa/ownership/{k:03}.png');bg=Image.new('RGBA',own.size,(35,39,47,255));bg.alpha_composite(own);ownsheet.paste(bg.convert('RGB').resize((360,340),Image.Resampling.LANCZOS),((k%4)*360,(k//4)*340))
    ImageDraw.Draw(ownsheet).text((8,8),'BLUE body | GOLD visible weapon | PINK foreground gripping hands',fill='white');ownsheet.save(D/'qa/ownership-contact-sheet.jpg',quality=95)
    manifest={'schema':'nobunaga-reverse-throw-visible-pixel-partition-v1','status':'approved composite preserved; visible-only extraction; no runtime change','frame_count':16,'duration_ms':800,'frame_durations_ms':[50]*16,'canvas':[1800,1700],'source_directory':str(S),'source_manifest_sha256':sha(S/'frame-manifest.json'),
        'layer_order':['body','weapon-visible','hand-foreground'],'compositing':'Start with body RGBA, source-over weapon-visible, then hand-foreground. Identity transforms only. Do not re-register or scale per frame.',
        'mask_semantics':'Binary disjoint ownership of original straight-RGBA pixels. Body mask includes the transparent background for exact byte ownership. Source edge pixels retain original color/alpha, including any flattened edge mixture.',
        'limitations':['Visible-pixel partition only. Body contains transparent holes where sword and gripping hands were cut out. Hidden body and hidden sword are NOT reconstructed.','Weapon is not a complete independently movable sprite. Repositioning any layer exposes holes and may reveal original edge mixtures.','Manual polygon boundaries are semantic approximations at contact edges; QA images make them reviewable. Pixel equality proves composite preservation, not perfect semantic segmentation.','Scabbard, costume fittings, non-gripping/throwing hands, and unclassified source artifacts remain in body.','Frame 005 has torso-occluded sword sections and separate visible hilt/blade regions. Frame 015 has a top-clipped blade tip.','Angles and palm coordinates are advisory art metadata, not authored physics, hitboxes, events, enemy attachment tracks or runtime sockets.','All approved source defects, including blade-removal edge remnants in some recovery frames, are preserved verbatim.'],
        'files':{'annotations':'segmentation-annotations.json','frames':'frame-manifest.json','validation':'validation.json','script':'build_layers.py','readme':'README.md','contact_sheets':['qa/approved-contact-sheet.jpg','qa/ownership-contact-sheet.jpg']+[f'qa/layer-contact-sheet-{n}.jpg' for n in range(1,5)]}}
    (D/'layer-manifest.json').write_text(json.dumps(manifest,indent=2));(D/'frame-manifest.json').write_text(json.dumps(rows,indent=2));
    (D/'validation.json').write_text(json.dumps({'all_16_recompose_pixel_exact':all(t['recomposed_rgba_pixel_equal'] for t in tests),'source_files_read_only':True,'movement_or_geometry_changed':False,'duration_ms':800,'frame_count':16,'layer_file_count':48,'mask_file_count':48,'rgba_equality_definition':'All four channels at every pixel; source hidden RGB retained by initializing with body.','semantic_quality':'Manual envelopes and color/scanline refinement inspected at native close-up; dark outline/contact classifications remain approximate. No complete or independently movable weapon is claimed.','frames':tests},indent=2))
    files=sorted(p for p in D.rglob('*') if p.is_file() and p.name!='SHA256SUMS')
    (D/'SHA256SUMS').write_text(''.join(f'{sha(p)}  {p.relative_to(D)}\n' for p in files))
    print(json.dumps({'frames':16,'rgba_exact':True,'layer_files':48,'mask_files':48,'duration_ms':800,'output':str(D)}))
if __name__=='__main__':main()
