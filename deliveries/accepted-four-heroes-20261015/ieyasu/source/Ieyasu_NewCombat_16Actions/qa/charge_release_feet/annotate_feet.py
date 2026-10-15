from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,math
P=Path(__file__).resolve().parents[2];D=P/'actions/charge_release';Q=Path(__file__).parent
# Manual visual estimates on native 560x400 frames; sole center, not a toe/heel contact landmark.
lf=[(205,363),(205,362),(208,365),(126,353),(126,357),(120,358),(118,359),(128,365),(118,365),(121,367),(126,366),(108,361),(205,364),(205,363),(205,361),(197,361),(205,363)]
rf=[(279,356),(277,352),(256,357),(202,361),(205,364),(203,362),(202,360),(197,357),(205,361),(196,361),(193,360),(195,365),(283,361),(280,362),(276,362),(266,362),(279,356)]
lk=[(218,326),(214,324),(218,326),(135,326),(131,327),(128,326),(128,329),(132,334),(127,330),(129,331),(135,332),(121,329),(222,330),(216,329),(215,331),(210,330),(218,326)]
rk=[(270,327),(265,321),(252,331),(192,326),(191,328),(191,328),(185,329),(182,332),(190,332),(182,333),(183,334),(182,332),(274,332),(270,332),(267,332),(258,333),(270,327)]
rows=[];sheet=Image.new('RGB',(2400,300*5),(43,50,60));before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in D.glob('*.png')}
for i in range(17):
 # Back-facing silhouettes: anatomical right projects screen-right. Transitional left profiles uncertain.
 rs='left' if i<=2 or i>=11 else 'right';unc=i in [3,7,8,9,10];R=lf[i] if rs=='left' else rf[i];L=rf[i] if rs=='left' else lf[i];RK=lk[i] if rs=='left' else rk[i];LK=rk[i] if rs=='left' else lk[i]
 r={'frame_1based':i+1,'right_foot_sole_center':R,'left_foot_sole_center':L,'right_knee_approx':RK,'left_knee_approx':LK,'screen_left_foot':lf[i],'screen_right_foot':rf[i],'anatomical_right_screen_side':rs,'anatomical_assignment':'inferred: torso/hip orientation and previous frame; legs partly obscured by skirt' if unc else 'visual torso/leg correspondence, not 3D-ground-truth','assignment_confidence':'low' if i in [8,9,10] else ('medium' if unc else 'medium-high'),'nominal_pivot':[205,365],'right_sole_center_distance_to_nominal_pivot':round(math.dist(R,(205,365)),1),'measurement_uncertainty_px':3,'note':'sole center is not identical to contact pivot; small offsets do not prove slipping'};rows.append(r)
 im=Image.open(D/f'body_canvas_{i:02}.png').convert('RGBA');bg=Image.new('RGBA',im.size,(43,50,60));bg.alpha_composite(im);tile=Image.new('RGB',(600,300),(43,50,60));crop=bg.crop((70,285,340,385)).resize((540,200));tile.paste(crop.convert('RGB'),(30,65));dr=ImageDraw.Draw(tile)
 def xy(p):return (30+(p[0]-70)*2,65+(p[1]-285)*2)
 for label,p,col in [('R',R,(255,100,90)),('L',L,(70,210,255)),('RK',RK,(255,100,90)),('LK',LK,(70,210,255))]:
  x,y=xy(p);dr.ellipse((x-4,y-4,x+4,y+4),fill=col);dr.text((x+5,y-12),label,fill=col)
 x,y=xy((205,365));dr.line((x-7,y,x+7,y),fill='yellow',width=2);dr.line((x,y-7,x,y+7),fill='yellow',width=2)
 dr.text((10,8),f'{i+1:02} R {R} / L {L}',fill='white');dr.text((10,25),'ANATOMY INFERRED' if unc else 'visual anatomy estimate',fill=(255,190,100));dr.text((10,42),'Yellow cross = required pivot (205,365)',fill='yellow');sheet.paste(tile,((i%4)*600,(i//4)*300))
json.dump({'action':'charge_release','read_only_source_review':True,'native_canvas':[560,400],'coordinate_origin':'top-left','method':'manual visual sole-center and knee estimates from enlarged native raster; +/-3px; no metadata yaw used as visual truth','source_png_sha256':before,'frames':rows,'major_pairs_1based':[[3,4],[11,12],[12,13]],'limitations':['anatomical mapping uncertain for 9-11 due hip/torso rotation ambiguity','foot sole center is not a physical contact point','static frame review, no realtime playback claim']},open(Q/'feet_knees.json','w'),indent=2)
sheet.save(Q/'feet_knees_contact.jpg',quality=95)
after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in D.glob('*.png')};assert before==after
for a,b in [(3,4),(7,8),(11,12),(12,13)]:
 x,y=rows[a-1],rows[b-1];print(a,b,'right',x['right_foot_sole_center'],y['right_foot_sole_center'],'left',x['left_foot_sole_center'],y['left_foot_sole_center'])
print('source PNGs unchanged',len(before))
