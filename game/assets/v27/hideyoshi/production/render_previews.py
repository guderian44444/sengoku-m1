#!/usr/bin/env python3
"""Offline asset compositor. These are NOT gameplay recordings."""
from pathlib import Path
import os
import argparse,json,math,hashlib
import numpy as np
from PIL import Image,ImageDraw
B=Path(os.environ.get("HIDEYOSHI_BUILD_ROOT",str(Path(__file__).resolve().parent)));A=B/'package/runtime';R=Path(os.environ.get('HIDEYOSHI_WEAPONS_DIR',str(B.parent/'sengoku_weapon_expansion_20261012/game/assets/v22/weapons')));C=1024;ROOT=np.array([512.,760.]);BH=350.
WR=json.loads((R/'registration.json').read_text())['items']
# Measured guard/mounting constraints for three review equipment. Source pixel coords.
HILTS={'sword_uchigatana':{'guard':[186,582],'handle':[604,821]},'sword_kanesada_mino':{'guard':[440,1065],'handle':[1090,1467]},'sword_okanehira':{'guard':[80,1190],'handle':[1220,1494]}}

def affine(im,scale,angle,anchor,origin):
 c,s=math.cos(angle),math.sin(angle);inv=np.array([[c,s],[-s,c]])/scale;t=np.array(anchor)-inv@np.array(origin)
 return im.transform((C,C),Image.Transform.AFFINE,(*inv[0],t[0],*inv[1],t[1]),Image.Resampling.BICUBIC)
def compose(f,weapon_id,debug=False):
 body=Image.open(A/f['file']).convert('RGBA');fg=Image.open(A/f['hand_foreground_file']).convert('RGBA');bs=BH/f['body_height'];root=np.array(f['foot']);hand=ROOT+(np.array(f['hand'])-root)*bs
 b=affine(body,bs,0,root,ROOT);hands=affine(fg,bs,0,root,ROOT);w=WR[weapon_id];wi=Image.open(R/w['file']).convert('RGBA');scale=w.get('world_length',115)/155*BH/w['length'];grip=np.array(w['grip'],float);angle=math.radians(f['weapon_angle']);report={'weapon':weapon_id,'world_length':w.get('world_length',115),'body_sha256':f['body_sha256'],'hand':hand.tolist(),'angle':f['weapon_angle'],'grip':grip.tolist(),'second_hand_fit':None,'mode':f['main_weapon_state']}
 if f.get('two_handed'):
  left=ROOT+(np.array(f['left_hand'])-root)*bs;delta=hand-left;angle=math.atan2(delta[1],delta[0])+math.pi/2;span=np.linalg.norm(delta)/scale;lo,hi=HILTS[weapon_id]['handle'];margin=6/scale
  # Shift only along existing handle, preserving item scale and artwork.
  miny=lo+margin;maxy=hi-margin-span
  fit=miny<=maxy
  if fit:grip[1]=np.clip(grip[1],miny,maxy)
  report.update({'grip':grip.tolist(),'angle':math.degrees(angle),'weapon_grip_offset_normalized':((grip-np.array(w['grip']))/w['length']).tolist(),'second_hand_fit':bool(fit),'secondary_handle_y':float(grip[1]+span),'handle_limits':[lo,hi],'hand_span_world':float(np.linalg.norm(delta)*155/BH)})
 if f['weapon_visible'] and f['main_weapon_state'] not in ['sheathed','hidden','sheathed_transition','drawing','resheathing']:
  rotation=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]])
  tip=hand+rotation@(np.array(w['tip_top'])-grip)*scale
  report['exposed_tip_world_preview']=tip.tolist();report['tip_ground_clearance_preview']=float(ROOT[1]-tip[1])
 state=f['main_weapon_state'];layer=Image.new('RGBA',(C,C))
 if state in ['sheathed','hidden']:
  if state=='sheathed' and f.get('scabbard_mouth'):
   mount=HILTS[weapon_id];arr=np.asarray(wi).copy();arr[:int(mount['guard'][1])-5,:,3]=0;wi=Image.fromarray(arr)
   mouth=ROOT+(np.array(f['scabbard_mouth'])-root)*bs;angle=math.radians(f.get('scabbard_direction_deg',135));layer=affine(wi,scale,angle,mount['guard'],mouth);report['sheath_mode']='separate hilt-only crop attached at authored empty-scabbard mouth'
 elif f['weapon_visible']:
  layer=affine(wi,scale,angle,grip,hand)
  if state in ['sheathed_transition','drawing','resheathing'] and f.get('scabbard_mouth'):
   # Hide only blade portion beyond the scabbard entrance plane.
   mouth=ROOT+(np.array(f['scabbard_mouth'])-root)*bs
   direction=np.array([math.sin(angle),-math.cos(angle)])
   yy,xx=np.indices((C,C));inside=(xx-mouth[0])*direction[0]+(yy-mouth[1])*direction[1]>0
   pixels=np.asarray(layer).copy();pixels[inside,3]=0;layer=Image.fromarray(pixels)
   report['sheath_plane']={'mouth':mouth.tolist(),'direction':direction.tolist(),'mode':'tip-side half-plane clipped into scabbard'}
 result=Image.new('RGBA',(C,C))
 if f.get('weapon_behind'):result.alpha_composite(layer)
 result.alpha_composite(b)
 if not f.get('weapon_behind'):result.alpha_composite(layer)
 result.alpha_composite(hands)
 alpha=np.asarray(layer)[:,:,3];report['weapon_edge_touch']=bool((alpha[0]>64).any() or (alpha[-1]>64).any() or (alpha[:,0]>64).any() or (alpha[:,-1]>64).any())
 report['body_edge_touch']=bool((np.asarray(b)[[0,-1],:,3]>64).any() or (np.asarray(b)[:,[0,-1],3]>64).any())
 if debug:
  d=ImageDraw.Draw(result);d.ellipse((hand[0]-4,hand[1]-4,hand[0]+4,hand[1]+4),fill='red')
 return result,report

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--clips',nargs='+');ap.add_argument('--weapons',nargs='+',default=['sword_uchigatana']);args=ap.parse_args();reg=json.loads((A/'registration.proposed.json').read_text());names=args.clips or list(reg['clips']);reports={}
 out=Path(os.environ.get('HIDEYOSHI_PREVIEW_DIR',str(B/'previews')));out.mkdir(exist_ok=True)
 for name in names:
  fs=reg['clips'][name]['frames'];sheet=Image.new('RGBA',(C*3,C*2),'#858580');reports[name]={}
  for wid in args.weapons:
   arr=[];rows=[];wd=out/'frames'/name/wid;wd.mkdir(parents=True,exist_ok=True)
   for i,f in enumerate(fs):
    comp,rep=compose(f,wid);bg=Image.new('RGBA',(C,C),'#858580');bg.alpha_composite(comp);ImageDraw.Draw(bg).text((20,20),f'{name} {i+1}/6 | {wid} | OFFLINE ASSET COMPOSITE',fill='white');bg.convert('RGB').save(wd/f'{i+1:02d}.png');arr.append(bg.convert('RGB'));rows.append(rep)
    if wid==args.weapons[0]:sheet.alpha_composite(bg,(i%3*C,i//3*C))
   arr[0].save(out/f'{name}-{wid}.gif',save_all=True,append_images=arr[1:],duration=150,loop=0);reports[name][wid]=rows
  sheet.convert('RGB').save(out/f'{name}-contact.jpg',quality=92)
  print(name,'preview',flush=True)
 rp=B/'qa/composite-report.json';existing=json.loads(rp.read_text()) if rp.exists() else {};existing.update(reports);rp.write_text(json.dumps(existing,indent=2)+'\n')
if __name__=='__main__':main()
