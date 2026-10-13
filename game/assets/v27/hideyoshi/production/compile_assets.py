#!/usr/bin/env python3
"""Compile measured native body crops and hand foreground layers, never repaint art.
Source polygons isolate neighboring drawings; raw sources remain immutable.
"""
from pathlib import Path
import os
import argparse,hashlib,json,math,shutil
import numpy as np
from PIL import Image,ImageDraw
B=Path(os.environ.get("HIDEYOSHI_BUILD_ROOT",str(Path(__file__).resolve().parent)));OUT=B/'package/runtime';QA=B/'qa'
TWO={'heavy1','heavy2','upper_heavy','ground_slam','charged_upper','charged_slam','air_heavy','mixed_finisher','guard','charge_upper','charge_slam','special_3'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def pt(v,org):return [round(float(v[0])-org[0],4),round(float(v[1])-org[1],4)]
def checkpt(p,size,label):
 assert 0<=p[0]<size[0] and 0<=p[1]<size[1],(label,p,size)
def compile_clip(name):
 mp=B/'metadata'/f'{name}.authored.json';m=json.loads(mp.read_text());frames=[];evidence=[]
 adjp=B/'metadata/review_adjustments.json';adj=json.loads(adjp.read_text()).get('clips',{}).get(name,{}) if adjp.exists() else {};order=adj.get('source_frame_order',list(range(1,7)))
 for i,source_index in enumerate(order):
  f=dict(m['frames'][source_index-1])
  if str(i+1) in adj.get('angles',{}):f['sword_angle_deg']=adj['angles'][str(i+1)]
  source=f.get('source',m['source']);sp=B/source;im=Image.open(sp).convert('RGBA');rawhash=sha(sp)
  rect=f.get('source_rect',f.get('cell_rect'));assert rect is not None,(name,i,'no rect')
  x,y,w,h=map(int,rect);root=f.get('root',f.get('foot'));hand=f.get('right_hand_grip') or f.get('right_hand_position') or f.get('right_hand');left=f.get('left_hand_position',f.get('left_hand'))
  assert root and hand and left,(name,i)
  poly=f.get('source_region_polygon',f.get('clip_polygon'))
  # Explicit polygons are in full-source pixels. They do not invent transparency holes.
  selected=im.copy()
  if poly:
   sel=Image.new('L',im.size);ImageDraw.Draw(sel).polygon([tuple(p) for p in poly],fill=255)
   aa=np.asarray(selected).copy();aa[:,:,3]=np.minimum(aa[:,:,3],np.asarray(sel));selected=Image.fromarray(aa)
  crop=selected.crop((x,y,x+w,y+h));
  # Include authored virtual root without changing its anatomical position.
  pad=4;lo_x=min(0,math.floor(root[0]-x)-pad);lo_y=min(0,math.floor(root[1]-y)-pad)
  hi_x=max(w,math.ceil(root[0]-x)+pad+1);hi_y=max(h,math.ceil(root[1]-y)+pad+1)
  body=Image.new('RGBA',(hi_x-lo_x+2*pad,hi_y-lo_y+2*pad));off=[pad-lo_x,pad-lo_y];body.alpha_composite(crop,tuple(off));org=[x-off[0],y-off[1]]
  rel=f'body/{name}/{i+1:02d}.png';dest=OUT/rel;dest.parent.mkdir(parents=True,exist_ok=True);body.save(dest)
  locroot=pt(root,org);lochand=pt(hand,org);locleft=pt(left,org)
  for label,v in [('root',locroot),('right',lochand),('left',locleft)]:checkpt(v,body.size,f'{name}/{i+1}/{label}')
  mask=Image.new('L',body.size);draw=ImageDraw.Draw(mask);oc=[]
  for o in f.get('hand_occluders',[])+f.get('body_foreground_occluders',[])+f.get('foreground_occluders',[]):
   if isinstance(o,list):o={'rect':o}
   if 'polygon' in o:
    p=[pt(q,org) for q in o['polygon']];draw.polygon([tuple(v) for v in p],fill=255);xs=[v[0] for v in p];ys=[v[1] for v in p];r=[min(xs),min(ys),max(xs)-min(xs)+1,max(ys)-min(ys)+1]
   else:
    rx,ry,rw,rh=o['rect'];r=[rx-org[0],ry-org[1],rw,rh];draw.rectangle((r[0],r[1],r[0]+rw,r[1]+rh),fill=255)
   oc.append([round(v,4) for v in r])
  a=np.asarray(body).copy();a[:,:,3]=np.minimum(a[:,:,3],np.asarray(mask));foreground=Image.fromarray(a);frel=f'layers/hands/{name}/{i+1:02d}.png';fp=OUT/frel;fp.parent.mkdir(parents=True,exist_ok=True);foreground.save(fp)
  if name=='guard' and i==0:f['weapon_behind']=False
  two=bool(f.get('two_handed',name in TWO and not(name=='special_3' and i<2)))
  height=float(f.get('body_height',f.get('body_height_px',f.get('anatomical_height_px',m.get('body_height',0)))));assert height>=280,(name,i,height)
  angle=f.get('sword_angle_deg',f.get('weapon_angle'))
  if angle is None and two:
   d=np.array(hand)-np.array(left);angle=math.degrees(math.atan2(d[1],d[0]))+90
  if angle is None and f.get('weapon_visible') is False:angle=0
  assert angle is not None,(name,i,'no angle')
  state=f.get('main_weapon_state',m.get('main_weapon_state','drawn'));visible=bool(f.get('weapon_visible',state not in ['sheathed','hidden']))
  rf={'file':rel,'rect':[0,0,*body.size],'foot':locroot,'body_height':height,'hand':lochand,'right_hand':lochand,'left_hand':locleft,'weapon_angle':float(angle),'weapon_behind':bool(f.get('weapon_behind',False)),'weapon_visible':visible,'weapon_grounded':False,'two_handed':two,'hand_occluders':oc,'hand_foreground_file':frel,'fan_state':f.get('fan_state',m.get('fan_state','stowed')),'main_weapon_state':state,'frame_phase':f.get('phase',f.get('frame_phase',str(i+1))),'source':{'file':source,'sha256':rawhash,'rect':rect,'polygon':poly,'body_origin_in_source':org,'authored_metadata_sha256':sha(mp)},'body_sha256':sha(dest)}
  rf['authored_evidence']={k:v for k,v in f.items() if any(token in k for token in ['confidence','visibility','rationale','reference','evidence','validated','inferred','notes'])}
  rf['source']['source_frame_index']=source_index
  if two:rf['second_hand']=locleft
  for key in ['scabbard_mouth','scabbard_tip']:
   if f.get(key):rf[key]=pt(f[key],org)
  for key in ['scabbard_direction_deg','scabbard_mouth_visibility','left_hand_visibility','left_hand_anchor_method','left_hand_anchor_confidence','left_hand_anchor_evidence','two_hand_axis_validated','left_hand_center_confidence','two_hand_axis_confidence','left_hand_anchor_reference','left_hand_anchor_rationale','measurement_confidence','attack_direction','approved_contact_number','root_kind','root_type','sheathed_layer_note','body_foreground_occluders']:
   if key in f:rf[key]=f[key]
  frames.append(rf);evidence.append({'frame':i+1,'source_sha256':rawhash,'body_sha256':sha(dest),'native_pixels_preserved':True,'source_polygon_applied':bool(poly),'dimensions':body.size})
 # Native pixels on an optional atlas; cell may exceed512 to preserve big authored sources.
 cw=max(Image.open(OUT/f['file']).width for f in frames)+16;ch=max(Image.open(OUT/f['file']).height for f in frames)+16
 atlas=Image.new('RGBA',(cw*3,ch*2));regions=[]
 for i,f in enumerate(frames):
  im=Image.open(OUT/f['file']);xy=[i%3*cw+8,i//3*ch+8];atlas.alpha_composite(im,tuple(xy));regions.append({'frame':i+1,'rect':[*xy,*im.size]})
 ap=OUT/'sheets'/f'{name}.png';ap.parent.mkdir(exist_ok=True);atlas.save(ap)
 return {'frames':frames,'native_sheet':{'file':f'sheets/{name}.png','cell':[cw,ch],'regions':regions},'metadata_source':str(mp.relative_to(B))},evidence

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--clips',nargs='+',required=True);args=ap.parse_args();OUT.mkdir(parents=True,exist_ok=True)
 regp=OUT/'registration.proposed.json';reg=json.loads(regp.read_text()) if regp.exists() else {'schema_version':1,'version':'v27','hero':'hideyoshi','production_id':'hideyoshi-katana-gourd-20261013','status':'Artwork package; proposed registration, not installed into game.','angle_convention':'tip up0, clockwise positive; right-facing baseline','clips':{}}
 ep=QA/'compiled-source-verification.json';evidence=json.loads(ep.read_text()) if ep.exists() else {}
 for n in args.clips:
  reg['clips'][n],evidence[n]=compile_clip(n);print(n,'compiled6',flush=True)
 if (B/'metadata/review_adjustments.json').exists():reg['review_adjustments']={'file':'production/metadata/review_adjustments.json','sha256':sha(B/'metadata/review_adjustments.json')}
 reg['registered_frame_count']=sum(len(c['frames']) for c in reg['clips'].values());regp.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n');(QA/'compiled-source-verification.json').write_text(json.dumps(evidence,indent=2)+'\n')
if __name__=='__main__':main()
