from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,math,sys
from scipy.ndimage import label,find_objects
from build_base import head95,font,sha
P=Path(__file__).resolve().parents[1];CANVAS=(520,380);ROOT=(220,333)
def build(action):
 D=P/action;cfg=json.loads((D/'build_config.json').read_text());S=D/'source';high=D/'frames_high';low=D/'frames';qa=D/'qa'
 for p in [high,low,qa]:p.mkdir(exist_ok=True)
 frames=[];records=[];sources={};sword=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
 def add_idle(dur,phase):
  idx=len(frames);ims={}
  for layer,f in [('body','body_exact_00.png'),('weapon','weapon_exact_00.png'),('hand_occlusion','hand_occlusion_exact_00.png'),('composite','composite_00.png')]:
   im=Image.new('RGBA',CANVAS);im.alpha_composite(Image.open(P/'idle'/f).convert('RGBA'),(35,80));im.save(low/f'{layer}_{idx:02}.png');ims[layer]=im
  frames.append(ims['composite']);records.append(dict(index=idx,duration_ms=dur,phase=phase,source='approved_idle',source_is_existing_approved=True,root_canvas=list(ROOT),root_world=[0,0],preview_displacement=[0,0],feet_canvas={'near':[185,330],'far':[253,330]},feet_world={'near':[185,330],'far':[253,330]},support='both',grip_canvas=[214.625,247.125],grip_world=[214.625,247.125],weapon_angle_deg=120,head_scale=.95,layer_order=['body','weapon','hand_occlusion'],fx=None))
 if cfg.get('idle_start') is not None:add_idle(cfg['idle_start'],'approved_idle_entry')
 for c in cfg['frames']:
  idx=len(frames);src=S/c['src'];im=Image.open(src).convert('RGBA');a=np.array(im);labs,n=label(a[:,:,3]>20);items=[]
  for ident,sl in enumerate(find_objects(labs),1):
   if (labs[sl]==ident).sum()>10000:items.append((ident,(sl[1].start,sl[0].start,sl[1].stop,sl[0].stop)))
  items.sort(key=lambda e:e[1][0]);ident,box=items[c['side']];sources[c['src']]={'sha256':sha(src),'size_px':im.size};a[:,:,3]=np.where(labs==ident,a[:,:,3],0);body=head95(Image.fromarray(a),tuple(c['head']));body.crop(box).save(high/f'body_{idx:02}.png')
  hm=Image.new('L',im.size);ImageDraw.Draw(hm).rounded_rectangle(c['hands'],radius=10,fill=255);ha=np.array(body);ha[:,:,3]=(ha[:,:,3].astype('uint16')*np.array(hm)//255).astype('uint8');hand=Image.fromarray(ha);hand.crop(box).save(high/f'hand_occlusion_{idx:02}.png')
  origin=c['origin'];s=c['scale'];ox=ROOT[0]-origin[0]*s;oy=ROOT[1]-origin[1]*s;world=c.get('world',[0,0]);preview=c.get('preview',world)
  pt=lambda p:[round(ox+p[0]*s,3),round(oy+p[1]*s,3)]
  size=(round((box[2]-box[0])*s),round((box[3]-box[1])*s));dest=(round(ox+box[0]*s),round(oy+box[1]*s))
  bc=Image.new('RGBA',CANVAS);bc.alpha_composite(body.crop(box).resize(size,Image.Resampling.LANCZOS),dest);hc=Image.new('RGBA',CANVAS);hc.alpha_composite(hand.crop(box).resize(size,Image.Resampling.LANCZOS),dest)
  g=pt(c['grip']);t=math.radians(c['angle']);ws=.145;co=math.cos(t)/ws;si=math.sin(t)/ws;px,py=g;ax,ay=180,710
  wl=sword.transform(CANVAS,Image.Transform.AFFINE,(co,si,ax-co*px-si*py,-si,co,ay+si*px-co*py),Image.Resampling.BICUBIC)
  comp=bc.copy();comp.alpha_composite(wl);comp.alpha_composite(hc)
  for name,z in [('body',bc),('weapon',wl),('hand_occlusion',hc),('composite',comp)]:z.save(low/f'{name}_{idx:02}.png')
  fpts={k:pt(v) for k,v in c['feet'].items()};fw={k:[p[0]+world[0],p[1]+world[1]] for k,p in fpts.items()}
  frames.append(comp);records.append(dict(index=idx,duration_ms=c['duration_ms'],phase=c['phase'],source=c['src'],source_rect=list(box),source_figure_height_px=box[3]-box[1],source_figure_span_px=max(box[2]-box[0],box[3]-box[1]),source_head_rect=c['head'],head_scale=.95,standing_ruler_px=150,body_calibration_scale=s,calibration_basis='same-direction head/torso and limb size, never silhouette equal-height scaling',origin_source=origin,root_canvas=list(ROOT),root_world=world,preview_displacement=preview,feet_canvas=fpts,feet_world=fw,support=c['support'],grip_canvas=g,grip_world=[g[0]+world[0],g[1]+world[1]],grip_source=c['grip'],grip_hand=c.get('grip_hand','both'),weapon_angle_deg=c['angle'],weapon_angle_convention='0 up, clockwise positive',weapon_source='../reference/sword_uchigatana.png',weapon_pivot_source=[180,710],weapon_scale=.145,layer_order=['body','weapon','hand_occlusion'],fx=None,event=c.get('event')))
 if cfg.get('idle_end') is not None:add_idle(cfg['idle_end'],'approved_idle_exit')
 review_w=cfg.get('review_width',640);candidate_x=cfg.get('review_candidate_x',200);native_size=tuple(cfg.get('preview_canvas',CANVAS));native_base=cfg.get('preview_base',[0,0]);duration=sum(r['duration_ms'] for r in records);review=[];native=[];idle=Image.open(P/'idle/composite_00.png').convert('RGBA');elapsed=0
 for i,(im,r) in enumerate(zip(frames,records)):
  bg=Image.new('RGBA',(review_w,420),(42,48,56,255));dr=ImageDraw.Draw(bg);dr.text((20,15),f'HIDEYOSHI / {action.upper()} CANDIDATE / HEAD 95%',font=font(16),fill='white');dr.text((65,53),'Approved combat idle',font=font(13),fill=(190,200,213));dr.text((candidate_x+148,53),f'{action} - fixed 150px ruler',font=font(13),fill=(190,200,213));bg.alpha_composite(idle,(-53,98));dx,dy=r['preview_displacement'];bg.alpha_composite(im,(round(candidate_x+dx),round(18+dy)));dr.line((45,352,review_w-46,352),fill=(100,110,125));dr.text((22,386),f'{i+1:02}/{len(frames):02} | {elapsed:03} ms | {duration} ms | no FX | loop {cfg["loop"]}',font=font(12),fill=(195,205,218));review.append(bg.convert('RGB'));elapsed+=r['duration_ms']
  nb=Image.new('RGBA',native_size,(42,48,56,255));nb.alpha_composite(im,(round(native_base[0]+dx),round(native_base[1]+dy)));native.append(nb.convert('RGB'))
 dur=[r['duration_ms'] for r in records]
 for name,arr in [('review',review),('preview',native)]:arr[0].save(D/f'hideyoshi_{action}_{name}.gif',save_all=True,append_images=arr[1:],duration=dur,loop=0,disposal=2,optimize=False)
 contact=Image.new('RGB',(review_w*2,420*math.ceil(len(frames)/2)),(42,48,56))
 for i,im in enumerate(review):contact.paste(im,((i%2)*review_w,(i//2)*420))
 contact.save(qa/'idle_action_contact.png');review[cfg.get('representative',min(2,len(review)-1))].save(qa/'idle_action_same_scale.png')
 meta=dict(character='hideyoshi',action=action,status='candidate_pending_user_review',description=cfg['description'],version=action+'_v1_direct_original_highres',duration_ms=duration,frame_count=len(frames),loop=cfg['loop'],preview_loop=True,preview_loop_reset_is_not_runtime_motion=True,canvas=list(CANVAS),standing_ruler_px=150,head_scale=.95,layers=['body','weapon','hand_occlusion'],frame_path='frames/{layer}_{index:02}.png',fx=None,source_generation='official image_gen; every source directly references approved original identity and full original mother sheet; no child generation loop',new_detail_disclosure='Only pose and cloth/armor detail redrawn at high resolution; no new ornament or identity redesign.',source_info=sources,world_motion={'mode':cfg.get('world_mode','sampled separate root track'),'root_track':[r['root_world'] for r in records],'preview_displacement_separate':True,'composite_pngs_are_root_local':True,'world_coordinates':'x right, y down; relative to action entry','world_end_delta':records[-1]['root_world']},frames=records,quality_notes=['Candidate; not runtime integrated.','Original high-resolution PNGs retained. Local head95 then one final body downsample.','Whole-body drawn poses; no optical-flow or synthetic motion interpolation.','Preview adds separate root displacement; do not apply it twice.','Approved idle entry/exit preserved without redraw when present.'])
 (D/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2));validation={'frame_count':len(frames),'duration_ms':duration,'raw_new_figure_heights':[r['source_figure_height_px'] for r in records if 'source_figure_height_px' in r],'raw_new_figure_spans':[r['source_figure_span_px'] for r in records if 'source_figure_span_px' in r],'layers':{},'visual_contact_inspected':False,'runtime_tested':False}
 for layer in ['body','weapon','hand_occlusion']:
  validation['layers'][layer]={'rgba':all(Image.open(low/f'{layer}_{i:02}.png').mode=='RGBA' for i in range(len(frames))),'transparent':all(np.array(Image.open(low/f'{layer}_{i:02}.png'))[:,:,3].min()==0 for i in range(len(frames)))}
 g=Image.open(D/f'hideyoshi_{action}_review.gif');validation['gif_decoded_frames']=g.n_frames;validation['gif_duration_ms']=sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames));validation['all_new_raw_above_600']=min(validation['raw_new_figure_spans'])>=600;(qa/'validation.json').write_text(json.dumps(validation,indent=2));print(action,json.dumps(validation))
if __name__=='__main__':
 for action in sys.argv[1:]:build(action)
