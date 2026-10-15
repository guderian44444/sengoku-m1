from PIL import Image,ImageDraw
from pathlib import Path
from scipy.ndimage import label,find_objects
import numpy as np,json,math,hashlib,copy
from head_scale import shrink_head
P=Path(__file__).resolve().parents[1];BASE=P/'actions/light_3_step_v2';D=P/'actions/light_3_fastlow_v3';D.mkdir(exist_ok=True);SRC=P/'actions/light_3_fastlow_source.png'
W,H=520,300;SC=.425;im=Image.open(SRC).convert('RGBA');a=np.array(im);labs,n=label(a[:,:,3]>20);obj=[]
for ident,s in enumerate(find_objects(labs),1):
 if (labs[s]==ident).sum()>3000:obj.append((ident,s))
obj.sort(key=lambda z:(round(((z[1][0].start+z[1][0].stop)/2-170)/340),z[1][1].start));assert len(obj)==9
CFG={3:dict(head=(287,346,375,439),hands=[(416,528),(432,534)],front=(445,674),rear=(102,680),angle=70),4:dict(head=(795,351,881,440),hands=[(917,551),(935,556)],front=(927,674),rear=(558,668),angle=90),5:dict(head=(1253,348,1343,439),hands=[(1391,558),(1407,567)],front=(1398,677),rear=(1063,678),angle=110),6:dict(head=(249,680,348,785),hands=[(375,835),(388,839)],front=(436,1006),rear=(158,932),angle=115)}
SWORD=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA');DUR=[60,100,80,30,30,30,40,60,70,70,110];assert sum(DUR)==680
base_md=json.loads((BASE/'metadata.json').read_text());frames=[]
def empty():return Image.new('RGBA',(W,H))
def changed(j):
 c=CFG[j];ident,s=obj[j];box=(s[1].start,s[0].start,s[1].stop,s[0].stop);v=a[s].copy();v[:,:,3]=np.where(labs[s]==ident,v[:,:,3],0);raw=shrink_head(Image.fromarray(v),box,c['head'],1,1);raw.save(D/f'body_{j+1:02}.png')
 ox=298-c['front'][0]*SC;oy=250-c['front'][1]*SC;body=empty();tile=raw.resize((round(raw.width*SC),round(raw.height*SC)),Image.Resampling.LANCZOS);body.alpha_composite(tile,(round(ox+box[0]*SC),round(oy+box[1]*SC)))
 hands=[(ox+x*SC,oy+y*SC) for x,y in c['hands']];grip=np.mean(hands,axis=0);px,py=grip;ang=c['angle'];t=math.radians(ang);co=math.cos(t)/.145;si=math.sin(t)/.145
 wp=SWORD.transform((W,H),Image.Transform.AFFINE,(co,si,180-co*px-si*py,-si,co,710+si*px-co*py),Image.Resampling.BICUBIC);comp=body.copy();comp.alpha_composite(wp);m=Image.new('L',(W,H));d=ImageDraw.Draw(m)
 for x,y in hands:d.ellipse((x-4.6,y-4.6,x+4.6,y+4.6),fill=255)
 hm=body.copy();hm.putalpha(Image.fromarray(np.minimum(np.array(body.getchannel('A')),np.array(m))));comp.alpha_composite(hm)
 matrix=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]])*.145
 tip=(grip+matrix@(np.array([185,7])-np.array([180,710]))).tolist();guard=(grip+matrix@(np.array([180,579])-np.array([180,710]))).tolist()
 rec=copy.deepcopy(base_md['frames'][j+1]);rec.update(source_index=j,source_rect=box,source_sheet=str(SRC),body_scale=SC,source_head_rect=c['head'],hand_centers=hands,grip_world=grip.tolist(),weapon_angle=ang,blade_guard_world=guard,blade_tip_world=tip,source_arm_edit='localized lower two-hand downward-cut pose',body_offset=[ox,oy],rear_foot_world=[ox+c['rear'][0]*SC,oy+c['rear'][1]*SC],front_foot_world=[298,250])
 return dict(body_canvas=body,weapon=wp,composite=comp,record=rec)
for k in range(11):
 if k-1 in CFG:frames.append(changed(k-1))
 else:frames.append(dict(**{l:Image.open(BASE/f'{l}_{k:02}.png').convert('RGBA') for l in ['body_canvas','weapon','composite']},record=copy.deepcopy(base_md['frames'][k])))
views=[];records=[];elapsed=0
for k,f in enumerate(frames):
 for layer in ['body_canvas','weapon','composite']:f[layer].save(D/f'{layer}_{k:02}.png')
 rec=f['record'];rec.update(index=k,duration_ms=DUR[k],start_ms=elapsed,end_ms=elapsed+DUR[k],event='contact_launch' if k==5 else ('front_foot_landing' if k==4 else None),active_downslash=k in [3,4,5,6]);elapsed+=DUR[k];records.append(rec)
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(f['composite'],mask=f['composite'].getchannel('A'));d=ImageDraw.Draw(bg);d.line((0,253,W,253),fill=(68,74,82));d.text((12,12),'HIDEYOSHI / light_3 / faster lower cut / 680 ms',fill='white');d.text((12,280),f'{k+1:02}/11  {DUR[k]} ms  '+('FAST DOWN CUT' if rec['active_downslash'] else rec['phase']),fill=(170,180,190));views.append(bg)
views[0].save(D/'light_3.gif',save_all=True,append_images=views[1:],duration=DUR,loop=0,disposal=2,optimize=False);views[5].save(D/'representative.png');frames[5]['composite'].save(D/'representative_rgba.png');cs=Image.new('RGB',(W*4,H*3),(42,48,56))
for k,v in enumerate(views):cs.paste(v,(k%4*W,k//4*H))
cs.save(D/'contact.png')
md=copy.deepcopy(base_md);md.update(revision='faster_lower_cut_11f_v3',description='第三段保持前跨與胸肩前向發力，實際下斬加速並壓低雙手握點與刀斬高度；命中擊飛後後腳跟進，總時長保持680ms。',frames=records,source_sha256=hashlib.sha256(SRC.read_bytes()).hexdigest(),source_sheet=str(SRC),unchanged_frame_source=str(BASE),timing_revision=dict(total_ms=680,frame_count=11,old_active_downslash_ms=220,new_active_downslash_ms=130,active_frames=[3,4,5,6],active_start_ms=240,active_end_ms=370,time_moved_to_windup_recovery_ms=90),contact_event=dict(frame=5,time_ms=300,end_ms=330,event='contact_launch',blade_guard_world=records[5]['blade_guard_world'],blade_tip_world=records[5]['blade_tip_world'],grip_world=records[5]['grip_world']),quality_checks=['11 decoded GIF frames with exact durations totaling 680ms','active descending cut shortened from 220ms to 130ms','arms and two-hand grip lowered together in four poses','front foot lock and rear catch-up preserved','unchanged poses reuse approved prior frames','original head 95 percent, independent katana layer'])
(D/'metadata.json').write_text(json.dumps(md,ensure_ascii=False,indent=2));g=Image.open(D/'light_3.gif');assert g.n_frames==11;assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==680
for k in range(11):
 for layer in ['body_canvas','weapon','composite']:
  z=Image.open(D/f'{layer}_{k:02}.png');assert z.mode=='RGBA' and z.size==(520,300) and z.getchannel('A').getextrema()[0]==0;z.load()
print(json.dumps(md['contact_event']));print(D)
