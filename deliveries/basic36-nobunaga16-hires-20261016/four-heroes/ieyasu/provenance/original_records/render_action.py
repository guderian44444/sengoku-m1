from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,json,math,hashlib,sys
BASE=Path(__file__).parent;SRC=BASE/'sources';OLD=BASE.parents[1]/'ieyasu06_newspec_20261015';W,H=480,320;RX,FY=220,280;SCALE=152/920
sw=Image.open(OLD/'reference/tachi.png').convert('RGBA');sa=Image.open(OLD/'reference/saya.png').convert('RGBA')
def isolate(f):
 im=Image.open(SRC/f['source']).convert('RGBA');ar=np.array(im);mask=np.zeros(ar.shape[:2],bool);box=f.get('rect',[0,0,im.width,im.height]);mask[box[1]:box[3],box[0]:box[2]]=True;lab,n=ndimage.label((ar[:,:,3]>80)&mask);cnt=np.bincount(lab.ravel());cnt[0]=0;selected=cnt.argmax()
 if 'component' in f:
  ids=np.argsort(cnt[1:])[-2:]+1;ids=sorted(ids,key=lambda j:np.where(lab==j)[1].min());selected=ids[f['component']]
 keep=ndimage.binary_dilation(lab==selected,iterations=2)&mask;ar[:,:,3]=np.where(keep,ar[:,:,3],0);return Image.fromarray(ar)
def place(im,s,ox,oy):
 small=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);out=Image.new('RGBA',(W,H));out.alpha_composite(small,(round(ox),round(oy)));return out
def weapon(src,anchor,point,angle,scale):
 t=math.radians(angle);c=math.cos(t)/scale;s=math.sin(t)/scale;gx,gy=point;ax,ay=anchor
 return src.transform((W,H),Image.Transform.AFFINE,(c,s,ax-c*gx-s*gy,-s,c,ay+s*gx-c*gy),Image.Resampling.BICUBIC)
def idle_layers():
 out={}
 for lay,file in [('body','body.png'),('weapon','weapon.png'),('sheath','sheath.png'),('hand_occlusion','hand_occlusion.png'),('composite','composite.png')]:
  can=Image.new('RGBA',(W,H));can.alpha_composite(Image.open(BASE/'idle'/file),(85,35));out[lay]=can
 return out
IDLE=idle_layers()
def build(cfg):
 action=cfg['action'];OUT=BASE/action;OUT.mkdir(exist_ok=True);recs=[];comps=[];elapsed=0
 for i,f in enumerate(cfg['frames'],1):
  if f.get('idle'):
   lays={k:v.copy() for k,v in IDLE.items()};rec=dict(source_file='../idle/composite.png',approved_exact_idle=True,source_effective_height=416,root_canvas=[RX,FY],grip_canvas=[224.08,201.06],hands_canvas=[[224.08,201.06]],weapon_angle_degrees=-55,sheath_angle_degrees=65,feet_canvas={'near':[160,280],'far':[276,280]},support_foot='both',scale=152/416)
  else:
   s=152/f.get('source_standing_ruler',920);body=isolate(f);aa=np.array(body.getchannel('A'));bb=Image.fromarray((aa>80).astype('uint8')*255).getbbox();body.save(OUT/f'source_body_{i:02}.png');ox=RX-f['root'][0]*s;oy=FY-f['root'][1]*s;offset=f.get('local_offset',[0,0]);ox+=offset[0];oy+=offset[1];b=place(body,s,ox,oy);hands=f['hands'];g=f.get('grip',[sum(x for x,y in hands)/len(hands),sum(y for x,y in hands)/len(hands)]);gp=[ox+g[0]*s,oy+g[1]*s];angle=f.get('angle',-55);sangle=f.get('sheath_angle',65)
   sword=weapon(sw,[100,1080],gp,angle,.085);sp=f.get('sheath_anchor',[g[0]-12,g[1]+12]);saya=weapon(sa,[87,22],[ox+sp[0]*s,oy+sp[1]*s],sangle,.073)
   mask=Image.new('L',body.size);md=ImageDraw.Draw(mask)
   for x,y in hands:
    rad=34*f.get('source_standing_ruler',920)/920;md.ellipse([x-rad,y-rad,x+rad,y+rad],fill=255)
   a=np.array(body);a[:,:,3]=(a[:,:,3].astype('uint16')*np.array(mask)//255).astype('uint8');hand=place(Image.fromarray(a),s,ox,oy);lays={'body':b,'weapon':sword,'sheath':saya,'hand_occlusion':hand};comp=Image.new('RGBA',(W,H))
   for lay in f.get('layer_order',['sheath','body','weapon','hand_occlusion']):comp.alpha_composite(lays[lay])
   lays['composite']=comp;feet={side:[ox+p[0]*s,oy+p[1]*s] for side,p in f['feet'].items()}
   rec=dict(source_file='../sources/'+f['source'],source_rect=f.get('rect'),source_sha256=hashlib.sha256((SRC/f['source']).read_bytes()).hexdigest(),source_bbox=list(bb),source_effective_height=bb[3]-bb[1],source_effective_width=bb[2]-bb[0],source_standing_ruler=f.get('source_standing_ruler',920),source_root=f['root'],root_canvas=[RX,FY],root_local=[0,0],render_origin=[ox,oy],scale=s,grip_source=g,grip_canvas=gp,hands_source=hands,hands_canvas=[[ox+x*s,oy+y*s] for x,y in hands],weapon_angle_degrees=angle,sheath_angle_degrees=sangle,feet_source=f['feet'],feet_canvas=feet,support_foot=f.get('support','both'))
  for lay,im in lays.items():im.save(OUT/f'{lay}_{i:02}.png')
  comps.append(lays['composite']);rec.update(frame=i,duration_ms=f['duration'],start_ms=elapsed,phase=f['phase'],event=f.get('event'),loop_next=(1 if cfg.get('loop') else None) if i==len(cfg['frames']) else i+1,world_delta=[0,0],preview_displacement=f.get('preview',[0,0]),grounded=f.get('grounded',True),fx=None,layer_order=f.get('layer_order',['sheath','body','weapon','hand_occlusion']),weapon_behind=False,sheath_behind=True);elapsed+=f['duration'];recs.append(rec)
 meta=dict(hero='ieyasu06',revision=action+'_candidate_01',action=cfg.get('runtime_action',action),approval='pending_user_review',loop=cfg.get('loop',False),frame_count=len(recs),total_ms=elapsed,standing_ruler_source_px=920,standing_ruler_target_px=152,new_source_standing_rulers=sorted(set(f.get('source_standing_ruler',920) for f in cfg['frames'] if not f.get('idle'))),scale_basis='declared native standing-equivalent drawing scale, never per-frame bbox height',per_frame_bbox_height_normalization=False,original_png_preserved=True,body_final_downsample_only=True,image_generation_tool='official image_gen.imagegen',direct_approved_references=['ieyasu06_newspec_20261015/reference/identity06.png','ieyasu06_newspec_20261015/actions/light_1_source.png'],layers=['body','weapon','sheath','hand_occlusion'],ordinary_action_fx=False,world_motion={'mode':'runtime_controller','per_frame_delta':[0,0],'preview_motion_not_baked':True},shared_idle='../idle/registration.json',frames=recs,runtime_integrated=False,notes=cfg.get('notes',[]));(OUT/'metadata.json').write_text(json.dumps(meta,indent=2))
 def bg():
  im=Image.new('RGB',(W,H),(37,43,52));ImageDraw.Draw(im).line((10,FY+1,W-10,FY+1),fill=(80,87,94));return im
 normal=[];comparison=[]
 for j,co in enumerate(comps):
  im=bg();off=cfg['frames'][j].get('preview',[0,0]);im.paste(co,(round(off[0]),round(off[1])),co);d=ImageDraw.Draw(im);d.text((12,9),f'IEYASU 06 | {action.upper()} CANDIDATE | 152px ruler',fill=(230,232,237));d.text((12,H-23),f'{j+1}/{len(comps)}  {recs[j]["phase"]}  {recs[j]["duration_ms"]}ms',fill=(192,199,208));normal.append(im)
  left=bg();left.paste(IDLE['composite'],(0,0),IDLE['composite']);ImageDraw.Draw(left).text((12,9),'APPROVED COMBAT IDLE | same 152px ruler',fill=(230,232,237));cp=Image.new('RGB',(W*2,H));cp.paste(left,(0,0));cp.paste(im,(W,0));comparison.append(cp)
 ds=[r['duration_ms'] for r in recs]
 for name,ims,factor in [('normal.gif',normal,1),('slow.gif',normal,2),('idle-comparison.gif',comparison,1)]:ims[0].save(OUT/name,save_all=True,append_images=ims[1:],duration=[d*factor for d in ds],loop=0,disposal=2)
 representative=cfg.get('representative',1);comparison[representative].save(OUT/'idle-comparison.png');sheet=Image.new('RGB',(W*4,H*math.ceil(len(normal)/4)))
 for j,im in enumerate(normal):sheet.paste(im,(j%4*W,j//4*H))
 sheet.save(OUT/'contact.png');new=[r for r in recs if not r.get('approved_exact_idle')];qa=dict(artifact_checks='pass',minimum_new_source_height=min(r['source_effective_height'] for r in new),minimum_new_source_max_dimension=min(max(r['source_effective_height'],r['source_effective_width']) for r in new),scale=SCALE,ruler=152,genuine_alpha=True,raw_sources_preserved=True,no_optical_flow=True,no_derived_small_frame_reference=True,existing_assets_unchanged=True,visual_review='pending',approval='pending_user',runtime_tested=False)
 for i in range(1,len(recs)+1):
  for lay in ['body','weapon','sheath','hand_occlusion','composite']:
   im=Image.open(OUT/f'{lay}_{i:02}.png');assert im.mode=='RGBA' and im.size==(W,H)
 (OUT/'QA.json').write_text(json.dumps(qa,indent=2));print(json.dumps({'action':action,'duration':elapsed,'frames':len(recs),'qa':qa,'normal':str((OUT/'normal.gif').resolve()),'normal_bytes':(OUT/'normal.gif').stat().st_size,'comparison':str((OUT/'idle-comparison.gif').resolve()),'comparison_bytes':(OUT/'idle-comparison.gif').stat().st_size},indent=2))
if __name__=='__main__':build(json.load(open(sys.argv[1])))
