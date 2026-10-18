from pathlib import Path
from PIL import Image
import json,hashlib,numpy as np,zipfile,shutil
B=Path(__file__).parent;m=json.loads((B/'metadata.json').read_text());cfg=json.loads((B/'config.json').read_text());ph=['near_heel_contact','near_weight_accept','far_passing','far_reach','far_heel_contact','far_weight_accept','near_passing','near_reach'];supports=['both','near','near','near','both','far','far','far']
m.update(revision='walk_v11_frame3_hand_correction',status='candidate_parent_visual_review_pass_pending_user',not_user_approved=True,excluded_versions={'walk_v6':'user rejected: short shuffling steps and fixed upper body','walk_v9':'independent visual QA failed: contact leg identity unreliable'},source_rule='Original approved full resolution identity directly referenced; no small rendered frame regeneration; no optical flow',visual_identity_check='Near-contact frame1 broad near skirt plate and thigh cross in front of central cloth/far thigh; frame5 far contact preserves opposite overlap; 7->8->1 preserves near forward swing',world_motion={'mode':'in_place','driver':'runtime_controller','preview_not_baked_into_world':True},reference_paths=['../source/idle-body.png','../walk_v9/source/near-pass.png'],source_manifest={})
for i,r in enumerate(m['frames']):
 r.update(phase=ph[i],events=[ph[i]]+(['loop_start'] if i==0 else ['loop_end_to_1'] if i==7 else []),feet_source={'near':cfg[i]['feet'][0],'far':cfg[i]['feet'][1]},feet_preview={'near':r['feet_preview'][0],'far':r['feet_preview'][1]},support_foot=supports[i],grounded=True,root_source=[cfg[i].get('root_x',550),cfg[i]['support_y']],root_canvas=[286,325],world_displacement=[0,0],preview_displacement=[0,0],next_frame=(i+1)%8+1,fx=None,layer_files={k:f'{k}_{i+1:02}.png' for k in ['body','weapon','hand_occlusion']})
 p=B/r['source'];im=Image.open(p);a=np.array(im)[:,:,3];y,x=np.where(a>128);m['source_manifest'][r['source']]=dict(sha256=hashlib.sha256(p.read_bytes()).hexdigest(),native_canvas=list(im.size),effective_figure_bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)],effective_figure_height=int(y.max()-y.min()+1),final_resample_count=1)
 layers={k:Image.open(B/f'{k}_{i+1:02}.png') for k in ['body','weapon','hand_occlusion']};comp=Image.new('RGBA',(640,380))
 for k in r['layer_order']:comp.alpha_composite(layers[k])
 assert np.array_equal(np.array(comp),np.array(Image.open(B/f'composite_{i+1:02}.png')))
 for k,im in layers.items():
  a=np.array(im)[:,:,3];assert max(a[0,:].max(),a[-1,:].max(),a[:,0].max(),a[:,-1].max())==0
m['frames'][7]['support_plane_note']=cfg[7]['ground_plane_note']
(B/'metadata.json').write_text(json.dumps(m,indent=2));(B/'QA.json').write_text(json.dumps(dict(visual_review='parent and independent reviewer: candidate pass, pending user',frame_count=8,total_ms=880,full_left_right_cycle='near/far thighs and skirt occlusion explicitly opposed in contact frames1/5',original_effective_heights=[r['source_effective_height_px'] for r in m['frames']],ruler=163,scale=163/1420,no_bbox_normalization=True,no_fx=True,layer_recompose_exact=True,transparent_boundaries=True),indent=2))
(B/'README.txt').write_text('Kennyo walk_v11 candidate. New near-contact/load/reach sources use explicit foreground crossing; old v6 user rejection and v9 QA failure remain retained, not overwritten. 8 frames,880ms,163px standing ruler. Three transparent layers and native originals preserved. Normal/slow/idle comparison GIFs repeat for review. Runtime world displacement remains zero, engine controller owns locomotion. metadata.json records timing, near/far foot identity, support, root, grips, weapon angle, events and source resolution/hash. Only source files selected by config.json are active; earlier attempts are preserved for provenance.\n')
for src,dst in [('kennyo03-walk.gif','kennyo03-walk-v11.gif'),('idle-walk-comparison.gif','kennyo03-walk-v11-idle-review.gif'),('contact-leg-identity-native.png','kennyo03-walk-v11-leg-identity.png')]:shutil.copy(B/src,B/dst)
files=[p for p in B.rglob('*') if p.is_file() and p.suffix!='.zip'];zpath=B/'kennyo03-walk-v11-complete.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED,6) as z:
 for p in files:z.write(p,Path('walk_v11')/p.relative_to(B))
with zipfile.ZipFile(zpath) as z:assert z.testzip() is None
print(zpath,zpath.stat().st_size,hashlib.sha256(zpath.read_bytes()).hexdigest())
