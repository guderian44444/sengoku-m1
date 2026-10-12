#!/usr/bin/env python3
"""Nobunaga v25 source-pixel comparison and all-25-action asset-composite video.
This is not gameplay footage. Uses current 48-weapon composition/hand occlusion.
"""
from pathlib import Path
from functools import lru_cache
import importlib.util,json,subprocess,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/nobunaga-dark-red-v25';OUT.mkdir(parents=True,exist_ok=True)
BASE=ROOT/'game/assets/v22';BEFORE=OUT/'before'
spec=importlib.util.spec_from_file_location('compose48',ROOT/'scripts/preview-weapons-v24.py');M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
M.SIZE=(1200,1100);M.ORIGIN=(600,740);M.HEIGHT=280
REG=json.loads((BASE/'nobunaga/registration.json').read_text());WID='sword_mikazuki_munechika';BG=(22,29,38);PANEL=(31,39,48);GOLD=(234,193,110);WHITE=(238,240,242);MUTED=(160,178,193)
@lru_cache(maxsize=12)
def font(n):return ImageFont.truetype(str(ROOT/'game/assets/v20/fonts/NotoSerifTC-VF.ttf'),n)
@lru_cache(maxsize=16)
def src(p):return Image.open(p).convert('RGBA')

def body(clip,frame,old=False):
 f=REG['clips'][clip]['frames'][frame];x,y,w,h=f['rect'];p=(BEFORE if old else BASE/'nobunaga')/f['file']
 if old and not p.exists():
  manifest=json.loads((ROOT/'game/assets/v25/nobunaga-dark-red.json').read_text());p=BASE/'nobunaga'/f['file'];assert clip in manifest['unchanged_clips'] and hashlib.sha256(p.read_bytes()).hexdigest()==manifest['unchanged_clips'][clip],'Missing before image for changed clip'
 im=src(p).crop((x,y,x+w,y+h))
 if 'clip_polygon' in f:
  from PIL import ImageChops
  mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon([tuple(v) for v in f['clip_polygon']],fill=255);im.putalpha(ImageChops.multiply(im.getchannel('A'),mask))
 return im

def main():
 clips=list(REG['clips']);allbounds=[];audit=[]
 for clip in clips:
  for fi,f in enumerate(REG['clips'][clip]['frames']):
   im,_=M.compose('nobunaga',WID,f);allbounds.append(im.getbbox());audit.append({'clip':clip,'frame':fi+1,'source':f['file'],'source_sha256':hashlib.sha256((BASE/'nobunaga'/f['file']).read_bytes()).hexdigest(),'registration':f})
 box=(min(b[0] for b in allbounds)-12,min(b[1] for b in allbounds)-12,max(b[2] for b in allbounds)+12,max(b[3] for b in allbounds)+12)
 # Before/after first-pose overview; exactly same geometry/scaling in each pair.
 sheet=Image.new('RGB',(2000,90+7*355),BG);d=ImageDraw.Draw(sheet);d.text((24,18),'信長暗紅甲｜左：上輪　右：本次｜待機等既有暗甲保留',font=font(29),fill=GOLD)
 for ai,clip in enumerate(clips):
  for j in range(2):
   im=body(clip,0,j==0);im.thumbnail((238,302),Image.Resampling.LANCZOS);x=ai%4*500+j*250;y=90+ai//4*355;d.rectangle((x+4,y+3,x+246,y+351),fill=PANEL);d.text((x+9,y+10),clip+(' 上輪' if j==0 else ' 暗紅'),font=font(18),fill=WHITE);sheet.paste(im,(x+(250-im.width)//2,y+44+(302-im.height)//2),im)
 sheet.save(OUT/'nobunaga-dark-red-before-after.png')
 focus=Image.new('RGB',(1600,80+4*420),BG);d=ImageDraw.Draw(focus);d.text((24,16),'信長暗紅甲｜左：上輪　右：本次｜待機保持原樣',font=font(31),fill=GOLD)
 for ri,clip in enumerate(['idle','light1','rising','air_heavy']):
  for j in range(2):
   im=body(clip,0,j==0);im.thumbnail((740,360),Image.Resampling.LANCZOS);x=j*800;y=80+ri*420;d.rounded_rectangle((x+12,y+5,x+788,y+414),radius=14,fill=PANEL);d.text((x+28,y+15),clip+(' 上輪' if j==0 else ' 暗紅'),font=font(24),fill=WHITE);focus.paste(im,(x+(800-im.width)//2,y+49+(360-im.height)//2),im)
 focus.save(OUT/'nobunaga-dark-red-focus.png')
 # Every authored pose in five pages, current final art only.
 for start in range(0,len(clips),5):
  page=Image.new('RGB',(1800,70+min(5,len(clips)-start)*350),BG);d=ImageDraw.Draw(page);d.text((24,14),'信長暗紅甲｜本次最終來源｜每組六格，完整150格',font=font(27),fill=GOLD)
  for ri,clip in enumerate(clips[start:start+5]):
   for fi in range(6):
    im=body(clip,fi);im.thumbnail((280,300),Image.Resampling.LANCZOS);x=fi*300;y=70+ri*350;d.text((x+8,y+5),clip+f' {fi+1}/6',font=font(18),fill=WHITE);page.paste(im,(x+(300-im.width)//2,y+40+(300-im.height)//2),im)
  page.save(OUT/f'nobunaga-dark-all-frames-{start//5+1}.png')
 # Current dark version only; both facings per action. No bright old version in film.
 proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'nobunaga-dark-red-all-25-actions.mp4')],stdin=subprocess.PIPE,stderr=open(OUT/'ffmpeg.log','w'))
 for ai,clip in enumerate(clips):
  views=[]
  for fi,f in enumerate(REG['clips'][clip]['frames']):
   pose,_=M.compose('nobunaga',WID,f);pose=pose.crop(box);pose.thumbnail((580,490),Image.Resampling.LANCZOS)
   im=Image.new('RGB',(1280,720),BG);d=ImageDraw.Draw(im);d.text((30,20),'信長｜暗紅甲最終版｜全部25動作・150格',font=font(31),fill=WHITE);d.text((30,67),'素材合成，非遊戲實機錄影｜固定每格展示，非招式實際時序',font=font(21),fill=GOLD);d.text((30,109),f'{ai+1:02d}/25  {clip}  ·  {fi+1}/6',font=font(23),fill=MUTED)
   for j in range(2):
    x=24+j*640;d.rounded_rectangle((x,151,x+592,677),radius=14,fill=PANEL);d.text((x+18,165),'右向・暗紅' if j==0 else '左向・暗紅',font=font(22),fill=GOLD);p=pose if j==0 else ImageOps.mirror(pose);im.paste(p,(x+(592-p.width)//2,194+(475-p.height)//2),p)
   views.append(im.tobytes())
  for t in range(48):proc.stdin.write(views[(t//4)%6])
  print(clip,flush=True)
 proc.stdin.close();assert proc.wait()==0
 (OUT/'preview-source-audit.json').write_text(json.dumps({'disclaimer':'Asset composite, not gameplay','clips':25,'frames':150,'duration':50,'fps':24,'weapon':WID,'weapon_catalog_count':len(M.SPECS),'frames_with_source_hashes':audit},ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
