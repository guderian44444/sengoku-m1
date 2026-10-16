from pathlib import Path
from PIL import Image
import numpy as np,math,json,ast
R=Path('nobunaga_impact_v4');O=Path('nobunaga_final_approved');BG=(37,39,43);template_path=R/'charge_ready_hires/source/shortened-blade.png';template=Image.open(template_path).convert('RGBA')
def metrics(a,b):
 d=np.abs(np.array(a.convert('RGB')).astype('int16')-np.array(b.convert('RGB')).astype('int16'));return dict(pixel_exact=not bool(d.max()),max_channel_difference=int(d.max()),mean_absolute_channel_difference=round(float(d.mean()),8),different_pixel_count=int(np.any(d,2).sum()),compared_pixel_count=d.shape[0]*d.shape[1])
def matrix(sc,base,tip,pos):
 bp=np.array(base)*sc+pos;ang=math.atan2(base[1]-tip[1],tip[0]-base[0])-math.atan2(29,441);c,s=math.cos(ang),math.sin(ang);return [c/sc,-s/sc,(-c*bp[0]+s*bp[1])/sc,s/sc,c/sc,49+(-s*bp[0]-c*bp[1])/sc]
bps=[((568,517),(418,96)),((697,440),(691,47)),((687,414),(936,37)),((738,456),(1080,79)),((748,529),(1168,206)),((734,571),(1189,304)),((720,579),(1206,429)),((720,637),(1211,577))]
p=O/'grab_start/source-mapping.json';x=json.load(open(p))
for i,r in enumerate(x['frames'][:8]):
 tr=r['source_to_review'];r['approved_layer_render_recipe']={'body_rgba':r['layers']['body'],'body_scale':tr['scale'],'body_offset':tr['offset'],'body_resampling':'LANCZOS','weapon_template':str(template_path),'weapon_base_native':list(bps[i][0]),'weapon_tip_native':list(bps[i][1]),'weapon_template_to_review_inverse_affine':matrix(tr['scale'],*bps[i],np.array(tr['unrounded_position'])),'weapon_resampling':'BICUBIC','layer_order':['body','weapon'],'output_canvas':[1440,1200]}
p.write_text(json.dumps(x,indent=2));p=O/'throw_forward/source-mapping.json';f=json.load(open(p))
for i in range(9,19):
 j=18-i
 if 'approved_layer_render_recipe' in x['frames'][j]:f['frames'][i]['approved_layer_render_recipe']=x['frames'][j]['approved_layer_render_recipe'];f['frames'][i]['exact_approved_recipe_reconstruction_vs_review']=x['frames'][j]['exact_approved_recipe_reconstruction_vs_review']
p.write_text(json.dumps(f,indent=2))
# Charge-ready/hold layer recipes use existing native body donor composites, no regeneration.
env={};tree=ast.parse((R/'charge_ready_squat_v2/build_preview.py').read_text())
for node in tree.body:
 if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ['blades'] for t in node.targets):exec(compile(ast.Module(body=[node],type_ignores=[]),'ready','exec'),env)
readyrows=json.load(open(R/'charge_ready_squat_v2/frame-manifest.json'))
for k in ['charge_ready','charge_hold']:
 d=R/('charge_ready_squat_v2' if k=='charge_ready' else 'charge_hold_squat');p=O/k/'source-mapping.json';x=json.load(open(p))
 for i,r in enumerate(x['frames']):
  if k=='charge_ready':
   row=readyrows[i];camera=row['uniform_camera_registration'];scale=.58*camera;front=row['lower_sole_front'];off=[round(630-front[0]*scale),round(1020-front[1]*scale)];us=row['upper_layer_scale'];dx,dy=row['upper_layer_translation'];base=[env['blades'][i][0][0]*us+dx,env['blades'][i][0][1]*us+dy];tip=env['blades'][i][1];bp=[base[0]*scale+off[0],base[1]*scale+off[1]];ang=math.atan2(env['blades'][i][0][1]-tip[1],tip[0]-env['blades'][i][0][0])-math.atan2(29,441)
  else:scale=.58;off=[round(630-1017*scale),round(1020-962*scale)];bp=[773*scale+off[0],670*scale+off[1]];ang=math.atan2(36,474)-math.atan2(29,441)
  c,s=math.cos(ang),math.sin(ang);sc=.58;tr=[c/sc,-s/sc,(-c*bp[0]+s*bp[1])/sc,s/sc,c/sc,49+(-s*bp[0]-c*bp[1])/sc];body_path=d/f'layers/body-{i:03}.png';body=Image.open(body_path).convert('RGB');out=Image.new('RGBA',(1440,1200),BG+(255,));out.paste(body.resize((round(body.width*scale),round(body.height*scale)),Image.Resampling.LANCZOS),off);out.alpha_composite(template.transform(out.size,Image.Transform.AFFINE,tr,Image.Resampling.BICUBIC));target=Image.open(d/f'frames-review/{i:03}.png')
  r['approved_layer_render_recipe']={'body_rgb':str(body_path),'body_scale':scale,'body_offset':off,'body_resampling':'LANCZOS','weapon_template':str(template_path),'weapon_template_to_review_inverse_affine':tr,'weapon_resampling':'BICUBIC','layer_order':['body','weapon'],'output_canvas':[1440,1200],'background_rgb':BG};r['exact_approved_recipe_reconstruction_vs_review']=metrics(out,target)
 p.write_text(json.dumps(x,indent=2));print(k,sum(r['exact_approved_recipe_reconstruction_vs_review']['pixel_exact'] for r in x['frames']),len(x['frames']))
