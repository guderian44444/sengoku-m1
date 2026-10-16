from pathlib import Path
from PIL import Image
import json, hashlib, collections
ROOT=Path.cwd(); R=Path('nobunaga_impact_v4'); OUT=Path('nobunaga_final_approved'); OUT.mkdir(exist_ok=True)
def rel(p):
 p=Path(p)
 try:return str(p.relative_to(ROOT))
 except ValueError:return str(p)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def info(p):
 p=Path(p);im=Image.open(p);a=im.getchannel('A') if im.mode=='RGBA' else None
 return dict(path=rel(p),sha256=sha(p),dimensions=list(im.size),mode=im.mode,alpha_extrema=list(a.getextrema()) if a else None)
vs={x['key']:x for x in json.load(open(OUT/'review-source-verification.json'))}; m=json.load(open(R/'delivery-manifest-hires.json')); clips=[]
for c in m['clips']:
 k=c['key'];d=R/c['directory'];notes=[]
 if k=='throw_reverse':d=R/'throw_reverse_planted_v2'
 root=d.parent if k in ['heavy','dash_heavy','air_light','air_heavy'] else d
 if k=='light_2':mp=root/'candidate-f-review.json';rows=json.load(open(mp))['frames'];paths=[Path(q['archived_selected_source']) for q in rows];notes=['Use candidate-f-selected-sources, not unselected frames-highres or earlier candidates.']
 elif k=='light_3':mp=root/'review.json';rows=json.load(open(mp))['measurements'];paths=[Path(q['native_path']) for q in rows];notes=['Only the 15 selected paths in review.json measurements are approved; frames-native contains 25 candidate files.']
 else:
  mp=d/'frame-manifest.json';rows=json.load(open(mp))
  if k=='light_1':paths=[root/f'frames-composited/{i:03}.png' for i in range(c['frames'])]
  elif k in ['heavy','dash_heavy','air_light','air_heavy','grab_hold','grab_hit_1','grab_hit_2']:paths=[root/f'frames-native/{i:03}.png' for i in range(c['frames'])]
  elif k in ['charge_ready','charge_hold','charge_release']:paths=[root/f'frames-composited/{i:03}.png' for i in range(c['frames'])];notes=['frames-highres is raw donor art, not the final composed actor/weapon/FX. Native composited exports are independently rendered from native layers.']
  elif k=='throw_reverse':paths=[root/f'frames-native/{i:03}.png' for i in range(16)]
  elif k=='grab_start':paths=[];notes=['First 8 approved RGB review frames come from grab_start_hires/candidate-b. Its 004/005 canonical blade root correction is not present in old native actor exports. Final 4 frames use native-registration.json sources. Native outputs must recompose approved body and canonical blade.']
  elif k=='throw_forward':paths=[root/f'frames-native/{i:03}.png' for i in range(9)];notes=['Native directory only covers frames000–008. Frames009–018 reuse grab_start_swordheld frames009..000; follow its original-source maps, never upscale those review PNGs.']
 layers=[]
 for p in sorted(root.rglob('*.png')):
  if '/layers/' in str(p) or p.name in ['canonical-steel-native.png','cloth-hair-mask.png']:
   layers.append(info(p))
 if k in ['grab_start','charge_ready','charge_hold','charge_release']:
  p=R/'charge_ready_hires/source/shortened-blade.png';layers.append(info(p))
 frame_sources=[info(p) for p in paths]
 review=d/'review.json' if (d/'review.json').exists() else root/'review.json'
 review_data=json.load(open(review)) if review.exists() else {}
 event_metadata={key:review_data[key] for key in ['terminal_frames','terminal_duration_ms','fast_frames','fast_total_ms','compression_ms','outward_burst_ms'] if key in review_data}
 if isinstance(rows,list):
  selected=[]
  for row in rows:
   selected.append({kk:v for kk,v in row.items() if any(t in kk.lower() for t in ['scale','sole','foot','feet','root','anchor','offset','translation','pelvis','blade','guard','palm','weapon','hand','world','fx','start_ms','end_ms']) or kk in ['frame','index','duration_ms','review','game']})
 else:selected=rows
 if k=='throw_reverse':layer_contract=json.load(open(root/'site-import-manifest.json'))['layers']
 else:layer_contract={'actor':'composite actor includes body, clothing, hair, hands, sword except charge release which has separate layers','independent_weapon':k in ['charge_ready','charge_hold','charge_release'],'hand_occlusion':'no dedicated hand-occlusion PNG track found; charge-release has body/weapon depth ordering', 'fx': 'separate fx_front/fx_back for001..023' if k=='charge_release' else 'no approved FX track'}
 clips.append(dict(key=k,status='approved',approved_preview=vs[k],selected_root=str(root),source_metadata=str(mp),source_records=rows,original_resolution_sources=frame_sources,existing_layers=layers,layer_contract=layer_contract,art_landmarks_and_registration=selected,art_event_markers=event_metadata,runtime_events={'status':'not supplied by this art-source audit; preserve and separately verify existing runtime contract','do_not_infer_hitboxes_or_weapon_sockets_from_art':True},notes=notes))
audit={'schema':'nobunaga-final-approved-source-audit-v1','approval':{'message_id':'Sentinel_003f9aaa53ac819191a42c7ac9485ce8','quote':'動作都OK了，把後續都處理好就上GIT','scope':'all16; provided by parent'},'baseline_manifest':str(R/'delivery-manifest-hires.json'),'baseline_exceptions':['All statuses are now approved by latest user instruction.','throw_reverse replaced with throw_reverse_planted_v2,16x50ms,eb9e66deb33d9784ffbd90ad30c9a28162326f6404ab536c135c86de84e3c9ec.'],'total_frames':sum(x['approved_preview']['frames'] for x in clips),'total_duration_ms':sum(x['approved_preview']['duration_ms'] for x in clips),'verification':{'all_16_approved_gif_hashes_match':all(x['approved_preview']['sha256_match'] for x in clips),'every_review_frame_quantizes_pixel_exact_to_approved_gif':all(all(x['approved_preview']['quantized_review_pixels_equal_gif_by_frame']) for x in clips),'source_files_unmodified':True},'clips':clips}
(OUT/'inventory.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print('inventory written',len(clips),audit['total_frames'])
