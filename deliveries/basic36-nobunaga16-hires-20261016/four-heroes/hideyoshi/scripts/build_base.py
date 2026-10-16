from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,math,hashlib,zipfile
from scipy.ndimage import label,find_objects
P=Path(__file__).resolve().parents[1]
ROOT=(220,253);CANVAS=(520,300)
CONFIG={
'hurt':dict(loop=False,description='站立受擊後仰、屈膝吸收，再回到核准戰鬥idle；不跨步，不帶FX。',idle_start=60,idle_end=160,frames=[
 dict(src='pair_0.png',side=0,s=.164,head=(307,62,487,239),hands=(445,418,582,505),grip=(515,463),feet=[(275,953),(726,953)],angle=123,dur=40,phase='initial_flinch'),
 dict(src='pair_0.png',side=1,s=.164,head=(889,104,1084,258),hands=(1145,463,1273,542),grip=(1211,502),feet=[(920,953),(1390,953)],angle=128,dur=60,phase='peak_back_recoil'),
 dict(src='pair_1.png',side=0,s=.170,head=(303,114,466,282),hands=(482,437,599,512),grip=(541,478),feet=[(265,953),(706,953)],angle=124,dur=70,phase='settle_from_recoil'),
 dict(src='pair_1.png',side=1,s=.170,head=(999,107,1178,287),hands=(1034,447,1155,529),grip=(1095,490),feet=[(902,953),(1316,960)],angle=120,dur=90,phase='regain_ready'),
]),
'stunned':dict(loop=True,description='站立暈眩：頭肩低垂、重心小幅左右搖晃；腳底固定，無星星、光圈或其他FX。',idle_start=None,idle_end=None,frames=[
 dict(src='pair_0.png',side=0,s=.170,head=(451,52,621,258),hands=(395,423,522,501),grip=(459,460),feet=[(294,931),(675,939)],angle=123,dur=220,phase='sag_left'),
 dict(src='pair_0.png',side=1,s=.170,head=(1030,53,1209,259),hands=(1026,426,1150,502),grip=(1089,465),feet=[(909,931),(1286,940)],angle=122,dur=180,phase='sag_center_low'),
 dict(src='pair_1.png',side=0,s=.168,head=(422,51,602,258),hands=(405,426,533,507),grip=(471,465),feet=[(286,948),(677,949)],angle=124,dur=220,phase='sag_right'),
 dict(src='pair_1.png',side=1,s=.168,head=(993,50,1185,260),hands=(996,443,1124,515),grip=(1060,481),feet=[(904,950),(1297,955)],angle=122,dur=180,phase='sag_center_high'),
])}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def font(size):
 try:return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',size)
 except:return ImageFont.load_default()
def head95(im,rect):
 x0,y0,x1,y1=rect;crop=im.crop(rect);nw=round(crop.width*.95);nh=round(crop.height*.95);o=im.copy();o.paste((0,0,0,0),rect);o.alpha_composite(crop.resize((nw,nh),Image.Resampling.LANCZOS),(x0+(crop.width-nw)//2,y1-nh));return o

def build(action):
 cfg=CONFIG[action];D=P/action;S=D/'source';high=D/'frames_high';low=D/'frames';qa=D/'qa'
 for p in [D,S,high,low,qa]:p.mkdir(parents=True,exist_ok=True)
 frames=[];records=[];sources={};sword=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
 def add_idle(dur,phase):
  idx=len(frames);images={};shift=(35,0)
  for layer,filename in [('body','body_exact_00.png'),('weapon','weapon_exact_00.png'),('hand_occlusion','hand_occlusion_exact_00.png'),('composite','composite_00.png')]:
   im=Image.new('RGBA',CANVAS);im.alpha_composite(Image.open(P/'idle'/filename).convert('RGBA'),shift);im.save(low/f'{layer}_{idx:02}.png');images[layer]=im
  frames.append(images['composite']);records.append(dict(index=idx,duration_ms=dur,phase=phase,source='approved_idle',source_is_existing_approved=True,root_canvas=list(ROOT),root_world=[0,0],preview_displacement=[0,0],feet_canvas={'near':[185,250],'far':[253,250]},grip_canvas=[214.625,167.125],weapon_angle_deg=120,layer_order=['body','weapon','hand_occlusion'],fx=None,head_scale=.95,standing_ruler_px=150))
 if cfg.get('idle_start') is not None:add_idle(cfg['idle_start'],'approved_idle_entry')
 for c in cfg['frames']:
  idx=len(frames);src=S/c['src'];im=Image.open(src).convert('RGBA');a=np.array(im);labs,n=label(a[:,:,3]>20);items=[]
  for ident,sl in enumerate(find_objects(labs),1):
   if (labs[sl]==ident).sum()>10000:items.append((ident,(sl[1].start,sl[0].start,sl[1].stop,sl[0].stop)))
  items.sort(key=lambda e:e[1][0]);ident,box=items[c['side']];sources[c['src']]={'sha256':sha(src),'size_px':im.size};a[:,:,3]=np.where(labs==ident,a[:,:,3],0);body=head95(Image.fromarray(a),c['head']);body.crop(box).save(high/f'body_{idx:02}.png')
  hm=Image.new('L',im.size);ImageDraw.Draw(hm).rounded_rectangle(c['hands'],radius=10,fill=255);ha=np.array(body);ha[:,:,3]=(ha[:,:,3].astype('uint16')*np.array(hm)//255).astype('uint8');hand=Image.fromarray(ha);hand.crop(box).save(high/f'hand_occlusion_{idx:02}.png')
  feet=c['feet'];origin=((feet[0][0]+feet[1][0])/2,max(feet[0][1],feet[1][1]));ox=ROOT[0]-origin[0]*c['s'];oy=ROOT[1]-origin[1]*c['s']
  pt=lambda p:[round(ox+p[0]*c['s'],3),round(oy+p[1]*c['s'],3)]
  size=(round((box[2]-box[0])*c['s']),round((box[3]-box[1])*c['s']));dest=(round(ox+box[0]*c['s']),round(oy+box[1]*c['s']))
  bc=Image.new('RGBA',CANVAS);bc.alpha_composite(body.crop(box).resize(size,Image.Resampling.LANCZOS),dest);hc=Image.new('RGBA',CANVAS);hc.alpha_composite(hand.crop(box).resize(size,Image.Resampling.LANCZOS),dest)
  g=pt(c['grip']);t=math.radians(c['angle']);ws=.145;co=math.cos(t)/ws;si=math.sin(t)/ws;px,py=g;ax,ay=180,710
  wl=sword.transform(CANVAS,Image.Transform.AFFINE,(co,si,ax-co*px-si*py,-si,co,ay+si*px-co*py),Image.Resampling.BICUBIC);comp=bc.copy();comp.alpha_composite(wl);comp.alpha_composite(hc)
  for name,z in [('body',bc),('weapon',wl),('hand_occlusion',hc),('composite',comp)]:z.save(low/f'{name}_{idx:02}.png')
  frames.append(comp);records.append(dict(index=idx,duration_ms=c['dur'],phase=c['phase'],source=c['src'],source_rect=list(box),source_figure_height_px=box[3]-box[1],source_head_rect=list(c['head']),head_scale=.95,standing_ruler_px=150,body_calibration_scale=c['s'],calibration_basis='same-direction head/torso measures, never whole-body bounding box equalization',root_canvas=list(ROOT),root_world=[0,0],preview_displacement=[0,0],feet_canvas={'near':pt(feet[0]),'far':pt(feet[1])},feet_source=feet,grip_canvas=g,grip_source=c['grip'],weapon_angle_deg=c['angle'],weapon_angle_convention='0 up, clockwise positive',weapon_source='../reference/sword_uchigatana.png',weapon_pivot_source=[180,710],weapon_scale=.145,layer_order=['body','weapon','hand_occlusion'],fx=None))
 if cfg.get('idle_end') is not None:add_idle(cfg['idle_end'],'approved_idle_exit')
 duration=sum(r['duration_ms'] for r in records);review=[];native=[];idle=Image.open(P/'idle/composite_00.png').convert('RGBA');elapsed=0
 for i,im in enumerate(frames):
  bg=Image.new('RGBA',(640,340),(42,48,56,255));dr=ImageDraw.Draw(bg);dr.text((20,15),f'HIDEYOSHI / {action.upper()} CANDIDATE / HEAD 95%',font=font(16),fill='white');dr.text((65,53),'Approved combat idle',font=font(13),fill=(190,200,213));dr.text((348,53),f'{action} - fixed 150px ruler',font=font(13),fill=(190,200,213));bg.alpha_composite(idle,(-53,18));bg.alpha_composite(im,(200,18));dr.line((45,272,594,272),fill=(100,110,125));dr.text((22,305),f'{i+1:02}/{len(frames):02} | {elapsed:03} ms | {duration} ms | no FX | runtime loop {cfg["loop"]}',font=font(12),fill=(195,205,218));review.append(bg.convert('RGB'));elapsed+=records[i]['duration_ms']
  nb=Image.new('RGBA',CANVAS,(42,48,56,255));nb.alpha_composite(im);native.append(nb.convert('RGB'))
 dur=[r['duration_ms'] for r in records]
 for name,arr in [('review',review),('inplace',native)]:arr[0].save(D/f'hideyoshi_{action}_{name}.gif',save_all=True,append_images=arr[1:],duration=dur,loop=0,disposal=2,optimize=False)
 cols=2;rows=math.ceil(len(frames)/cols);contact=Image.new('RGB',(640*cols,340*rows),(42,48,56))
 for i,im in enumerate(review):contact.paste(im,((i%cols)*640,(i//cols)*340))
 contact.save(qa/'idle_action_contact.png');review[1 if cfg.get('idle_start') is not None else 0].save(qa/'idle_action_same_scale.png')
 meta=dict(character='hideyoshi',action=action,status='candidate_pending_user_review',description=cfg['description'],version=action+'_v1_direct_original_highres',duration_ms=duration,frame_count=len(frames),loop=cfg['loop'],preview_loop=True,preview_loop_reset_is_not_runtime_motion=True,canvas=list(CANVAS),standing_ruler_px=150,head_scale=.95,layers=['body','weapon','hand_occlusion'],frame_path='frames/{layer}_{index:02}.png',fx=None,source_generation='official image_gen; every source directly references approved original identity and full original mother sheet; no generated child sprite used as input',new_detail_disclosure='High-resolution redrawing adds only pose and cloth/armor line detail, no identity/costume/ornament redesign.',source_info=sources,world_motion={'mode':'stationary','root_track':[[0,0]]*len(frames),'preview_displacement_separate':True},frames=records,quality_notes=['Candidate; not runtime integrated.','Original high-resolution PNGs retained. Body downsampled once after local 95% head calibration.','Whole-body drawn poses, no optical-flow or interpolation.','Approved idle entry/exit, when present, are byte-preserving translated originals; not regenerated.'])
 (D/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
 validation={'frame_count':len(frames),'duration_ms':duration,'raw_new_figure_heights':[r['source_figure_height_px'] for r in records if 'source_figure_height_px' in r],'layers':{},'visual_contact_inspected':False,'runtime_tested':False}
 for layer in ['body','weapon','hand_occlusion']:
  validation['layers'][layer]={'rgba':all(Image.open(low/f'{layer}_{i:02}.png').mode=='RGBA' for i in range(len(frames))),'transparent':all(np.array(Image.open(low/f'{layer}_{i:02}.png'))[:,:,3].min()==0 for i in range(len(frames)))}
 g=Image.open(D/f'hideyoshi_{action}_review.gif');validation['gif_decoded_frames']=g.n_frames;validation['gif_duration_ms']=sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames));validation['all_new_raw_above_600']=min(validation['raw_new_figure_heights'])>=600;(qa/'validation.json').write_text(json.dumps(validation,indent=2));print(action,json.dumps(validation))
 return D
if __name__=='__main__':
 import sys
 for action in sys.argv[1:]:build(action)
