from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np
from pathlib import Path
p=Path('nobunaga_impact_v4/grab_hold_swordheld/frames-native/000.png');im=Image.open(p).convert('RGBA');a=np.array(im);rgb=a[:,:,:3].astype(float);v=rgb.max(2);sat=v-rgb.min(2);mask=(v>100)&(sat<60)&(a[:,:,3]>80);mask=ndimage.binary_closing(mask,iterations=2);lab,n=ndimage.label(mask);records=[]
for i,sl in enumerate(ndimage.find_objects(lab),1):
 if sl is None:continue
 y,x=np.where(lab[sl]==i);x=x+sl[1].start;y=y+sl[0].start
 if len(x)<35:continue
 pts=np.c_[x,y];eig,vec=np.linalg.eigh(np.cov(pts.T));u=vec[:,-1];pr=pts@u;length=float(np.ptp(pr));width=float(np.sqrt(max(eig[0],1))*4);score=length*min(length/max(width,1),20);records.append((score,i,len(x),length,width,sl))
records.sort(reverse=True);print(records[:10]);bg=Image.new('RGBA',im.size,(40,40,40,255));bg.alpha_composite(im);d=ImageDraw.Draw(bg)
for k,(_,i,n,l,w,sl) in enumerate(records[:10]):d.rectangle((sl[1].start,sl[0].start,sl[1].stop,sl[0].stop),outline='lime',width=3);d.text((sl[1].start,sl[0].start),str(k),fill='white')
bg.save('nobunaga_final_approved/qa/blade-probe.png')
