from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
P=Path(__file__).parent;F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
for side in ['near','far']:
 im=Image.new('RGB',(768,1024),'white');d=ImageDraw.Draw(im);d.text((15,12),'TRUE PASSING: swing shoe moves UNDER BODY, beside support calf',fill='black',font=F);d.text((15,38),'Narrow silhouette. NOT split stride. NOT rear folded heel.',fill='black',font=F)
 d.ellipse((385,90,510,230),outline='#777777',width=9);d.polygon([(310,265),(510,275),(440,520),(350,520)],outline='#777777',width=9);d.line([(310,295),(295,420),(405,470)],fill='#777777',width=22);d.line([(510,295),(520,420),(435,470)],fill='#777777',width=22);d.line([(365,520),(425,520)],fill='black',width=10)
 near=[(365,520),(430,730),(420,850),(475,880)] if side=='near' else [(365,520),(380,760),(390,960),(450,980)]
 far=[(425,520),(410,760),(390,960),(450,980)] if side=='near' else [(425,520),(450,730),(440,850),(495,880)]
 for pts,col in [(far,'#1854b8'),(near,'#c6252f')]:
  d.line(pts,fill=col,width=36,joint='curve')
  for x,y in pts[:3]:d.ellipse((x-23,y-23,x+23,y+23),fill=col,outline='black',width=2)
 d.line((350,989,520,989),fill='gray',width=2);d.text((35,600),'Knees stay BELOW hips',fill='black',font=F);d.text((35,627),'Swing shoe beside calf',fill='black',font=F);d.text((15,995),'RED near/right, BLUE far/left. Only '+side.upper()+' leg swings.',fill='black',font=F);im.save(P/('true_passing_'+side+'.png'))
