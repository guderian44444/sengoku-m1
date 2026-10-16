from pathlib import Path
import json,subprocess
from PIL import Image,ImageDraw,ImageFont
import numpy as np
from scipy.io import wavfile
r=Path(__file__).resolve().parent;m=json.loads((r/'manifest.json').read_text());p=r/'preview';p.mkdir(exist_ok=True)
font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
def f(s):return ImageFont.truetype(font,s)
actors=[('nobunaga','信長','#ff9a56'),('oichi','阿市','#8fe8ff'),('hideyoshi','秀吉','#b4efad'),('ieyasu','家康','#e8b076'),('mitsuhide','光秀','#c8c0ff'),('tadakatsu','忠勝','#ff7862')]
for i,(a,name,c) in enumerate(actors):
 im=Image.new('RGB',(1280,720),'#111826');d=ImageDraw.Draw(im)
 d.rectangle((64,60,72,615),fill=c);d.text((102,66),'吞食戰國  /  必殺音效試聽',font=f(32),fill='#aab9d0')
 d.text((100,128),f'{i+1:02d}  {name}',font=f(64),fill=c);d.text((100,225),m['actors'][a]['text'],font=f(52),fill='white')
 d.text((104,310),'既有日文原音 remaster ＋ 原創分層 SFX',font=f(26),fill='#d0d7e1')
 if a in ['hideyoshi','ieyasu']:
  new=m['actors'][a]['new_authoring_name_unvoiced'];d.text((104,358),f'LEGACY 舊招名｜新「{new}」日文配音待製作',font=f(27),fill='#f5c66f')
 else:d.text((104,358),'保留既有台詞與角色聲線；沒有重新配音',font=f(27),fill='#97a9c0')
 sr,x=wavfile.read(r/'wav'/f'{a}_preview.wav');x=x.astype(float)/32768
 for j,chunk in enumerate(np.array_split(x,1050)):
  h=int(max(abs(chunk))*95);d.line((105+j,505-h,105+j,505+h),fill=c,width=1)
 d.text((104,608),'數值檢查通過｜未經人工聽感驗收｜請以實際試聽判斷',font=f(25),fill='#b8c3d6')
 im.save(p/f'{a}.png')
 subprocess.run(['ffmpeg','-v','error','-y','-loop','1','-i',str(p/f'{a}.png'),'-i',str(r/'wav'/f'{a}_preview.wav'),'-t','4.5','-r','24','-c:v','libx264','-preset','fast','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k',str(p/f'{a}.mp4')],check=True)
(p/'concat.txt').write_text(''.join(f"file '{a}.mp4'\n" for a,_,_ in actors))
subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(p/'concat.txt'),'-c','copy','-movflags','+faststart',str(p/'Sengoku_Japanese_Special_Audio_Preview.mp4')],check=True)
