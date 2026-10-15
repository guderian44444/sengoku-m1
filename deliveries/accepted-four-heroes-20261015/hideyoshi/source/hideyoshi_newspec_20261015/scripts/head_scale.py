from PIL import Image,ImageDraw
import numpy as np
HEADS={
'air_light':[(101,11,175,114),(421,52,490,151),(712,5,791,111),(969,4,1040,112),(146,394,220,494),(420,398,492,500),(694,436,768,539),(101,11,175,114)],
'air_heavy':[(139,27,203,127),(436,73,503,173),(688,58,759,150),(969,58,1038,150),(139,403,210,503),(421,455,491,560),(704,431,776,535),(139,27,203,127)],
'dash_heavy':[(211,57,294,144),(451,58,538,153),(692,34,780,137),(1003,45,1088,147),(167,402,247,502),(432,405,518,511),(695,374,781,480),(211,57,294,144)],

'light_3':[(101,9,169,111),(388,15,452,118),(651,12,722,112),(970,13,1043,115),(193,398,264,483),(463,405,532,498),(723,397,793,496),(101,9,169,111)],
'light_1':[(108,24,190,110),(424,50,486,116),(690,46,772,138),(987,65,1058,150),(184,416,269,514),(463,429,550,520),(692,402,777,497),(108,24,190,110)],
'heavy':[(103,17,177,104),(387,31,469,124),(714,67,792,160),(981,37,1061,125),(117,407,190,494),(391,402,463,489),(703,402,779,493),(103,17,177,104)],
'light_2':[(108,4,170,99),(390,10,458,105),(706,18,779,111),(1005,14,1077,109),(144,397,215,484),(405,391,473,480),(706,394,781,495),(108,4,170,99)]}
def shrink_head(body,source_box,rect,fx,fy,scale=.95):
 x0,y0,x1,y1=rect;x0=round(x0*fx-source_box[0]);x1=round(x1*fx-source_box[0]);y0=round(y0*fy-source_box[1]);y1=round(y1*fy-source_box[1]);x0=max(0,x0);y0=max(0,y0);x1=min(body.width,x1);y1=min(body.height,y1)
 if x1<=x0 or y1<=y0:return body
 p=body.crop((x0,y0,x1,y1));w,h=p.size;nw,nh=round(w*scale),round(h*scale);q=p.resize((nw,nh),Image.Resampling.LANCZOS);edited=body.copy();edited.paste((0,0,0,0),(x0,y0,x1,y1));edited.alpha_composite(q,(x0+(w-nw)//2,y1-nh))
 # retain 4px neckline transition, not shoulder/arm or full torso
 blend=Image.new('L',body.size,255);d=ImageDraw.Draw(blend)
 for k in range(min(5,h)):
  d.line((x0,y1-1-k,x1-1,y1-1-k),fill=round(k/5*255))
 return Image.composite(edited,body,blend)
