from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,sys,json,hashlib,math,shutil
BASE=Path(__file__).parent;sys.path.insert(0,str(BASE));import render_action as R
OUT=BASE/'run_v4';Q=OUT/'qa';Q.mkdir(exist_ok=True);s=152/920;ox=220-560*s;oy=280-949*s
upper=Image.open(Q/'fixed_upper_native.png').convert('RGBA')
configs=[
 {'contact':1,'phase':'far_contact','duration':100,'event':'far_foot_contact','support':'far'},
 {'src':'run_v4_near_support_far_low_pass_v2_raw.png','dx':155,'dy':949-1450/1.5,'phase':'far_support_near_low_swing','duration':90,'support':'far','feet':{'near':[380,1160],'far':[640,1450]}},
 {'src':'run_v4_near_low_flight_raw.png','dx':100,'dy':20,'phase':'short_flight_near_leads','duration':60,'support':'none','feet':{'near':[890,1340],'far':[145,1230]}},
 {'contact':4,'phase':'near_contact','duration':100,'event':'near_foot_contact','support':'near'},
 {'src':'run_v4_far_support_near_low_pass_v2_raw.png','dx':170,'dy':949-1420/1.5,'phase':'near_support_far_low_swing','duration':90,'support':'near','feet':{'near':[600,1420],'far':[370,1170]}},
 {'src':'run_v4_far_low_flight_raw.png','dx':130,'dy':12,'phase':'short_flight_far_leads','duration':60,'support':'none','feet':{'near':[115,1175],'far':[910,1355]}}
]
old=json.load(open(BASE/'run_v2/metadata.json'));recs=[];comps=[];elapsed=0
for i,f in enumerate(configs,1):
 if 'contact' in f:
  j=f['contact'];lays={k:Image.open(BASE/f'run_v2/{k}_{j:02}.png').convert('RGBA') for k in ['body','weapon','sheath','hand_occlusion']};rec=dict(old['frames'][j-1]);rec.update(retained_parent_reviewed_contact=True)
 else:
  lower=R.isolate({'source':f['src']});aa=np.array(lower);nativebbox=lower.getbbox();aa[:810,:,3]=0;lower=Image.fromarray(aa);lower.save(Q/f'lower_part_{i:02}_native.png')
  dx,dy=f['dx'],f['dy'];b=R.place(lower,s/1.5,ox+dx*s,oy+dy*s);b.alpha_composite(R.place(upper,s,ox,oy))
  if f['phase'].startswith('short_flight'):
   side='near' if i==3 else 'far';patch=Image.open(BASE/f'sources/run_v4_flight_{side}_seam_raw.png').convert('RGBA');ss=(152/1380)*(1536/patch.width)
   pp=R.place(patch,ss,ox,oy);mask=Image.new('L',(480,320));md=ImageDraw.Draw(mask);md.rectangle((round(ox+370*152/1380),round(oy+740*152/1380),round(ox+1080*152/1380),round(oy+925*152/1380)),fill=255)
   # Only local waist patch replaces pixels, including clearing duplicate armor; fixed original upper overlays it again.
   ma=np.array(mask);ba=np.array(b.getchannel('A'));ma=np.where(ba>1,ma,0).astype('uint8');mask=Image.fromarray(ma);md=ImageDraw.Draw(mask);md.rectangle((round(ox+810*152/1380),round(oy+750*152/1380),round(ox+905*152/1380),round(oy+850*152/1380)),fill=255)
   b=Image.composite(pp,b,mask);b.alpha_composite(R.place(upper,s,ox,oy));mask.save(Q/f'seam_patch_mask_{i:02}_game.png')
  gp=[ox+621*s,oy+435.5*s];hands=[[590,433],[652,438]]
  sw=R.weapon(R.sw,[100,1080],gp,-55,.085);sa=R.weapon(R.sa,[87,22],[ox+609*s,oy+447.5*s],65,.073)
  hm=Image.new('L',upper.size);dd=ImageDraw.Draw(hm)
  for x,y in hands:dd.ellipse((x-34,y-34,x+34,y+34),fill=255)
  a=np.array(upper);a[:,:,3]=a[:,:,3].astype('uint16')*np.array(hm)//255;hand=R.place(Image.fromarray(a),s,ox,oy);lays={'body':b,'weapon':sw,'sheath':sa,'hand_occlusion':hand}
  # Native assembly for inspection, never used as a downsample input.
  nat=Image.new('RGBA',(1800,1536));nat.alpha_composite(lower,(round(dx*1.5),round(dy*1.5)));nat.alpha_composite(upper.resize((2304,1536),Image.Resampling.NEAREST),(0,0));nat.save(Q/f'hybrid_{i:02}_native.png')
  rec=dict(source_file='../sources/'+f['src'],source_sha256=hashlib.sha256((BASE/'sources'/f['src']).read_bytes()).hexdigest(),source_effective_height=nativebbox[3]-nativebbox[1],source_bbox=list(nativebbox),source_standing_ruler=1380,upper_source_file='../sources/run_v2_contacts_raw.png',upper_source_component=0,upper_source_standing_ruler=920,upper_mask='qa/fixed_upper_native.png',lower_mask=f'qa/lower_part_{i:02}_native.png',source_part_render={'upper':{'scale':s,'origin':[ox,oy]},'lower':{'scale':s/1.5,'origin':[ox+dx*s,oy+dy*s]}},source_root=[(560-dx)*1.5,(949-dy)*1.5],root_canvas=[220,280],root_local=[0,0],grip_canvas=gp,hands_canvas=[[ox+x*s,oy+y*s] for x,y in hands],weapon_angle_degrees=-55,sheath_angle_degrees=65,feet_canvas={k:[ox+dx*s+x*s/1.5,oy+dy*s+y*s/1.5] for k,(x,y) in f['feet'].items()},feet_source=f['feet'],anatomy_labels_assigned_after_visual_review=True)
 comp=Image.new('RGBA',(480,320))
 for k in ['sheath','body','weapon','hand_occlusion']:lays[k].save(OUT/f'{k}_{i:02}.png');comp.alpha_composite(lays[k])
 comp.save(OUT/f'composite_{i:02}.png');comps.append(comp)
 rec.update(frame=i,duration_ms=f['duration'],start_ms=elapsed,phase=f['phase'],event=f.get('event'),support_foot=f['support'],grounded=f['support']!='none',loop_next=i+1 if i<6 else 1,world_delta=[0,0],preview_displacement=[0,0],world_travel_preview_only=[-80+(i-1)*32,0],layer_order=['sheath','body','weapon','hand_occlusion'],weapon_behind=False,sheath_behind=True,fx=None);recs.append(rec);elapsed+=f['duration']
meta={'hero':'ieyasu06','action':'run','revision':'run_v4_candidate_01','approval':'pending_dynamic_parent_review','loop':True,'frame_count':6,'total_ms':elapsed,'standing_ruler_target_px':152,'source_standing_rulers':[920,1380],'per_frame_bbox_height_normalization':False,'body_final_downsample_only':True,'source_parts_sampled_once_directly_to_game':True,'native_hybrids_are_inspection_only':True,'image_generation_tool':'official image_gen.imagegen','original_png_preserved':True,'ordinary_action_fx':False,'direct_approved_references':['ieyasu06_newspec_20261015/reference/identity06.png','ieyasu06_newspec_20261015/actions/light_1_source.png'],'layers':['body','weapon','sheath','hand_occlusion'],'world_motion':{'mode':'runtime_controller','per_frame_delta':[0,0],'preview_motion_not_baked':True},'shared_idle':'../idle/registration.json','frames':recs,'runtime_integrated':False,'notes':['One cycle has exactly one far contact and one near contact; no horizontal mirror.','Parent allowed the v2 two contact poses, then allowed v4 low passing poses as candidates. Passing frame5 knee-cuff junction has slight occlusion ambiguity retained for candidate dynamic review.','Upper body is fixed high-resolution contact original. Low passing and short-flight lower halves are generated directly against approved references. Part composite permitted; game body samples each original part once with LANCZOS.','Flight shoe clearance is approximately 5px. No raised high knee or wide scissor flight.','Flight waist cleanup uses only a bounded high-resolution official-imagegen seam patch; face, hands, chest, knees and feet remain direct original parts.','Frame6 source sandal extreme tip touches source edge; visible toe outline is intact, padded game canvas has no clipped alpha.']}
(OUT/'metadata.json').write_text(json.dumps(meta,indent=2))
normal=[];compare=[];zoom=[];world=[]
for i,(co,r) in enumerate(zip(comps,recs)):
 im=Image.new('RGB',(480,320),'#252b34');im.paste(co,(0,0),co);d=ImageDraw.Draw(im);d.line((10,281,470,281),fill='#68717b');d.text((12,10),'IEYASU RUN v4 CANDIDATE | 152px ruler',fill='white');d.text((12,298),f'{i+1}/6 {r["phase"]} {r["duration_ms"]}ms',fill='white');normal.append(im)
 left=Image.new('RGB',(480,320),'#252b34');left.paste(R.IDLE['composite'],(0,0),R.IDLE['composite']);ImageDraw.Draw(left).text((12,10),'APPROVED COMBAT IDLE | 152px ruler',fill='white');ImageDraw.Draw(left).line((10,281,470,281),fill='#68717b');cp=Image.new('RGB',(960,320));cp.paste(left,(0,0));cp.paste(im,(480,0));compare.append(cp)
 z=im.crop((100,105,330,290)).resize((690,555),Image.Resampling.NEAREST);zoom.append(z)
 wr=Image.new('RGB',(480,320),'#252b34');wr.paste(co,(-80+i*32,0),co);ImageDraw.Draw(wr).line((10,281,470,281),fill='#68717b');ImageDraw.Draw(wr).text((12,10),'PREVIEW TRAVEL ONLY - runtime world delta remains 0',fill='white');world.append(wr)
for name,frames,factor,loop in [('normal.gif',normal,1,True),('idle-comparison.gif',compare,1,True),('zoom.gif',zoom,1,True),('slow-once.gif',normal,3,False),('world-preview.gif',world,1,True)]:
 kw={'save_all':True,'append_images':frames[1:],'duration':[f['duration']*factor for f in configs],'disposal':2}
 if loop:kw['loop']=0
 frames[0].save(OUT/name,**kw)
compare[1].save(OUT/'idle-comparison.png');strip=Image.new('RGB',(1380,820),'#252b34');d=ImageDraw.Draw(strip)
for i,im in enumerate(normal):
 crop=im.crop((100,105,330,290)).resize((460,370),Image.Resampling.NEAREST);strip.paste(crop,(i%3*460,i//3*410+30));d.text((i%3*460+10,i//3*410+8),f'{i+1} {recs[i]["phase"]}',fill='white')
strip.save(OUT/'numbered-pose-strip-final.png')
# Native lower limb strip for visibility of true upper thigh overlap.
nat=Image.new('RGB',(1800,800),'#bbc0c5')
for i,j in enumerate([3,6]):
 im=Image.open(Q/f'hybrid_{j:02}_native.png');bg=Image.new('RGBA',im.size,'#bbc0c5');bg.alpha_composite(im);crop=bg.crop((100,750,1000,1500)).convert('RGB');nat.paste(crop,(i*900,30));ImageDraw.Draw(nat).text((i*900+12,10),f'FRAME {j}: near thigh {"forward" if j==3 else "back"}; short flight',fill='black')
nat.save(Q/'flight_lower_native.png')
# canonical three layer export
T=BASE/'three_layer_export/run_v4';T.mkdir(exist_ok=True,parents=True);checks=[]
for i,co in enumerate(comps,1):
 b=Image.open(OUT/f'sheath_{i:02}.png').convert('RGBA');b.alpha_composite(Image.open(OUT/f'body_{i:02}.png'));lays=[b,Image.open(OUT/f'weapon_{i:02}.png'),Image.open(OUT/f'hand_occlusion_{i:02}.png')];cc=Image.new('RGBA',(480,320))
 for k,im in zip(['body','weapon','hand_occlusion'],lays):im.save(T/f'{k}_{i:02}.png');cc.alpha_composite(im)
 cc.save(T/f'composite_{i:02}.png');ar=np.array(cc);checks.append({'frame':i,'three_layer_max_rgba_error':int(np.abs(ar.astype(int)-np.array(co).astype(int)).max()),'canvas_edge_alpha_nonzero':int(np.count_nonzero(ar[0,:,3])+np.count_nonzero(ar[-1,:,3])+np.count_nonzero(ar[:,0,3])+np.count_nonzero(ar[:,-1,3]))})
cm=dict(meta);cm.update(layers=['body','weapon','hand_occlusion'],body_includes_sheath=True,source_revision='../../run_v4/metadata.json');
for r in cm['frames']:r['layer_order']=['body','weapon','hand_occlusion']
(T/'metadata.json').write_text(json.dumps(cm,indent=2));(OUT/'QA.json').write_text(json.dumps({'visual_review':'pending_dynamic_parent_review','ruler':152,'frame_checks':checks,'raw_sources_preserved':True,'no_optical_flow':True,'no_derived_small_frame_reference':True,'runtime_tested':False,'minimum_new_full_source_height':min(r.get('source_effective_height',9999) for r in recs)},indent=2));print('Built 6 frames',elapsed,'ms',checks)
