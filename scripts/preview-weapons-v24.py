#!/usr/bin/env python3
"""30 weapons × 12 authored attack poses × both facings (720 views).
Asset composites only, never represented as live gameplay captures.
Uses the existing runtime grip/rotation/scaling/occlusion/bowstring convention.
"""
from pathlib import Path
from functools import lru_cache
import json,math,subprocess,argparse
from PIL import Image,ImageDraw,ImageFont,ImageChops,ImageOps

ROOT=Path(__file__).resolve().parents[1];ASSET=ROOT/'game/assets/v22'
OUT=ROOT/'artifacts/weapon-expansion-v24';OUT.mkdir(parents=True,exist_ok=True)
SIZE=(1600,1400);ORIGIN=(800,900);HEIGHT=240
BG=(22,29,38);PANEL=(30,39,49);GOLD=(234,193,110);WHITE=(237,240,241);MUTED=(155,175,188)
HERO={'sword':'nobunaga','spear':'tadakatsu','bow':'oichi'}
FAMILY={'sword':'刀','spear':'槍','bow':'弓'}
FONT=ROOT/'game/assets/v20/fonts/NotoSerifTC-VF.ttf'
SPECS=json.loads((ASSET/'weapons/registration.json').read_text())['items']
ITEMS=json.loads((ROOT/'game/assets/v24/weapons/implemented-stats.json').read_text())
REG={h:json.loads((ASSET/h/'registration.json').read_text()) for h in HERO.values()}

@lru_cache(maxsize=16)
def font(n):return ImageFont.truetype(str(FONT),n)
@lru_cache(maxsize=16)
def fallback(n):return ImageFont.truetype(str(ROOT/'game/assets/v24/fonts/SengokuReferenceFallback.otf'),n)
MISSING=set(json.loads((ROOT/'game/assets/v24/fonts/glyph-coverage.json').read_text())['fallback_characters'])
def draw_text(d,xy,value,font,fill):
 x,y=xy
 for line in value.split('\n'):
  px=x;run='';last=None
  for char in line+'\0':
   current=char in MISSING
   if last is not None and (current!=last or char=='\0'):
    f=fallback(font.size) if last else font;d.text((px,y),run,font=f,fill=fill);px+=f.getlength(run);run=''
   run+=char;last=current
  y+=round(font.size*1.25)

@lru_cache(maxsize=32)
def source(path):return Image.open(path).convert('RGBA')
def transform(im,s,tx,ty):return im.transform(SIZE,Image.Transform.AFFINE,(1/s,0,-tx/s,0,1/s,-ty/s),Image.Resampling.BICUBIC)

def compose(hero,wid,f):
 x,y,w,h=f['rect'];raw=source(ASSET/hero/f['file']).crop((x,y,x+w,y+h));body=raw.copy()
 if 'clip_polygon' in f:
  mask=Image.new('L',raw.size);ImageDraw.Draw(mask).polygon([tuple(p) for p in f['clip_polygon']],fill=255);body.putalpha(ImageChops.multiply(body.getchannel('A'),mask))
 bs=HEIGHT/f['body_height'];foot=f['foot'];hand=[(f['hand'][i]-foot[i])*bs for i in range(2)]
 tx=ORIGIN[0]-foot[0]*bs;ty=ORIGIN[1]-foot[1]*bs
 body=transform(body,bs,tx,ty);weapon=Image.new('RGBA',SIZE);spec=SPECS[wid]
 s=spec['world_length']*HEIGHT/(148 if hero=='oichi' else 155)/spec['length'];a=math.radians(f['weapon_angle']);c=math.cos(a);sn=math.sin(a);grip=list(spec['grip'])
 if wid.startswith('spear') and f.get('weapon_grounded',False) and abs(c)>.5:
  bottom=spec['tip_bottom'];grip[1]=bottom[1]+(hand[1]/s+(bottom[0]-grip[0])*sn)/c
 hx=ORIGIN[0]+hand[0];hy=ORIGIN[1]+hand[1]
 if f.get('weapon_visible',True):
  inverse=(c/s,sn/s,grip[0]-(c*hx+sn*hy)/s,-sn/s,c/s,grip[1]-(-sn*hx+c*hy)/s)
  weapon=source(ASSET/'weapons'/spec['file']).transform(SIZE,Image.Transform.AFFINE,inverse,Image.Resampling.BICUBIC)
  if wid.startswith('bow'):
   def point(p):return (hx+s*((p[0]-grip[0])*c-(p[1]-grip[1])*sn),hy+s*((p[0]-grip[0])*sn+(p[1]-grip[1])*c))
   points=[point(spec['tip_top']),point(spec['tip_bottom'])]
   if 'second_hand' in f and not f.get('weapon_behind',False):points=[points[0],tuple(ORIGIN[i]+(f['second_hand'][i]-foot[i])*bs for i in range(2)),points[1]]
   ImageDraw.Draw(weapon).line(points,fill=(230,222,189,219),width=2)
 out=Image.alpha_composite(weapon,body) if f.get('weapon_behind',False) else Image.alpha_composite(body,weapon)
 if f.get('weapon_visible',True):
  oc=Image.new('RGBA',raw.size)
  for ox,oy,ow,oh in f.get('hand_occluders',[f['hand_occluder']] if 'hand_occluder' in f else []):
   box=(max(0,ox),max(0,oy),min(w,ox+ow),min(h,oy+oh))
   if box[2]>box[0] and box[3]>box[1]:oc.paste(raw.crop(box),box[:2])
  out=Image.alpha_composite(out,transform(oc,bs,tx,ty))
 bbox=out.getbbox();assert bbox and bbox[0]>2 and bbox[1]>2 and bbox[2]<SIZE[0]-2 and bbox[3]<SIZE[1]-2,(wid,f,bbox)
 return out,(hx,hy)

def fitted(image,bounds,size,face=1,offset=(0,0)):
 im=Image.new('RGBA',(bounds[2]-bounds[0],bounds[3]-bounds[1]));im.alpha_composite(image,(offset[0]-bounds[0],offset[1]-bounds[1]));im.thumbnail(size,Image.Resampling.LANCZOS)
 return ImageOps.mirror(im) if face<0 else im

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--family',choices=list(HERO));parser.add_argument('--no-video',action='store_true');args=parser.parse_args()
 audit=[]
 for family in ([args.family] if args.family else HERO):
  group=[w for w in ITEMS if w['family']==family];hero=HERO[family];dest=OUT/family;dest.mkdir(exist_ok=True)
  # A single family-bound framing preserves relative lengths across all ten.
  poses={};boxes=[]
  for w in group:
   for action in ['light1','heavy1']:
    for n,f in enumerate(REG[hero]['clips'][action]['frames']):
     pic,hand=compose(hero,w['id'],f);bbox=pic.getbbox();poses[w['id'],action,n]=(pic.crop(bbox),hand,bbox);boxes.append(bbox)
     audit.append({'weapon':w['id'],'hero':hero,'action':action,'frame':n+1,'facings':[1,-1],'source_file':f['file'],'source_rect':f['rect'],'weapon_angle':f['weapon_angle'],'grip_world':hand,'bbox':pic.getbbox(),'weapon_visible':f.get('weapon_visible',True),'second_hand':f.get('second_hand'),'hand_occluders':f.get('hand_occluders',[f['hand_occluder']] if 'hand_occluder' in f else [])})
  bounds=(min(b[0] for b in boxes)-12,min(b[1] for b in boxes)-12,max(b[2] for b in boxes)+12,max(b[3] for b in boxes)+12)
  for w in group:
   sheet=Image.new('RGB',(2400,1180),BG);d=ImageDraw.Draw(sheet)
   draw_text(d,(28,15),w['name']+'｜普通／重擊 × 6畫格 × 雙朝向',font=font(31),fill=WHITE)
   draw_text(d,(28,60),'素材畫格合成，非遊戲實機；依現行握點、遮擋、弓弦與比例重建',font=font(24),fill=GOLD)
   for ai,action in enumerate(['light1','heavy1']):
    for fi,face in enumerate([1,-1]):
     for n in range(6):
      x=n*400;y=110+(ai*2+fi)*265;d.rectangle((x+4,y+3,x+396,y+260),fill=PANEL)
      draw_text(d,(x+12,y+7),('普通' if ai==0 else '重擊')+' '+('右' if face==1 else '左')+f' {n+1}/6',font=font(20),fill=MUTED)
      pic=fitted(poses[w['id'],action,n][0],bounds,(380,222),face,poses[w['id'],action,n][2][:2]);sheet.paste(pic,(x+(400-pic.width)//2,y+34+(222-pic.height)//2),pic)
   sheet.save(dest/(w['id']+'-attacks.png'))
  # One 30-second family movie; all 120 unique body/weapon pairs and mirrors.
  if not args.no_video:
   proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1600x1000','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/f'weapons-{family}-30s.mp4')],stdin=subprocess.PIPE,stderr=open(dest/'ffmpeg.log','w'))
   for wi,w in enumerate(group):
    frames=[]
    for n in range(6):
     im=Image.new('RGB',(1600,1000),BG);d=ImageDraw.Draw(im)
     draw_text(d,(30,16),f'新增{FAMILY[family]} {wi+1:02d}/10  '+w['name'],font=font(32),fill=WHITE)
     draw_text(d,(30,65),'素材畫格合成，非遊戲實機錄影',font=font(25),fill=GOLD)
     for ai,action in enumerate(['light1','heavy1']):
      for fi,face in enumerate([1,-1]):
       x=fi*790+15;y=110+ai*420;d.rounded_rectangle((x,y,x+775,y+408),radius=14,fill=PANEL)
       draw_text(d,(x+20,y+14),('普通攻擊' if ai==0 else '重攻擊')+' · '+('右向' if face==1 else '左向')+f' · {n+1}/6',font=font(22),fill=MUTED)
       pic=fitted(poses[w['id'],action,n][0],bounds,(740,350),face,poses[w['id'],action,n][2][:2]);im.paste(pic,(x+(775-pic.width)//2,y+50+(350-pic.height)//2),pic)
     draw_text(d,(30,958),f"傷害+{w['damage_bonus']} / 距離{w['reach_bonus']:+g} / 擊退+{w['knockback']:g}  ·  數值為遊戲設定",font=font(22),fill=MUTED)
     frames.append(im.tobytes())
    for t in range(72):proc.stdin.write(frames[(t//6)%6])
   proc.stdin.close();assert proc.wait()==0
  poses.clear();source.cache_clear()
 (OUT/('composition-audit-'+(args.family or 'all')+'.json')).write_text(json.dumps({'description':'素材合成，不是實機或碰撞測試','pose_pairs':len(audit),'mirrored_views':len(audit)*2,'frames':audit},ensure_ascii=False,indent=2)+'\n')
 # Canonical overview is separately labelled as original game illustrations.
 if not args.family:
  overview=Image.new('RGB',(3000,1900),BG);d=ImageDraw.Draw(overview)
  draw_text(d,(30,20),'新增30把武器｜原創遊戲美術',font=font(44),fill=WHITE)
  draw_text(d,(30,80),'18把既有武器保持不變；史料、復原設計及遊戲能力分欄。此圖不是實物照片。',font=font(27),fill=GOLD)
  for fi,family in enumerate(HERO):
   for i,w in enumerate(x for x in ITEMS if x['family']==family):
    x=i*300;y=140+fi*585;d.rounded_rectangle((x+6,y+6,x+294,y+575),radius=12,fill=PANEL)
    name=w['name'].replace('（復原）','')
    while d.textbbox((0,0),name,font=font(23))[2]>275 and '・' in name:name=name.replace('・','\n',1)
    draw_text(d,(x+15,y+18),name,font=font(23),fill=WHITE)
    pic=source(ASSET/'weapons'/SPECS[w['id']]['file']).copy();pic.thumbnail((245,430),Image.Resampling.LANCZOS);overview.paste(pic,(x+(300-pic.width)//2,y+72+(430-pic.height)//2),pic)
    draw_text(d,(x+15,y+517),w['role'],font=font(20),fill=MUTED)
  overview.save(OUT/'weapon-30-overview.png')
 print('Composites:',OUT)

if __name__=='__main__':main()
