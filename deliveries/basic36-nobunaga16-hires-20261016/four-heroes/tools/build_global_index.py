from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
import json,hashlib,csv,io
D=Path(__file__).resolve().parents[1];E='Sentinel_003f9aaa53ac819191a42c7ac9485ce8';order=['walk','run','jump','hurt','stunned','launched','down','recovering','victory']
M={'schema':'sengoku.four-heroes.base-actions.final.v1','accepted_event':{'message_id':E,'quote':'動作都OK了，把後續都處理好就上GIT'},'accepted_action_count':36,'game_frame_count':212,'runtime_tested':False,'runtime_integrated':False,'previous_assets_modified':False,'characters':{},'actions':[],'canonical_contract':'contracts/<character>/<action>.json','coordinate_system':'Canvas pixels, x-right/y-down; root is explicit. Preview and runtime world motion are independent. Anatomical foot mappings may be unresolved.'};Q={'all_actions_accepted':True,'runtime_tested':False,'frame_checks':[]};reps={}
for c in ['tadakatsu','hideyoshi','ieyasu','kennyo']:
 C=D/c;cm=json.loads((C/'integration_manifest.json').read_text());aa=cm['actions'];aa={a['action']:a for a in aa} if isinstance(aa,list) else aa
 M['characters'][c]={'entry':f'{c}/integration_manifest.json','standing_ruler_px':cm['standing_ruler_px'],'accepted_actions':9,'frame_count':sum(a['frame_count'] for a in aa.values()),'runtime_tested':False};reps[c]=[]
 for action in order:
  a=aa[action];mp=C/a['metadata'];raw=json.loads(mp.read_text());fs=[]
  if c=='kennyo':data=json.loads((C/a['integration_frames']).read_text());orig=data['frames']
  else:orig=raw['frames']
  for idx,f in enumerate(orig):
   if c in ['tadakatsu','hideyoshi']:
    r=f['integration'];base=C;layers=r['layers'];co=r['composite'];feet=r['feet_canvas_px'];root=r['root_canvas_px'];grips=r['grips_canvas_px'];angle=r['weapon_angle_deg'];conv=r['weapon_angle_convention'];lo=r['layer_order'];ev=r['events'];preview=r['preview_offset_px'];world=r['world_root_offset_px'];mapping=r['foot_identity'];source=r['source'];gripstate=r['grip_state'];anchor=r['weapon_anchor_canvas_px'];baked=r['pose_offset_already_baked_px']
   elif c=='kennyo':
    r=f;base=mp.parent;layers=r['layer_files'];co=r['composite_file'];feet=r['feet_px'];root=r['root_px'];grips=r['grips_px'];angle=r['weapon_angle_degrees'];conv=r['weapon_angle_convention'];lo=r['layer_order_back_to_front'];ev=r['events'];preview=r['preview_displacement_px'];world=r['world_displacement_px'];mapping={'status':'original_landmark_indices; anatomical mapping unregistered'};source={'legacy_path':r.get('source'),'metadata_base':str(mp.parent.relative_to(D))};gripstate='released' if r['weapon_released'] else 'held';anchor=r.get('released_weapon_anchor_px',grips[0] if grips else None);baked=None
   else:
    r=f;base=mp.parent;layers=r['layer_files'];co=r['composite_file'];feet=dict(r['feet_canvas'],**r['anatomical_feet_canvas']);root=r['root_canvas'];grips=r['hands_canvas'];angle=r['weapon_angle_degrees'];conv=r['weapon_angle_convention'];lo=r['layer_order'];ev=[e['name'] for e in r.get('event_markers',[])];preview=r['preview_displacement'];world=r['world_delta'];mapping={'status':r['anatomical_mapping_status'],'source_indices':r['landmark_source_index']};source={'parts':r.get('source_parts',[]),'paths_base':c};gripstate=r.get('grip_state','see_frame_metadata');anchor=r.get('grip_canvas');baked=None
   paths={n:str((base/p).relative_to(D)) for n,p in layers.items()};cop=str((base/co).relative_to(D));ims={n:Image.open(D/p).convert('RGBA') for n,p in paths.items()};composite=Image.new('RGBA',next(iter(ims.values())).size)
   for n in lo:composite.alpha_composite(ims[n])
   expected=Image.open(D/cop).convert('RGBA');exact=not any(v[1] for v in ImageChops.difference(composite,expected).getextrema());bb=expected.getchannel('A').getbbox();w,h=expected.size;bounds=bb and bb[0]>0 and bb[1]>0 and bb[2]<w and bb[3]<h
   assert exact and bounds,(c,action,idx,'layer/bounds');assert len([v for v in feet.values() if v is not None])>=2 and root and angle is not None
   dur=r['duration_ms'];item={'frame_index':idx,'duration_ms':dur,'start_ms':sum(t['duration_ms'] for t in fs),'canvas_size_px':[w,h],'root_canvas_px':root,'feet_canvas_px':feet,'foot_identity':mapping,'grips_canvas_px':grips,'grip_state':gripstate,'weapon_anchor_canvas_px':anchor,'weapon_angle_degrees':angle,'weapon_angle_convention':conv,'layer_order_back_to_front':lo,'layers':paths,'composite':cop,'events':ev,'preview_displacement_px':preview,'world_displacement_px':world,'world_motion_owner':'runtime_controller; values are not engine-tested tuning','pose_offset_already_baked_px':baked,'source_provenance':source,'runtime_tested':False}
   fs.append(item);Q['frame_checks'].append({'character':c,'action':action,'frame_index':idx,'layer_recomposition_exact':exact,'alpha_clear_at_canvas_edges':bool(bounds)})
  total=sum(f['duration_ms'] for f in fs);assert total==a['total_duration_ms'] and len(fs)==a['frame_count']
  cp=D/'contracts'/c/(action+'.json');cp.parent.mkdir(parents=True,exist_ok=True);contract={'schema':'sengoku.animation.frames.v1','character':c,'action':action,'status':'accepted','accepted_event':E,'standing_ruler_px':cm['standing_ruler_px'],'frame_count':len(fs),'total_duration_ms':total,'loop':a['loop'],'terminal_hold':a['terminal_hold'],'runtime_tested':False,'source_metadata':str(mp.relative_to(D)),'all_file_paths_relative_to':'final_git_bundle root','frames':fs};cp.write_text(json.dumps(contract,ensure_ascii=False,indent=2))
  M['actions'].append({k:contract[k] for k in ['character','action','status','standing_ruler_px','frame_count','total_duration_ms','loop','terminal_hold']}|{'contract':str(cp.relative_to(D)),'source_metadata':str(mp.relative_to(D))})
  pick={'walk':2,'run':1,'jump':3,'hurt':2,'stunned':1,'launched':2,'down':len(fs)-1,'recovering':min(3,len(fs)-1),'victory':min(2,len(fs)-1)}[action];pick=min(pick,len(fs)-1);reps[c].append({'action':action,'frame_index':pick,'composite':fs[pick]['composite'],'caption':{'walk':'passing / alternating gait','run':'support and passing','jump':'airborne; fixed anatomical scale','hurt':'standing hit reaction','stunned':'FX-free loop','launched':'knockback air pose','down':'terminal death-compatible hold','recovering':'rise / pickup; returns to registered idle','victory':'victory gesture; returns to registered idle'}[action]})
 # A same-game-scale sheet, not a newly generated character image.
 sheet=Image.new('RGB',(1920,1230),(40,44,48));dr=ImageDraw.Draw(sheet)
 for i,rp in enumerate(reps[c]):
  im=Image.open(D/rp['composite']);x=i%3*640+(640-im.width)//2;y=i//3*410;sheet.paste(im,(x,y),im);dr.text((i%3*640+8,y+385),f"{c} / {rp['action']} / frame {rp['frame_index']+1}: {rp['caption']}",fill='white')
 (D/'representatives').mkdir(exist_ok=True);sheet.save(D/'representatives'/f'{c}.png')
assert len(M['actions'])==36 and len(Q['frame_checks'])==212
Q.update(actions=36,frames=212,all_layer_recomposition_exact=True,all_alpha_edges_clear=True)
(D/'manifest.json').write_text(json.dumps(M,ensure_ascii=False,indent=2));(D/'acceptance.json').write_text(json.dumps(M['accepted_event']|{'all36_accepted':True,'latest_ieyasu_run':'run_v5','runtime_tested':False},ensure_ascii=False,indent=2));(D/'representatives/description.json').write_text(json.dumps(reps,indent=2));(D/'QA.json').write_text(json.dumps(Q,indent=2))
s=io.StringIO();w=csv.writer(s);w.writerow(['character','action','status','frames','duration_ms','ruler_px','contract'])
for a in M['actions']:w.writerow([a['character'],a['action'],a['status'],a['frame_count'],a['total_duration_ms'],a['standing_ruler_px'],a['contract']])
(D/'action-index.csv').write_text(s.getvalue());print('36 accepted / 212 frames all recomposed exactly, alpha edges clear; contracts + representative sheets generated')
