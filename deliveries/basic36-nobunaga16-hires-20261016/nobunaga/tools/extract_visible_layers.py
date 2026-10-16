from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,json,math,hashlib,sys
D=Path(__file__).resolve().parents[1];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def detect(a):
 rgb=a[:,:,:3].astype(float);v=rgb.max(2);sat=v-rgb.min(2);alpha=a[:,:,3]>0
 bright=(v>100)&(sat<60)&(a[:,:,3]>80)
 lab,n=ndimage.label(ndimage.binary_closing(bright,iterations=2));rs=[]
 for i,sl in enumerate(ndimage.find_objects(lab),1):
  if sl is None:continue
  y,x=np.where(lab[sl]==i);x=x+sl[1].start;y=y+sl[0].start
  if len(x)<60:continue
  pts=np.c_[x,y];eig,vec=np.linalg.eigh(np.cov(pts.T));u=vec[:,-1];pr=pts@u;le=float(np.ptp(pr));wi=float(np.sqrt(max(eig[0],1))*4);score=le*min(le/max(wi,1),20)
  if le<100:continue
  rs.append((score,i,pts,u,le,wi))
 if not rs:raise ValueError('No candidate blade found')
 rs.sort(key=lambda r:r[0],reverse=True);score,i,pts,u,le,wi=rs[0];pr=pts@u;end1=pts[pr<np.quantile(pr,.035)].mean(0);end2=pts[pr>np.quantile(pr,.965)].mean(0)
 r,g,b=np.moveaxis(rgb,2,0);skin=(r>110)&(g>65)&(g/np.maximum(r,1)>.48)&(g/np.maximum(r,1)<.86)&(b/np.maximum(g,1)>.36)&(b/np.maximum(g,1)<.88)&(r>g*1.12)&alpha
 slabel,sn=ndimage.label(ndimage.binary_closing(skin,iterations=2));sizes=np.bincount(slabel.ravel());valid=sizes>=100;valid[0]=False;skin=valid[slabel]
 dist=ndimage.distance_transform_edt(~skin)
 def d(p):return dist[int(np.clip(p[1],0,a.shape[0]-1)),int(np.clip(p[0],0,a.shape[1]-1))]
 base,tip=(end1,end2) if d(end1)<d(end2) else (end2,end1);u=(tip-base)/np.linalg.norm(tip-base);norm=np.array([-u[1],u[0]]);y,x=np.indices(a.shape[:2]);along=(x-base[0])*u[0]+(y-base[1])*u[1];cross=(x-base[0])*norm[0]+(y-base[1])*norm[1]
 steel=ndimage.binary_dilation(ndimage.binary_fill_holes(lab==i),iterations=3)&alpha
 # Only the visible hilt/guard corridor; do not pretend to recover occluded pixels.
 hiltgeo=(along>-215)&(along<4)&(abs(cross)<18);guardgeo=(along>-25)&(along<15)&(abs(cross)<38)
 metal=((r>75)&(g>45)&(r/np.maximum(g,1)<2.6)&(g/np.maximum(b,1)>1.15)) | ((sat<50)&(v<120))
 hl,hn=ndimage.label(ndimage.binary_closing(skin,iterations=2));hm=np.zeros(alpha.shape,bool);palms=[];candidates=[]
 for hi,sl in enumerate(ndimage.find_objects(hl),1):
  if sl is None:continue
  yy,xx=np.where(hl[sl]==hi);xx+=sl[1].start;yy+=sl[0].start
  if len(xx)<140:continue
  cen=np.array([xx.mean(),yy.mean()]);vct=cen-base;alongc=vct@u;crossc=vct@norm;distance=float(np.linalg.norm(vct))
  if not (-225<alongc<-25 and abs(crossc)<45 and distance<240):continue
  if np.ptp(xx)>180 or np.ptp(yy)>205:continue
  candidates.append((len(xx),hi,cen.tolist(),distance))
 if candidates:
  largest=max(r[0] for r in candidates)
  for count,hi,cen,di in sorted(candidates,reverse=True)[:2]:
   if count<largest*.22:continue
   hm|=hl==hi;palms.append((di,cen,count))
 hm=ndimage.binary_dilation(ndimage.binary_fill_holes(hm),iterations=3)&alpha
 weapon=(steel|((hiltgeo|guardgeo)&metal&alpha))&~hm
 hm &=~steel
 # Count likely silhouette underlap: occupied pixels on both sides of visible steel.
 step=max(12,min(wi/2+6,40));y1=np.rint(y+norm[1]*step).astype(int).clip(0,a.shape[0]-1);x1=np.rint(x+norm[0]*step).astype(int).clip(0,a.shape[1]-1);y2=np.rint(y-norm[1]*step).astype(int).clip(0,a.shape[0]-1);x2=np.rint(x-norm[0]*step).astype(int).clip(0,a.shape[1]-1);rest=alpha&~weapon&~hm;under=steel&rest[y1,x1]&rest[y2,x2]
 palms.sort();meta={'detector':'visible neutral steel PCA + bounded hilt corridor + skin hand mask; source-pixel partition','blade_base_art_px':base.tolist(),'blade_tip_art_px':tip.tolist(),'blade_projected_angle_clockwise_from_right_deg':math.degrees(math.atan2(u[1],u[0])),'grip_art_px':palms[0][1] if palms else None,'additional_hand_regions':[p[1] for p in palms[1:]],'landmark_status':'image-derived advisory, not runtime socket','blade_candidate_length_px':le,'blade_candidate_width_px':wi,'candidate_score':score,'manual_review_required':le<160 or wi>90 or score<1400 or not palms,'likely_body_hidden_by_blade_pixels':int(under.sum()),'hidden_body_complete':False,'hidden_weapon_under_hands_complete':False,'visible_weapon_depth':'source occlusions baked; visible pixels only; no inferred rear geometry'}
 return weapon,hm,meta

def partition(src,out,i):
 im=Image.open(src).convert('RGBA');a=np.array(im);wm,hm,m=detect(a);out.mkdir(parents=True,exist_ok=True)
 for name in ['body','weapon','hand_occlusion','masks']:(out/name).mkdir(exist_ok=True)
 masks={'weapon':wm,'hand_occlusion':hm,'body':~(wm|hm)};layers=[]
 for name in ['body','weapon','hand_occlusion']:
  b=a.copy();b[~masks[name]]=0;bi=Image.fromarray(b);p=out/name/f'{i:03}.png';bi.save(p);layers.append(bi);m[name+'_path']=str(p.relative_to(D));m[name+'_sha256']=sha(p)
 Image.fromarray(wm.astype('uint8')*255).save(out/'masks'/f'{i:03}-weapon.png');Image.fromarray(hm.astype('uint8')*255).save(out/'masks'/f'{i:03}-hand.png')
 comp=Image.new('RGBA',im.size)
 for l in layers:comp.alpha_composite(l)
 aa=np.array(comp);same=(aa[:,:,3]==a[:,:,3]).all() and np.array_equal(aa[a[:,:,3]>0],a[a[:,:,3]>0]);assert same
 m.update({'frame':i,'source':str(src),'source_sha256':sha(src),'canvas':list(im.size),'recomposition_visible_rgba_exact':True,'rgba_max_channel_error_visible':0,'layer_order_back_to_front':['body','weapon','hand_occlusion'],'separate_movement_safe':False})
 # Highlight masks on real pixels so all 216 poses can be visually checked without tiny sprite sheets.
 q=Image.new('RGBA',im.size,(35,40,48,255));q.alpha_composite(im);z=np.array(q);z[wm,:3]=(z[wm,:3]*.3+np.array([45,220,250])*.7).astype('uint8');z[hm,:3]=(z[hm,:3]*.3+np.array([240,70,190])*.7).astype('uint8');q=Image.fromarray(z).convert('RGB');q.thumbnail((360,360));return m,q

def main():
 inv=json.loads((D/'inventory.json').read_text());only=set(sys.argv[1:]);allmeta=[]
 for c in inv['clips']:
  key=c['key']
  if key=='throw_reverse' or only and key not in only:continue
  comp=D/key/'frames-composite';fs=sorted(comp.glob('*.png'))
  if len(fs)!=c['approved_preview']['frames']:print('NOT_READY',key,len(fs),flush=True);continue
  result=[];thumbs=[]
  for i,p in enumerate(fs):
   if key=='charge_release' and i>0:p=D/key/'layers-native'/'actor'/f'{i:03}.png'
   m,q=partition(p,D/key/'layers-visible',i);m.update({'duration_ms':c['approved_preview']['durations_ms'][i]});result.append(m);thumbs.append(q);print(key,i,'review?',m['manual_review_required'],flush=True)
  (D/key/'layers-visible-manifest.json').write_text(json.dumps(result,indent=2));sheet=Image.new('RGB',(1440,400*math.ceil(len(thumbs)/4)),(35,40,48));dr=ImageDraw.Draw(sheet)
  for i,q in enumerate(thumbs):xx=i%4*360;yy=i//4*400;sheet.paste(q,(xx,yy+30));dr.text((xx+10,yy+5),f'{key} {i:02} '+('CHECK' if result[i]['manual_review_required'] else ''),fill='white')
  sheet.save(D/'qa'/f'{key}-layers.jpg',quality=94);allmeta.extend({'key':key,**r} for r in result)
 (D/'automatic-layer-summary.json').write_text(json.dumps(allmeta,indent=2))
if __name__=='__main__':main()
