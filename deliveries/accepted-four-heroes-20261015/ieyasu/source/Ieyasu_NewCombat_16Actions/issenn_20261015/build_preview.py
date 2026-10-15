from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
import numpy as np,json,math,sys,shutil
D=Path(__file__).parent;P=D.parent;sys.path.insert(0,str(P/'scripts'));import build_rest;build_rest.W=640;from build_rest import transform
W,H=640,400;sw0=Image.open(P/'reference/tachi.png').convert('RGBA');sa=Image.open(P/'reference/saya.png').convert('RGBA')
def objects(src,n,rows,remove=False):
 a=np.array(Image.open(src).convert('RGBA'))
 if remove:
  mag=(a[:,:,0]>120)&(a[:,:,2]>100)&(a[:,:,1]<.6*np.maximum(a[:,:,0],a[:,:,2]));a[binary_dilation(mag,iterations=1),3]=0
 lab,k=label(a[:,:,3]>30);sz=np.bincount(lab.ravel());ids=np.argsort(sz[1:])[-n:]+1;ids=sorted(ids,key=lambda q:(int(np.where(lab==q)[0].mean()//(a.shape[0]/rows)),np.where(lab==q)[1].mean()));out=[]
 for q in ids:
  ar=a.copy();ar[:,:,3]=np.where(binary_dilation(lab==q,iterations=1),a[:,:,3],0);out.append(Image.fromarray(ar))
 return out
ready=objects(D/'sources/ready_correct.png',6,2,True);rel=objects(D/'sources/release.png',12,3)
Rgr=[(429,203),(883,244),(1356,267),(350,770),(823,790),(1327,796)];Lgr=[(203,242),(757,252),(1274,269),(255,770),(779,789),(1280,793)];feet=[(78,529),(615,529),(1123,529),(83,1000),(592,1000),(1080,1000)]
records={};outall=[];dsall=[]
def make(stage,i,body,s,foot,footx,grip,mouth,ms,bladefrac=1,bladeangle=90,event=None):
 ox=footx-foot[0]*s;oy=365-foot[1]*s;layer=Image.new('RGBA',(W,H));layer.alpha_composite(body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS),(round(ox),round(oy)));g=[ox+grip[0]*s,oy+grip[1]*s];m=[ox+mouth[0]*s,oy+mouth[1]*s]
 if stage=='ready':
  m[1]=g[1];m[0]=g[0]-10.625 if i>=4 else m[0];bladeangle=270;bladefrac=max(0,min(1,((g[0]-m[0])/.085-125)/955))
 sword=sw0.copy();ar=np.array(sword);ar[:int(955*(1-bladefrac)),:,3]=0;sword=Image.fromarray(ar);weapon=transform(sword,(100,1080),g,bladeangle,.085)
 if stage in ['ready','hold'] :ang=math.degrees(math.atan2(m[1]-g[1],m[0]-g[0]))-90
 else:ang=65
 sheath=transform(sa,(87,22),m,ang,.06);comp=Image.new('RGBA',(W,H));comp.alpha_composite(sheath);comp.alpha_composite(layer);comp.alpha_composite(weapon)
 for x,y in [g,m]:comp.alpha_composite(layer.crop((round(x-4),round(y-4),round(x+4),round(y+4))),(round(x-4),round(y-4)))
 dest=D/stage;dest.mkdir(exist_ok=True)
 for k,im in [('body_canvas',layer),('sword',weapon),('sheath',sheath),('composite',comp)]:im.save(dest/f'{k}_{i:02}.png')
 r=dict(frame=i,duration_ms=ms,grip_world=g,saya_mouth=m,root_world=[footx,365],source_foot=foot,source_grip=grip,source_mouth=mouth,body_scale=s,event=event,blade_angle_deg=bladeangle,blade_visible_fraction=bladefrac);records.setdefault(stage,[]).append(r);return comp
for i in range(6):
 s=.29;g=Rgr[i];m=Lgr[i];dist=math.dist(g,m)*s;angle=math.degrees(math.atan2(m[1]-g[1],m[0]-g[0]))+90
 make('ready',i,ready[i],s,feet[i],120,g,m,[140,140,150,150,160,160][i],max(0,min(1,(dist-11)/80)),angle,'charge_start' if i==0 else 'hold_enter' if i==5 else None)
for k in ['body_canvas','sword','sheath','composite']:shutil.copy(D/'ready'/f'{k}_05.png',D/'hold'/f'{k}_00.png');shutil.copy(D/'ready'/f'{k}_05.png',D/'release'/f'{k}_00.png')
records['hold']=[dict(records['ready'][-1],frame=0,duration_ms=400,event='charge_hold')];records['release']=[dict(records['ready'][-1],frame=0,duration_ms=40,event=None)]
marks=json.load(open(D/'qa/release_landmarks.json'))['rows'];support=[(58,347),(456,340),(712,346),(1374,346),(204,688),(500,695),(750,699),(1377,700),(65,1052),(382,1051),(994,1051),(1382,1052)];world=[120,120,120,267,267,267,267,371,371,371,485,485];tim=[40,100,40,40,40,100,40,40,100,80]
for i,j in enumerate(range(2,12),start=1):
 r=marks[j];events={1:'instant_draw_linear_hit_start',2:'step_left_1',6:'step_right_2',8:'linear_hit_end',9:'step_left_3_and_brake',10:'forward_stop'}
 make('release',i,rel[j],.39,support[j],world[j],r['right_grip_center'],r['left_saya_hand_center'],tim[i-1],1,90,events.get(i))
for k in ['body_canvas','sword','sheath','composite']:shutil.copy(D/'release'/f'{k}_10.png',D/'release'/f'{k}_11.png')
records['release'].append(dict(records['release'][-1],frame=11,duration_ms=140,event='forward_blade_stop'))
# Ghosts are independent overlays; body/weapon images remain clean.
for i in range(12):
 fx=Image.new('RGBA',(W,H))
 for start,source in [(2,1),(6,5),(9,8)]:
  age=i-start
  if 0<=age<=2:
   ghost=Image.open(D/'release'/f'composite_{source:02}.png').convert('RGBA');ar=np.array(ghost);ar[:,:,3]=(ar[:,:,3]*[.26,.15,.06][age]).astype('uint8');fx.alpha_composite(Image.fromarray(ar))
 fx.save(D/'release'/f'fx_afterimage_{i:02}.png');fx.alpha_composite(Image.open(D/'release'/f'composite_{i:02}.png'));fx.save(D/'release'/f'preview_fx_{i:02}.png')
 records['release'][i]['afterimage_event']=dict(opacity=.26,ttl_ms=120,independent_layer=True) if i in [2,6,9] else None
# Independent sword-wave and non-game measurement enemy knockdowns.
wave_sheet=Image.open(D/'sources/slash_wave.png').convert('RGBA');waves=[]
for j in range(6):
 tile=wave_sheet.crop(((j%3)*512,(j//3)*512,(j%3+1)*512,(j//3+1)*512));
 if j==4:tile.paste((0,0,0,0),(0,0,50,512))
 tile=tile.crop(tile.getbbox());waves.append(tile)
proxy=Image.open(P/'grabs/grab_start/proxy_00.png').convert('RGBA');proxy=proxy.crop(proxy.getbbox())
for i,r in enumerate(records['release']):
 wave=Image.new('RGBA',(W,H));enemy=Image.new('RGBA',(W,H))
 if 1<=i<=10:
  j=[0,0,1,2,2,3,3,4,4,5,5,5][i];tile=waves[j];tile=tile.resize((260,240),Image.Resampling.LANCZOS);front=min(635,r['grip_world'][0]+115);wave.alpha_composite(tile,(round(front-260),155))
 for ex,hit in [(320,2),(410,5),(505,7)]:
  age=i-hit;ang=0 if age<0 else min(88,20+age*24);lay=transform(proxy,(proxy.width/2,proxy.height),(ex,365),ang,.85);enemy.alpha_composite(lay)
 wave.save(D/'release'/f'fx_sword_wave_{i:02}.png');enemy.save(D/'release'/f'proxy_knockdown_{i:02}.png')
 combined=enemy.copy();combined.alpha_composite(Image.open(D/'release'/f'fx_afterimage_{i:02}.png'));combined.alpha_composite(Image.open(D/'release'/f'composite_{i:02}.png'));combined.alpha_composite(wave);combined.save(D/'release'/f'preview_fx_{i:02}.png')
 r['hit_policy']={'shape':'forward_swept_corridor','pierces_enemies':True,'reaction':'knockdown','deduplicate':'per_enemy_per_action','proxy_is_demo_only':True} if i==1 else None
for stage in ['ready','hold']:
 for i in range(len(records[stage])):
  enemy=Image.new('RGBA',(W,H))
  for ex in [320,410,505]:enemy.alpha_composite(transform(proxy,(proxy.width/2,proxy.height),(ex,365),0,.85))
  enemy.alpha_composite(Image.open(D/stage/f'composite_{i:02}.png'));enemy.save(D/stage/f'preview_fx_{i:02}.png')
for stage,rs in records.items():
 frames=[];dur=[]
 for i,r in enumerate(rs):
  im=Image.open(D/stage/f'preview_fx_{i:02}.png');bg=Image.new('RGB',(W,H),(47,53,61));bg.paste(im,mask=im.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,366,W,366),fill=(80,86,93));dr.text((12,12),f'IEYASU ISSEN / {stage} / {i+1}/{len(rs)}',fill='white');frames.append(bg);dur.append(r['duration_ms'])
 frames[0].save(D/stage/'normal.gif',save_all=True,append_images=frames[1:],duration=dur,disposal=2);cs=Image.new('RGB',(W*4,H*math.ceil(len(frames)/4)))
 for i,im in enumerate(frames):cs.paste(im,((i%4)*W,(i//4)*H))
 cs.save(D/stage/'contact.png');(D/stage/'metadata.json').write_text(json.dumps(dict(action='charge_'+stage,frames=rs,total_ms=sum(dur)),indent=2));outall+=frames;dsall+=dur
outall[0].save(D/'three_stage_normal.gif',save_all=True,append_images=outall[1:],duration=dsall,disposal=2);outall[0].save(D/'three_stage_slow.gif',save_all=True,append_images=outall[1:],duration=[x*3 for x in dsall],disposal=2)
print([(k,len(v),sum(x['duration_ms'] for x in v)) for k,v in records.items()])
