"""Independent, read-only inspection of a frozen shared VFX package."""
import sys,json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(sys.argv[1]);out=Path(sys.argv[2]);c=json.loads((root/'game/vfx/v2/catalog.json').read_text())['effects'];r={'effects':{},'scope':'CPU pixel/math checks only; not native GPU validation'}
for k,s in c.items():
 p=root/'game'/s['texture'].removeprefix('res://');raw=p.read_bytes();im=Image.open(p);a=np.asarray(im.getchannel('A'));h,w=a.shape
 assert im.mode=='RGBA' and s['frames']==s['columns']==s['rows']==1 and im.size==tuple(s['cell'])
 assert hashlib.sha256(raw).hexdigest()==s['sha256']
 assert a.min()==0 and a.max()>200 and np.any((a>0)&(a<255))
 edge=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
 y,x=np.where(a>8);info={'sha256':s['sha256'],'size':im.size,'frames':s['frames'],'clear_fraction':float((a==0).mean()),'partial_fraction':float(((a>0)&(a<255)).mean()),'edge_alpha_max':int(edge.max()),'alpha_gt8_margin':int(min(x.min(),y.min(),w-1-x.max(),h-1-y.max()))}
 if s.get('split_depth'):
  assert s['pivot'][1]==s['seam']
  info['seam_normalized']=s['seam']
 if s.get('motion')=='ellipse_flow':
  n=2048;u=np.concatenate([np.linspace(0,1,n),np.linspace(0,1,n),np.zeros(n),np.ones(n)]);v=np.concatenate([np.zeros(n),np.ones(n),np.linspace(0,1,n),np.linspace(0,1,n)])
  pad=float(s.get('render_padding',0));u=u*(1+2*pad)-pad;v=v*(1+2*pad)-pad;center=np.array(s['flow_center']);rad=np.array(s['flow_radius']);q=np.array([u-center[0],v-center[1]])/rad[:,None];worst=0
  for t in np.linspace(0,2*np.pi,361):
   uv=center[:,None]+np.array([[np.cos(t),-np.sin(t)],[np.sin(t),np.cos(t)]])@q*rad[:,None]
   x=np.clip(np.round(uv[0]*(w-1)).astype(int),0,w-1);y=np.clip(np.round(uv[1]*(h-1)).astype(int),0,h-1);worst=max(worst,int(a[y,x].max()))
  info['rotation_boundary_alpha_max_361_angles']=worst
 r['effects'][k]=info
out.write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
