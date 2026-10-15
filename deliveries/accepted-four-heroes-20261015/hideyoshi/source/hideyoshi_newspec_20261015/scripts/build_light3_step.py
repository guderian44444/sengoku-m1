from PIL import Image, ImageDraw
from pathlib import Path
from scipy.ndimage import label, find_objects
import numpy as np, json, math, hashlib
from head_scale import shrink_head
P=Path(__file__).resolve().parents[1]; D=P/'actions/light_3_step_v2';D.mkdir(exist_ok=True)
SRC=P/'actions/light_3_step_source.png';im=Image.open(SRC).convert('RGBA');a=np.array(im);labels,n=label(a[:,:,3]>20)
objects=[]
for ident,s in enumerate(find_objects(labels),1):
 if (labels[s]==ident).sum()>3000:objects.append((ident,s))
objects.sort(key=lambda z:(round(((z[1][0].start+z[1][0].stop)/2-170)/340),z[1][1].start))
assert len(objects)==9
HEAD=[(237,10,318,113),(754,7,847,115),(1250,10,1341,115),(287,345,375,438),(794,349,880,438),(1284,346,1373,439),(249,680,347,785),(749,677,846,783),(1246,672,1333,784)]
HANDS=[[(204,52),(214,40)],[(735,68),(746,59)],[(1402,148),(1415,141)],[(462,455),(470,452)],[(970,461),(981,456)],[(1460,459),(1474,454)],[(377,811),(387,807)],[(817,837),(831,833)],[(1273,837),(1290,842)]]
REAR=[(101,342),(615,336),(1110,339),(102,678),(555,666),(1093,675),(158,932),(691,1005),(1221,1011)]
FRONT=[(333,330),(942,300),(1463,322),(445,674),(927,674),(1430,677),(436,1006),(918,1007),(1368,1006)]
ANGLES=[-30,-20,35,60,85,105,115,120,120]
SC=.425; W,H=520,300; SWORD=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
DUR=[60,70,60,50,50,60,60,60,60,60,90]
PHASES=['shared_ready','rear_load','rear_push_front_lift','front_foot_reach','front_foot_landing','contact_hip_chest_drive','follow_through','rear_foot_lift_catch_up','rear_foot_landing','settle_ready','shared_ready_advanced']
# Freeze the original shared start for reproducibility while other actions are revised independently.
for layer in ['body_canvas','weapon','composite']:
 f=D/f'base_{layer}.png'
 if not f.exists():Image.open(P/'actions/light_3'/f'{layer}_00.png').save(f)
def empty():return Image.new('RGBA',(W,H))
def shared(dx):
 f={}
 for layer in ['body_canvas','weapon','composite']:
  out=empty();out.alpha_composite(Image.open(D/f'base_{layer}.png'),(dx,0));f[layer]=out
 f['record']=dict(source='frozen_shared_light3_start',root_translation=[dx,0],head_scale=.95)
 return f

def render(j):
 ident,s=objects[j];box=(s[1].start,s[0].start,s[1].stop,s[0].stop);tile=a[s].copy();tile[:,:,3]=np.where(labels[s]==ident,tile[:,:,3],0);body=shrink_head(Image.fromarray(tile),box,HEAD[j],1,1)
 if j<3:
  support=REAR[j];target=(148,250);support_name='rear_toe_push'
 else:
  support=FRONT[j];target=(298,250);support_name='front_sole_locked'
 ox=target[0]-support[0]*SC;oy=target[1]-support[1]*SC
 canvas=empty();tile=body.resize((round(body.width*SC),round(body.height*SC)),Image.Resampling.LANCZOS);canvas.alpha_composite(tile,(round(ox+box[0]*SC),round(oy+box[1]*SC)))
 hands=[(ox+x*SC,oy+y*SC) for x,y in HANDS[j]];px,py=np.mean(hands,axis=0);ang=ANGLES[j];t=math.radians(ang);co=math.cos(t)/.145;si=math.sin(t)/.145
 weapon=SWORD.transform((W,H),Image.Transform.AFFINE,(co,si,180-co*px-si*py,-si,co,710+si*px-co*py),Image.Resampling.BICUBIC)
 comp=canvas.copy();comp.alpha_composite(weapon)
 mask=Image.new('L',(W,H));draw=ImageDraw.Draw(mask)
 for x,y in hands:draw.ellipse((x-4.6,y-4.6,x+4.6,y+4.6),fill=255)
 hand=canvas.copy();hand.putalpha(Image.fromarray(np.minimum(np.array(canvas.getchannel('A')),np.array(mask))));comp.alpha_composite(hand)
 rec=dict(source_index=j,source_rect=box,body_scale=SC,head_scale=.95,source_head_rect=HEAD[j],head_scale_anchor='neck',hand_centers=hands,grip_world=[float(px),float(py)],weapon_angle=ang,weapon_scale=.145,weapon_grip_local=[180,710],support_foot=support_name,support_world=target,rear_foot_world=[ox+REAR[j][0]*SC,oy+REAR[j][1]*SC],front_foot_world=[ox+FRONT[j][0]*SC,oy+FRONT[j][1]*SC],body_offset=[ox,oy],pose_generation='new imagegen pose; no frame repetition or body-only translation')
 body.save(D/f'body_{j+1:02}.png')
 return dict(body_canvas=canvas,weapon=weapon,composite=comp,record=rec)
frames=[shared(0)]+[render(j) for j in range(9)]+[shared(58)]
views=[];records=[]
for k,f in enumerate(frames):
 for layer in ['body_canvas','weapon','composite']:f[layer].save(D/f'{layer}_{k:02}.png')
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(f['composite'],mask=f['composite'].getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,253,W,253),fill=(68,74,82));dr.text((12,12),'HIDEYOSHI / light_3 / forward step / 680 ms',fill='white');dr.text((12,280),f'{k+1:02}/11  {PHASES[k]}',fill=(170,180,190));views.append(bg)
 rec=f['record'];rec.update(index=k,duration_ms=DUR[k],phase=PHASES[k],event='contact_launch' if k==5 else ('front_foot_landing' if k==4 else None));records.append(rec)
views[0].save(D/'light_3.gif',save_all=True,append_images=views[1:],duration=DUR,loop=0,disposal=2,optimize=False)
views[5].save(D/'representative.png');frames[5]['composite'].save(D/'representative_rgba.png')
cs=Image.new('RGB',(W*4,H*3),(42,48,56))
for i,v in enumerate(views):cs.paste(v,(i%4*W,i//4*H))
cs.save(D/'contact.png')
md=dict(action='light_3',revision='forward_step_11f_v2',description='第三段大幅橫切：後腳推地、前腳抬起前跨，落地時髖與胸肩前向發力；命中擊飛後後腳跟進，收刀回站。',duration_ms=680,frame_count=11,head_scale=.95,canvas=[W,H],net_forward_travel_px=58,source_sha256=hashlib.sha256(SRC.read_bytes()).hexdigest(),source_sheet=str(SRC),frames=records,render_body_layer='body_canvas_XX.png',quality_checks=['9 newly generated distinct intermediate body poses','front foot lifts, reaches, then lands before contact','rear foot follows after contact','rear support locked during push; front support locked during contact and recovery','original generated head locally scaled to 95 percent at neck','two-hand grip with independent katana layer','11 decoded GIF frames; exact 680ms'],limitations=['whole-body sprites, not anatomical rig parts','large third swing is game choreography','katana flat rotation; perspective variants pending','review candidate; not runtime integrated'])
(D/'metadata.json').write_text(json.dumps(md,ensure_ascii=False,indent=2))
g=Image.open(D/'light_3.gif');assert g.n_frames==11;assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==680
for k in range(11):
 for layer in ['body_canvas','weapon','composite']:
  z=Image.open(D/f'{layer}_{k:02}.png');assert z.mode=='RGBA' and z.size==(520,300) and z.getchannel('A').getextrema()[0]==0;z.load()
print(D)
