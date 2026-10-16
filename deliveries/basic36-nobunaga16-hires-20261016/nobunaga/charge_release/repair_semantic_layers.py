from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,math,json,hashlib,ast,os
O=Path(__file__).resolve().parents[1];R=O.parent/'nobunaga_impact_v4';BG=(35,40,48)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def skin_in_box(a,box,wm):
 rgb=a[:,:,:3].astype(float);r,g,b=np.moveaxis(rgb,2,0);mask=(r>110)&(g>65)&(g/np.maximum(r,1)>.48)&(g/np.maximum(r,1)<.86)&(b/np.maximum(g,1)>.4)&(b/np.maximum(g,1)<.88)&(r>g*1.12)&(a[:,:,3]>0)
 roi=np.zeros(mask.shape,bool);x0,y0,x1,y1=np.rint(box).astype(int);roi[max(0,y0):min(a.shape[0],y1),max(0,x0):min(a.shape[1],x1)]=True;mask &=roi&~wm;lab,n=ndimage.label(ndimage.binary_closing(mask,iterations=1));ct=np.bincount(lab.ravel());good=ct>=25;good[0]=False;mask=good[lab];return ndimage.binary_dilation(ndimage.binary_fill_holes(mask),iterations=2)&roi&~wm&(a[:,:,3]>0)
def partition(k,i,src,wm,hm,meta):
 d=O/k;im=Image.open(src).convert('RGBA');a=np.array(im);wm=wm&(a[:,:,3]>0);hm=hm&~wm&(a[:,:,3]>0);out=d/'layers-visible';layers=[]
 for name,mask in [('body',~(wm|hm)),('weapon',wm),('hand_occlusion',hm)]:
  b=a.copy();b[~mask]=0;q=Image.fromarray(b);p=out/name/f'{i:03}.png';p.parent.mkdir(parents=True,exist_ok=True);q.save(p,compress_level=3);layers.append(q);meta[name+'_path']=str(p.relative_to(O));meta[name+'_sha256']=sha(p)
 for name,m in [('weapon',wm),('hand',hm)]:p=out/'masks'/f'{i:03}-{name}.png';p.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(m.astype('uint8')*255).save(p)
 comp=Image.new('RGBA',im.size)
 for q in layers:comp.alpha_composite(q)
 aa=np.asarray(comp);exact=np.array_equal(aa[:,:,3],a[:,:,3]) and np.array_equal(aa[a[:,:,3]>0],a[a[:,:,3]>0]);assert exact,(k,i)
 meta.update(frame=i,source=str(src.relative_to(O)),source_sha256=sha(src),canvas=list(im.size),recomposition_visible_rgba_exact=True,rgba_max_channel_error_visible=0,layer_order_back_to_front=['body','weapon','hand_occlusion'],separate_movement_safe=False,hand_occlusion_pixels=int(hm.sum()),visible_weapon_pixels=int(wm.sum()),manual_review_required=False)
 q=Image.new('RGBA',im.size,BG+(255,));q.alpha_composite(im);z=np.array(q);z[wm,:3]=(z[wm,:3]*.3+np.array([45,220,250])*.7).astype('uint8');z[hm,:3]=(z[hm,:3]*.3+np.array([240,70,190])*.7).astype('uint8');q=Image.fromarray(z);bb=im.getbbox();q=q.crop(bb);q.thumbnail((360,360));return meta,q.convert('RGB'),comp

def sheet(k,thumbs,records):
 out=Image.new('RGB',(1440,400*math.ceil(len(thumbs)/4)),BG);dr=ImageDraw.Draw(out)
 for i,q in enumerate(thumbs):x=i%4*360;y=i//4*400;out.paste(q,(x,y+30));dr.text((x+10,y+5),f'{k} {i:02} authored-source masks',fill='white')
 out.save(O/'qa'/f'{k}-layers.jpg',quality=94);(O/k/'layers-visible-manifest.json').write_text(json.dumps(records,indent=2))
# Original approved source layout; no PCA or brightness-based blade discovery.
env={};tree=ast.parse((R/'charge_release_hires_range150/build_preview.py').read_text())
for n in tree.body:
 if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ['DUR','YAWS','keys','CONF'] for t in n.targets):exec(compile(ast.Module(body=[n],type_ignores=[]),'charge_recipe','exec'),env)
boxes={'gather':(775,455,965,585),'yaw000':(1170,305,1325,410),'yaw045':(1150,255,1305,370),'yaw090-true':(820,135,935,250),'yaw090':(225,240,375,350),'yaw180':(130,275,285,390),'yaw225':(145,285,295,415),'yaw270':(535,240,710,355),'yaw315':(1180,275,1335,395),'landing':(1200,310,1370,445),'guard':(520,520,645,680)}
records=[];thumbs=[];d=O/'charge_release'
for i,(key,yaw,dur) in enumerate(zip(env['keys'],env['YAWS'],env['DUR'])):
 src=d/('frames-composite/000.png' if i==0 else f'layers-native/actor/{i:03}.png');a=np.array(Image.open(src).convert('RGBA'))
 if i==0:
  # Source low-pose native composite uses the ready/hold native camera. Canonical blade is independently transformed at scale1.
  template=Image.open(R/'charge_ready_hires/source/shortened-blade.png').convert('RGBA');off=np.array([2000-1017,1500-962]);base=np.array([773,670])+off;ang=math.atan2(36,474)-math.atan2(29,441);c,s=math.cos(ang),math.sin(ang);tr=(c,-s,-c*base[0]+s*base[1],s,c,49-s*base[0]-c*base[1]);wp=template.transform((4000,1800),Image.Transform.AFFINE,tr,Image.Resampling.BICUBIC);wm=np.array(wp)[:,:,3]>0;box=np.array([620,615,785,750])+np.tile(off,2);behind=False
 else:
  conf=env['CONF'][key];target=np.array([2000.,1500.]);target[0]+=70*(2.25/.58) if i>=21 else 0;off=target-np.array(conf['support']);wp=np.array(Image.open(d/f'layers-native/weapon/{i:03}.png'));bo=np.array(Image.open(d/f'layers-native/body/{i:03}.png'));behind=yaw is not None and 20<yaw%360<165;wm=(wp[:,:,3]>0)&((bo[:,:,3]<255) if behind else True);box=np.array(boxes[key])+np.tile(off,2)
 hm=skin_in_box(a,box,wm);meta={'detector':'approved authored canonical-weapon alpha and original body/weapon depth order; manually bounded hand ROI, no PCA','duration_ms':dur,'weapon_behind_body':behind,'weapon_contents':'existing independent canonical exposed steel; body-donor hilt/guard remain fused unless included in hand-occlusion. No hidden pixels invented.','manual_hand_roi_native':box.tolist(),'hand_status':'source-visible skin inside manually inspected grip window, excluded from known physical steel','hidden_body_complete':False,'hidden_weapon_under_hands_complete':False,'visible_weapon_depth':'original layer order preserved'}
 m,q,comp=partition('charge_release',i,src,wm,hm,meta)
 if i:
  full=Image.open(d/f'layers-native/fx_back/{i:03}.png').convert('RGBA');full.alpha_composite(comp);full.alpha_composite(Image.open(d/f'layers-native/fx_front/{i:03}.png').convert('RGBA'));m['fx_layers_back_front']=[f'charge_release/layers-native/fx_back/{i:03}.png',f'charge_release/layers-native/fx_front/{i:03}.png']
 else:full=comp;m['fx_layers_back_front']=[]
 expected=np.array(Image.open(d/f'frames-composite/{i:03}.png').convert('RGBA'));f=np.array(full);m['full_actor_fx_recomposition_visible_rgba_exact']=bool(np.array_equal(f[:,:,3],expected[:,:,3]) and np.array_equal(f[expected[:,:,3]>0],expected[expected[:,:,3]>0]));assert m['full_actor_fx_recomposition_visible_rgba_exact'],i
 records.append(m);thumbs.append(q);print('charge_release',i,m['hand_occlusion_pixels'],flush=True)
sheet('charge_release',thumbs,records)
# Grab-start: use exact approved canonical native weapon for000..007, never PCA-derived blade candidates.
k='grab_start';d=O/k;prior=json.load(open(d/'layers-visible-manifest.json'));timing=json.load(open(d/'source-mapping.json'))['approved_preview']['durations_ms'];bps=[((568,517),(418,96)),((697,440),(691,47)),((687,414),(936,37)),((738,456),(1080,79)),((748,529),(1168,206)),((734,571),(1189,304)),((720,579),(1206,429)),((720,637),(1211,577))];boxes2=[(530,525,650,690),(640,450,750,615),(570,415,705,555),(610,450,745,580),(590,525,740,615),(570,560,735,665),(555,560,720,675),(550,610,720,725)];records=[];thumbs=[]
for i in range(12):
 src=d/f'frames-composite/{i:03}.png';a=np.array(Image.open(src).convert('RGBA'))
 if i<8:
  wp=np.array(Image.open(d/f'layers-native/weapon/{i:03}.png'));wm=wp[:,:,3]>0;base,tip=map(np.array,bps[i]);u=(tip-base)/np.linalg.norm(tip-base);n=np.array([-u[1],u[0]]);y,x=np.indices(a.shape[:2]);along=(x-base[0])*u[0]+(y-base[1])*u[1];cross=(x-base[0])*n[0]+(y-base[1])*n[1];rgb=a[:,:,:3];v=rgb.max(2);sat=v-rgb.min(2);residue=(along>8)&(along<np.linalg.norm(tip-base)+30)&(abs(cross)<70)&(v>95)&(sat<65)&(a[:,:,3]>0);lab,num=ndimage.label(residue);ct=np.bincount(lab.ravel());keep=ct>=80;keep[0]=False;wm|=keep[lab];hm=skin_in_box(a,boxes2[i],wm);meta={'detector':'approved canonical native steel alpha plus existing neutral steel remnants in authored blade corridor; bounded manual grip ROI, no PCA','manual_hand_roi_native':boxes2[i],'weapon_contents':'visible canonical steel plus already-approved residual steel. Hilt/guard remain source-body unless hand-overlap pixels; no new art.','canonical_weapon_path':f'grab_start/layers-native/weapon/{i:03}.png'}
 elif i==9:
  # Retain the blade partition, repair the missing gripping hand only in its actual lower-right source hand region.
  wm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-weapon.png'))>0
  # Exact source-native coordinates checked against original reach-1-down source.
  box=(285,615,455,785);hm=skin_in_box(a,box,wm);meta={'detector':'retained verified visible weapon mask; manually bounded missing-grip correction','manual_hand_roi_native':box,'weapon_contents':'retained source-visible steel/guard/hilt partition'}
 else:
  wm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-weapon.png'))>0;hm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-hand.png'))>0;meta={kk:v for kk,v in prior[i].items() if kk not in ['frame','source','source_sha256']};meta['detector']='retained existing visually checked source-pixel partition for sword-held reach/grip'
 meta['duration_ms']=timing[i];meta['hidden_body_complete']=False;meta['hidden_weapon_under_hands_complete']=False;m,q,_=partition(k,i,src,wm,hm,meta);records.append(m);thumbs.append(q);print('grab_start',i,m['hand_occlusion_pixels'],flush=True)
sheet(k,thumbs,records)
