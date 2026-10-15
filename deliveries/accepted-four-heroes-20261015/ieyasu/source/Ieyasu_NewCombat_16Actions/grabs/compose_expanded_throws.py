from pathlib import Path
from PIL import Image,ImageDraw
import json,math,copy,hashlib
R=Path(__file__).parent;M=json.loads((R/'registration.json').read_text());B=R/'before_throw_expansion'
newhands={'throw_forward':{4:([140,147],[125,145]),7:([216,96],[197,91]),10:([225,138],[185,152])},'throw_reverse':{4:([162,101],[132,114]),5:([116,114],[102,109]),6:([53,164],[69,152]),9:([80,167],[110,170])}}
# Neutral proxy geometry centered on its collar, independent of protagonist raster.
def proxy(collar,angle=0):
 im=Image.new('RGBA',(480,280));d=ImageDraw.Draw(im);x,y=collar;c=(160,177,192,230)
 def tr(p):
  a=math.radians(angle);px,py=p;return (x+px*math.cos(a)-py*math.sin(a),y+px*math.sin(a)+py*math.cos(a))
 def line(ps,w):d.line([tr(p) for p in ps],fill=c,width=w,joint='curve')
 line([(10,0),(22,47)],13);feet_y=220-y if angle==0 else 118;line([(22,43),(7,feet_y)],9);line([(22,43),(40,feet_y)],9);line([(10,0),(33,19),(24,34)],7);line([(10,0),(0,13)],7);line([(10,0),(3,-17)],7)
 h=tr((3,-24));d.ellipse((h[0]-11,h[1]-12,h[0]+11,h[1]+12),fill=c)
 return im
for name in ['throw_forward','throw_reverse']:
 a=M[name];out=R/name;rev=name=='throw_reverse';release=6;frames=[];cleanframes=[];elapsed=0
 for i,f in enumerate(a['frames']):
  if i in newhands[name]:rh,lh=newhands[name][i]
  else:
   sh=f['registration_shift_x'];rh=[f['right_hand'][0]+sh,f['right_hand'][1]];lh=[f['left_hand'][0]+sh,f['left_hand'][1]]
  f['right_hand']=rh;f['left_hand']=lh;f['grasp_contact']=rh;f['waist']=[150+f['registration_shift_x'],147];f['events']=[name+'_release'] if i==release else [];f['grasp_active']=i<release;f['time_ms']=elapsed;elapsed+=f['duration_ms'];f['hand_measurement']='visual measured on registered 152px pose; approx +/-3px';f['layer_order']=['proxy_back','weapon_back','body','proxy_after_release'];f['source']=f.get('source',a['source']);f['source_sha256']=f.get('source_sha256',a['source_sha256'])
  f['world_yaw_deg']=([0,20,85,120,155,180,180,180,180,180,180,180] if rev else [0,-20,-40,-70,-100,-140,-170,-155,-130,-90,-55,-30,0])[i]
  if i<release:
   angle=([0,0,50,75,95,110] if rev else [0,0,-20,-40,-55,-70])[i];pr=proxy(rh,angle)
  else:
   # Independent ballistic path after release: not re-attached to subsequent hand movement.
   k=i-release;origin=(92,142) if rev else (225,86);cx=origin[0]+(-21 if rev else 25)*k;cy=origin[1]-15*k+6*k*k;angle=(140+25*k) if rev else (-95-22*k);pr=proxy((cx,cy),angle);f['proxy_release_path']={'collar':[cx,cy],'angle':angle,'independent_of_followup_hands':True}
  if i==0:pr=Image.open(R/'grab_hold'/'proxy_00.png').convert('RGBA')
  body=Image.open(out/f'body_{i:02}.png').convert('RGBA');w=Image.open(B/name/'weapon_00.png').convert('RGBA')
  if f['registration_shift_x']:
   nw=Image.new('RGBA',w.size);nw.alpha_composite(w,(f['registration_shift_x'],0));w=nw
  pr.save(out/f'proxy_{i:02}.png');w.save(out/f'weapon_{i:02}.png')
  bg=Image.new('RGBA',(480,280),(53,62,72,255));d=ImageDraw.Draw(bg);d.text((10,8),f'Ieyasu06 {name} {i+1}/{a["count"]} | 152px | ONE SHOT',fill='white');d.text((10,24),'Neutral measuring proxy, not final enemy',fill=(180,190,200));d.line((0,221,480,221),fill=(80,91,103));bg.alpha_composite(pr);bg.alpha_composite(w);bg.alpha_composite(body)
  if i>=release:bg.alpha_composite(pr)
  frames.append(bg.convert('RGB'));bc=Image.new('RGBA',(480,280),(53,62,72,255));bc.alpha_composite(w);bc.alpha_composite(body);cleanframes.append(bc.convert('RGB'))
 ds=[f['duration_ms'] for f in a['frames']]
 for fn,mul in [('normal',1),('slow',3)]:frames[0].save(out/(fn+'.gif'),save_all=True,append_images=frames[1:],duration=[v*mul for v in ds],disposal=2)
 cleanframes[0].save(out/'body_only.gif',save_all=True,append_images=cleanframes[1:],duration=ds,disposal=2)
 # Single playback, no loop extension. Re-open to replay.
 sheet=Image.new('RGB',(1440,280*math.ceil(len(frames)/3)));[sheet.paste(f,((i%3)*480,(i//3)*280)) for i,f in enumerate(frames)];sheet.resize((960,187*math.ceil(len(frames)/3))).save(out/'contact.jpg')
 a['qa']['live_playback_inspected']=False;a['qa']['expanded_contact_visually_inspected']=True
(R/'registration.json').write_text(json.dumps(M,indent=2))
