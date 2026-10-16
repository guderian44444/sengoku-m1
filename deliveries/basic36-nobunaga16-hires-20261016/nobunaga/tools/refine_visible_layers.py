from extract_visible_layers import D,sha
from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,json,math
# Hand-traced foreground grip regions, in each unchanged native master coordinate system.
P={
'light_1:5':[[[686,650],[709,654],[728,669],[732,687],[721,706],[709,720],[689,712],[670,714],[661,700],[662,679]],[[672,715],[693,714],[707,731],[702,761],[691,785],[674,787],[663,773],[649,765],[648,746],[655,727]]],
'light_1:6':[[[631,545],[651,548],[671,561],[675,580],[662,598],[645,610],[627,600],[616,604],[607,589],[612,568]],[[586,593],[608,597],[626,611],[623,631],[605,653],[586,663],[574,649],[561,640],[560,621],[568,605]]],
'light_1:3':[[[603,460],[616,456],[628,463],[635,480],[641,502],[641,513],[626,520],[611,534],[592,543],[577,536],[573,517],[584,495],[587,474]],[[612,529],[630,533],[644,542],[651,562],[649,574],[626,581],[618,594],[601,584],[593,573],[595,550]]],
'light_2:4':[[[677,523],[691,520],[705,529],[712,543],[705,557],[704,575],[697,589],[681,590],[673,584],[667,564],[665,552]],[[729,532],[747,528],[764,537],[773,551],[771,573],[758,590],[743,593],[718,588],[711,577],[715,554]]],
'light_3:13':[[[712,486],[727,488],[750,504],[755,519],[747,532],[732,542],[715,533],[697,541],[682,529],[686,508]],[[693,539],[711,540],[724,549],[725,568],[713,588],[696,596],[677,583],[679,563],[682,548]]],
'light_3:14':[[[668,523],[687,524],[705,533],[709,551],[698,568],[680,570],[661,579],[650,567],[654,541]],[[662,575],[681,574],[697,582],[695,607],[680,628],[662,626],[652,616],[651,594]]],
'heavy:13':[[[605,430],[640,420],[659,427],[667,445],[652,465],[637,474],[626,489],[613,477],[591,474],[590,460]],[[590,478],[616,479],[632,493],[632,525],[618,545],[599,551],[592,529],[576,519],[576,501]]],
'charge_ready:1':[[[866,617],[891,615],[912,626],[914,646],[899,665],[882,675],[863,668],[847,672],[845,653],[852,631]],[[861,667],[884,667],[899,682],[896,711],[885,726],[866,726],[856,716],[850,699],[853,680]]],
'dash_heavy:10':[[[720,260],[745,254],[766,266],[770,288],[760,307],[742,313],[730,304],[714,314],[705,300],[705,282]],[[744,300],[768,300],[785,312],[788,343],[775,355],[757,347],[740,350],[732,332],[733,314]]],
'dash_heavy:11':[[[617,510],[639,510],[659,521],[662,541],[651,559],[637,569],[620,560],[599,566],[591,552],[595,534]],[[608,557],[628,558],[640,574],[636,602],[625,620],[609,619],[598,606],[589,594],[592,575]]],
'dash_heavy:12':[[[631,569],[654,569],[670,582],[672,604],[655,620],[642,626],[627,616],[608,624],[600,609],[605,590]],[[622,620],[642,619],[656,635],[652,669],[640,685],[626,684],[615,670],[605,656],[609,635]]]
}
(D/'tools'/'manual-layer-regions.json').write_text(json.dumps(P,indent=2))
keys=set(k.split(':')[0] for k in P)|{'grab_hit_1','grab_hit_2'}
for key in keys:
 mp=D/key/'layers-visible-manifest.json';ms=json.loads(mp.read_text())
 for i,m in enumerate(ms):
  k=f'{key}:{i}';belt=key in ['grab_hit_1','grab_hit_2'] and i in [2,4]
  if k not in P and not belt:continue
  out=D/key/'layers-visible';im=Image.open(D/key/'frames-composite'/f'{i:03}.png').convert('RGBA');a=np.array(im);wm=np.array(Image.open(out/'masks'/f'{i:03}-weapon.png'))>0;hm=np.array(Image.open(out/'masks'/f'{i:03}-hand.png'))>0
  if belt:
   hm[:,600:]=False;m['additional_hand_regions']=[]
  else:
   mask=Image.new('L',im.size);dr=ImageDraw.Draw(mask)
   for pp in P[k]:dr.polygon([tuple(p) for p in pp],fill=255)
   hm=np.array(mask)>0;hm &= a[:,:,3]>0
   centers=[np.mean(pp,axis=0).tolist() for pp in P[k]];m['grip_art_px']=centers[0];m['additional_hand_regions']=centers[1:]
  if k=='light_2:4':
   m['blade_base_art_px']=[614,562];m['blade_tip_art_px']=[65,515];u=np.array([-549,-47],float);u/=np.linalg.norm(u);m['blade_projected_angle_clockwise_from_right_deg']=math.degrees(math.atan2(u[1],u[0]));y,x=np.indices(a.shape[:2]);along=(x-614)*u[0]+(y-562)*u[1];cross=(x-614)*(-u[1])+(y-562)*u[0];wm |= ((along>-210)&(along<10)&(abs(cross)<19)|((along>-34)&(along<20)&(abs(cross)<40)))&(a[:,:,3]>0)
  wm &= ~hm
  for name,mask in [('body',~(wm|hm)),('weapon',wm),('hand_occlusion',hm)]:
   aa=a.copy();aa[~mask]=0;p=out/name/f'{i:03}.png';Image.fromarray(aa).save(p);m[name+'_sha256']=sha(p)
  Image.fromarray(wm.astype('uint8')*255).save(out/'masks'/f'{i:03}-weapon.png');Image.fromarray(hm.astype('uint8')*255).save(out/'masks'/f'{i:03}-hand.png')
  m['manual_semantic_refinement']='hand traced grip polygons / excluded face or belt medallion; unchanged source pixels';m['manual_review_required']=False
 mp.write_text(json.dumps(ms,indent=2))
# Refresh QA sheets from actual resulting masks.
for key in keys:
 ms=json.loads((D/key/'layers-visible-manifest.json').read_text());sheet=Image.new('RGB',(1440,400*math.ceil(len(ms)/4)),(35,40,48));dr=ImageDraw.Draw(sheet)
 for i,m in enumerate(ms):
  im=Image.open(D/key/'frames-composite'/f'{i:03}.png').convert('RGBA');b=Image.new('RGBA',im.size,(35,40,48,255));b.alpha_composite(im);z=np.array(b);out=D/key/'layers-visible';wm=np.array(Image.open(out/'masks'/f'{i:03}-weapon.png'))>0;hm=np.array(Image.open(out/'masks'/f'{i:03}-hand.png'))>0;z[wm,:3]=(z[wm,:3]*.3+np.array([45,220,250])*.7).astype('uint8');z[hm,:3]=(z[hm,:3]*.3+np.array([240,70,190])*.7).astype('uint8');q=Image.fromarray(z).convert('RGB');q.thumbnail((360,360));xx=i%4*360;yy=i//4*400;sheet.paste(q,(xx,yy+30));dr.text((xx+10,yy+5),f'{key} {i:02}',fill='white')
 sheet.save(D/'qa'/f'{key}-layers.jpg',quality=94)
print('refined',sum(len(json.loads((D/k/'layers-visible-manifest.json').read_text())) for k in keys),'frames in',len(keys),'clips')
