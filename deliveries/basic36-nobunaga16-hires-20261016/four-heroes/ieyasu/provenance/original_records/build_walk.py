from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,json,math,hashlib,shutil
BASE=Path(__file__).parent;SRC=BASE/'sources';OUT=BASE/'walk';OLD=BASE.parents[1]/'ieyasu06_newspec_20261015'
W,H=480,280; RX,FY=220,240;SCALE=152/920
spec=[
 dict(source='walk_01_02_raw.png',component=0,root=[450,950],hands=[[470,478],[530,478]],near=[174,946],far=[695,946],support='far',phase='far_left_contact',duration=120),
 dict(source='walk_01_02_raw.png',component=1,root=[1220,954],hands=[[1235,492],[1296,495]],near=[942,948],far=[1390,948],support='far',phase='far_left_down_near_toeoff',duration=130),
 dict(source='walk_07_08_raw.png',component=0,root=[450,962],hands=[[440,437],[495,437]],near=[634,851],far=[445,960],support='far',phase='far_left_support_near_right_passing',duration=160),
 dict(source='walk_07_08_raw.png',component=1,root=[1190,941],hands=[[1175,438],[1234,439]],near=[1403,928],far=[853,940],support='far',phase='far_left_push_near_right_forward',duration=130),
 dict(source='walk_contacts_retry_raw.png',component=0,root=[480,981],hands=[[464,490],[554,481]],near=[603,977],far=[305,942],support='near',phase='near_right_contact',duration=120),
 dict(source='walk_near_down_far_pass_raw.png',component=0,root=[540,965],hands=[[540,463],[610,464]],near=[640,961],far=[270,952],support='near',phase='near_right_down_far_left_toeoff',duration=130),
 dict(source='walk_near_down_far_pass_raw.png',component=1,root=[1160,965],hands=[[1175,453],[1240,454]],near=[1191,963],far=[1015,891],support='near',phase='near_right_support_far_left_passing',duration=160),
 dict(source='walk_03_04_raw.png',component=1,root=[1200,967],hands=[[1211,444],[1273,445]],near=[885,963],far=[1410,919],support='near',phase='near_right_push_far_left_forward',duration=130),
]
cache={}
def isolate(file,component):
 if file not in cache:
  im=Image.open(SRC/file).convert('RGBA');a=np.array(im);lab,n=ndimage.label(a[:,:,3]>80);cnt=np.bincount(lab.ravel());ids=np.argsort(cnt[1:])[-2:]+1;ids=sorted(ids,key=lambda j:np.where(lab==j)[1].min());cache[file]=(a,lab,ids)
 a,lab,ids=cache[file];keep=ndimage.binary_dilation(lab==ids[component],iterations=3);q=a.copy();q[:,:,3]=np.where(keep,q[:,:,3],0);return Image.fromarray(q)
def place(im,scale,ox,oy):
 small=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(W,H));canvas.alpha_composite(small,(round(ox),round(oy)));return canvas
sw=Image.open(OLD/'reference/tachi.png').convert('RGBA');sa=Image.open(OLD/'reference/saya.png').convert('RGBA')
def weapon(src,anchor,point,angle,scale):
 t=math.radians(angle);c=math.cos(t)/scale;s=math.sin(t)/scale;gx,gy=point;ax,ay=anchor
 return src.transform((W,H),Image.Transform.AFFINE,(c,s,ax-c*gx-s*gy,-s,c,ay+s*gx-c*gy),Image.Resampling.BICUBIC)
records=[];comps=[];elapsed=0
for i,f in enumerate(spec,1):
 body=isolate(f['source'],f['component']);alpha=np.array(body.getchannel('A'));bb=Image.fromarray((alpha>80).astype('uint8')*255).getbbox();body.save(OUT/f'source_body_{i:02}.png')
 ox=RX-f['root'][0]*SCALE;oy=FY-f['root'][1]*SCALE;b=place(body,SCALE,ox,oy)
 # Use the exact approved combat tachi and saya artwork, size and guard angle.
 grip=[sum(p[0] for p in f['hands'])/2,sum(p[1] for p in f['hands'])/2];gp=[ox+grip[0]*SCALE,oy+grip[1]*SCALE]
 sword=weapon(sw,[100,1080],gp,-55,.085);sheath=weapon(sa,[87,22],[gp[0]-2,gp[1]+2],65,.073)
 mask=Image.new('L',body.size);md=ImageDraw.Draw(mask)
 for x,y in f['hands']:md.ellipse([x-34,y-34,x+34,y+34],fill=255)
 a=np.array(body);a[:,:,3]=(a[:,:,3].astype('uint16')*np.array(mask)//255).astype('uint8');hand=place(Image.fromarray(a),SCALE,ox,oy)
 comp=Image.new('RGBA',(W,H))
 for layer in [sheath,b,sword,hand]:comp.alpha_composite(layer)
 for label,im in [('body',b),('weapon',sword),('sheath',sheath),('hand_occlusion',hand),('composite',comp)]:im.save(OUT/f'{label}_{i:02}.png')
 comps.append(comp);local={side:[(f[side][0]-f['root'][0])*SCALE,(f[side][1]-f['root'][1])*SCALE] for side in ['near','far']}
 rec=dict(frame=i,source_file='../sources/'+f['source'],source_component=f['component'],source_sha256=hashlib.sha256((SRC/f['source']).read_bytes()).hexdigest(),source_bbox=list(bb),source_effective_height=bb[3]-bb[1],source_root=f['root'],root_canvas=[RX,FY],root_local=[0,0],render_origin=[ox,oy],scale=SCALE,duration_ms=f['duration'],start_ms=elapsed,phase=f['phase'],feet_source={s:f[s] for s in ['near','far']},feet_local=local,feet_canvas={s:[RX+local[s][0],FY+local[s][1]] for s in ['near','far']},support_foot=f['support'],leg_identity={'near':'anatomical_right','far':'anatomical_left'},grip_source=grip,grip_canvas=gp,hands_source=f['hands'],hands_canvas=[[ox+x*SCALE,oy+y*SCALE] for x,y in f['hands']],weapon_angle_degrees=-55,sheath_angle_degrees=65,weapon_angle_convention='clockwise rotation of approved upward-pointing tachi',layer_order=['sheath','body','weapon','hand_occlusion'],weapon_behind=False,sheath_behind=True,loop_next=1 if i==8 else i+1,world_delta=[0,0],fx=None,grounded=True)
 elapsed+=f['duration'];records.append(rec)
# Copy-only exact approved idle. Translation merely centers the comparison panel.
idle0=Image.open(BASE/'idle/composite.png').convert('RGBA');idle=Image.new('RGBA',(W,H));idle.alpha_composite(idle0,(85,-5));idle.save(BASE/'idle/comparison_centered.png')
# Preview track is separate from game world motion. Foot-lock chosen support samples.
preview_root=[0.0];switch=12.0
for j in range(1,8):
 prev,cur=records[j-1],records[j];delta=prev['feet_local'][prev['support_foot']][0]-cur['feet_local'][cur['support_foot']][0] if prev['support_foot']==cur['support_foot'] else switch;preview_root.append(preview_root[-1]+delta)
cycle_disp=preview_root[-1]+switch
for j,r in enumerate(records):r['preview_displacement_px']=[round(preview_root[j],4),0]
meta=dict(hero='ieyasu06',revision='graywhite06_walk_candidate_01',action='walk',approval='pending_user_review',loop=True,loop_start=1,loop_end=8,frame_count=8,total_ms=elapsed,standing_ruler_source_px=920,standing_ruler_target_px=152,one_constant_body_scale=SCALE,per_frame_bbox_height_normalization=False,original_png_preserved=True,body_final_downsample_only=True,image_generation_tool='official image_gen.imagegen',direct_approved_references=[str(OLD/'reference/identity06.png'),str(OLD/'actions/light_1_source.png')],layers=['body','weapon','sheath','hand_occlusion'],ordinary_action_fx=False,world_motion=dict(mode='in_place',per_frame_delta=[0,0],driver='runtime_controller',preview_motion_not_baked=True),preview_motion=dict(mode='discrete_support_foot_lock',displacement_per_cycle=cycle_disp,displacement_by_frame=preview_root,step_switch_advance=switch,not_runtime_world_motion=True),shared_idle='../idle/registration.json',frames=records,runtime_integrated=False,limitations=['Foot contacts and anatomical overlap are visual measurements, not rig simulation.','Generated independent keyframes retain source pose-height variation; fixed scale, no bbox equalization.','Candidate is not approved and not integrated into game or site.'])
(OUT/'metadata.json').write_text(json.dumps(meta,indent=2))
def bg():
 im=Image.new('RGB',(W,H),(37,43,52));d=ImageDraw.Draw(im);d.line((10,FY+1,W-10,FY+1),fill=(80,87,94));return im
normal=[];comparison=[]
for j,comp in enumerate(comps):
 can=bg();can.paste(comp,(0,0),comp);d=ImageDraw.Draw(can);d.text((12,9),'IEYASU 06 | WALK CANDIDATE | 152px ruler',fill=(230,232,237));d.text((12,H-23),f'{j+1}/8  {records[j]["phase"]}  {records[j]["duration_ms"]}ms',fill=(192,199,208));normal.append(can)
 cp=Image.new('RGB',(W*2,H),(37,43,52));left=bg();left.paste(idle,(0,0),idle);ImageDraw.Draw(left).text((12,9),'APPROVED COMBAT IDLE | same 152px ruler',fill=(230,232,237));cp.paste(left,(0,0));cp.paste(can,(W,0));comparison.append(cp)
durs=[r['duration_ms'] for r in records]
for name,frames,factor in [('normal.gif',normal,1),('slow.gif',normal,2),('idle-walk-comparison.gif',comparison,1)]:frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=[x*factor for x in durs],loop=0,disposal=2)
comparison[0].save(OUT/'idle-walk-comparison.png')
contact=Image.new('RGB',(W*4,H*2))
for j,f in enumerate(normal):contact.paste(f,(j%4*W,j//4*H))
contact.save(OUT/'contact.png')
# Show transition to/from actual approved idle without introducing an idle hitch into the continuous loop.
idlebg=bg();idlebg.paste(idle,(0,0),idle);ImageDraw.Draw(idlebg).text((12,9),'IEYASU 06 | approved idle / walk / approved idle',fill='white')
transition=[idlebg]+normal*2+[idlebg];transition[0].save(OUT/'idle-walk-idle.gif',save_all=True,append_images=transition[1:],duration=[500]+durs*2+[500],loop=0,disposal=2)
WW,HH=1000,330;travel=[]
for cycle in range(2):
 for j,comp in enumerate(comps):
  im=Image.new('RGB',(WW,HH),(37,43,52));d=ImageDraw.Draw(im);d.line((0,FY+31,WW,FY+31),fill=(85,92,99))
  for tick in range(0,WW,40):d.line((tick,FY+31,tick,FY+38),fill=(110,117,124))
  pos=round(20+cycle*cycle_disp+preview_root[j]);im.paste(comp,(pos,30),comp);d.text((14,10),'IEYASU 06 | WALK | preview-only planted-foot root track',fill=(230,232,237));d.text((14,HH-25),'2 cycles; GIF reset only. Runtime sprite is in-place; no FX.',fill=(192,199,208));travel.append(im)
travel[0].save(OUT/'world-preview.gif',save_all=True,append_images=travel[1:],duration=durs*2,loop=0,disposal=2)
errors=[]
for i,r in enumerate(records,1):
 for lay in ['body','weapon','sheath','hand_occlusion','composite']:
  im=Image.open(OUT/f'{lay}_{i:02}.png');assert im.size==(W,H) and im.mode=='RGBA';assert im.getextrema()[3][0]==0
 assert r['source_effective_height']>=600
 if i>1 and records[i-2]['support_foot']==r['support_foot']:
  prev=records[i-2];errors.append(abs(prev['feet_local'][r['support_foot']][0]+preview_root[i-2]-r['feet_local'][r['support_foot']][0]-preview_root[i-1]))
qa=dict(artifact_checks='pass',frame_count=8,minimum_effective_source_height=min(r['source_effective_height'] for r in records),maximum_effective_source_height=max(r['source_effective_height'] for r in records),constant_scale=SCALE,target_standing_ruler=152,max_discrete_support_lock_error_px=max(errors),genuine_alpha=True,raw_generated_sources_preserved=True,no_optical_flow=True,no_repeated_small_tile_generation=True,all_generation_references_approved_identity_and_combat_originals=True,existing_combat_assets_unchanged=True,portrait_is_approved_source_crop=True,no_fx=True,visual_review='pending_final_contact_and_gif_review',approval='pending_user')
(OUT/'QA.json').write_text(json.dumps(qa,indent=2))
(BASE/'README.txt').write_text('Ieyasu gray-white06 walk candidate. Existing combat assets unchanged.\nOnly walk was drawn. Stop for user review before 8 remaining base actions.\nidle/ registers exact approved light_1 frame0; portrait/ is crop only.\nwalk/ contains 8 RGBA body/weapon/sheath/hand-occlusion/composite layers, metadata and previews.\nsources/ preserves every official image_gen original including rejected alternatives.\nSource character effective height 896-957px. Constant 152/920 scale; no frame bbox normalization.\nOrdinary walk has no FX. Each frame directly generated using approved identity and combat source references, no optical flow.\nWeapon/saya reuse approved artwork and angle. World delta is zero; preview foot-lock root track is separate.\nLoop 8 to 1. Idle transition preview is separate from the uninterrupted walk loop.\nCandidate pending user approval, not installed in website or Git.\n')
print(json.dumps({'output':str(OUT.resolve()),'frames':8,'total_ms':elapsed,'preview_cycle_displacement':cycle_disp,'qa':qa},indent=2))
