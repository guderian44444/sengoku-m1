from PIL import Image,ImageDraw
import numpy as np, math,json,hashlib,pathlib,shutil
BASE=pathlib.Path(__file__).parent
if not (BASE / "references").exists(): BASE=BASE.parent
W,H=480,280
CFG={'air_light':dict(src='exec-2f603fe4-0c0c-47ae-afeb-3dd50c71cbf9.png',ruler=560,hands=[(412,162),(226,31),(458,376),(495,428),(446,341),(464,295)],right=[(352,157),(215,42),(425,379),(464,434),(411,341),(384,278)],angles=[-20,-65,115,150,120,30],roots=[(300,550),(300,550),(300,550),(300,572),(300,550),(300,550)],ys=[207,194,190,195,208,225],xs=[128]*6,durations=[80,110,60,80,90,140],events=['airborne','large_overhead_backswing','steep_downward_contact','deep_followthrough','recover_from_downswing','descent_exit'])}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(name):
 c=CFG[name];d=BASE/name;d.mkdir(exist_ok=True);src=d/'source_raw.png'
 if not src.exists(): shutil.copy(BASE.parent/'generated_images'/c['src'],src)
 shutil.copy(src,d/'source_final.png');im=Image.open(src).convert('RGBA');bow=Image.open(BASE/'references/bow_azusa.png').convert('RGBA');s=148/c['ruler'];bs=132/992
 out=[];records=[]
 for i in range(6):
  x,y=(i%3)*512,(i//3)*512;h=512
  if i==0:h=480
  if i==3:y=490;h=534
  body=im.crop((x,y,x+512,y+h));body.save(d/f'body_{i+1:02}.png');rx,ry=c['roots'][i];ox=c['xs'][i]-rx*s;oy=c['ys'][i]-ry*s;gr=c['hands'][i];grscreen=(ox+gr[0]*s,oy+gr[1]*s)
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
  canvas=Image.new('RGB',(W,H),(42,48,57));canvas.paste(b,mask=b.getchannel('A'));dd=ImageDraw.Draw(canvas);dd.line([(20,246),(460,246)],fill=(72,80,90));dd.text((12,10),name+' v2 | deeper downward swing | 148px',fill=(210,216,225));dd.text((12,264),'BODY / BOW / STRING / PROJECTILES: separate',fill=(150,160,175));out.append(canvas)
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
