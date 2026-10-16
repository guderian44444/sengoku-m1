from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
P=Path(__file__).parent;F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
for side in ['near','far']:
 im=Image.new('RGB',(768,1024),'white');d=ImageDraw.Draw(im)
 d.text((15,12),'RUN PASSING / consistent forward torso lean, 3-4 side view',fill='black',font=F)
 d.ellipse((460,80,585,240),outline='#777777',width=9)
 d.polygon([(385,285),(550,300),(440,590),(350,590)],outline='#777777',width=9)
 d.line([(385,310),(350,435),(445,505)],fill='#777777',width=22);d.line([(550,325),(555,440),(480,505)],fill='#777777',width=22)
 d.line([(365,590),(425,590)],fill='black',width=10)
 near=[(365,590),(470,760),(490,875),(555,900)] if side=='near' else [(365,590),(380,790),(390,960),(450,980)]
 far=[(425,590),(410,790),(390,960),(450,980)] if side=='near' else [(425,590),(485,760),(500,875),(565,900)]
 for pts,col in [(far,'#1854b8'),(near,'#c6252f')]:
  d.line(pts,fill=col,width=36,joint='curve')
  for x,y in pts[:3]:d.ellipse((x-23,y-23,x+23,y+23),fill=col,outline='black',width=2)
 d.line((350,989,520,989),fill='gray',width=2)
 d.text((20,660),'Knees stay low',fill='black',font=F);d.text((20,690),'Swing shoe moves',fill='black',font=F);d.text((20,720),'UNDER hips to calf',fill='black',font=F)
 d.text((15,995),'RED near/right, BLUE far/left. '+side.upper()+' leg swings.',fill='black',font=F)
 im.save(P/('forward_passing_'+side+'.png'))
