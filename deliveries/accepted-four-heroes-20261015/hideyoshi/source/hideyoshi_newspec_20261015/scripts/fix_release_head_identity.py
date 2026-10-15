from PIL import Image,ImageDraw,ImageOps
from pathlib import Path
import numpy as np,json,math,hashlib
P=Path(__file__).resolve().parents[1];B=P/'actions/charge_release_scale_v4';D=P/'actions/charge_release_headlock_v5';D.mkdir(exist_ok=True)
ref=Image.open(P/'hideyoshi_head95_single_preview.png').convert('RGBA');rm=Image.new('L',ref.size);ImageDraw.Draw(rm).polygon([(104,0),(206,0),(206,77),(182,81),(171,84),(152,95),(138,81),(136,67),(108,65)],fill=255);head=ref.copy();head.putalpha(Image.fromarray(np.minimum(np.array(ref.getchannel('A')),np.array(rm))))
# All coordinates are in the final 520x300 canvas. No body or weapon transforms are performed.
CFG={
 0:dict(kind='approved',anchor=(227,138.5),box=(210,106,247,142),poly=[(211,106),(246,106),(246,137),(237,137),(237,133),(218,133),(213,130),(211,126)]),
 1:dict(kind='same_view',anchor=(231,131),box=(210,100,246,134),scale=(.94,.96)),
 2:dict(kind='same_view',anchor=(268,127),box=(251,97,287,130),scale=(.94,.96)),
 3:dict(kind='same_view',anchor=(268,135),box=(249,101,288,139),scale=(.94,.96)),
 4:dict(kind='approved_mirror',anchor=(247,146.5),box=(228,108,266,151)),
 5:dict(kind='same_view',anchor=(220,148),box=(204,111,237,152),scale=(.92,.94)),
 6:dict(kind='approved',anchor=(208.5,151),box=(189,116,228,157)),
 7:dict(kind='approved',anchor=(213.5,151.5),box=(193,116,233,158)),
 'hold':dict(kind='approved',anchor=(185,144),box=(165,114,206,151)),
}
def edit(old,c):
 a=np.array(old);xx,yy=np.meshgrid(np.arange(old.width),np.arange(old.height));x,y=c['anchor'];x0,y0,x1,y1=c['box'];mask=Image.new('L',old.size)
 if 'poly' in c:ImageDraw.Draw(mask).polygon(c['poly'],fill=255)
 else:
  ImageDraw.Draw(mask).rectangle(c['box'],fill=255)
  ma=np.array(mask);R,G,BL=[a[:,:,k].astype(float) for k in range(3)];garment=((R>90)&(R>1.8*G))|((BL>R*1.1)&(BL>35))|((np.minimum(R,np.minimum(G,BL))>150)&(np.max(a[:,:,:3],axis=2)-np.min(a[:,:,:3],axis=2)<45))
  ma[(yy>y-11)&garment]=0
  # Preserve the physical lower neck socket and all collar pixels.
  ma[(yy>=y-4)&(xx>=x-6)&(xx<=x+6)]=0
  ma[yy>=y+1]=0;mask=Image.fromarray(ma)
 body=old.copy();body.putalpha(Image.fromarray(np.where(np.array(mask)>0,0,a[:,:,3]).astype('uint8')))
 if c['kind'].startswith('approved'):
  sx=-.31875 if c['kind']=='approved_mirror' else .31875;sy=.31875;ox=x-150*sx;oy=y-93*sy;new=head.transform(old.size,Image.Transform.AFFINE,(1/sx,0,-ox/sx,0,1/sy,-oy/sy),Image.Resampling.BICUBIC);method='approved95 original pixels'+(' mirrored for left-facing same angle' if sx<0 else '')
 else:
  sx,sy=c['scale'];dx=x*(1-sx);dy=y*(1-sy);isol=old.copy();isol.putalpha(Image.fromarray(np.minimum(a[:,:,3],np.array(mask))));new=isol.transform(old.size,Image.Transform.AFFINE,(1/sx,0,-dx/sx,0,1/sy,-dy/sy),Image.Resampling.BICUBIC);method='same-angle original head only; narrow facial/hair volume, neck locked; no angle substitution'
 body.alpha_composite(new);return body,mask,new,method
m=json.loads((B/'metadata.json').read_text());frames=[];views=[];rows=[]
for i,r in enumerate(m['frames']):
 old=Image.open(B/f'body_canvas_{i:02}.png').convert('RGBA')
 if i==16:body=old.copy();clear=Image.new('L',old.size);new=Image.new('RGBA',old.size);method='exact approved shared-ready head already present';c=None
 else:
  key='hold' if i==0 else r['source_index'];c=CFG[key];body,clear,new,method=edit(old,c)
  if key==0:body=Image.open(P/'head_identity_fix/body_nearside_candidate.png').convert('RGBA')
 # Preserve original composite everywhere except the changed head pixel region.
 comp=Image.open(B/f'composite_{i:02}.png').convert('RGBA');changed=np.any(np.array(old)!=np.array(body),axis=2);ca=np.array(comp);ba=np.array(body);ca[changed]=ba[changed];comp=Image.fromarray(ca)
 for name,z in [('body_canvas',body),('composite',comp)]:z.save(D/f'{name}_{i:02}.png')
 for name in ['weapon','fx_back','fx_front']:Image.open(B/f'{name}_{i:02}.png').save(D/f'{name}_{i:02}.png')
 ys,xs=np.where(changed);bb=None if len(xs)==0 else [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];assert not np.any(changed[165:]),'body below neck modified'
 rows.append(dict(index=i,source_index=r.get('source_index'),method=method,neck_anchor=None if c is None else c['anchor'],changed_bbox=bb,changed_pixels=int(changed.sum()),body_below_y165_pixel_exact=True,weapon_pixel_exact=True))
 r['head_identity_correction']=rows[-1];frames.append(comp);bg=Image.new('RGB',(520,300),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dd=ImageDraw.Draw(bg);dd.line((0,253,520,253),fill=(68,74,82));dd.text((12,12),'HIDEYOSHI / charge_release / approved head / 1240 ms',fill='white');dd.text((12,280),f'{i+1:02}/17  approved identity / original footwork + reach',fill=(170,180,190));views.append(bg)
views[0].save(D/'charge_release_headlock_v5.gif',save_all=True,append_images=views[1:],duration=[r['duration_ms'] for r in m['frames']],loop=0,disposal=2,optimize=False);views[5].save(D/'representative.png');frames[5].save(D/'representative_rgba.png');cs=Image.new('RGB',(2080,1500),(42,48,56))
for i,v in enumerate(views):cs.paste(v,(i%4*520,i//4*300))
cs.save(D/'contact.png');m.update(revision='left_pivot_reach_approved_head_identity_v5',head_identity_audit=dict(approved_reference='hideyoshi_head95_single_preview.png',approved_sha256=hashlib.sha256((P/'hideyoshi_head95_single_preview.png').read_bytes()).hexdigest(),source_before_fix=str(B.relative_to(P)),method='same-angle approved head pixels; original yaw heads only locally calibrated when face direction differs',frames=rows,body_and_weapon_unchanged=True,generated_turntable_used=False));(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));g=Image.open(D/'charge_release_headlock_v5.gif');assert g.n_frames==17 and sum((g.seek(i) or g.info['duration']) for i in range(17))==1240
cs=Image.new('RGB',(1800,800),(42,48,56));dd=ImageDraw.Draw(cs)
for j in range(8):
 i=j+1 if j<6 else j+8;box=CFG[j]['box'];crop=(box[0]-3,box[1]-3,box[2]+3,box[3]+3)
 for k,path in enumerate([B,D]):
  z=Image.open(path/f'body_canvas_{i:02}.png');c=z.crop(crop).resize(((crop[2]-crop[0])*4,(crop[3]-crop[1])*4),Image.Resampling.NEAREST);x=(j%4)*440+k*210;y=(j//4)*380;cs.paste(c,(x,y),c);dd.text((x,y+220),f'{"before" if k==0 else "after"} src{j}',fill='white')
cs.save(D/'head_angle_QA.png');print(D)
