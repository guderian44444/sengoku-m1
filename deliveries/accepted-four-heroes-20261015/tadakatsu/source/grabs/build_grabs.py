#!/usr/bin/env python3
"""Deterministic source extraction, registration, layered previews and metadata.
No generated poses are interpolated, reversed, warped or optical-flowed.
"""
from pathlib import Path
import argparse,json,hashlib
import math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parent
SOURCE=ROOT/'references'
W,H=640,340
BASELINE=296
ANCHOR_X=180
# Fixed per SOURCE SHEET, measured against the approved identity's helmet/antler
# silhouette, then visually checked against its breastplate and the main pack.
# Never normalize the height of each action frame or each pose's bounding box.
SHEET_SCALE={'grab_start':0.410,'grab_hold':0.440,'grab_hit_1':0.500,'grab_hit_2':0.500,'throw_forward':0.490,'throw_reverse':0.535}
HEAD_REFERENCE={'identity_top_to_chin_px':140,'identity_antler_span_px':130,'canonical_identity_scale':160/370,'canonical_head_height_px':140*160/370,'canonical_antler_span_px':130*160/370,'source_first_pose_measurements':{'grab_start':{'top_to_chin':140,'antler_span':146},'grab_hold':{'top_to_chin':126,'antler_span':140},'grab_hit_1':{'top_to_chin':115,'antler_span':118},'grab_hit_2':{'top_to_chin':114,'antler_span':121},'throw_forward':{'top_to_chin':116,'antler_span':123},'throw_reverse':{'top_to_chin':106,'antler_span':105}},'method':'Manual helmet/antler landmarks, balanced against chest scale. Fixed sheet-level factor; minor generated proportion differences remain.'}

def clean_component(im,label=None):
    arr=np.array(im.convert('RGBA')); core=arr[:,:,3]>=96
    labs,n=ndi.label(core)
    if label is None:
        ids=np.bincount(labs.ravel());ids[0]=0;label=int(ids.argmax())
    region=labs==label
    region=ndi.binary_dilation(region,iterations=2)
    arr[:,:,3]=np.where(region & (arr[:,:,3]>=10),arr[:,:,3],0)
    return Image.fromarray(arr)

def components(im):
    a=np.array(im)[:,:,3];lab,n=ndi.label(a>=96);out=[]
    for i,s in enumerate(ndi.find_objects(lab)):
        area=int((lab[s]==i+1).sum())
        if area<5000:continue
        box=[s[1].start,s[0].start,s[1].stop,s[0].stop]
        # Mask only the actual connected character, never a neighboring grid cell.
        mask=ndi.binary_dilation(lab==i+1,iterations=2)
        ar=np.array(im);ar[:,:,3]=np.where(mask & (a>=10),a,0)
        bb=Image.fromarray(ar[:,:,3]).getbbox()
        crop=Image.fromarray(ar).crop(bb)
        out.append({'box':list(bb),'image':crop,'area':area,'cy':(box[1]+box[3])/2,'cx':(box[0]+box[2])/2})
    # Layout rows are separated by > 100px; allow sprite centers varying within row.
    out.sort(key=lambda p:p['cy'])
    rows=[]
    for v in out:
        if not rows or abs(v['cy']-np.mean([q['cy'] for q in rows[-1]]))>150:rows.append([])
        rows[-1].append(v)
    return [v for row in rows for v in sorted(row,key=lambda q:q['cx'])]

def foot_anchor(im,side='left'):
    a=np.array(im)[:,:,3]>=96
    ys,xs=np.where(a)
    bottom=ys.max()
    # Find separate boot contacts in the lowest 8 px of the opaque silhouette.
    xx=np.where(a[max(0,bottom-7):bottom+1].any(axis=0))[0]
    groups=np.split(xx,np.where(np.diff(xx)>14)[0]+1)
    groups=[g for g in groups if len(g)>5]
    g=groups[-1] if side=='right' else groups[0]
    return [float((g.min()+g.max())/2),float(bottom)]

def contours(im):
    mask=(np.array(im)[:,:,3]>=96).astype('uint8')
    # Exact alpha boundary pixels, in row-major order, not a convex box.
    edge=mask & ~ndi.binary_erosion(mask)
    ys,xs=np.where(edge)
    return {'encoding':'unordered boundary pixels xy; authoritative contour is character alpha','points':np.stack([xs,ys],axis=1).tolist()}

def spear_layer(angle=24,rotate_with_body=False):
    im=clean_component(Image.open(SOURCE/'spear_suyari.png'))
    # Complete 270px tip-to-butt spear, pivoted at its verified grip. Positive
    # angles lean its tip left. The stowed grip is behind the torso at (220,198).
    ws=270/962;t=math.radians(angle);co,si=math.cos(t),math.sin(t)
    a,b=co/ws,-si/ws;d,e=si/ws,co/ws;gx,gy=220,198
    return im.transform((W,H),Image.Transform.AFFINE,(a,b,188-a*gx-b*gy,d,e,621-d*gx-e*gy),Image.Resampling.BICUBIC)

def build(name,source,durations,events,side='left'):
    out=ROOT/name;out.mkdir(exist_ok=True)
    for d in ['character','weapon_back','composite','source_crops']:(out/d).mkdir(exist_ok=True)
    im=Image.open(source).convert('RGBA');cs=components(im)
    assert len(cs)==len(durations),(len(cs),len(durations))
    scale=SHEET_SCALE[name]
    weapon=spear_layer();frames=[];md=[];transparent_sheet=Image.new('RGBA',(W*len(cs),H))
    for i,c in enumerate(cs):
        crop=c['image'];crop.save(out/'source_crops'/f'{i:02d}.png')
        scaled=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        anchor=foot_anchor(scaled,side)
        actual_support=anchor.copy()
        if name=='throw_reverse':
            # Explicitly track the same left-on-sheet boot through the turn.
            # Different boot sole heights make a lowest-row heuristic switch feet.
            source_foot_x=[130,600,995,99,499,982,190,568,950][i]
            anchor[0]=(source_foot_x-c['box'][0])*scale
            weapon=spear_layer([24,18,10,0,-8,-16,-24,-24,-24][i],True)
        dx=round(ANCHOR_X-anchor[0]);dy=round(BASELINE-anchor[1])
        char=Image.new('RGBA',(W,H));char.alpha_composite(scaled,(dx,dy))
        char.save(out/'character'/f'{i:02d}.png');weapon.save(out/'weapon_back'/f'{i:02d}.png')
        comp=Image.alpha_composite(weapon,char);comp.save(out/'composite'/f'{i:02d}.png')
        transparent_sheet.alpha_composite(char,(i*W,0))
        bg=Image.new('RGBA',(W,H),(29,34,42,255));d=ImageDraw.Draw(bg)
        d.line([(20,BASELINE),(620,BASELINE)],fill=(82,91,98),width=1)
        bg=Image.alpha_composite(bg,comp)
        d=ImageDraw.Draw(bg);d.text((20,14),f'{name}   {i+1}/{len(cs)}   {durations[i]} ms',fill=(230,230,230))
        frames.append(bg.convert('RGB'))
        md.append({'index':i,'source_rect':c['box'],'duration_ms':durations[i],'scale':scale,'translation':[dx,dy],'support_foot':[round(actual_support[0]+dx,2),round(actual_support[1]+dy,2)],'registration_anchor':[round(anchor[0]+dx,2),round(anchor[1]+dy,2)],'support_side':side,'registration_mode':'tracked left boot x plus independently measured grounded sole y' if name=='throw_reverse' else 'measured support boot','yaw_degrees':[45,90,135,180,225,270,285,300,315][i] if name=='throw_reverse' else 45,'weapon_rotation_degrees':[24,18,10,0,-8,-16,-24,-24,-24][i] if name=='throw_reverse' else 24,'alpha_bbox':list(char.getbbox()),'contours':contours(char),'events':events.get(i,[])})
    # One shared GIF palette prevents changing colors between frames.
    montage=Image.new('RGB',(W*len(frames),H))
    for i,fr in enumerate(frames):montage.paste(fr,(W*i,0))
    pal=montage.quantize(colors=255,method=Image.Quantize.MEDIANCUT)
    gif=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in frames]
    gif[0].save(out/f'{name}.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,disposal=2,optimize=False)
    gif[0].save(out/f'{name}-slow.gif',save_all=True,append_images=gif[1:],duration=[d*3 for d in durations],loop=0,disposal=2,optimize=False)
    thumb=Image.new('RGB',(W*3,H*((len(frames)+2)//3)),(29,34,42))
    for i,fr in enumerate(frames):thumb.paste(fr,((i%3)*W,(i//3)*H))
    thumb.save(out/f'{name}-contact.png');transparent_sheet.save(out/f'{name}-character-sheet.png')
    meta={'action':name,'source':str(Path(source).name),'canvas':[W,H],'preview_body_height_target':160,'floor_y':BASELINE,'fixed_sheet_scale':scale,'scale_reference':HEAD_REFERENCE,'frame_count':len(cs),'duration_ms':sum(durations),'durations_ms':durations,'loop_preview':True,'runtime_loop':name=='grab_hold','weapon_layer':'weapon_back','weapon_length_px':270,'weapon_grip_canvas':[220,198],'weapon_mode':'stowed behind body; complete verified spear; progressive tilt during reverse turn','interpolation':'none; distinct generated keyframes only','normalization':'fixed per-sheet scale from approved helmet/antler and chest comparison, never per-pose bbox; measured opaque support boot anchored AFTER resize','frames':md,'qa_limits':['Generated anatomy and costume detail can vary slightly between poses.','Preview loops restart the action; runtime transitions are not integrated.','Opponent contact is metadata; no opponent is baked into character layers.','No runtime or game repository was modified.']}
    if name=='grab_hit_2' and Path(source).name=='grab_hit_1-source.png':meta.update(owner_revision='Use first knee pose set for both; second duration600ms',contact_start_ms=sum(durations[:4]))
    (out/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
    print(json.dumps({'action':name,'frames':len(cs),'duration_ms':sum(durations),'path':str(out/f'{name}.gif'),'scale':scale,'source_bboxes':[c['box'] for c in cs]}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('source');p.add_argument('--durations',required=True);p.add_argument('--events',default='{}');p.add_argument('--support',default='left');args=p.parse_args()
    build(args.name,args.source,[int(x) for x in args.durations.split(',')],{int(k):v for k,v in json.loads(args.events).items()},args.support)
