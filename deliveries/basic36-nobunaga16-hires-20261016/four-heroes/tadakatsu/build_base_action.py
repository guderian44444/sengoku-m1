from pathlib import Path
from PIL import Image, ImageDraw
from scipy import ndimage
import numpy as np,json,math,hashlib,sys
BASE=Path(__file__).parent; NAME=sys.argv[1]; D=BASE/NAME; cfg=json.loads((D/'config.json').read_text()); SRC=D/'source'; W,H=560,360;RX,FY=240,328;S=163/cfg.get('standing_ruler_source_px',740);WL=270*163/160
spear=Image.open(BASE/'source/spear_suyari-original.png').convert('RGBA');cache={}
def isolate(file,component):
 path=Path(file);path=path if path.is_absolute() else SRC/path
 key=str(path)
 if key not in cache:
  im=Image.open(path).convert('RGBA');a=np.array(im);lab,n=ndimage.label(a[:,:,3]>32);cnt=np.bincount(lab.ravel());ids=[int(i) for i in np.argsort(cnt[1:])[::-1]+1 if cnt[i]>10000];ids=sorted(ids,key=lambda i:np.where(lab==i)[1].min());cache[key]=(a,lab,ids,path)
 a,lab,ids,path=cache[key];keep=ndimage.binary_dilation(lab==ids[component],iterations=2);o=a.copy();o[:,:,3]=np.where(keep,o[:,:,3],0);return Image.fromarray(o),path

def place(im,s,ox,oy):
 resized=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);out=Image.new('RGBA',(W,H));out.alpha_composite(resized,(round(ox),round(oy)));return out

def render(body,f,i):
 s=f.get('scale',S);root=f['root'];rx,ry=f.get('root_canvas',[RX,FY]);offset=f.get('body_offset',[0,0]);ox=rx-root[0]*s+offset[0];oy=ry-root[1]*s+offset[1]
 b=place(body,s,ox,oy);hands=f.get('hands',[]);g=hands[0] if hands else [root[0],root[1]-500];gx,gy=f.get('weapon_grip_canvas',[ox+g[0]*s,oy+g[1]*s]);ang=f.get('angle')
 if ang is None:dx,dy=hands[1][0]-g[0],hands[1][1]-g[1];ang=math.degrees(math.atan2(dx,-dy))
 ws=f.get('weapon_length',WL)/962;co,si=math.cos(math.radians(ang)),math.sin(math.radians(ang));a,bv,dd,ee=co/ws,si/ws,-si/ws,co/ws
 weapon=spear.transform((W,H),Image.Transform.AFFINE,(a,bv,188-a*gx-bv*gy,dd,ee,621-dd*gx-ee*gy),Image.Resampling.BICUBIC)
 if not f.get('weapon_visible',True):weapon=Image.new('RGBA',(W,H))
 mask=Image.new('L',body.size);md=ImageDraw.Draw(mask)
 rad=f.get('hand_radius',35)
 for hx,hy in hands:md.ellipse((hx-rad,hy-rad,hx+rad,hy+rad),fill=255)
 ar=np.array(body);ar[:,:,3]=(ar[:,:,3].astype(np.uint16)*np.array(mask)//255).astype(np.uint8);hand=place(Image.fromarray(ar),s,ox,oy)
 if f.get('weapon_detached'):hand=Image.new('RGBA',(W,H))
 comp=Image.new('RGBA',(W,H));order=['weapon','body','hand_occlusion'] if f.get('weapon_behind',False) else ['body','weapon','hand_occlusion'];layers={'body':b,'weapon':weapon,'hand_occlusion':hand}
 for k in order:comp.alpha_composite(layers[k])
 for k,im in dict(layers,composite=comp).items():im.save(D/f'{k}_{i:02}.png')
 return comp,dict(scale=s,render_origin=[ox,oy],root_source=root,root_canvas=[rx,ry],body_offset_px=offset,hands_source=hands,hands_canvas=[[ox+x*s,oy+y*s] for x,y in hands],weapon_grip_canvas=[gx,gy],weapon_angle_degrees=ang,weapon_length_px=f.get('weapon_length',WL),weapon_behind=f.get('weapon_behind',False),weapon_detached=f.get('weapon_detached',False),weapon_visible=f.get('weapon_visible',True),layer_order=order,feet_source=f.get('feet',{}),feet_canvas={k:[ox+p[0]*s,oy+p[1]*s] for k,p in f.get('feet',{}).items()})
records=[];comps=[];elapsed=0
for i,f in enumerate(cfg['frames'],1):
 body,path=isolate(f['file'],f.get('component',0));bbox=body.getbbox();body.crop(bbox).save(D/f'source_body_{i:02}.png');comp,r=render(body,f,i);comps.append(comp)
 r.update(frame=i,phase=f['phase'],event=f.get('event',f['phase']),duration_ms=f['duration'],start_ms=elapsed,reused_approved=f.get('reused_approved',False),source_file=str(path.relative_to(BASE)),source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),source_bbox=list(bbox),source_effective_height=bbox[3]-bbox[1],source_effective_max_dimension=max(bbox[2]-bbox[0],bbox[3]-bbox[1]),standing_ruler_source_px=f.get('standing_ruler_source_px',cfg.get('standing_ruler_source_px',740)),standing_ruler_target_px=163,grounded=f.get('grounded',True),support_foot=f.get('support'),world_delta=[0,0],preview_displacement=f.get('preview_displacement',[0,0]),next_frame=1 if i==len(cfg['frames']) and cfg['loop'] else (None if i==len(cfg['frames']) else i+1),fx=None)
 records.append(r);elapsed+=f['duration']
meta=dict(hero='tadakatsu',action=NAME,revision=cfg.get('revision','r3_candidate_01'),status='candidate_pending_user',loop=cfg['loop'],terminal_hold=cfg.get('terminal_hold',False),terminal_event=cfg.get('terminal_event'),frame_count=len(records),total_ms=elapsed,standing_ruler_target_px=163,standing_ruler_source_px=cfg.get('standing_ruler_source_px',740),body_scale=S,per_frame_bbox_normalization=False,preserve_original_png=True,body_resample='once from original high-resolution source to final scale',world_motion={'mode':'in_place','driver':'runtime_controller','preview_displacement_not_baked':True},preview_motion=cfg.get('preview_motion',{'mode':'in_place'}),ordinary_action_fx=False,imagegen='official image_gen.imagegen',identity_references=['../source/approved-original-master.png','../source/walk-01-02.png'],shared_idle='../identity/registration.json',frames=records,runtime_integrated=False)
(D/'metadata.json').write_text(json.dumps(meta,indent=2))
# Shift the approved idle on a larger canvas without resampling.
idle=Image.new('RGBA',(W,H));old=Image.open(BASE/'identity/composite_01.png');idle.alpha_composite(old,(RX-220,FY-238))
frames=[];comparisons=[]
for j,c in enumerate(comps):
 bg=Image.new('RGB',(W,H),(37,43,52));dr=ImageDraw.Draw(bg);dr.line((10,FY+1,W-10,FY+1),fill=(80,87,94));bg.paste(c,(0,0),c.getchannel('A'));dr.text((12,10),f'TADAKATSU r3 | {NAME.upper()} CANDIDATE | 163px ruler',fill=(230,232,237));dr.text((12,H-20),f'{j+1}/{len(comps)}  {records[j]["phase"]}  {records[j]["duration_ms"]}ms',fill=(185,193,202));frames.append(bg)
 cp=Image.new('RGB',(W*2,H),(37,43,52));cp.paste(idle,(0,0),idle.getchannel('A'));ImageDraw.Draw(cp).text((12,10),'APPROVED COMBAT IDLE | same 163px ruler',fill=(230,232,237));ImageDraw.Draw(cp).line((10,FY+1,W-10,FY+1),fill=(80,87,94));cp.paste(bg,(W,0));comparisons.append(cp)
durations=[r['duration_ms'] for r in records]
# Review GIF repeats for inspection, but runtime loop is explicitly cfg.loop.
for name,fs,mult in [('normal.gif',frames,1),('slow.gif',frames,2),('idle-comparison.gif',comparisons,1)]:fs[0].save(D/name,save_all=True,append_images=fs[1:],duration=[v*mult for v in durations],loop=0,disposal=2)
comparisons[0].save(D/'idle-comparison.png');columns=4;cs=Image.new('RGB',(W*columns,H*math.ceil(len(frames)/columns)),(37,43,52))
for j,im in enumerate(frames):cs.paste(im,(j%columns*W,j//columns*H))
cs.save(D/'contact.png')
qa=dict(structural_checks='pass',frame_count=len(records),total_ms=elapsed,target_standing_ruler_px=163,constant_scale=S,original_sources_preserved=True,transparent_layers=True,no_fx=True,loop=cfg['loop'],terminal_hold=cfg.get('terminal_hold',False),visual_review='pending',min_new_source_effective_height=min((r['source_effective_height'] for r in records if not r['reused_approved']),default=None),min_source_effective_height=min(r['source_effective_height'] for r in records),min_source_effective_max_dimension=min(r['source_effective_max_dimension'] for r in records),no_optical_flow=True,bbox_height_normalization=False)
for j in range(1,len(records)+1):
 for lay in ['body','weapon','hand_occlusion','composite']:
  im=Image.open(D/f'{lay}_{j:02}.png');assert im.mode=='RGBA' and im.size==(W,H) and im.getextrema()[3][0]==0
(D/'QA.json').write_text(json.dumps(qa,indent=2));print(json.dumps(qa))
