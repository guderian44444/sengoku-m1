from playwright.sync_api import sync_playwright
from pathlib import Path
from PIL import Image
R=Path(__file__).parent.resolve();names=['grab_start','grab_hold','grab_hit_1','grab_hit_2','throw_forward','throw_reverse']
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);page=b.new_page(viewport={'width':800,'height':420})
 for n in names:
  page.set_content('<style>body{margin:0;background:#2d323c}</style><img src="file://'+str(R/n/'normal.gif')+'">')
  page.goto('file://'+str(R/n/'normal.gif'));shots=[]
  for i in range(8):
   page.wait_for_timeout(100);f=R/n/f'playback_{i:02}.png';page.screenshot(path=str(f));shots.append(Image.open(f).convert('RGB'))
  out=Image.new('RGB',(1600,840));
  for i,im in enumerate(shots):out.paste(im.resize((400,420)),((i%4)*400,(i//4)*420))
  out.save(R/n/'normal_playback.jpg')
 b.close()
print('Browser normal-speed captures complete')
