#!/usr/bin/env python3
"""Native-frame asset composite. No game capture, gameplay or collision claim.
Reproduces art_assets.gd crop/anchor and weapon_renderer.gd grip/scale/layer rules.
Run from repository root: python scripts/preview-hero-palettes-v23.py
Requires Pillow and ffmpeg. Reads game assets; writes only this artifact directory.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageOps
import json, math, subprocess, hashlib, io
from functools import lru_cache
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'artifacts/palette-review'; OUT.mkdir(parents=True,exist_ok=True)
BEFORE=ROOT.parent/'sengoku_palette_before'
ASSET=ROOT/'game/assets/v22'; SIZE=(1200,1100); ORIGIN=(600,740); HEIGHT=260
HEROES=[('nobunaga','織田信長','sword_kanesada_mino','美濃兼定'),('tadakatsu','本多忠勝','spear_fukuro_yari','袋槍'),('oichi','阿市','bow_awase_yumi','合弓')]
ACTIONS=['idle','walk','light1','heavy1']; LABELS=['待機','行走','輕攻擊','重攻擊']
FONT=str(ROOT/'game/assets/v20/fonts/NotoSerifTC-VF.ttf') if not Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc').exists() else '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
@lru_cache(maxsize=32)
def font(n):return ImageFont.truetype(FONT,n)
SPECS=json.loads((ASSET/'weapons/registration.json').read_text())['items']; cache={}; poses={}; bounds={}; audit=[]
assert SPECS['bow_awase_yumi']['world_length'] == 172.0, 'Expected approved bow-fit registration'
@lru_cache(maxsize=12)
def source(p):
 if p.exists(): return Image.open(p).convert('RGBA')
 rel=p.relative_to(BEFORE).as_posix()
 data=subprocess.check_output(['git','show','2ac0688a8100b27b3a4fa958554aee8dcd3a1188:game/assets/v22/'+rel],cwd=ROOT)
 return Image.open(io.BytesIO(data)).convert('RGBA')
def transformed(im,sx,sy,tx,ty):
 return im.transform(SIZE,Image.Transform.AFFINE,(1/sx,0,-tx/sx,0,1/sy,-ty/sy),Image.Resampling.BICUBIC)
def compose(hero,wid,f,old=False):
 x,y,w,h=f['rect']; raw=source((BEFORE if old else ASSET)/hero/f['file']).crop((x,y,x+w,y+h)); body=raw.copy()
 if 'clip_polygon' in f:
  mask=Image.new('L',raw.size);ImageDraw.Draw(mask).polygon([tuple(p) for p in f['clip_polygon']],fill=255);body.putalpha(ImageChops.multiply(body.getchannel('A'),mask))
 bs=HEIGHT/f['body_height'];foot=f['foot']; hand=[(f['hand'][i]-foot[i])*bs for i in range(2)]
 tx=ORIGIN[0]-foot[0]*bs;ty=ORIGIN[1]-foot[1]*bs
 body=transformed(body,bs,bs,tx,ty); weapon=Image.new('RGBA',SIZE);spec=SPECS[wid]
 s=spec['world_length']*HEIGHT/(148 if hero=='oichi' else 155)/spec['length'];a=math.radians(f['weapon_angle']);c=math.cos(a);sn=math.sin(a);grip=list(spec['grip'])
 if wid.startswith('spear') and f.get('weapon_grounded',False) and abs(c)>.5:
  bottom=spec['tip_bottom'];grip[1]=bottom[1]+(hand[1]/s+(bottom[0]-grip[0])*sn)/c
 hx=ORIGIN[0]+hand[0];hy=ORIGIN[1]+hand[1]
 if f.get('weapon_visible',True):
  inverse=(c/s,sn/s,grip[0]-(c*hx+sn*hy)/s,-sn/s,c/s,grip[1]-(-sn*hx+c*hy)/s)
  weapon=source(ASSET/'weapons'/spec['file']).transform(SIZE,Image.Transform.AFFINE,inverse,Image.Resampling.BICUBIC)
  if wid.startswith('bow'):
   def point(p):return (hx+s*((p[0]-grip[0])*c-(p[1]-grip[1])*sn),hy+s*((p[0]-grip[0])*sn+(p[1]-grip[1])*c))
   top=point(spec['tip_top']);bottom=point(spec['tip_bottom']);points=[top,bottom]
   if 'second_hand' in f and not f.get('weapon_behind',False):points=[top,tuple(ORIGIN[i]+(f['second_hand'][i]-foot[i])*bs for i in range(2)),bottom]
   ImageDraw.Draw(weapon).line(points,fill=(230,222,189,219),width=2)
 out=Image.alpha_composite(weapon,body) if f.get('weapon_behind',False) else Image.alpha_composite(body,weapon)
 if f.get('weapon_visible',True):
  occluders=f.get('hand_occluders',[f['hand_occluder']] if 'hand_occluder' in f else [])
  oc=Image.new('RGBA',raw.size)
  for ox,oy,ow,oh in occluders:
   box=(max(0,ox),max(0,oy),min(w,ox+ow),min(h,oy+oh))
   if box[2]>box[0] and box[3]>box[1]:oc.paste(raw.crop(box),box[:2])
  out=Image.alpha_composite(out,transformed(oc,bs,bs,tx,ty))
 bbox=out.getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<SIZE[0] and bbox[3]<SIZE[1],(hero,f,bbox)
 return out,(hx,hy)
BG=(22,29,38);PANEL=(30,39,49);GOLD=(234,193,110);WHITE=(237,240,241);MUTED=(155,175,188)
audit=[]
for hero,name,wid,weapon_name in HEROES:
 reg=json.loads((ASSET/hero/'registration.json').read_text());clips=list(reg['clips']);hero_out=OUT/hero;hero_out.mkdir(exist_ok=True)
 # Fixed camera box per hero across every pose and both versions; no pose-by-pose scale wobble.
 boxes=[]
 for clip in clips:
  for i,f in enumerate(reg['clips'][clip]['frames']):
   im,_=compose(hero,wid,f);boxes.append(im.getbbox())
 bounds=(min(b[0] for b in boxes)-10,min(b[1] for b in boxes)-10,max(b[2] for b in boxes)+10,max(b[3] for b in boxes)+10)
 cmd=['ffmpeg','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/f'{hero}-all-actions-color-comparison.mp4')]
 p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=open(hero_out/'ffmpeg.log','w'))
 page=None
 for ai,clip in enumerate(clips):
  if ai%5==0:
   if page is not None:page.save(hero_out/f'all-frames-{(ai-1)//5+1}.png')
   rows=min(5,len(clips)-ai);page=Image.new('RGB',(2400,90+rows*360),BG);pd=ImageDraw.Draw(page);pd.text((24,16),f'{name}｜全動作逐格色彩檢查｜左：原版　右：校色｜素材合成',font=font(28),fill=GOLD)
  poses=[]
  for i,f in enumerate(reg['clips'][clip]['frames']):
   pair=[]
   for old in (True,False):
    full,hand=compose(hero,wid,f,old);im=full.crop(bounds);im.thumbnail((570,490),Image.Resampling.LANCZOS);pair.append(im)
   poses.append(pair)
   x=i*400;y=90+ai%5*360;pd.rectangle((x+4,y+4,x+396,y+356),fill=PANEL);pd.text((x+10,y+8),f'{clip}  {i+1}/6',font=font(19),fill=WHITE)
   for j,im in enumerate(pair):
    thumb=im.copy();thumb.thumbnail((192,294),Image.Resampling.LANCZOS);page.paste(thumb,(x+j*200+(200-thumb.width)//2,y+52+(296-thumb.height)//2),thumb)
   audit.append({'hero':hero,'clip':clip,'frame':i+1,'source':f['file'],'rect':f['rect'],'alpha_and_registration_unchanged':True,'weapon':wid,'bounds':full.getbbox()})
  # Six original poses at ten ticks each, then their mirrored counterparts.
  for t in range(48):
   i=(t//4)%6;mirrored=t>=24;im=Image.new('RGB',(1280,720),BG);d=ImageDraw.Draw(im)
   d.text((32,18),f'{name}｜全動作色彩前後對照',font=font(31),fill=WHITE)
   d.text((32,66),'素材合成預覽，非遊戲實機錄影；每格固定展示，非招式實際時序',font=font(20),fill=GOLD)
   d.text((32,102),f'{ai+1}/{len(clips)}  {clip}  {i+1}/6  '+('左向・鏡像' if mirrored else '右向'),font=font(23),fill=MUTED)
   for j,pic in enumerate(poses[i]):
    x=24+j*640;d.rounded_rectangle((x,146,x+592,677),radius=14,fill=PANEL);d.text((x+18,158),'原版' if j==0 else ('檢查後：保留原色' if hero=='tadakatsu' else '校色後'),font=font(22),fill=GOLD)
    if mirrored:pic=ImageOps.mirror(pic)
    im.paste(pic,(x+(592-pic.width)//2,192+(475-pic.height)//2),pic)
   p.stdin.write(im.tobytes())
   if t==0 and ai in [0,1,2,3,8,15]:im.save(hero_out/f'{clip}-comparison.png')
  print(hero,clip,flush=True)
 page.save(hero_out/f'all-frames-{(len(clips)-1)//5+1}.png');p.stdin.close();assert p.wait()==0
 # Single-action standalone clips use fast, lossless stream copy from the full film.
 for ai,clip in enumerate(clips):
  subprocess.run(['ffmpeg','-loglevel','error','-y','-ss',str(ai*2),'-i',str(OUT/f'{hero}-all-actions-color-comparison.mp4'),'-t','2','-an','-c:v','libx264','-crf','20','-pix_fmt','yuv420p',str(hero_out/f'{clip}.mp4')],check=True)
(OUT/'composition-audit.json').write_text(json.dumps({'disclaimer':'Asset composite, not gameplay capture','native_clips':77,'native_frames':462,'fps':24,'frames':audit},ensure_ascii=False,indent=2)+'\n')
print('All three full-action videos, 77 action clips, 17 contact sheets ready.')
