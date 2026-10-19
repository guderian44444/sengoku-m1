from pathlib import Path
import json,math,hashlib,subprocess
import numpy as np
from scipy import ndimage
from PIL import Image,ImageDraw,ImageFont,ImageFilter,ImageOps
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];OLD=ROOT/'artifacts/oichi-high-kick-20261019/preview-v1';PREVIOUS=OLD.parent/'preview-v2'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.run(['git',*args],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace').stdout.strip()
original=json.loads((OUT/'poses.json').read_text('utf-8'));poses=original['poses'];tests=json.loads((PREVIOUS/'range-test-results.json').read_text())
body_files=[OUT/p['file'] for p in poses];body_hashes=[sha(p) for p in body_files]
runtime_paths=['game/core/battle.gd','game/core/combat_moves.gd','game/render/battle_view.gd','game/render/weapon_renderer.gd','game/assets/v33/oichi/registration.json','game/assets/v22/weapons/bow_azusa.png']
before={p:sha(ROOT/p) for p in runtime_paths}
W,H=1600,920;GROUND=603;ZOOM=2;BODY_SCALE=148*ZOOM/original['body_ruler_px'];FX_SCALE=1.5
sheet_roots=[p['root_in_sheet'] for p in poses]
# Whole-body artwork is unchanged. These sockets belong only to this preview's equipment layer.
bow_hands=[(261,157),(648,158),(1016,151),(1299,185),(177,660),(603,684),(1034,686),(1399,660)]
arrow_hands=[(273,146),(662,145),(1025,137),(1354,147),(239,647),(665,674),(1050,676),(1416,654)]
angles=[-48,-50,-52,-55,-56,-52,-50,-48]
bow_image=Image.open(ROOT/'game/assets/v22/weapons/bow_azusa.png').convert('RGBA');bow_spec=json.loads((ROOT/'game/assets/v22/weapons/registration.json').read_text())['items']['bow_azusa']
fontpath='C:/Windows/Fonts/msjh.ttc';fonts={s:ImageFont.truetype(fontpath,s) for s in [16,19,22,26,36]}
bodies=[Image.open(p).convert('RGBA') for p in body_files]
body_scaled=[p.resize((round(p.width*BODY_SCALE),round(p.height*BODY_SCALE)),Image.Resampling.LANCZOS) for p in bodies]
reg=json.loads((ROOT/'game/assets/v19/enemies/registration.json').read_text())['actors']
def enemy_frame(key,i):
 s=reg[key];im=Image.open(ROOT/'game/assets/v19/enemies'/s['file']).convert('RGBA');x,y,w,h=s['regions'][str(i)];im=im.crop((x,y,x+w,y+h));a=[s['feet'][i][0]-x,s['feet'][i][1]-y];factor=146*ZOOM/s['body_heights'][i]
 pixels=np.array(im);labels,n=ndimage.label(pixels[:,:,3]>64);sizes=np.bincount(labels.ravel());sizes[0]=0;keep=ndimage.binary_dilation(labels==sizes.argmax(),iterations=2);pixels[:,:,3]*=keep.astype('uint8');im=Image.fromarray(pixels)
 return im.resize((round(w*factor),round(h*factor)),Image.Resampling.LANCZOS),[v*factor for v in a]
enemy_idle=enemy_frame('soldier-idle',0);enemy_air=enemy_frame('soldier-death',2);enemy_down=enemy_frame('soldier-death',5)
def local(point,i):return ((point[0]-sheet_roots[i][0])*BODY_SCALE,(point[1]-sheet_roots[i][1])*BODY_SCALE)
def world(point,cx,face):return (cx+point[0]*face,GROUND+point[1])
def toe(i):return [poses[i]['toe_in_sheet'][d]-sheet_roots[i][d] for d in [0,1]]
def curve(a,b,c,d,t):return tuple((1-t)**3*a[k]+3*(1-t)**2*t*b[k]+3*(1-t)*t*t*c[k]+t**3*d[k] for k in [0,1])
def enlarge(point,pivot):return tuple(pivot[k]+(point[k]-pivot[k])*FX_SCALE for k in [0,1])
def equipment(i,cx,face):return Image.new('RGBA',(W,H)),{'bow':'integrated in full-pose generated artwork','arrow':None}

def draw_body(canvas,i,cx,face):
 im=body_scaled[i] if face==1 else ImageOps.mirror(body_scaled[i]);anchor=poses[i]['root_in_crop'];ax=anchor[0]*BODY_SCALE if face==1 else im.width-anchor[0]*BODY_SCALE
 canvas.alpha_composite(im,(round(cx-ax),round(GROUND-anchor[1]*BODY_SCALE)))
def hand_foreground(canvas,i,cx,face):pass

from functools import lru_cache
import sys
sys.path.insert(0,str(OUT))
from textured_foot_fx import make_foot_fx
@lru_cache(maxsize=4)
def fx_base(i):
 def point(k):return world(tuple(v*BODY_SCALE for v in toe(k)),250,1)
 hip=world(local(poses[i]['hip_in_sheet'],i),250,1)
 return make_foot_fx(point(2),point(3),point(i),hip,(W,H),i==4)
def fx(i,tick,cx,face):
 if i not in [3,4]:return Image.new('RGBA',(W,H))
 layer,_=fx_base(i);layer=layer.copy()
 alpha=1 if tick<10 else max(0,(12-tick)/3)
 layer.putalpha(layer.getchannel('A').point(lambda a:round(a*alpha)))
 if face==-1:layer=ImageOps.mirror(layer)
 return layer

def enemy(canvas,cx,face,t):
 st={'x':120,'z':0,'action':'idle'} if t<8 else tests['motion'][min(t-8,len(tests['motion'])-1)]
 x=cx+st['x']*ZOOM*face;y=GROUND-st['z']*ZOOM
 frame,anchor=enemy_idle if t<8 else enemy_down if st['action']=='down' else enemy_air
 # Native source faces right. Enemy faces the hero in both mirrored panels.
 ef=-face;im=frame if ef==1 else ImageOps.mirror(frame);ax=anchor[0] if ef==1 else im.width-anchor[0]
 layer=Image.new('RGBA',(W,H));d=ImageDraw.Draw(layer);d.ellipse((x-40,GROUND-5,x+45,GROUND+9),fill=(8,14,19,255));layer.alpha_composite(im,(round(x-ax),round(y-anchor[1])))
 # Clip only to the test viewport: physics and camera-independent coordinates remain unchanged.
 x0,x1=(24,784) if face==1 else (816,1576);canvas.alpha_composite(layer.crop((x0,118,x1,645)),(x0,118))
 return st
def render(i,t):
 canvas=Image.new('RGBA',(W,H),(14,22,29,255));d=ImageDraw.Draw(canvas)
 d.rounded_rectangle((20,16,W-20,104),radius=16,fill=(28,40,51));d.text((42,28),'B 氣勁試作｜腿型與白色內層仍待修圖',font=fonts[36],fill=(242,248,251));d.text((45,76),'正常速度 1×　｜　武將劍氣紋理・加大加粗　｜　沿用第三段判定 ×1.20　｜　隔離預覽・未啟用正式綁定',font=fonts[19],fill=(168,198,218))
 for cx,face in [(250,1),(1350,-1)]:
  x0=24 if face==1 else 816;d=ImageDraw.Draw(canvas);d.rounded_rectangle((x0,118,x0+760,645),radius=16,fill=(24,34,44));d.text((x0+20,134),'向右 · 持弓、無箭' if face==1 else '向左 · 持弓、無箭',font=fonts[22],fill=(183,209,226));d.line((x0+18,GROUND+1,x0+742,GROUND+1),fill=(72,94,111),width=2);d.ellipse((cx-63,GROUND-6,cx+74,GROUND+12),fill=(9,15,20))
  canvas=Image.alpha_composite(canvas,fx(i,t,cx,face));draw_body(canvas,i,cx,face);weapons,sockets=equipment(i,cx,face);canvas=Image.alpha_composite(canvas,weapons)
  # Grip occlusion uses unchanged original hand pixels; equipment remains visible on both sides of the fist.
  hand_foreground(canvas,i,cx,face);state=enemy(canvas,cx,face,t);d=ImageDraw.Draw(canvas)
  if t>=8:d.text((x0+420,140),'命中 → 擊飛' if state['action']!='down' else '擊飛完成',font=fonts[22],fill=(135,232,207))
  if t in [8,10]:
   point=world(tuple(v*BODY_SCALE for v in toe(i)),cx,face)
   for k in range(7):
    a=k*math.tau/7+.2;d.line((point[0]+math.cos(a)*8,point[1]+math.sin(a)*8,point[0]+math.cos(a)*24,point[1]+math.sin(a)*24),fill=(255,236,178,240),width=2)
 d=ImageDraw.Draw(canvas);d.text((40,657),poses[i]['label']+'　｜　此片只更新氣勁；角色沿用舊 B，腿型及白色內層尚未修正',font=fonts[22],fill=(225,239,246))
 d.rounded_rectangle((24,699,784,895),radius=14,fill=(24,34,44));d.text((42,710),'判定俯視示意（前向距離 × 縱深半寬）',font=fonts[22],fill=(225,239,246))
 ox=85;oy=807;sx=2.35;sy=.65
 d.rectangle((ox-18*sx,oy-69.12*sy,ox+215.28*sx,oy+69.12*sy),outline=(116,134,149),width=2)
 d.rectangle((ox-18*sx,oy-82.944*sy,ox+258.336*sx,oy+82.944*sy),outline=(94,219,249),width=3)
 d.ellipse((ox-5,oy-5,ox+5,oy+5),fill=(255,221,140));d.text((ox-20,oy+57),'阿市',font=fonts[16],fill=(255,221,140))
 px=ox+236*sx;d.ellipse((px-6,oy-6,px+6,oy+6),fill=(117,237,178));d.text((px-28,oy-31),'236',font=fonts[16],fill=(117,237,178));d.text((235,866),'灰：原範圍　　藍：修正版　　綠點：新增可命中位置',font=fonts[16],fill=(174,202,222))
 d.rounded_rectangle((816,699,1576,895),radius=14,fill=(24,34,44));d.text((838,710),'隔離測試結果 · 左右邊界 32 項通過',font=fonts[22],fill=(225,239,246))
 d.text((838,752),'前向 215.28 → 258.336　　縱深 ±69.12 → ±82.944',font=fonts[19],fill=(150,226,248));d.text((838,785),'236：原版未中／修正版命中　　258.436：修正版未中',font=fonts[19],fill=(177,207,224));d.text((838,818),'擊飛沿用原值：水平 12、垂直 6；前兩段判定未變',font=fonts[19],fill=(177,207,224));d.text((838,851),'133ms 接觸／417ms 動作　·　畫面放大 2×，未放慢',font=fonts[19],fill=(177,207,224))
 return canvas.convert('RGB')
holds=[p['ticks'] for p in poses]
def pose_at(t):
 if t<0:return 7
 at=0
 for i,n in enumerate(holds):
  if t<at+n:return i
  at+=n
 return 7
frames=[];log=[]
for tick in range(0,120,2):
 t=tick-30;i=pose_at(t);frames.append(render(i,t));log.append({'capture_tick':tick,'action_tick':t,'pose':i})
delays=[round((i+1)*100/30)*10-round(i*100/30)*10 for i in range(len(frames))]
gif=OUT/'oichi-B-fx-only-body-and-white-costume-pending-normal-speed.gif';frames[0].save(gif,save_all=True,append_images=frames[1:],duration=delays,loop=0,disposal=2,optimize=False)
render(4,8).save(OUT/'B-contact.png');render(7,-1).save(OUT/'B-ready.png')
board=Image.new('RGB',(1600,920));
for i in range(8):
 im=render(i,sum(holds[:i])).crop((24,118,784,645));im.thumbnail((400,430));board.paste(im,((i%4)*400,(i//4)*460+26));ImageDraw.Draw(board).text(((i%4)*400+12,(i//4)*460),f'{i} {poses[i]["label"]}',font=fonts[19],fill='white')
board.save(OUT/'B-all-poses.jpg',quality=91)
after={p:sha(ROOT/p) for p in runtime_paths};assert before==after;assert body_hashes==[sha(p) for p in body_files];assert sum(delays)==2000
settings={'enabled':False,'scope':'isolated preview only; not read by live game','fx_scale_xy':1.0,'fx_envelope_reference_scale':1.5,'new_fx_thickness_rule':'1.09 x actual hip-to-heel radius x 0.34','texture_source':str(OUT/'references/approved-officer-arc.png'),'fx_thickness_scale':'dynamic from actual leg radius','fx_pivot':'registered heel endpoint; ribbon follows actual chamber-to-thrust trajectory','light3_only_reach_multiplier':1.2,'light3_only_depth_multiplier':1.2,'effective_base_reach':215.28,'effective_preview_reach':258.336,'effective_base_depth_half':69.12,'effective_preview_depth_half':82.944,'behind':18,'bow_world_length':150,'arrow_world_length':0,'bow_hands_sheet_px':[],'arrow_hands_sheet_px':[],'bow_angles_deg':[]}
(OUT/'disabled-preview-settings.json').write_text(json.dumps(settings,ensure_ascii=False,indent=2),encoding='utf-8')
manifest={'settings':settings,'source_body_sha256':body_hashes,'generated_full_poses_unwarped':True,'body_correction_status':'blocked by image service; old B pixels retained','white_underlayer_status':'not yet corrected','delivery_scope':'FX-only preview, not a complete revised B','generation_source':original['source_sheet'],'fx_metrics':fx_base(4)[1],'pose_registration':original,'bow_source':'generated complete-pose equipment based on game/assets/v22/weapons/bow_azusa.png','arrow_rendering':'none; no arrow generated or drawn','equipment_layer':'complete generated body and held bow, unchanged pixels; no carried arrow','tick_hz':60,'capture_fps':30,'cycle_ms':2000,'hit_tick':8,'motion_end_tick':25,'head':git('rev-parse','HEAD'),'branch':git('branch','--show-current'),'runtime_before':before,'runtime_after':after,'tracked_status':git('status','--short','--untracked-files=no'),'tests':str(PREVIOUS/'range-test-results.json'),'peak_launch_z':max(m['z'] for m in tests['motion']),'capture_log':log,'gif':{'path':str(gif),'size':gif.stat().st_size,'sha256':sha(gif)}}
(OUT/'preview-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(manifest['gif'],ensure_ascii=False))
