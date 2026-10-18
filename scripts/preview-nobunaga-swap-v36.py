"""Preview repaired native layers with the existing complete equipment textures."""
from pathlib import Path
import json, math
import numpy as np
import cv2
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'artifacts/basic36-nobunaga16-git-20261016/deliveries/basic36-nobunaga16-hires-20261016/nobunaga'
OUT=ROOT/'prototypes/nobunaga-repair-v36/swap-review'
WEAPONS=ROOT/'game/assets/v22/weapons'

def main():
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--clip',default='charge_release',choices=['charge_release','grab_start','throw_forward','throw_reverse']);args=parser.parse_args()
    clip=args.clip;frames=json.loads((SOURCE/clip/'delivery-frames.json').read_text())
    overrides=json.loads((OUT.parent/'source-overrides.json').read_text())
    bindings={f['frame']:f for f in overrides['frame_bindings'] if f['clip']==clip}
    items=json.loads((WEAPONS/'registration.json').read_text())['items']
    sem=json.loads((SOURCE/clip/'layers-visible-manifest.json').read_text()) if (SOURCE/clip/'layers-visible-manifest.json').exists() else []
    tiles=[];movie=[]
    for i,f in enumerate(frames):
        if i not in bindings:continue
        binding=bindings[i]
        body=Image.open(OUT.parent/binding['body']).convert('RGBA')
        hands=Image.open(OUT.parent/binding['hands']).convert('RGBA')
        if sem:
            grip=np.array(sem[i]['grip_art_px']);base=np.array(sem[i]['blade_base_art_px']);tip=np.array(sem[i]['blade_tip_art_px'])
        else:
            grip=np.array(f['grip_art_native_px']['right']);base=np.array(f['weapon_axis']['blade_base_native']);tip=np.array(f['weapon_axis']['visible_tip_native'])
        direction=(tip-base)/np.linalg.norm(tip-base)
        root=np.array(f['root_art_native_px']);scale=155/914
        row=Image.new('RGB',(1200,340),'#4b5057')
        for col,weapon_id in enumerate(['sword_uchigatana','sword_heshikiri','sword_dojigiri']):
            item=items[weapon_id];weapon=np.array(Image.open(WEAPONS/item['file']).convert('RGBA'))
            size=115/float(item['length'])/scale
            co=-direction[1]*size;si=direction[0]*size
            matrix=np.array([[co,-si,0],[si,co,0]],dtype=float)
            matrix[:,1]*=binding.get('weapon_longitudinal_scale',1.0)
            matrix[:,2]=grip-matrix[:,:2]@np.array(item['grip'])
            matrix*=scale;matrix[:,2]+=np.array([200,290])-root*scale
            rendered_weapon=Image.fromarray(cv2.warpAffine(weapon,matrix,(400,340),flags=cv2.INTER_LINEAR))
            actor=Image.new('RGBA',(400,340))
            pos=(round(200-root[0]*scale),round(290-root[1]*scale))
            scaled_body=body.resize((round(body.width*scale),round(body.height*scale)),Image.Resampling.LANCZOS)
            scaled_hands=hands.resize(scaled_body.size,Image.Resampling.LANCZOS)
            behind=binding['weapon_behind_body']
            if behind: actor.alpha_composite(rendered_weapon)
            actor.alpha_composite(scaled_body,pos)
            if not behind: actor.alpha_composite(rendered_weapon)
            actor.alpha_composite(scaled_hands,pos)
            row.paste(actor,(col*400,0),actor)
            ImageDraw.Draw(row).text((col*400+5,5),f'{clip} {i:03} {weapon_id}',fill='white')
        tiles.append(row);movie.append(row)
    sheet=Image.new('RGB',(1200,len(tiles)*340),'#303030')
    for i,tile in enumerate(tiles):sheet.paste(tile,(0,i*340))
    sheet.save(OUT/f'{clip}-weapons.jpg',quality=94)
    movie[0].save(OUT/f'{clip}-weapons.gif',save_all=True,append_images=movie[1:],duration=[f['duration_ms'] for i,f in enumerate(frames) if i in bindings],loop=0)
    print(f'Previewed {len(tiles)} repaired frames, three complete weapons at 155px standing ruler')

if __name__=='__main__':main()
