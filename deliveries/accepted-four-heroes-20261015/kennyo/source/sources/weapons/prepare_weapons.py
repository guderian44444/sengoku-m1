from PIL import Image
import numpy as np, json, hashlib
from pathlib import Path
D=Path(__file__).parent
src=D/'weapons-source.png'; im=Image.open(src).convert('RGBA'); a=np.array(im)[:,:,3]
meta={'source':str(src),'source_size':im.size,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'provenance':'Built-in image_gen transparent RGBA, then only crop, uniform scale, and registration; no local synthesis.','reference_body_standing_height_px':160,'coordinate_system':'top-left pixels; weapon_angle 0 means up, clockwise positive','weapons':{}}
for name,x0,x1,length in [('long_staff',100,300,190),('ornate_shakujo',360,640,215),('approved03_naginata',700,950,230)]:
    part=im.crop((x0,0,x1,im.height)); ar=np.array(part)[:,:,3]; ys,xs=np.where(ar>16); box=(int(xs.min()+x0),int(ys.min()),int(xs.max()+x0+1),int(ys.max()+1)); crop=im.crop(box); crop.save(D/(name+'-source.png'))
    p=np.array(crop); ah=p[:,:,3]; yy=int(crop.height*.74); cols=np.where(ah[yy]>64)[0]; axis=float((cols.min()+cols.max())/2)
    scale=length/(crop.height-1); sz=(round(crop.width*scale),round(crop.height*scale)); small=crop.resize(sz,Image.Resampling.LANCZOS)
    out=Image.new('RGBA',(128,256)); px=round(64-axis*scale);py=246-sz[1]+1;out.alpha_composite(small,(px,py));out.save(D/(name+'.png'))
    meta['weapons'][name]={'source_crop':box,'source_size':crop.size,'source_axis_x':axis,'source_tip':[axis,0],'source_butt':[axis,crop.height-1],'game_file':str(D/(name+'.png')),'game_canvas':[128,256],'scale':scale,'physical_length_px':length,'physical_length_body_ratio':length/160,'tip_axis':[64,246-length],'butt':[64,246],'main_grip':[64,178],'aux_grip':[64,142],'tail_grip':[64,234],'sha256':hashlib.sha256((D/(name+'.png')).read_bytes()).hexdigest(),'alpha_range':list(out.getchannel('A').getextrema())}
(D/'weapons-metadata.json').write_text(json.dumps(meta,indent=2))
print(json.dumps(meta,indent=2))
