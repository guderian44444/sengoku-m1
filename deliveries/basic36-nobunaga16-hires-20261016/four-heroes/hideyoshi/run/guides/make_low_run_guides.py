from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
P=Path(__file__).parent;F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
def single(name,near,far,title):
 im=Image.new('RGB',(768,1024),'white');d=ImageDraw.Draw(im);d.text((15,15),title,fill='black',font=F);d.text((15,43),'LOW knee arc, narrow parallel leg tracks. Torso faces RIGHT.',fill='black',font=F)
 d.ellipse((400,105,520,245),outline='#777777',width=8);d.polygon([(330,280),(510,290),(442,520),(350,520)],outline='#777777',width=8);d.line([(330,305),(310,425),(405,470)],fill='#777777',width=20);d.line([(510,305),(530,430),(435,470)],fill='#777777',width=20);d.line([(365,520),(425,520)],fill='black',width=10)
 for pts,col in [(far,'#1854b8'),(near,'#c6252f')]:
  d.line(pts,fill=col,width=36,joint='curve')
  for x,y in pts[:3]:d.ellipse((x-24,y-24,x+24,y+24),fill=col,outline='black',width=2)
 d.text((12,995),'RED near right / BLUE far left. No actual colored marks.',fill='black',font=F);im.save(P/name)
single('low_passing_near.png',[(365,520),(480,700),(510,850),(555,875)],[(425,520),(385,750),(355,960),(410,980)],'NEAR right leg swings LOW ahead / FAR left foot supports')
single('low_passing_far.png',[(365,520),(350,750),(335,960),(390,980)],[(425,520),(500,700),(520,850),(570,875)],'FAR left leg swings LOW ahead / NEAR right foot supports')
single('low_flight_near.png',[(365,520),(500,745),(575,915),(635,940)],[(425,520),(300,765),(220,760),(185,800)],'SHORT flight: NEAR right forward / FAR left folds behind')
single('low_flight_far.png',[(365,520),(260,765),(180,760),(145,800)],[(425,520),(560,745),(635,915),(695,940)],'SHORT flight: FAR left forward / NEAR right folds behind')
a=Image.open(P/'low_flight_near.png');b=Image.open(P/'low_flight_far.png');out=Image.new('RGB',(1536,1024),'white');out.paste(a,(0,0));out.paste(b,(768,0));out.save(P/'low_opposite_flight.png')
