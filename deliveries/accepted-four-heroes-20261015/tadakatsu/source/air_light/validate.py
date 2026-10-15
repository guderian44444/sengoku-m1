from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,math
ROOT=Path(__file__).resolve().parent
m=json.loads((ROOT/'metadata.json').read_text());fm=json.loads((ROOT/'frames-manifest.json').read_text())
rows=[];hashes=[]
for i,r in enumerate(m['frames']):
 a=np.array(Image.open(ROOT/'character'/f'{i:02}.png'));rr,gg,bb,aa=np.moveaxis(a.astype('int16'),2,0);ys,xs=np.where(aa>100)
 pink=(rr>100)&(bb>80)&(rr-gg>50)&(bb-gg>50)&(aa>80);assert not pink.any(),(i,int(pink.sum()))
 c=np.array(Image.open(ROOT/'composite'/f'{i:02}.png'))[:,:,3]>100;edge=int(c[0].sum()+c[-1].sum()+c[:,0].sum()+c[:,-1].sum());assert edge==0
 tip=r['weapon_tip_canvas'];butt=r['weapon_butt_canvas'];length=math.dist(tip,butt);assert abs(length-285)<1e-6;assert tip[0]>max(h[0]for h in r['hands_canvas']) and tip[0]>butt[0]
 assert ys.max()<296
 hashes.append(hashlib.sha256(a.tobytes()).hexdigest());rows.append({'frame':i+1,'character_bbox':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'ground_clearance':int(296-ys.max()),'edge_pixels':edge,'magenta_pixels':int(pink.sum()),'weapon_length_px':round(length,5),'forward_tip':True,'hands_axis_error':abs((r['hands_canvas'][1][0]-r['hands_canvas'][0][0])*(tip[1]-butt[1])-(r['hands_canvas'][1][1]-r['hands_canvas'][0][1])*(tip[0]-butt[0]))/length})
 for v in [fm['frames'][i]['src'],*fm['frames'][i]['layers'].values()]:assert (ROOT/v).exists(),v
assert len(set(hashes))==12
im=Image.open(ROOT/'normal.gif');dur=[]
for i in range(im.n_frames):im.seek(i);dur.append(im.info.get('duration'))
assert im.n_frames==12 and sum(dur)==720
slow=Image.open(ROOT/'slow.gif');sd=[]
for i in range(slow.n_frames):slow.seek(i);sd.append(slow.info.get('duration'))
assert sum(sd)==2160
q={'status':'self-check complete; awaiting parent independent visual review before Library upload','twelve_unique_cloud_drawn_character_poses':True,'frame_count':12,'duration_ms':sum(dur),'durations_ms':dur,'canvas':[640,340],'website_manifest':'frames-manifest.json','all_manifest_targets_exist':True,'frames':rows,'visual_review':['Inspected both six-pose cloud source sheets and twelve-frame contact sheet.','Component-specific extraction retains full capes, antlers, hands and feet with no neighboring sprite fragments. Source bounding boxes may overlap, but actual alpha components are independent.','All poses face right; near right hand remains rear grip, far left hand remains forward grip. No back-facing coil or sweep.','Shoulder/elbow extension reaches forward at frame7, then returns to guard while descending.','Both sheets use one identical fixed .43 scale, matched against original character helmet/chest reference.','Spear remains full285px with no longitudinal shortening; all blade tips are to the right of both hands.','Airborne root rises then descends smoothly; each foot stays above floor296.'],'limitations':['Only static source/contact sheets and selected stills visually reviewed; GIF frame timing and order decoded. Live playback was not independently watched.','No opponent collision, range/damage, or game runtime verification.','Whole-body PNG layers are not per-limb articulated rigs.']}
(ROOT/'QA.json').write_text(json.dumps(q,indent=2));print(json.dumps({'frames':12,'ms':sum(dur),'unique':len(set(hashes)),'all_forward':True,'feet':[r['character_bbox'][3]-1 for r in rows],'manifest_ok':True}))
