from PIL import Image,ImageDraw
from pathlib import Path
import json,hashlib,math
P=Path(__file__).parent
CFG={
'grab_start':dict(src='grab_start_clean.png',grid=(3,2),ruler=490,roots=[(280,500),(280,500),(280,500),(280,495),(280,495),(280,495)],hands=[(256,212),(110,226),(462,143),(482,110),(330,160),(370,145)],dur=[110,110,90,80,110,180],events={1:['bow_stowed'],3:['grab_attach'],4:['pull_close'] }),
'grab_hold':dict(src='grab_hold.png',grid=(3,1),ruler=680,roots=[(400,690)]*3,hands=[(600,215)]*3,dur=[240,240,240],events={0:['hold_loop_start']}),
}
def run(name,c):
 im=Image.open(P/c['src']).convert('RGBA');w,h=im.size;cols,rows=c['grid'];cw,ch=w//cols,h//rows;s=148/c['ruler'];d=P/name;d.mkdir(exist_ok=True);frames=[];records=[]
 bow=Image.open(P/'bow_azusa.png').convert('RGBA');bow.thumbnail((44,133));bow=bow.rotate(18,expand=True,resample=Image.Resampling.BICUBIC)
 for i,(root,hand,ms) in enumerate(zip(c['roots'],c['hands'],c['dur'])):
  x,y=i%cols*cw,i//cols*ch;crop=im.crop((x,y,x+cw,y+ch));crop.save(d/f'body_{i:02}.png');pose=crop.resize((round(cw*s),round(ch*s)),Image.Resampling.LANCZOS);off=(round(155-root[0]*s),round(194-root[1]*s));contact=(round(off[0]+hand[0]*s),round(off[1]+hand[1]*s));canvas=Image.new('RGBA',(400,240),'#313845')
  # Independent neutral preview victim. Never baked into body PNG.
  victim=Image.new('RGBA',canvas.size);v=ImageDraw.Draw(victim);vx=max(contact[0]+15,220);vy=116
  if name=='grab_start' and i<3:vx=250
  v.ellipse((vx-9,vy-46,vx+9,vy-28),fill='#8293a6');v.line([(vx,vy-24),(vx,vy+23)],fill='#8293a6',width=18);v.line([(vx,vy-18),contact],fill='#a6b5c6',width=9);v.line([(vx,vy+22),(vx-12,193)],fill='#8293a6',width=10);v.line([(vx,vy+22),(vx+17,193)],fill='#8293a6',width=10)
  if name.startswith('throw'):
   victim=Image.new('RGBA',canvas.size);tile=Image.new('RGBA',(70,130));td=ImageDraw.Draw(tile);td.ellipse((26,2,44,20),fill='#8293a6');td.line([(35,25),(35,72)],fill='#8293a6',width=18);td.line([(35,32),(10,49)],fill='#a6b5c6',width=9);td.line([(35,70),(17,122)],fill='#8293a6',width=10);td.line([(35,70),(54,122)],fill='#8293a6',width=10)
   reverse=name.endswith('reverse');angles=[0,10,65,100,150,200,250,270];positions=[(230,133),(211,129),(190,108),(177,89),(214,79),(264,92),(310,130),(330,178)]
   if reverse:angles=[0,-25,-70,-110,-155,-210,-250,-270];positions=[(220,133),(199,119),(174,86),(151,66),(114,70),(80,97),(51,135),(48,179)]
   tile=tile.rotate(angles[i],expand=True,resample=Image.Resampling.BICUBIC);px,py=positions[i];victim.alpha_composite(tile,(round(px-tile.width/2),round(py-tile.height/2)))
  victim.save(d/f'victim_preview_{i:02}.png');canvas.alpha_composite(victim);canvas.alpha_composite(bow,(off[0]+round(170*s),off[1]+round(100*s)));canvas.alpha_composite(pose,off);dr=ImageDraw.Draw(canvas);dr.text((10,8),name+' | 148px | timing prototype',fill='white');dr.text((10,220),'Neutral victim = preview stand-in; separate layers',fill='#bdc8d8');frames.append(canvas.convert('RGB'))
  records.append(dict(frame=i,source_rect=[x,y,cw,ch],root=list(root),body_height=c['ruler'],grab_contact=list(hand),grip=None,stow_anchor=[170,100],weapon_angle=18,weapon_behind=True,second_hand=None,duration_ms=ms,events=c['events'].get(i,[]),measurement_status='preview visually authored anchors; runtime registration pending'))
 frames[0].save(P/(name+'_148px.gif'),save_all=True,append_images=frames[1:],duration=c['dur'],loop=0,disposal=2)
 meta=dict(clip=name,prototype=True,runtime_modified=False,source=c['src'],sha256=hashlib.sha256((P/c['src']).read_bytes()).hexdigest(),coordinate_space='cell_pixels',body_height_target=148,frames=records,layer_order=['victim_preview','stowed_bow','body'],victim_note='Neutral silhouette is only a preview stand-in. Release and landing belong to victim layer.',alpha_zero_fraction=sum(a==0 for a in im.getchannel('A').getdata())/(w*h));(P/(name+'.json')).write_text(json.dumps(meta,indent=2))
CFG['grab_hit_1']=dict(src='grab_hit_1.png',grid=(2,2),ruler=490,roots=[(460,500),(225,500),(340,495),(450,495)],hands=[(665,155),(445,155),(700,110),(510,145)],dur=[100,90,70,160],events={2:['knee_contact_1'],3:['return_hold']})
CFG['grab_hit_2']=dict(src='grab_hit_2.png',grid=(2,2),ruler=490,roots=[(450,490),(250,490),(410,490),(360,490)],hands=[(680,125),(495,125),(660,110),(590,130)],dur=[90,90,80,180],events={2:['knee_contact_2'],3:['turn_hip_prepare']})
CFG['throw_forward']=dict(src='throw_forward.png',grid=(4,2),ruler=490,roots=[(210,480),(230,480),(220,480),(210,480),(210,480),(200,480),(210,480),(220,480)],hands=[(355,140),(310,190),(335,160),(325,220),(380,125),(380,125),(325,220),(350,170)],dur=[100,100,110,100,80,80,120,210],events={0:['grab_attached'],2:['hip_pivot'],3:['victim_loaded'],5:['throw_release'],7:['victim_land','recovery_end']})
CFG['throw_reverse']=dict(src='throw_reverse_v2.png',grid=(4,2),ruler=490,roots=[(210,480),(230,480),(220,480),(210,480),(210,480),(200,480),(210,480),(220,480)],hands=[(330,300),(350,250),(235,30),(165,30),(60,65),(30,160),(60,200),(150,160)],dur=[100,110,120,120,90,80,130,210],events={0:['grab_attached'],1:['reverse_pivot'],2:['victim_on_shoulder'],3:['over_shoulder'],5:['throw_release'],7:['victim_land','recovery_end']})
if __name__=='__main__':
 import sys
 for n in sys.argv[1:] or CFG:run(n,CFG[n])
