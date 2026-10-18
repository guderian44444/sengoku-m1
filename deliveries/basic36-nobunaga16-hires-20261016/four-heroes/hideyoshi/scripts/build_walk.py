from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import numpy as np,json,math,hashlib,shutil
from scipy.ndimage import label,find_objects
P=Path(__file__).resolve().parents[1];D=P/'walk';S=D/'source';W,H=520,300;ROOT=(220,253)
# Manually inspected anatomical landmarks in raw original-resolution generated sheets.
# All calibration factors use same-direction head/torso measure, never whole-body bbox fitting.
CFG=[
 dict(src='pair_0.png',side=0,s=.158,hip=(465,570),head=(326,15,526,213),grip=(469,453),hands=(397,415,541,488),near=(247,937),far=(582,960),support='far',phase='far_heel_contact',angle=120),
 dict(src='pair_0.png',side=1,s=.158,hip=(1187,586),head=(1089,32,1279,231),grip=(1209,470),hands=(1140,434,1281,503),near=(977,938),far=(1293,971),support='far',phase='far_down_near_toe_off',angle=116),
 dict(src='pair_1.png',side=0,s=.165,hip=(493,581),head=(364,46,554,238),grip=(503,449),hands=(434,412,570,487),near=(337,889),far=(529,946),support='far',phase='far_support_near_passing',angle=120),
 dict(src='cross_3.png',side=1,s=.165,hip=(1117,560),head=(1009,39,1203,230),grip=(1122,435),hands=(1058,394,1193,468),near=(1312,910),far=(951,916),support='far',phase='near_reach_far_toe_push',angle=120),
 dict(src='cross_2.png',side=0,s=.162,hip=(510,564),head=(357,15,556,214),grip=(503,421),hands=(431,379,569,460),near=(631,935),far=(393,898),support='near',phase='near_heel_contact',angle=123),
 dict(src='cross_2.png',side=1,s=.162,hip=(1179,568),head=(1032,16,1228,215),grip=(1178,435),hands=(1106,394,1241,468),near=(1218,954),far=(1012,898),support='near',phase='near_down_far_toe_off',angle=120),
 dict(src='pair_3.png',side=0,s=.165,hip=(445,556),head=(340,26,536,220),grip=(456,435),hands=(393,397,525,472),near=(326,947),far=(599,893),support='near',phase='near_support_far_passing',angle=120),
 dict(src='pair_3.png',side=1,s=.165,hip=(1125,574),head=(1009,30,1207,228),grip=(1148,439),hands=(1084,400,1216,478),near=(949,940),far=(1303,942),support='near',phase='far_reach_near_toe_push',angle=120),
]
# Near/far leg identity follows the anatomical hip-to-shin path through the crossing poses.
def head95(im,rect):
 x0,y0,x1,y1=rect;crop=im.crop(rect);nw=round(crop.width*.95);nh=round(crop.height*.95)
 out=im.copy();out.paste((0,0,0,0),rect);out.alpha_composite(crop.resize((nw,nh),Image.Resampling.LANCZOS),(x0+(crop.width-nw)//2,y1-nh));return out

def font(sz):
 try:return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',sz)
 except:return ImageFont.load_default()

def put(im,layer,xy=(0,0)):
 im.alpha_composite(layer,tuple(map(round,xy)))

def pt(c,p):return [round(ROOT[0]+(p[0]-c['hip'][0])*c['s'],3),round(ROOT[1]+(p[1]-c[c['support']][1])*c['s'],3)]
frames=[];records=[];source_info={};highdir=D/'frames_high';lowdir=D/'frames';highdir.mkdir(exist_ok=True);lowdir.mkdir(exist_ok=True)
sword=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
for i,c in enumerate(CFG):
 src=S/c['src'];im=Image.open(src).convert('RGBA');a=np.array(im);labs,n=label(a[:,:,3]>20);items=[]
 for ident,sl in enumerate(find_objects(labs),1):
  if (labs[sl]==ident).sum()>10000:items.append((ident,(sl[1].start,sl[0].start,sl[1].stop,sl[0].stop)))
 items.sort(key=lambda e:e[1][0]);ident,box=items[c['side']];source_info[c['src']]={'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'size':im.size}
 a[:,:,3]=np.where(labs==ident,a[:,:,3],0);body=head95(Image.fromarray(a),c['head']);body.crop(box).save(highdir/f'body_{i:02}.png')
 # Retain a source-sized high resolution hand occlusion layer using original hand pixels.
 hm=Image.new('L',im.size);hd=ImageDraw.Draw(hm);x0,y0,x1,y1=c['hands'];hd.rounded_rectangle(c['hands'],radius=12,fill=255)
 ha=np.array(body);ha[:,:,3]=(ha[:,:,3].astype('uint16')*np.array(hm)//255).astype('uint8');hand=Image.fromarray(ha);hand.crop(box).save(highdir/f'hand_occlusion_{i:02}.png')
 ox=ROOT[0]-c['hip'][0]*c['s'];oy=ROOT[1]-c[c['support']][1]*c['s'];dest=(round(ox+box[0]*c['s']),round(oy+box[1]*c['s']))
 lc=Image.new('RGBA',(W,H));tile=body.crop(box).resize((round((box[2]-box[0])*c['s']),round((box[3]-box[1])*c['s'])),Image.Resampling.LANCZOS);put(lc,tile,dest)
 hc=Image.new('RGBA',(W,H));put(hc,hand.crop(box).resize(tile.size,Image.Resampling.LANCZOS),dest)
 g=pt(c,c['grip']);ang=c['angle'];t=math.radians(ang);ws=.145;co=math.cos(t)/ws;si=math.sin(t)/ws;ax,ay=180,710;px,py=g
 weapon=sword.transform((W,H),Image.Transform.AFFINE,(co,si,ax-co*px-si*py,-si,co,ay+si*px-co*py),Image.Resampling.BICUBIC)
 comp=lc.copy();put(comp,weapon);put(comp,hc)
 for name,z in [('body',lc),('weapon',weapon),('hand_occlusion',hc),('composite',comp)]:z.save(lowdir/f'{name}_{i:02}.png')
 frames.append(comp)
 rec=dict(index=i,duration_ms=120,phase=c['phase'],source=c['src'],source_rect=box,source_figure_height_px=box[3]-box[1],body_calibration_scale=c['s'],calibration_basis='same-direction head and shoulder/torso landmarks; not bounding-box height',head_scale=.95,head_rect_source=c['head'],root_canvas=list(ROOT),root_local=[0,0],pelvis_canvas=pt(c,c['hip']),feet_canvas={'near':pt(c,c['near']),'far':pt(c,c['far'])},support_foot=c['support'],grip_canvas=g,grip_source=list(c['grip']),weapon_angle_deg=ang,weapon_angle_convention='0 up, clockwise positive',weapon_source='reference/sword_uchigatana.png',weapon_scale=.145,weapon_pivot_source=[180,710],layer_order=['body','weapon','hand_occlusion'],fx=None,world_root_translation=None,preview_translation=None)
 records.append(rec)
# Source pose foot identities are explicitly reconciled for the eight-phase cycle:
# First half: image-right hip leg supports then transfers. Second half: crossing image-left hip leg supports.
# Preview root trajectory is derived from successive planted-foot x anchors to avoid pixel sliding.
span=[(0,3,'far'),(4,7,'near')]
world=[];base=0
for start,end,foot in span:
 for j in range(start,end+1):
  off=records[start]['feet_canvas'][foot][0]-records[j]['feet_canvas'][foot][0]
  world.append(base+off)
 if end<7:base=world[-1]+12
loop_stride=world[-1]+12
for i,r in enumerate(records):r['world_root_translation']=[round(world[i],3),0];r['preview_translation']=[0,0];r['loop']=True
# Preserve approved idle as-is. Its original source stays byte-identical.
idle=Image.open(P/'idle/composite_00.png').convert('RGBA')
# Real portrait is an unscaled crop of an approved image, never regenerated.
por=Image.open(P/'reference/approved_head95.png').convert('RGBA');por.crop((98,0,214,129)).save(P/'portrait/hideyoshi_approved_portrait.png')
(P/'portrait/metadata.json').write_text(json.dumps({'source':'../reference/approved_head95.png','source_sha256':hashlib.sha256((P/'reference/approved_head95.png').read_bytes()).hexdigest(),'crop':[98,0,214,129],'resampled':False,'generated':False},indent=2))
# Main review: same-scale approved combat idle beside walk.
review=[];worldprev=[];native=[]
for i,comp in enumerate(frames):
 bg=Image.new('RGBA',(640,340),(42,48,56,255));dr=ImageDraw.Draw(bg);dr.text((20,15),'HIDEYOSHI / WALK CANDIDATE / HEAD 95%',font=font(16),fill=(235,240,245));dr.text((72,53),'Approved combat idle',font=font(13),fill=(190,200,213));dr.text((363,53),'Walk - same 150px ruler',font=font(13),fill=(190,200,213))
 # approved original pelvis is approx183; align to130, new walk pelvis220 ->420.
 put(bg,idle,(-53,18));put(bg,comp,(200,18));dr.line((45,272,594,272),fill=(100,110,125));dr.text((25,304),f'{i+1:02}/08  |  {i*120:03} ms  |  full cycle 960 ms  |  no FX',font=font(13),fill=(195,205,218));review.append(bg.convert('RGB'))
 nb=Image.new('RGBA',(W,H),(42,48,56,255));put(nb,comp);native.append(nb.convert('RGB'))
 wb=Image.new('RGBA',(640,300),(42,48,56,255));wd=ImageDraw.Draw(wb);wd.text((18,16),'WORLD DISPLACEMENT DEMO (not baked into sprite)',font=font(14),fill='white');
 for gx in range(0,640,20):wd.line((gx,254,gx+6,254),fill=(120,130,145))
 put(wb,comp,(round(world[i])-80,0));wd.text((18,278),f'frame {i+1}  root x +{world[i]:.1f}px  | loop resets preview only',font=font(12),fill=(195,205,218));worldprev.append(wb.convert('RGB'))
for name,arr in [('hideyoshi_walk_review.gif',review),('hideyoshi_walk_inplace.gif',native),('hideyoshi_walk_world.gif',worldprev)]:arr[0].save(D/name,save_all=True,append_images=arr[1:],duration=[120]*8,loop=0,disposal=2,optimize=False)
contact=Image.new('RGB',(640*2,340*4),(42,48,56))
for i,im in enumerate(review):contact.paste(im,((i%2)*640,(i//2)*340))
contact.save(D/'qa/idle_walk_same_scale_contact.png');review[0].save(D/'qa/idle_walk_same_scale.png')
meta={'character':'hideyoshi','action':'walk','status':'candidate_pending_user_review','version':'walk_v1_original_direct_hi_res','duration_ms':960,'frame_count':8,'loop':True,'canvas':[W,H],'standing_ruler_px':150,'head_scale':.95,'approved_idle':'../idle/composite_00.png','ordinary_action_fx':None,'source_generation':'official image_gen; direct original identity and full approved mother sheet for every call; no generated sprite used as generation input','new_detail_disclosure':'High-resolution redraw adds cloth folds, armor linework and walk-pose detail only; identity, costume and accessories locked to approved originals.','source_info':source_info,'layers':['body','weapon','hand_occlusion'],'frame_path':'frames/{layer}_{index:02}.png','world_motion':{'mode':'sampled root track separate from body sprites','cycle_displacement_px':round(loop_stride,3),'track_units':'game pixels; x right, y down','support_intervals':span,'preview_resets_world_each_cycle':True},'frames':records,'quality_notes':['Not integrated in game runtime.','Eight generated whole-body poses, not skeletal rig.','Candidate gait needs final user approval; feet and crossing leg identity inspected.','Head95 applied locally at neck anchor; all final game-size body frames downsampled directly from source only once.']}
(D/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
# Technical validations.
checks={}
for layer in ['body','weapon','hand_occlusion']:
 checks[layer+'_rgba']=all(Image.open(lowdir/f'{layer}_{i:02}.png').mode=='RGBA' for i in range(8));checks[layer+'_transparent']=all(np.array(Image.open(lowdir/f'{layer}_{i:02}.png'))[:,:,3].min()==0 for i in range(8))
for fn in ['hideyoshi_walk_review.gif','hideyoshi_walk_inplace.gif','hideyoshi_walk_world.gif']:
 g=Image.open(D/fn);checks[fn]={'frame_count':g.n_frames,'duration_ms':sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames)),'loop':g.info.get('loop')}
checks['raw_figure_heights']=[r['source_figure_height_px'] for r in records];checks['all_above_600']=min(checks['raw_figure_heights'])>=600;checks['approved_idle_byte_identical']=hashlib.sha256((P/'idle/composite_00.png').read_bytes()).hexdigest()==hashlib.sha256((P.parents[1]/'hideyoshi_newspec_20261015/reference/shared_ready/composite_00.png').read_bytes()).hexdigest()
(D/'qa/technical_validation.json').write_text(json.dumps(checks,indent=2));print(json.dumps(checks,indent=2));print('World:',world,loop_stride)
