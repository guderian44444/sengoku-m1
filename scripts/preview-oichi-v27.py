#!/usr/bin/env python3
"""Offline asset composites at actual148px world scale, not viewport captures.
Reproduces the current body anchor, weapon scale/angle, bowstring and hand layers.
Only writes review outputs; never alters original source art or runtime selection.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import hashlib
import json
import math
from PIL import Image,ImageDraw,ImageChops,ImageOps

ROOT=Path(__file__).resolve().parents[1]
WEAPONS=ROOT/'game/assets/v22/weapons'
SPECS=json.loads((WEAPONS/'registration.json').read_text())['items']
SIZE=(400,350)
ORIGIN=(200,275)


@lru_cache(maxsize=64)
def source(path):
    image=Image.open(path);image.load()
    if image.mode!='RGBA':raise ValueError('Native RGBA required')
    return image


def transform(image,scale,tx,ty):
    return image.transform(SIZE,Image.Transform.AFFINE,(1/scale,0,-tx/scale,0,1/scale,-ty/scale),Image.Resampling.BILINEAR)


def compose(folder,frame,height,weapon_id,body_only=False):
    x,y,w,h=frame['rect']
    raw=source(folder/frame['file']).crop((x,y,x+w,y+h))
    body=raw.copy()
    if 'clip_polygon' in frame:
        mask=Image.new('L',body.size)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in frame['clip_polygon']],fill=255)
        body.putalpha(ImageChops.multiply(body.getchannel('A'),mask))
    scale=height/frame['body_height'];foot=frame['foot']
    hand=[(frame['hand'][i]-foot[i])*scale for i in range(2)]
    tx,ty=ORIGIN[0]-foot[0]*scale,ORIGIN[1]-foot[1]*scale
    body=transform(body,scale,tx,ty)
    if body_only or not frame.get('weapon_visible',True):return body
    spec=SPECS[weapon_id]
    bow_scale=spec.get('world_length',175)*height/148/spec['length']
    angle=math.radians(frame['weapon_angle']);c,s=math.cos(angle),math.sin(angle)
    grip=spec['grip'];hx,hy=ORIGIN[0]+hand[0],ORIGIN[1]+hand[1]
    inverse=(c/bow_scale,s/bow_scale,grip[0]-(c*hx+s*hy)/bow_scale,
             -s/bow_scale,c/bow_scale,grip[1]-(-s*hx+c*hy)/bow_scale)
    bow=source(WEAPONS/spec['file']).transform(SIZE,Image.Transform.AFFINE,inverse,Image.Resampling.BILINEAR)
    def endpoint(p):return (hx+bow_scale*((p[0]-grip[0])*c-(p[1]-grip[1])*s),hy+bow_scale*((p[0]-grip[0])*s+(p[1]-grip[1])*c))
    points=[endpoint(spec['tip_top']),endpoint(spec['tip_bottom'])]
    if 'second_hand' in frame and not frame.get('weapon_behind',False):
        points.insert(1,tuple(ORIGIN[i]+(frame['second_hand'][i]-foot[i])*scale for i in range(2)))
    ImageDraw.Draw(bow).line(points,fill=(230,222,189,219),width=1)
    out=Image.alpha_composite(bow,body) if frame.get('weapon_behind',False) else Image.alpha_composite(body,bow)
    occlusion=Image.new('RGBA',raw.size)
    for ox,oy,ow,oh in frame.get('hand_occluders',[]):
        box=(max(0,ox),max(0,oy),min(w,ox+ow),min(h,oy+oh))
        if box[2]>box[0] and box[3]>box[1]:occlusion.paste(raw.crop(box),(box[0],box[1]))
    return Image.alpha_composite(out,transform(occlusion,scale,tx,ty))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--registration',type=Path,required=True)
    parser.add_argument('--sources',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--height',type=float,default=148)
    parser.add_argument('--weapon',default='bow_awase_yumi')
    parser.add_argument('--body-only',action='store_true')
    parser.add_argument('--skip-stale',action='store_true')
    args=parser.parse_args()
    registration=json.loads(args.registration.read_text())
    args.out.mkdir(parents=True,exist_ok=True)
    report={'type':'offline_asset_composite_not_game_capture','height':args.height,'weapon':args.weapon,'clips':{},'skipped_stale':[]}
    for clip,item in registration['clips'].items():
        stale=any(hashlib.sha256((args.sources/frame['file']).read_bytes()).hexdigest()!=frame['source_sha256'] for frame in item['frames'])
        if stale:
            if args.skip_stale:report['skipped_stale'].append(clip);continue
            raise ValueError(f'{clip}: source changed after registration; remeasure/rebuild')
        page=Image.new('RGBA',(1200,740),(104,104,104,255));draw=ImageDraw.Draw(page)
        draw.text((16,12),f'{clip} / {args.height:g}px anatomical world height / offline asset composite, not viewport capture',fill='white')
        records=[]
        for index,frame in enumerate(item['frames']):
            card=compose(args.sources,frame,args.height,args.weapon,args.body_only)
            px,py=index%3*400,40+index//3*350
            draw.line((px+40,py+ORIGIN[1],px+360,py+ORIGIN[1]),fill=(65,65,65),width=1)
            page.alpha_composite(card,(px,py))
            draw.text((px+15,py+305),f'frame {index+1} / anatomical ruler {frame["body_height"]}px',fill='white')
            records.append({'frame':index+1,'file':frame['file'],'bounds':card.getbbox(),'body_height':frame['body_height']})
        page.convert('RGB').save(args.out/f'{clip}.png')
        report['clips'][clip]=records
    (args.out/'preview-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Wrote {len(report["clips"])} actual-scale asset composite sheets; skipped stale: {report["skipped_stale"]}')


if __name__=='__main__':main()
