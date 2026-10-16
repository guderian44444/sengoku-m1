from pathlib import Path
from PIL import Image
import numpy as np,json,ast,math,hashlib
O=Path(__file__).resolve().parents[1];R=O.parent/'nobunaga_impact_v4';d=O/'charge_release';m=json.load(open(d/'layers-visible-manifest.json'));env={}
for n in ast.parse((R/'charge_release_hires_range150/build_preview.py').read_text()).body:
 if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ['DUR','YAWS','keys','CONF'] for t in n.targets):exec(compile(ast.Module(body=[n],type_ignores=[]),'recipe','exec'),env)
for i,r in enumerate(m):
 hm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-hand.png'))>0;yy,xx=np.nonzero(hm);r['grip_art_px']=[round(float(xx.mean()),2),round(float(yy.mean()),2)] if len(xx) else None;r['grip_measurement']='advisory visible hand-mask centroid; not authored weapon socket';r['native_layer_based']=True;r['authored_yaw_degrees']=env['YAWS'][i]
 if i==0:
  base=np.array([773,670])+np.array([2000-1017,1500-962]);wm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-weapon.png'))>0;r['weapon_native_source']='nobunaga_impact_v4/charge_ready_hires/source/shortened-blade.png';r['weapon_native_source_transform']='exact scale1 approved squat-hold frame008 placement'
 else:
  c=env['CONF'][env['keys'][i]];target=np.array([2000.,1500.]);target[0]+=70*(2.25/.58) if i>=21 else 0;base=np.array(c['base'])+target-np.array(c['support']);wp=d/f'layers-native/weapon/{i:03}.png';wm=np.array(Image.open(wp))[:,:,3]>0;r['weapon_native_source']=str(wp.relative_to(O));r['weapon_native_source_sha256']=hashlib.sha256(wp.read_bytes()).hexdigest();r['original_actor_native_source']=f'charge_release/layers-native/actor/{i:03}.png';r['original_body_native_source']=f'charge_release/layers-native/body/{i:03}.png'
 yy,xx=np.nonzero(wm);pts=np.column_stack([xx,yy]).astype(float);cen=pts.mean(0);ev,vec=np.linalg.eigh(np.cov(pts,rowvar=False));u=vec[:,-1];proj=(pts-cen)@u;end=[cen+u*np.quantile(proj,.005),cen+u*np.quantile(proj,.995)];tip=max(end,key=lambda v:np.linalg.norm(v-base))
 r['blade_base_art_px']=np.round(base,3).tolist();r['blade_tip_art_px']=np.round(tip,3).tolist();r['blade_angle_deg']=round(float(np.degrees(np.arctan2(*(tip-base)[::-1]))),3);r['blade_measurement']='base from exact approved native transform; tip advisory PCA endpoint of authored independent steel alpha. PCA measures known layer only, never selects pixels.'
 r['coverage_gaps']=['Independent native weapon contains exposed steel only; donor-painted hilt and guard remain partly in body and hand-overlap layers.','Hidden body under weapon and hidden weapon under hands are not reconstructed; this is a source-exact visible partition, not a clean swap-ready rig.']
 if i==0:r['coverage_gaps'].append('Frame000 has no independent original native body layer; actor is source-exact approved hold endpoint and its steel mask uses the approved canonical template transform.')
 r['semantic_visual_review']='all24 cropped actor overlays inspected: correct grip regions, no face/neck selected; foreshortened008/016 and highguard022/023 checked'
(d/'layers-visible-manifest.json').write_text(json.dumps(m,indent=2))
summary={'clip':'charge_release','frames':24,'native_layer_based_frames':24,'actor_recomposition_pixel_exact_frames':sum(r['recomposition_visible_rgba_exact'] for r in m),'actor_fx_recomposition_pixel_exact_frames':sum(r['full_actor_fx_recomposition_visible_rgba_exact'] for r in m),'native_master_art_changed':False,'mask_measurements_advisory':True,'exposed_steel_only_hilt_guard_incomplete':{'count':24,'frames':list(range(24))},'hidden_fill_complete':False,'fully_swap_ready':False,'fx_separate':True,'qa_overlay':'qa/charge_release-layers.jpg'}
(d/'semantic-coverage.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
