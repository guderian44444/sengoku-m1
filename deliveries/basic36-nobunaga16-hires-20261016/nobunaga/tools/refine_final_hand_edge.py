from extract_visible_layers import D,sha
from PIL import Image,ImageDraw
import numpy as np,json
key='grab_start';i=1;mp=D/key/'layers-visible-manifest.json';rows=json.load(open(mp));m=rows[i];im=Image.open(D/key/'frames-composite'/f'{i:03}.png').convert('RGBA');a=np.array(im);o=D/key/'layers-visible';wm=np.array(Image.open(o/'masks'/f'{i:03}-weapon.png'))>0;hm=np.array(Image.open(o/'masks'/f'{i:03}-hand.png'))>0;lim=Image.new('L',im.size);dr=ImageDraw.Draw(lim)
for poly in [[(672,463),(698,464),(717,474),(714,490),(706,507),(690,520),(670,513),(649,516),(640,500),(648,480)],[(665,515),(685,515),(701,527),(700,550),(692,566),(676,571),(664,559),(650,550),(650,533)]]:dr.polygon(poly,fill=255)
hm&=np.array(lim)>0;wm&=~hm
for name,mask in [('body',~(wm|hm)),('weapon',wm),('hand_occlusion',hm)]:
 z=a.copy();z[~mask]=0;p=o/name/f'{i:03}.png';Image.fromarray(z).save(p);m[name+'_sha256']=sha(p)
Image.fromarray(hm.astype('uint8')*255).save(o/'masks'/f'{i:03}-hand.png');y,x=np.where(hm);m['grip_art_px']=[float(x.mean()),float(y.mean())];m['hand_occlusion_pixels']=int(hm.sum());m['manual_semantic_refinement']='Final native polygon constraint removes connected face/neck skin and gold pommel from gripping-hand mask';mp.write_text(json.dumps(rows,indent=2));print('hand edge fixed',m['grip_art_px'])
