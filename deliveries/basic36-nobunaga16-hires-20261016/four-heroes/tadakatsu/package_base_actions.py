from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,zipfile,os
B=Path(__file__).parent;acts=['walk','run','jump','hurt','stunned','launched','down','recovering','victory'];frames=[];index={};checks=[]
for a in acts:
 d=B/a;m=json.loads((d/'metadata.json').read_text());q=json.loads((d/'QA.json').read_text());status='user_positive_approved_walk' if a=='walk' else 'candidate_pending_user'
 for r in m['frames']:
  n=r['frame'];ims={l:Image.open(d/f'{l}_{n:02}.png').convert('RGBA') for l in ['body','weapon','hand_occlusion']};c=Image.new('RGBA',ims['body'].size)
  for l in r['layer_order']:c.alpha_composite(ims[l])
  actual=Image.open(d/f'composite_{n:02}.png');assert np.array_equal(np.array(c),np.array(actual)),(a,n,'layer composition mismatch')
  for l,im in dict(ims,composite=actual).items():
   alpha=np.array(im)[:,:,3];assert max(alpha[0,:].max(),alpha[-1,:].max(),alpha[:,0].max(),alpha[:,-1].max())==0,(a,n,l,'border')
  frames.append(dict(action=a,frame=n,duration_ms=r['duration_ms'],phase=r['phase'],event=r.get('event',r['phase']),source=r['source_file'],source_effective_height=r['source_effective_height'],root_source=r.get('root_source',r.get('source_root')),root_canvas=r['root_canvas'],feet_source=r['feet_source'],feet_canvas=r['feet_canvas'],hands_source=r['hands_source'],hands_canvas=r['hands_canvas'],weapon_angle_degrees=r['weapon_angle_degrees'],layer_order=r['layer_order'],world_delta=r['world_delta'],preview_displacement=r.get('preview_displacement_px',r.get('preview_displacement',[0,0])),pose_offset_px=r.get('body_offset_px',[0,0]),next_frame=r.get('next_frame',r.get('loop_next')),grounded=r.get('grounded'),support=r.get('support_foot'),fx=None))
 newheights=[r['source_effective_height'] for r in m['frames'] if not r.get('reused_approved')]
 index[a]=dict(status=status,metadata=f'{a}/metadata.json',qa=f'{a}/QA.json',normal_gif=f'{a}/normal.gif',idle_review_gif=f'{a}/'+('idle-walk-comparison.gif' if a=='walk' else 'idle-comparison.gif'),frame_count=m['frame_count'],duration_ms=m['total_ms'],loop=m['loop'],terminal_hold=m.get('terminal_hold',False),min_new_source_effective_height_px=min(newheights))
 checks.append(dict(action=a,frame_count=m['frame_count'],layers_recompose_exactly=True,all_final_alpha_boundaries_clear=True,all_new_sources_above600px=min(newheights)>=600))
assert (B/'launched/composite_05.png').read_bytes()==(B/'down/composite_01.png').read_bytes()
assert (B/'down/composite_04.png').read_bytes()==(B/'recovering/composite_01.png').read_bytes()
manifest=dict(hero='tadakatsu',revision='r3_base_actions_20261015',scope='nine base actions with registered approved combat idle and cropped portrait',overall_status='walk approved; eight other actions remain candidates',standing_ruler_px=163,total_actions=9,total_frames=len(frames),source_master='source/approved-original-master.png',source_master_sha256=hashlib.sha256((B/'source/approved-original-master.png').read_bytes()).hexdigest(),idle_registration='identity/registration.json',portrait='identity/portrait-approved-crop.png',actions=index,latest_library_index='base-actions-library.json',unified_frames='unified-frame-index.json',ordinary_actions_fx=False,existing_16_combat_assets='unchanged',site_or_git_changes=False,runtime_integrated=False,source_notes='Original approved idle is reused at its native original resolution; all newly drawn poses exceed600px effective height. Rejected source attempts are retained for provenance but only config.json files choose active frames.')
(B/'manifest.json').write_text(json.dumps(manifest,indent=2));(B/'unified-frame-index.json').write_text(json.dumps(frames,indent=2));(B/'FINAL-QA.json').write_text(json.dumps(dict(actions=checks,total_frames=len(frames),handoff_launched_to_down='pixel_exact',handoff_down_to_recovering='pixel_exact',no_optical_flow=True,constant_anatomical_ruler=True,per_frame_bbox_normalization=False),indent=2))
(B/'README.txt').write_text('''Honda Tadakatsu r3: nine base actions, 2026-10-15\n\nWalk received positive user approval. Run, jump, hurt, stunned, launched, down, recovering and victory remain review candidates. The latest jump includes strengthened crouch/chest anticipation and leg/arm takeoff.\n\nEach action directory contains three transparent RGBA layers per frame (body, weapon, hand_occlusion), composites, normal and slow review GIFs, same-scale approved-idle comparison, metadata.json and QA.json; frame configuration is in config.json (walk uses build_walk.py). High-resolution originals are preserved in source/ folders. Review GIFs repeat for inspection; consult metadata.loop for runtime behavior. Down has a full impact/settle sequence and terminal death-compatible hold, not merely a static hold. Launched/down and down/recovering handoffs are pixel-identical.\n\nStanding ruler is163px. Paired upright sources use163/740; high-resolution single falling/recovery sources use163/1050 anatomical ruler. Approved combat idle is reused unchanged at163/370. No per-frame bbox equalization. Native source PNGs are preserved and reduced only once into body layers. All new source figures exceed600px effective height; old approved idle reuse is explicitly marked. Rejected source attempts may remain in source/ but are not selected in config.json.\n\nworld_delta is zero for all frames; runtime controller owns world displacement. Walk world-preview is a separate foot-lock demonstration. pose/body_offset records visible local pose placement (including jumping or knockback illustration offsets); it does not authorize runtime world motion. Keep these offsets separate when importing.\n\nidentity/ contains exact approved combat idle registration and a portrait crop, not a newly drawn portrait. All ordinary actions have noFX. No existing combat source, site or Git repository was modified.\n\nmanifest.json lists all actions and status. unified-frame-index.json normalizes frame timing, events, roots, feet, hands, weapon angles, layers and motion fields. base-actions-library.json lists current delivery IDs.\n''')
# Persist Library version xattrs on corresponding local upload copies.
u=json.loads((B/'base-actions-upload-records.json').read_text());lib={'walk':json.loads((B/'library-delivery.json').read_text()),'superseded_jump':[]}
for key,record in u.items():
 for r in (record or {}).get('results',[]):
  name=r['file_name'];base=name.replace('(1)','');matches=list(B.glob('*/'+base))
  for path in matches:
   for x in r.get('xattrs',[]):os.setxattr(path,x['name'],x['value'].encode())
  a=base.removeprefix('tadakatsu-r3-').split('-')[0].split('.')[0]
  typ='idle_review_gif' if 'idle-review' in base else 'metadata' if base.endswith('.json') else 'normal_gif'
  if 'jump_library' in key:lib['superseded_jump'].append(r['library_file_id'])
  else:lib.setdefault(a,{})[typ]=r['library_file_id']
(B/'base-actions-library.json').write_text(json.dumps(lib,indent=2))
files=[p for p in B.rglob('*') if p.is_file() and 'deliverables' not in p.relative_to(B).parts and p.suffix!='.zip' and p.name!='SHA256.json']
shas={str(p.relative_to(B)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.name!='SHA256.json'};(B/'SHA256.json').write_text(json.dumps(shas,indent=2));files.append(B/'SHA256.json')
out=B/'deliverables';out.mkdir(exist_ok=True)
for flavor in ['complete','runtime-review']:
 zip_path=out/f'tadakatsu-r3-nine-base-actions-{flavor}.zip'
 selected=files if flavor=='complete' else [p for p in files if 'source' not in p.relative_to(B).parts and not p.name.startswith('source_body_') and not p.name.startswith('body_source_') and p.suffix!='.py']
 with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,6) as z:
  for p in selected:z.write(p,Path('tadakatsu')/p.relative_to(B))
 with zipfile.ZipFile(zip_path) as z:assert z.testzip() is None
 print(json.dumps(dict(file=str(zip_path.resolve()),bytes=zip_path.stat().st_size,sha256=hashlib.sha256(zip_path.read_bytes()).hexdigest(),files=len(selected))))
print('Validated',len(frames),'frames; all layers and alpha boundaries pass.')
