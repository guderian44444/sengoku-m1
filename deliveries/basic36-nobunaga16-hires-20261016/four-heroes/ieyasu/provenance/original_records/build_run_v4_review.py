from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,sys
BASE=Path(__file__).parent;sys.path.insert(0,str(BASE));import render_action as R
OUT=BASE/'run_v4';OUT.mkdir(exist_ok=True);Q=OUT/'qa';Q.mkdir(exist_ok=True)
# Cut only at existing armor and coat edges. Final game pixels sample each original part exactly once.
upper=R.isolate({'source':'run_v2_contacts_raw.png','component':0})
mask=Image.new('L',upper.size);d=ImageDraw.Draw(mask)
d.polygon([(0,0),(850,0),(850,540),(736,540),(690,559),(601,568),(570,527),(552,496),(533,579),(423,558),(415,545),(398,571),(337,543),(326,573),(268,553),(266,530),(270,500),(0,500)],fill=255)
a=np.array(upper);a[:,:,3]=a[:,:,3].astype('uint16')*np.array(mask)//255;upper=Image.fromarray(a);upper.save(Q/'fixed_upper_native.png')
# Names below refer to visual review, not generator's filenames.
specs=[('near_support','run_v4_far_support_near_low_pass_v2_raw.png',170,5),('far_support','run_v4_near_support_far_low_pass_v2_raw.png',155,-12)]
for name,src,dx,dy in specs:
 lower=R.isolate({'source':src});ar=np.array(lower);ar[:810,:,3]=0;lower=Image.fromarray(ar);lower.save(Q/f'{name}_lower_original.png')
 # Native QA composite is inspection only. The game renderer below samples both original parts once.
 native=Image.new('RGBA',(1536,1536));native.alpha_composite(lower,(round(dx*1.5),round(dy*1.5)));native.alpha_composite(upper.resize((2304,1536),Image.Resampling.NEAREST),(0,0));native.save(Q/f'{name}_native_hybrid.png')
 s=152/920;ox=220-560*s;oy=280-949*s
 body=R.place(lower,s/1.5,ox+dx*s,oy+dy*s);body.alpha_composite(R.place(upper,s,ox,oy));body.save(OUT/f'{name}_body.png')
 hands=[[590,433],[652,438]];gp=[ox+621*s,oy+435.5*s]
 sw=R.weapon(R.sw,[100,1080],gp,-55,.085);sa=R.weapon(R.sa,[87,22],[ox+609*s,oy+447.5*s],65,.073)
 hm=Image.new('L',upper.size);hd=ImageDraw.Draw(hm)
 for x,y in hands:hd.ellipse((x-34,y-34,x+34,y+34),fill=255)
 ar=np.array(upper);ar[:,:,3]=ar[:,:,3].astype('uint16')*np.array(hm)//255;hand=R.place(Image.fromarray(ar),s,ox,oy)
 comp=Image.new('RGBA',(480,320))
 for lay,im in [('sheath',sa),('body',body),('weapon',sw),('hand_occlusion',hand)]:im.save(OUT/f'{name}_{lay}.png');comp.alpha_composite(im)
 comp.save(OUT/f'{name}_composite.png')
# Anatomy: trace actual visible contours; dotted A junction marks uncertainty rather than assuming the label.
red=(242,64,77);blue=(39,151,245);can=Image.new('RGB',(1224,800),'#d2d6da')
for j,(name,src,dx,dy) in enumerate(specs):
 im=Image.open(BASE/'sources'/src).convert('RGBA');bg=Image.new('RGBA',im.size,'#b2b6ba');bg.alpha_composite(im);crop=bg.crop((200,740,800,1480)).convert('RGB');can.paste(crop,(j*612,40));dd=ImageDraw.Draw(can);dd.text((j*612+12,12),f'{"A" if j==0 else "B"}: inferred {name}; trace follows visible cloth',fill='black')
 # coordinates are original source. Near visible outline and foot path; far in blue.
 if j==0:
  near=[(350,840),(390,910),(520,965),(610,1020),(560,1085),(550,1255),(600,1393)]
  far=[(650,845),(700,960),(700,1025),(585,1045),(425,1005),(364,1060),(385,1150)]
 else:
  near=[(340,850),(395,920),(530,945),(575,990),(505,1015),(390,1010),(365,1100),(395,1163)]
  far=[(665,858),(700,978),(670,1060),(600,1110),(590,1280),(635,1420)]
 for pts,col in [(far,blue),(near,red)]:
  pts=[(x-200+j*612,y-740+40) for x,y in pts];dd.line(pts,fill=col,width=5,joint='curve')
  for pt in [pts[0],pts[len(pts)//2],pts[-1]]:dd.ellipse((pt[0]-6,pt[1]-6,pt[0]+6,pt[1]+6),fill=col)
 dd.text((j*612+12,767),'RED near / BLUE far; A knee-cuff junction is less certain' if j==0 else 'B near folded leg visibly overlays far support thigh',fill='black')
can.save(Q/'low_passing_native_paths.png')
# Four keys only: contact -> low passing, each leg once. Missing flight explicitly declared.
ims=[Image.open(BASE/'run_v2/composite_01.png'),Image.open(OUT/'far_support_composite.png'),Image.open(BASE/'run_v2/composite_04.png'),Image.open(OUT/'near_support_composite.png')]
labels=['1 FAR contact (retained)','2 FAR support / NEAR low swing','3 NEAR contact (retained)','4 NEAR support / FAR low swing (review junction)']
frames=[];strip=Image.new('RGB',(1440,400),'#252b34')
for i,(im,label) in enumerate(zip(ims,labels)):
 fr=Image.new('RGB',(480,320),'#252b34');fr.paste(im,(0,0),im);dd=ImageDraw.Draw(fr);dd.line((12,281,470,281),fill='#69727e');dd.text((12,12),'IEYASU KEY POSES - NOT FINAL RUN',fill='white');dd.text((12,292),label,fill='white');frames.append(fr)
 crop=fr.crop((50,70,410,320));strip.paste(crop,(i*360,70));ImageDraw.Draw(strip).text((i*360+8,32),label,fill='white')
ImageDraw.Draw(strip).text((12,370),'KEY-POSE REVIEW ONLY: short flight transitions not included. 152px ruler, no per-frame bbox scaling.',fill='white');strip.save(OUT/'numbered-pose-strip.png')
frames[0].save(OUT/'slow-once.gif',save_all=True,append_images=frames[1:],duration=[650]*4,disposal=2)
(Q/'review_status.json').write_text(json.dumps({'status':'pending_parent_visual_review','two_contacts':'parent allowed retaining v2 contacts','passing_A':'tentative near support; knee-cuff overlap ambiguous','passing_B':'near swing/far support; clearer occlusion','flight_included':False,'native_hybrids':'QA composites only; each source part sampled directly once for game pixels','source_standing_equivalent':{'upper':920,'lower':1380}},indent=2))
