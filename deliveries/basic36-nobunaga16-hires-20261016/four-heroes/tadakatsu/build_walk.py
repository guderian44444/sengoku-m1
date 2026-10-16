from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
import numpy as np, json, math, hashlib, shutil
BASE=Path(__file__).parent
SRC=BASE/'source'; OUT=BASE/'walk'; ID=BASE/'identity'
for p in [OUT,ID]:p.mkdir(parents=True,exist_ok=True)
W,H=480,280; RX,FY=220,238; SCALE=163/740; SPEARLEN=270*163/160
spec=[
 dict(source='walk-01-02.png',component=0,root=[530,945],hands=[[610,430],[742,420]],near=[250,941],far=[733,936],support='far',phase='far_contact',duration=120),
 dict(source='walk-01-02.png',component=1,root=[1262,934],hands=[[1345,430],[1472,420]],near=[1015,907],far=[1360,930],support='far',phase='far_down_near_toeoff',duration=150),
 dict(source='walk-03-04.png',component=0,root=[550,956],hands=[[640,430],[760,416]],near=[556,858],far=[490,952],support='far',phase='far_support_near_passing',duration=170),
 dict(source='walk-03-04.png',component=1,root=[1264,949],hands=[[1345,430],[1470,420]],near=[1450,909],far=[981,945],support='far',phase='far_push_near_forward_swing',duration=120),
 dict(source='walk-05-06-corrected.png',component=0,root=[532,952],hands=[[620,430],[745,420]],near=[700,948],far=[323,931],support='near',phase='near_contact',duration=120),
 dict(source='walk-05-06-corrected.png',component=1,root=[1275,954],hands=[[1345,430],[1490,420]],near=[1382,950],far=[1067,818],support='near',phase='near_down_far_toeoff',duration=120),
 dict(source='walk-07-08-corrected.png',component=0,root=[526,969],hands=[[610,430],[725,420]],near=[570,965],far=[362,853],support='near',phase='near_support_far_passing',duration=200),
 dict(source='walk-07-08-corrected.png',component=1,root=[1252,944],hands=[[1335,425],[1460,415]],near=[1004,939],far=[1444,878],support='near',phase='near_push_far_forward_swing',duration=120),
]
cache={}
def isolate(file,component):
 if file not in cache:
  im=Image.open(SRC/file).convert('RGBA'); ar=np.array(im); lab,n=ndimage.label(ar[:,:,3]>32);count=np.bincount(lab.ravel()); ids=np.argsort(count[1:])[-2:]+1
  ids=sorted(ids,key=lambda i:np.where(lab==i)[1].min()); cache[file]=(im,ar,lab,ids)
 im,ar,lab,ids=cache[file];keep=ndimage.binary_dilation(lab==ids[component],iterations=2);q=ar.copy();q[:,:,3]=np.where(keep,q[:,:,3],0);return Image.fromarray(q)
def place(im,s,ox,oy):
 # The only body resampling is this last reduction from preserved source pixels.
 scaled=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS)
 out=Image.new('RGBA',(W,H));out.alpha_composite(scaled,(round(ox),round(oy)));return out
spear=Image.open(SRC/'spear_suyari-original.png').convert('RGBA')
def render(body,root,hands,scale,index,dest):
 ox=RX-root[0]*scale;oy=FY-root[1]*scale
 b=place(body,scale,ox,oy);g=hands[0];gx=ox+g[0]*scale;gy=oy+g[1]*scale
 dx=hands[1][0]-g[0];dy=hands[1][1]-g[1];angle=math.degrees(math.atan2(dx,-dy))
 co,si=math.cos(math.radians(angle)),math.sin(math.radians(angle));ws=SPEARLEN/962
 aa,bb=co/ws,si/ws;dd,ee=-si/ws,co/ws
 weapon=spear.transform((W,H),Image.Transform.AFFINE,(aa,bb,188-aa*gx-bb*gy,dd,ee,621-dd*gx-ee*gy),Image.Resampling.BICUBIC)
 mask=Image.new('L',body.size);md=ImageDraw.Draw(mask)
 # Hand occlusion is copied from the untouched source, not newly painted.
 rad=35 if scale==SCALE else 15
 for hx,hy in hands:md.ellipse((hx-rad,hy-rad,hx+rad,hy+rad),fill=255)
 ha=np.array(body);ha[:,:,3]=(ha[:,:,3].astype(np.uint16)*np.array(mask)//255).astype(np.uint8);hand=place(Image.fromarray(ha),scale,ox,oy)
 composite=b.copy();composite.alpha_composite(weapon);composite.alpha_composite(hand)
 for label,im in [('body',b),('weapon',weapon),('hand_occlusion',hand),('composite',composite)]:im.save(dest/f'{label}_{index:02}.png')
 return composite,dict(render_origin=[ox,oy],scale=scale,grip_source=g,grip_canvas=[gx,gy],hands_source=hands,hands_canvas=[[ox+x*scale,oy+y*scale] for x,y in hands],weapon_angle_degrees=angle,weapon_angle_convention='degrees clockwise from source spear upward axis',weapon_behind=False,layer_order=['body','weapon','hand_occlusion'],weapon_length_px=SPEARLEN)
# Register exact already-approved shared combat idle. No redraw.
approved=Image.open(SRC/'approved-original-master.png').convert('RGBA').crop((0,0,512,512));a=np.array(approved);lab,n=ndimage.label(a[:,:,3]>24);cnt=np.bincount(lab.ravel());cnt[0]=0;keep=ndimage.binary_dilation(lab==cnt.argmax(),iterations=2);a[:,:,3]=np.where(keep,a[:,:,3],0);approved=Image.fromarray(a);approved.save(ID/'approved-idle-source-crop.png')
idle,irec=render(approved,[297,490],[[316,261],[411,252]],163/370,1,ID)
# Portrait is a simple crop of the same approved artwork; no generation.
approved.crop((214,18,380,225)).save(ID/'portrait-approved-crop.png')
irec.update(id='tadakatsu_r3_shared_idle',approval='already_approved_per_parent_user_context',original_source='tadakatsu_delivery_20261015_forward/main/light_1/source.png',source_rect=[0,0,512,512],source_standing_ruler_px=370,target_standing_ruler_px=163,loop=True,frame_duration_ms=800,world_delta=[0,0],portrait=dict(file='portrait-approved-crop.png',crop_in_idle_source=[214,18,380,225],generated=False))
(ID/'registration.json').write_text(json.dumps(irec,indent=2))
records=[];comps=[];elapsed=0
for i,f in enumerate(spec,1):
 body=isolate(f['source'],f['component']);bb=body.getbbox();body.crop(bb).save(OUT/f'source_body_{i:02}.png')
 comp,rec=render(body,f['root'],f['hands'],SCALE,i,OUT);comps.append(comp)
 local={side:[(f[side][0]-f['root'][0])*SCALE,(f[side][1]-f['root'][1])*SCALE] for side in ['near','far']}
 rec.update(frame=i,source_file='../source/'+f['source'],source_component=f['component'],source_sha256=hashlib.sha256((SRC/f['source']).read_bytes()).hexdigest(),source_bbox=list(bb),source_effective_height=bb[3]-bb[1],source_root=f['root'],root_canvas=[RX,FY],root_local=[0,0],duration_ms=f['duration'],start_ms=elapsed,phase=f['phase'],feet_source={side:f[side] for side in ['near','far']},feet_local=local,feet_canvas={side:[RX+local[side][0],FY+local[side][1]] for side in ['near','far']},support_foot=f['support'],loop_next=1 if i==8 else i+1,world_delta=[0,0],fx=None,grounded=True)
 elapsed+=f['duration'];records.append(rec)
# The asset is in-place. A separate preview-only root track cancels each planted foot's screen-space motion.
preview_root=[0.0];step_switch=10.0
for j in range(1,8):
 prev,cur=records[j-1],records[j]
 delta=prev['feet_local'][prev['support_foot']][0]-cur['feet_local'][cur['support_foot']][0] if prev['support_foot']==cur['support_foot'] else step_switch
 preview_root.append(preview_root[-1]+delta)
cycle_disp=preview_root[-1]+step_switch
for j,r in enumerate(records):r['preview_displacement_px']=[round(preview_root[j],4),0]
meta=dict(hero='tadakatsu',revision='r3_walk_candidate_01',action='walk',approval='pending_user_review',loop=True,loop_start=1,loop_end=8,frame_count=8,total_ms=elapsed,standing_ruler_source_px=740,standing_ruler_target_px=163,one_constant_body_scale=SCALE,per_frame_bbox_height_normalization=False,original_png_preserved=True,final_downsample_only=True,image_generation_tool='official image_gen.imagegen',direct_approved_master_reference='../source/approved-original-master.png',detail_note='High-resolution redrawing clarified existing armor, lacing and feather details; no new ornaments intended.',layers=['body','weapon','hand_occlusion'],ordinary_action_fx=False,world_motion=dict(mode='in_place',per_frame_delta=[0,0],driver='runtime_controller',preview_motion_not_baked=True),preview_motion=dict(mode='discrete_support_foot_lock',displacement_per_cycle=cycle_disp,displacement_by_frame=preview_root,step_switch_advance=step_switch,not_runtime_world_motion=True),shared_idle='../identity/registration.json',frames=records,runtime_integrated=False)
(OUT/'metadata.json').write_text(json.dumps(meta,indent=2))
# Dark neutral background previews, no FX or fake motion blur.
def bg():
 im=Image.new('RGB',(W,H),(37,43,52));d=ImageDraw.Draw(im);d.line((10,FY+1,W-10,FY+1),fill=(80,87,94));return im
def paste_rgb(base,comp):base.paste(comp,(0,0),comp.getchannel('A'))
normal=[];comparison=[]
for j,comp in enumerate(comps):
 can=bg();paste_rgb(can,comp);d=ImageDraw.Draw(can);d.text((12,9),'TADAKATSU r3 | WALK CANDIDATE | 163px ruler',fill=(230,232,237));d.text((12,H-23),f'{j+1}/8  {records[j]["phase"]}  {records[j]["duration_ms"]}ms',fill=(192,199,208));normal.append(can)
 cp=Image.new('RGB',(W*2,H),(37,43,52));left=bg();paste_rgb(left,idle);ImageDraw.Draw(left).text((12,9),'APPROVED COMBAT IDLE | same 163px ruler',fill=(230,232,237));cp.paste(left,(0,0));cp.paste(can,(W,0));comparison.append(cp)
durs=[r['duration_ms'] for r in records]
for name,frames,factor in [('normal.gif',normal,1),('slow.gif',normal,2),('idle-walk-comparison.gif',comparison,1)]:frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=[x*factor for x in durs],loop=0,disposal=2)
comparison[0].save(OUT/'idle-walk-comparison.png')
contact=Image.new('RGB',(W*4,H*2))
for j,f in enumerate(normal):contact.paste(f,(j%4*W,j//4*H))
contact.save(OUT/'contact.png')
# Separate world-travel review: each planted foot has a fixed world X through its support phase.
WW,HH=1000,330;travel=[]
for cycle in range(2):
 for j,comp in enumerate(comps):
  im=Image.new('RGB',(WW,HH),(37,43,52));d=ImageDraw.Draw(im);d.line((0,FY+31,WW,FY+31),fill=(85,92,99))
  for tick in range(0,WW,40):d.line((tick,FY+31,tick,FY+38),fill=(110,117,124))
  pos=round(50+cycle*cycle_disp+preview_root[j]);im.paste(comp,(pos,30),comp.getchannel('A'));d.text((14,10),'TADAKATSU | WALK | preview-only planted-foot root track',fill=(230,232,237));d.text((14,HH-25),'2 cycles; reset at GIF boundary. Runtime asset stays in-place; no FX.',fill=(192,199,208));travel.append(im)
travel[0].save(OUT/'world-preview.gif',save_all=True,append_images=travel[1:],duration=durs*2,loop=0,disposal=2)
# Tests validate artifact structure and selected support-point locking, not subjective animation approval.
errors=[]
for i,r in enumerate(records,1):
 for lay in ['body','weapon','hand_occlusion','composite']:
  im=Image.open(OUT/f'{lay}_{i:02}.png'); assert im.size==(W,H) and im.mode=='RGBA'; assert im.getextrema()[3][0]==0
 assert r['source_effective_height']>=600
 for side,p in r['feet_canvas'].items(): assert 0<=p[0]<W and 0<=p[1]<H
 lock_error=None
 if i>1 and records[i-2]['support_foot']==r['support_foot']:
  prev=records[i-2];a=prev['feet_local'][r['support_foot']][0]+preview_root[i-2];b=r['feet_local'][r['support_foot']][0]+preview_root[i-1];lock_error=abs(a-b);errors.append(lock_error)
qa=dict(artifact_checks='pass',frame_count=8,minimum_effective_source_height=min(r['source_effective_height'] for r in records),constant_scale=SCALE,target_standing_ruler=163,max_discrete_support_lock_error_px=max(errors),genuine_alpha=True,raw_generated_sources_preserved=True,no_optical_flow=True,no_repeated_small_tile_generation=True,all_new_generation_referenced_approved_full_master=True,existing_combat_assets_unchanged=True,portrait_is_approved_source_crop=True,no_fx=True,visual_review='pending_final_contact_and_gif_review',approval='pending_user',note='Near/far leg labels describe cycle continuity; no new anatomical color markings added.')
(OUT/'QA.json').write_text(json.dumps(qa,indent=2))
(BASE/'README.txt').write_text('Honda Tadakatsu r3 walk candidate. Existing combat assets unchanged.\nOnly walk was drawn. Stop here for user review before remaining base actions.\nidentity/ contains exact approved combat idle registration and portrait crop.\nwalk/ contains 8 independent RGBA layers, source crops, GIFs and per-frame metadata.\nsource/ preserves all full-resolution official image_gen originals, including rejected half-cycle attempts.\n163px standing ruler; fixed 163/740 scale for all walk frames. Existing idle uses equivalent 163/370 ruler.\nworld_delta is zero: preview displacement is a separate discrete foot-lock demonstration and must not be silently baked into runtime.\nLoop 8 to 1; no duplicate idle frame interrupts walk. No FX.\nCandidate needs user approval; it is not installed in a site or repository.\n')
print(json.dumps({'output':str(OUT.resolve()),'frames':8,'total_ms':elapsed,'preview_cycle_displacement':cycle_disp,'qa':qa},indent=2))
