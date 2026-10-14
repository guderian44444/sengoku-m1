from PIL import Image,ImageDraw
import numpy as np, math,json,hashlib,pathlib,shutil
BASE=pathlib.Path(__file__).parent
if not (BASE / "references").exists(): BASE=BASE.parent
W,H=480,280
CFG={
'air_light':dict(src='exec-84ad1fb2-9124-4ff6-bb61-9a58b6edc698.png',ruler=560,hands=[(399,137),(220,30),(468,218),(478,265),(428,290),(444,292)],right=[(340,140),(218,39),(221,198),(443,258),(385,286),(250,167)],angles=[-20,-65,25,65,30,0],roots=[(300,550)]*6,ys=[207,194,190,195,208,225],xs=[128]*6,durations=[90,100,60,70,90,130],events=['airborne','coil','melee_contact','followthrough','descending','descent_exit']),
'air_heavy':dict(src='exec-bca77840-448f-46aa-a41e-e68536bca2c2.png',ruler=550,hands=[(473,235),(445,238),(462,228),(475,229),(445,233),(420,308)],right=[(264,100),(211,108),(239,112),(198,63),(120,42),(262,150)],angles=[25,25,25,25,25,5],roots=[(300,550)]*6,ys=[208,193,187,192,210,228],xs=[128]*6,durations=[100,130,160,90,110,150],events=['airborne','draw','full_draw','release_three_simultaneous','followthrough','descent_exit'])}
CFG['dash_heavy']=dict(src='exec-3696e0a9-43ec-4eac-a3b2-f08cfd2fd78e.png',ruler=530,hands=[(398,159),(238,90),(452,136),(470,243),(416,254),(371,285)],right=[(354,205),(194,78),(422,150),(453,248),(370,245),(185,281)],angles=[-15,105,65,74,30,0],roots=[(420,483),(458,480),(426,480),(370,484),(401,484),(364,487)],ys=[246]*6,xs=[122,150,150,150,150,150],durations=[80,100,60,90,130,180],events=['last_running_step','front_foot_plant','melee_contact','braking_support','recover','standing_exit'])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(name):
 c=CFG[name];d=BASE/name;d.mkdir(exist_ok=True);src=d/'source_raw.png'
 if not src.exists(): shutil.copy(BASE.parent/'generated_images'/c['src'],src)
 shutil.copy(src,d/'source_final.png');im=Image.open(src).convert('RGBA');bow=Image.open(BASE/'references/bow_azusa.png').convert('RGBA');s=148/c['ruler'];bs=132/992
 out=[];records=[]
 for i in range(6):
  x,y=(i%3)*512,(i//3)*512;body=im.crop((x,y,x+512,y+(500 if name in ['air_heavy','dash_heavy'] and i<3 else 512)));body.save(d/f'body_{i+1:02}.png');rx,ry=c['roots'][i];ox=c['xs'][i]-rx*s;oy=c['ys'][i]-ry*s;gr=c['hands'][i];grscreen=(ox+gr[0]*s,oy+gr[1]*s)
  b=Image.new('RGBA',(W,H));small=body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS);b.alpha_composite(small,(round(ox),round(oy)))
  a=math.radians(c['angles'][i]);co,si=math.cos(a),math.sin(a)
  def pt(p):
   xx,yy=(p[0]-240)*bs,(p[1]-640)*bs
   return(grscreen[0]+co*xx-si*yy,grscreen[1]+si*xx+co*yy)
  # inverse mapping locks exact bow grip to measured anatomical left hand
  A=co/bs;B=si/bs;D=-si/bs;E=co/bs;gx,gy=grscreen
  weapon=bow.transform((W,H),Image.Transform.AFFINE,(A,B,240-A*gx-B*gy,D,E,640-D*gx-E*gy),Image.Resampling.BICUBIC)
  tips=[pt((150,16)),pt((142,978))];string=Image.new('RGBA',(W,H));dr=ImageDraw.Draw(string)
  rh=c['right'][i];rhs=(ox+rh[0]*s,oy+rh[1]*s)
  drawpoint=rhs if name=='air_heavy' and i in [0,1,2] else None
  dr.line([tips[0],drawpoint,tips[1]] if drawpoint else tips,fill=(220,203,160,255),width=1)
  weapon.alpha_composite(string);weapon.save(d/f'weapon_{i+1:02}.png');b.alpha_composite(weapon)
  # redraw only the measured fingertips, no broad arm occlusion
  occ=(gr[0]-9,gr[1]-9,gr[0]+9,gr[1]+9);patch=body.crop(occ).resize((max(1,round(18*s)),max(1,round(18*s))),Image.Resampling.LANCZOS);b.alpha_composite(patch,(round(ox+occ[0]*s),round(oy+occ[1]*s)))
  projectile=Image.new('RGBA',(W,H));pd=ImageDraw.Draw(projectile)
  if name=='air_heavy' and i<=2:
   vv=(math.cos(math.radians(25)),math.sin(math.radians(25)))
   for lane in [-2,0,2]:
    tail=(rhs[0],rhs[1]+lane);end=(gx+vv[0]*15,gy+lane+vv[1]*15);pd.line([tail,end],fill=(205,191,153,255),width=1)
  if name=='air_heavy' and i>=3 and i<=4:
   # simultaneous parallel volley, fixed identical heading, <= half viewport range
   vv=(math.cos(math.radians(25)),math.sin(math.radians(25)));nn=(-vv[1],vv[0]);dist=25 if i==3 else 180
   for lane in [-4,0,4]:
    end=(gx+vv[0]*dist+nn[0]*lane,gy+vv[1]*dist+nn[1]*lane);tail=(end[0]-vv[0]*27,end[1]-vv[1]*27)
    pd.line([tail,end],fill=(225,210,169,255),width=1);pd.polygon([end,(end[0]-vv[0]*5+nn[0]*2,end[1]-vv[1]*5+nn[1]*2),(end[0]-vv[0]*5-nn[0]*2,end[1]-vv[1]*5-nn[1]*2)],fill=(220,225,220,255))
  projectile.save(d/f'projectile_{i+1:02}.png');b.alpha_composite(projectile);b.save(d/f'composite_{i+1:02}.png')
  canvas=Image.new('RGB',(W,H),(42,48,57));canvas.paste(b,mask=b.getchannel('A'));dd=ImageDraw.Draw(canvas);dd.line([(20,246),(460,246)],fill=(72,80,90));dd.text((12,10),name+' | 148px | timing prototype',fill=(210,216,225));dd.text((12,264),'BODY / BOW / STRING / PROJECTILES: separate',fill=(150,160,175));out.append(canvas)
  rec=dict(frame=i+1,source_rect=[x,y,body.width,body.height],body_height=c['ruler'],foot=list(c['roots'][i]),left_hand=list(gr),right_hand=list(rh),weapon_angle=c['angles'][i],weapon_behind=False,weapon_visible=True,hand_occluders=[list(occ)],event=c['events'][i],duration_ms=c['durations'][i],root_preview=[c['xs'][i],c['ys'][i]])
  if drawpoint:rec['second_hand']=list(rh)
  if name=='dash_heavy' and i in [1,2,3]:rec['bow_bash_support_hand']=list(rh)
  records.append(rec)
 out[0].save(d/f'{name}_148px_normal.gif',save_all=True,append_images=out[1:],duration=c['durations'],loop=0,disposal=2)
 contact=Image.new('RGB',(W*3,H*2));[contact.paste(q,((j%3)*W,(j//3)*H)) for j,q in enumerate(out)];contact.save(d/'contact_sheet.png')
 meta=dict(action=name,prototype=True,source_sha256=sha(d/'source_final.png'),raw_sha256=sha(d/'source_raw.png'),native_alpha_preserved=True,anatomical_measurement='Manually inspected crown-neck, torso, unfolded thigh/shin/foot chain; constant standing-equivalent ruler across tucked poses, never bbox height.',frames=records,preview_only=True,runtime_changed=False,volley='simultaneous prototype; three parallel down-right trajectories; 0.5 viewport max range' if name=='air_heavy' else 'no arrows',timing='Approximate prototype; old metadata has no durations; variable keyframe dwell, no optical flow')
 (d/'anchors_events.json').write_text(json.dumps(meta,indent=2));shutil.copy(__file__,d/'build_preview.py');print(d/f'{name}_148px_normal.gif')
if __name__=='__main__':
 import sys
 for name in sys.argv[1:] or CFG:build(name)
