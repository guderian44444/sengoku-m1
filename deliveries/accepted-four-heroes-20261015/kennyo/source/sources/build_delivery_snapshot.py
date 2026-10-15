from pathlib import Path
from PIL import Image
import shutil,json,hashlib,zipfile,datetime
ROOT=Path(__file__).resolve().parent.parent;SRC=ROOT/'kennyo03_newspec_20261015';CFG=json.loads((SRC/'DELIVERY_CONFIG.json').read_text());DST=ROOT/'kennyo03_snapshot_20261015_v2'
assert len(CFG)==16 and all(v['id'] for v in CFG.values()),'Await all final revision IDs'
assert not DST.exists(),'Snapshot must be immutable, choose a new snapshot ID'
DST.mkdir();shutil.copytree(SRC,DST/'sources',ignore=shutil.ignore_patterns('__pycache__','*.pyc','*.zip'))
manifest={'schema_version':1,'snapshot_id':DST.name,'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'character':'本願寺顯如','identity':'approved revised candidate03, white cowl, lean face, large beads, dark armored sohei','identity_library_file_id':'libfile_0b466147f34c819189263b7b1e01da26','review_status':'latest user-directed candidates, not a claim of whole-set final approval','runtime_integrated':False,'anatomical_standing_height_px':163,'scale_rule':'fixed per-source anatomical head/torso/bone scale; exclude Tadakatsu antlers; crouched poses are not bbox-normalized','default_weapon':'ornate_shakujo, full215px, independent grip and front/back occlusion','source_reference':'sources/source/specs/SOURCE_MANIFEST.json','latest_overrides':'sources/USER_OVERRIDES.md','readme':'sources/README_DELIVERY.md','timing_rule':'decoded GIF durations are authoritative; all frames10ms units with remainder allocation; air_heavy source945ms rounds to950ms','actions':[]}
for key,v in CFG.items():
 d=DST/'sources'/v['dir'];gif=d/(f'kennyo03_{key}.gif' if v['dir'].startswith('grabs/') else 'normal.gif')
 im=Image.open(gif);dur=[]
 for i in range(im.n_frames):im.seek(i);dur.append(im.info.get('duration',0))
 assert len(dur)==v['expected_frames'],(key,len(dur));assert sum(dur)==v['expected_ms'],(key,sum(dur));assert all(x>0 and x%10==0 for x in dur)
 out=DST/'review'/key;out.mkdir(parents=True);shutil.copy(gif,out/'normal.gif')
 # Representative is selected from the exact decoded normal-speed animation.
 rep={'charge_release':9,'charge_hold':0,'grab_hold':0,'light_1':5,'light_2':3,'light_3':5,'heavy':4,'throw_forward':4,'throw_reverse':4,'air_light':6,'air_heavy':6,'dash_heavy':3}.get(key,min(3,len(dur)-1))
 im.seek(rep);im.convert('RGB').save(out/'representative.jpg',quality=92)
 meta=d/('stow-metadata.json' if key=='charge_ready' else 'metadata.json');m=json.loads(meta.read_text())
 layers=[str(f.relative_to(DST)) for f in sorted(d.rglob('*.png')) if not any(t in f.name for t in ['source','poster','contact','representative'])]
 strikes=[]
 for ev in m.get('strike_events',[]):
  e=dict(ev);e['gif_start_ms']=sum(dur[:e['frame']-1]);strikes.append(e)
 action={'key':key,'title':v['title'],'asset_revision_directory':v['dir'],'library_file_id':v['id'],'library_version':v['version'],'normal_gif':str((out/'normal.gif').relative_to(DST)),'representative_image':str((out/'representative.jpg').relative_to(DST)),'representative_frame_zero_based':rep,'frame_count':len(dur),'gif_decoded_durations_ms':dur,'gif_decoded_total_ms':sum(dur),'source_design_total_ms':945 if key=='air_heavy' else sum(dur),'gif_sha256':hashlib.sha256(gif.read_bytes()).hexdigest(),'source_directory':str(d.relative_to(DST)),'source_metadata':str(meta.relative_to(DST)),'layer_files':layers,'strike_events':strikes,'description':v['title']}
 if key=='grab_hit_1':action.update(motion_alias='grab_hit_2',event_namespace='grab_hit_1')
 if key=='charge_hold':action.update(body_motion='one fixed still pose; no breathing/bob')
 if key=='charge_release':action.update(body_keys_previous=33,body_keys_current=38,body_plus_keys=5,fx_glyph='卍',fx_unicode='U+534D',six_independent_strike_pulses=True,approved_body_and_beads_unchanged_in_fx_v4=True)
 manifest['actions'].append(action)
(DST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(DST/'README.txt').write_text('顯如03最新16招審圖快照。manifest.json為唯一入口。review內正常速度GIF與代表圖可直接匯入16候選；sources保留完整原圖、提示、逐格透明分層、慢速、量測事件與舊版歷程。不得從無版本目錄或舊GIF猜最新。\n逐格時長已逐一解碼驗證；以gif_decoded_durations_ms為準。人物站立163px，以本多頭頂至腳底為尺規且不含鹿角。集氣保持人物完全不動。念珠38格3170ms，左拉越頭右甩三輪，正立佛教卍字獨立高速投射。\n本包是候選素材與接入準備，不代表整套最終通過審核。未改Git/runtime。正式引擎仍需接觸、碰撞、取消、世界位移阻擋、抓放與跨招姿勢QA。\n小review ZIP不含sources；完整來源ZIP才含全部分層和歷程。\n')
files=[f for f in DST.rglob('*') if f.is_file()];hashes={str(f.relative_to(DST)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};(DST/'SHA256.json').write_text(json.dumps(hashes,indent=2))
reviewfiles=[f for f in DST.rglob('*') if f.is_file() and ('review' in f.relative_to(DST).parts or f.name in ('manifest.json','README.txt'))]
(DST/'REVIEW_SHA256.json').write_text(json.dumps({str(f.relative_to(DST)):hashlib.sha256(f.read_bytes()).hexdigest() for f in reviewfiles},indent=2));reviewfiles.append(DST/'REVIEW_SHA256.json')
for typ,fs in [('review',reviewfiles),('full_sources',[f for f in DST.rglob('*') if f.is_file()])]:
 q=ROOT/(DST.name+'_'+typ+'.zip')
 with zipfile.ZipFile(q,'w',zipfile.ZIP_DEFLATED) as z:
  for f in fs:z.write(f,f.relative_to(DST))
 with zipfile.ZipFile(q) as z:assert z.testzip() is None
 print(q.name,q.stat().st_size,flush=True)
print('verified16 actions; exact decoded durations; frozen snapshot',DST,flush=True)
