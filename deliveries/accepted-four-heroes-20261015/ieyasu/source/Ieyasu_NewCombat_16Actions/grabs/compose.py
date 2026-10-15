from pathlib import Path
from PIL import Image,ImageDraw
import json,math,copy,hashlib
R=Path(__file__).parent;M=json.loads((R/'registration.json').read_text())
HANDS={'grab_hold':[(209,100),(209,100),(209,101),(208,106),(208,104),(209,104)],'grab_start':[(190,154),(226,100),(215,99),(208,103),(176,112),(207,105)],'grab_hit_2':[(194,109),(193,109),(209,116),(210,125),(195,111),(195,110)],'throw_forward':[(214,112),(177,151),(179,139),(149,153),(178,111),(218,83),(230,96),(251,121),(202,151),(201,118)],'throw_reverse':[(207,115),(159,174),(173,110),(168,105),(161,114),(96,174),(114,35),(74,177),(96,160),(93,121)]}
LEFT={'grab_hold':[(171,115),(171,115),(171,116),(170,120),(170,119),(171,119)],'grab_start':[(132,153),(137,140),(137,140),(142,140),(146,129),(172,117)],'grab_hit_2':[(176,118),(176,116),(194,125),(196,132),(180,118),(176,118)],'throw_forward':[(192,117),(169,152),(172,144),(137,152),(160,116),(202,82),(209,106),(231,126),(187,153),(144,145)],'throw_reverse':[(176,125),(153,170),(145,109),(123,103),(150,115),(83,170),(140,36),(68,173),(161,136),(144,145)]}
rawleft=copy.deepcopy(LEFT)
rawhands=copy.deepcopy(HANDS)
for n,a in M.items():
 if n=='grab_hit_1':continue
 for i,f in enumerate(a['frames']):
  if 'reused_from' in f:
   r=f['reused_from'];HANDS[n][i]=rawhands[r['action']][r['frame']];LEFT[n][i]=rawleft[r['action']][r['frame']]
HANDS['grab_hit_1']=copy.deepcopy(HANDS['grab_hit_2']);LEFT['grab_hit_1']=copy.deepcopy(LEFT['grab_hit_2'])
# Manually measured grip centers on registered 152px canvas. Other actions added after source QA.
saya=Image.open(R.parent/'reference/saya.png').convert('RGBA');tachi=Image.open(R.parent/'reference/tachi.png').convert('RGBA');hilt=tachi.crop((0,955,tachi.width,tachi.height)).rotate(180,expand=True).resize((9,23),Image.Resampling.LANCZOS);saya=saya.resize((10,73),Image.Resampling.LANCZOS);sheath=Image.new('RGBA',(24,100));sheath.alpha_composite(hilt,(8,0));sheath.alpha_composite(saya,(7,21))
for name,info in M.items():
 if name not in HANDS:continue
 out=R/name;frames=[];bframes=[]
 for i,f in enumerate(info['frames']):
  body=Image.open(out/f'body_{i:02}.png');hand=HANDS[name][i];f.update(right_hand=hand,left_hand=LEFT[name][i],grasp_contact=hand,waist=[150,147],action_key=name,events=[],hand_measurement='visually measured approximate +/-3px at 152px scale',weapon_state='sheathed separate layer')
  if name.startswith('grab_hit') and i==3:f['events']=[name+'_contact']
  if name=='grab_start' and i==3:f['events']=['grip_close']
  w=Image.new('RGBA',(480,280));p=sheath.rotate(-50,expand=True,resample=Image.Resampling.BICUBIC);w.alpha_composite(p,(115,135));w.save(out/f'weapon_{i:02}.png')
  proxy=Image.new('RGBA',(480,280));d=ImageDraw.Draw(proxy);x,y=hand
  if name=='grab_start' and i<3:x,y=(225,100)
  if name.startswith('throw') and i>=(5 if name=='throw_reverse' else 6):x,y=HANDS[name][5 if name=='throw_reverse' else 6]
  c=(160,177,192,230);d.line([(x+10,y),(x+22,y+47)],fill=c,width=13);d.line([(x+22,y+43),(x+7,218)],fill=c,width=9);d.line([(x+22,y+43),(x+40,218)],fill=c,width=9);d.line([(x+10,y),(x+33,y+19),(x+24,y+34)],fill=c,width=7);d.line([(x+10,y),(x,y+13)],fill=c,width=7);d.line([(x+10,y),(x+3,y-17)],fill=c,width=7);d.ellipse((x-8,y-36,x+14,y-12),fill=c);
  if name.startswith('throw'):
   rev=name=='throw_reverse';release=5 if rev else 6
   phase=([0,15,75,95,125,160,210,250,280,300] if rev else [0,0,-25,-50,-70,-90,-110,-140,-170,-190])[i]
   if i>0:
    pivot=(x+10,y);proxy=proxy.rotate(phase,resample=Image.Resampling.BICUBIC,center=pivot)
   if i>=release:
    shift=(-25*(i-release) if rev else 30*(i-release));fall=8*(i-release)**2
    shifted=Image.new('RGBA',(480,280));shifted.alpha_composite(proxy,(shift,fall));proxy=shifted
   f['events']=[name+'_release'] if i==release else [];f['grasp_active']=i<release;f['proxy_rotation_deg']=phase
   f['world_yaw_deg']=([0,20,90,135,160,180,180,180,180,180] if rev else [0,-20,-45,-80,-140,-170,-150,-100,-40,0])[i]
   f['view']=(['right','right','back_three_quarter','back','back_three_quarter','left','left','left','left','left'] if rev else ['right','front_three_quarter','front_three_quarter','front','back','back_three_quarter','right','right','right','right'])[i]
  proxy.save(out/f'proxy_{i:02}.png')
  bg=Image.new('RGBA',(480,280),(53,62,72,255));d=ImageDraw.Draw(bg);d.text((10,8),f'Ieyasu06 {name} {i+1}/{info["count"]} | body 152px',fill='white');d.text((10,24),'Neutral measuring proxy, not final enemy',fill=(180,190,200));d.line((0,221,480,221),fill=(80,91,103));bg.alpha_composite(proxy);bg.alpha_composite(w);bg.alpha_composite(body);frames.append(bg.convert('RGB'))
  bg=Image.new('RGBA',(480,280),(53,62,72,255));bg.alpha_composite(w);bg.alpha_composite(body);bframes.append(bg.convert('RGB'))
 ds=[f['duration_ms'] for f in info['frames']]
 for fn,mul in [('normal',1),('slow',3)]:frames[0].save(out/(fn+'.gif'),save_all=True,append_images=frames[1:],duration=[v*mul for v in ds],loop=0,disposal=2)
 bframes[0].save(out/'body_only.gif',save_all=True,append_images=bframes[1:],duration=ds,loop=0,disposal=2)
 contact=Image.new('RGB',(1440,280*math.ceil(len(frames)/3)));[contact.paste(f,((i%3)*480,(i//3)*280)) for i,f in enumerate(frames)];contact.resize((960,187*math.ceil(len(frames)/3))).save(out/'contact.jpg')
 info['identity_reference_sha256']=hashlib.sha256((R.parent/'reference/identity06.png').read_bytes()).hexdigest();info['qa']={'source_and_registered_contact_visually_inspected':True,'live_playback_inspected':False,'neighbor_alpha_isolated':True,'proxy_is_final_enemy':False}
(R/'registration.json').write_text(json.dumps(M,indent=2))
