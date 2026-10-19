"""Native preview FX mesh using the approved officer arc texture, no body edits."""
from pathlib import Path
import json,math
import numpy as np
from scipy.ndimage import map_coordinates
from PIL import Image,ImageFilter

BASE=Path(__file__).resolve().parent
source=json.loads((BASE/'references/sources.json').read_text('utf-8'))['approved_fx']
spec=source['registration']
texture=np.array(Image.open(BASE/'references/approved-officer-arc.png').convert('RGBA'),dtype=float)

def ribbon_layer(points,width,size):
    points=np.asarray(points,dtype=float)
    pad=width*.65+6
    lo=np.floor(points.min(axis=0)-pad).astype(int);hi=np.ceil(points.max(axis=0)+pad).astype(int)
    lo=np.maximum(lo,[0,0]);hi=np.minimum(hi,size)
    yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]]
    best=np.full(xx.shape,np.inf);u=np.zeros(xx.shape);signed=np.zeros(xx.shape)
    distances=np.linalg.norm(np.diff(points,axis=0),axis=1);cum=np.r_[0,np.cumsum(distances)];total=max(1,cum[-1])
    for k,(a,b) in enumerate(zip(points[:-1],points[1:])):
        delta=b-a;length=max(.001,distances[k]);t=np.clip(((xx-a[0])*delta[0]+(yy-a[1])*delta[1])/(length*length),0,1)
        px=a[0]+delta[0]*t;py=a[1]+delta[1]*t;dx=xx-px;dy=yy-py;d2=dx*dx+dy*dy;take=d2<best
        u[take]=(cum[k]+t[take]*length)/total
        signed[take]=(dx[take]*-delta[1]+dy[take]*delta[0])/length
        best[take]=d2[take]
    taper=np.maximum(.001,np.sin(np.pi*u)**.58)
    band=width*taper
    v=signed/band
    valid=(abs(v)<=.5)&(u>.001)&(u<.999)&(best<=(band*.5)**2)
    angle=np.deg2rad(-108+216*u)
    radial=spec['fx_outer_radius_source_px']*(.63+.38*(v+.5))
    tx=spec['origin_fx_px'][0]+np.cos(angle)*radial
    ty=spec['origin_fx_px'][1]+np.sin(angle)*radial
    rgba=np.stack([map_coordinates(texture[:,:,ch],[ty,tx],order=1,mode='constant',cval=0) for ch in range(4)],axis=2)
    rgba[:,:,3]*=valid*np.clip(taper*1.5,0,1)
    patch=Image.fromarray(np.clip(rgba,0,255).astype('uint8'))
    layer=Image.new('RGBA',size);layer.alpha_composite(patch,tuple(lo))
    glow=layer.filter(ImageFilter.GaussianBlur(5))
    glow.putalpha(glow.getchannel('A').point(lambda a:round(a*.45)))
    return Image.alpha_composite(glow,layer)

def make_foot_fx(heel_chamber,heel_extension,heel_contact,hip,size,impact):
    a=np.array(heel_chamber,dtype=float);end=np.array(heel_contact,dtype=float)
    mid=np.array(heel_extension,dtype=float) if impact else (a+end)*.5
    control=2*mid-.5*(a+end)
    points=[(1-t)**2*a+2*(1-t)*t*control+t*t*end for t in np.linspace(0,1,81)]
    radius=float(np.linalg.norm(end-np.array(hip)))
    thickness=radius*1.09*.34
    layer=ribbon_layer(points,thickness,size)
    if impact:
        forward=[end+np.array([x,0]) for x in np.linspace(-14,radius*.42,41)]
        layer=Image.alpha_composite(layer,ribbon_layer(forward,thickness*.50,size))
    return layer,{'hip_to_heel_radius_px':radius,'ribbon_width_px':thickness,'previous_ribbon_width_px':27,'thickness_ratio_to_previous':thickness/27,'forward_impact_length_px':radius*.42 if impact else 0}
