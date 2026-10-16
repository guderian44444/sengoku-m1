"""Build an additive final asset handoff. Never changes the original asset directories."""
from pathlib import Path
import copy, hashlib, json, shutil
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent
SRC = OUT.parents[1] / 'ieyasu'
REF = OUT.parents[2] / 'ieyasu06_newspec_20261015'
ACTIONS = ['walk','hurt','stunned','jump','launched','down','recovering','victory_v2','run_v5']
LAYERS = ['body','weapon','hand_occlusion']
APPROVAL = {'message_id':'Sentinel_003f9aaa53ac819191a42c7ac9485ce8','quote':'動作都OK了，把後續都處理好就上GIT','scope':'All nine latest Ieyasu base actions, including run_v5 and victory_v2. Visual asset acceptance; not evidence of runtime testing.'}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,v):
 p=OUT/p; p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def cp(a,b):
 b=OUT/b;b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a,b)
def rgba(p): return Image.open(p).convert('RGBA')
def arr(p): return np.array(rgba(p)).astype('int16')
def err(a,b): return int(np.abs(np.array(a).astype('int16')-np.array(b).astype('int16')).max())
def rel(p): return str(Path(p).relative_to(OUT))
def source_entry(path,role,**extra):
 p=OUT/path;assert p.exists(),p
 return {'role':role,'path':str(path),'sha256':sha(p),**extra}

# All originals retained, including unused/rejected history. Only selected source_parts drive current art.
for p in sorted((SRC/'sources').iterdir()):
 if p.is_file(): cp(p,Path('sources')/p.name)
for p in sorted((REF/'reference').iterdir()):
 if p.is_file():cp(p,Path('approved_reference/reference')/p.name)
cp(REF/'actions/light_1_source.png','approved_reference/actions/light_1_source.png')
for p in (REF/'actions/light_1').glob('*.png'):
 if p.name.endswith('_00.png'):cp(p,Path('approved_reference/actions/light_1')/p.name)
for d in ['prompts','configs']:
 for p in (SRC/d).rglob('*'):
  if p.is_file():cp(p,Path('provenance')/d/p.relative_to(SRC/d))
for fn in ['build_walk.py','render_action.py','build_run_v4_review.py','build_run_v4_final.py','build_run_v5.py','qa_eight_actions.py','generation_record.json','original_source_inventory.json']:
 if (SRC/fn).exists():cp(SRC/fn,Path('provenance/original_records')/fn)
for d in ['run_v4/qa','run_v5/qa','qa_eight_actions']:
 for p in (SRC/d).rglob('*'):
  if p.is_file(): cp(p,Path('provenance')/d/p.relative_to(SRC/d))
for name in ['QA.json','assembly_provenance.json','independent_visual_review.json','metadata.json']:
 if (SRC/'run_v4'/name).exists():cp(SRC/'run_v4'/name,Path('provenance/run_v4_locked_baseline')/name)
for i in range(1,7):
 for layer in ['body','weapon','sheath','hand_occlusion','composite']:
  cp(SRC/f'run_v4/{layer}_{i:02}.png',f'provenance/run_v4_locked_baseline/{layer}_{i:02}.png')
  cp(SRC/f'run_v5/{layer}_{i:02}.png',f'provenance/run_v5_original_four_layers/{layer}_{i:02}.png')
for p in (SRC/'run_v5/masks').glob('*.png'):cp(p,Path('run_v5/masks')/p.name)
cp(SRC/'run_v5/head_master_native.png','provenance/run_v5/head_master_native.png')

# Official idle: preserve native evidence and export canonical canvas by integer translation only.
for p in (SRC/'idle').iterdir():
 if p.is_file():cp(p,Path('provenance/idle_native')/p.name)
reg=json.load(open(SRC/'idle/registration.json'))
assert sha(OUT/'approved_reference/actions/light_1/composite_00.png')==reg['source_sha256']
merged=Image.new('RGBA',(520,280));merged.alpha_composite(rgba(SRC/'idle/sheath.png'));merged.alpha_composite(rgba(SRC/'idle/body.png'))
for n in LAYERS:
 im=merged if n=='body' else rgba(SRC/f'idle/{n}.png')
 can=Image.new('RGBA',(480,320));can.alpha_composite(im,(85,35));(OUT/'idle').mkdir(exist_ok=True);can.save(OUT/f'idle/{n}.png')
idle=Image.new('RGBA',(480,320))
for n in LAYERS:idle.alpha_composite(rgba(OUT/f'idle/{n}.png'))
idle.save(OUT/'idle/composite.png')
expected=Image.new('RGBA',(480,320));expected.alpha_composite(rgba(SRC/'idle/composite.png'),(85,35));assert err(idle,expected)==0
ireg={'hero':'ieyasu06','status':'registered_from_approved_combat','approval':APPROVAL,'source':'../approved_reference/actions/light_1/composite_00.png','source_sha256':reg['source_sha256'],'artwork_changes':False,'canvas':[480,320],'native_canvas':[520,280],'translation_only':[85,35],'export_resampling':False,'standing_ruler_px':152,'root_canvas':[220,280],'root_local':[0,0],'feet_canvas':{'near':[160,280],'far':[276,280]},'anatomical_feet_canvas':{'left':None,'right':None},'leg_identity':{'near':None,'far':None},'landmark_source_index':{'near':'near','far':'far'},'anatomical_mapping_status':'not_explicitly_registered; runtime mapping must be confirmed','grip_canvas':[224.08,201.06],'hands_canvas':[[224.08,201.06]],'weapon_angle_degrees':-55,'weapon_angle_convention':'clockwise from approved upward-pointing tachi; screen +x right, +y down','layers':LAYERS,'layer_order':LAYERS,'body_includes_scabbard':True,'duration_ms':800,'loop':True,'loop_next':1,'grounded':True,'support_foot':'both','event':None,'landing':False,'settle':True,'preview_displacement':[0,0],'world_delta':[0,0],'fx':None,'recomposite_pixel_exact':True,'runtime_integrated':False,'original_native_registration':'../provenance/idle_native/registration.json'}
write('idle/registration.json',ireg)
cp(SRC/'portrait/portrait.png','portrait/portrait.png')
write('portrait/provenance.json',{'source':'../approved_reference/actions/light_1_source.png','source_sha256':sha(OUT/'approved_reference/actions/light_1_source.png'),'crop':reg['portrait']['crop'],'redrawn':False,'portrait_sha256':sha(OUT/'portrait/portrait.png')})

report={'scope':'Offline asset integrity checks, not game/runtime validation','approval':APPROVAL,'runtime_tested':False,'actions':{},'seams':{},'run_v5_locked_legs':[]}
catalog=[];source_usage={};reference_paths=['approved_reference/reference/identity06.png','approved_reference/reference/identity06_original.png','approved_reference/actions/light_1_source.png','approved_reference/reference/tachi.png','approved_reference/reference/saya.png']
terminal={'walk':('loop',None),'run_v5':('loop',None),'stunned':('loop_until_stun_ends','idle'),'hurt':('return_to_idle','idle'),'jump':('return_to_idle_after_runtime_landing','idle'),'launched':('wait_for_runtime_ground_contact','down'),'down':('hold_last_until_recovery','recovering'),'recovering':('return_to_idle','idle'),'victory_v2':('return_to_idle','idle')}
for folder in ACTIONS:
 old=json.load(open(SRC/folder/'metadata.json'))
 canonical=SRC/'run_v5/three_layer' if folder=='run_v5' else SRC/'three_layer_export'/folder
 cm=json.load(open(canonical/'metadata.json'))
 cp(SRC/folder/'metadata.json',Path('provenance/original_metadata')/f'{folder}.json')
 if (SRC/folder/'QA.json').exists():cp(SRC/folder/'QA.json',Path('provenance/original_qa')/f'{folder}.json')
 action=old['action'];frames=[];checks=[];time=0
 for original,f in zip(old['frames'],cm['frames']):
  i=f['frame'];ff=copy.deepcopy(f)
  for n in LAYERS+['composite']:cp(canonical/f'{n}_{i:02}.png',Path(folder)/f'{n}_{i:02}.png')
  im=Image.new('RGBA',(480,320))
  for n in LAYERS:im.alpha_composite(rgba(OUT/folder/f'{n}_{i:02}.png'))
  assert err(im,rgba(OUT/folder/f'composite_{i:02}.png'))==0
  orig=Image.new('RGBA',(480,320));orig.alpha_composite(rgba(SRC/folder/f'composite_{i:02}.png'),(0,40) if folder=='walk' else (0,0));assert err(im,orig)==0
  a=np.array(im)[:,:,3];border=int(np.count_nonzero(np.r_[a[0,:],a[-1,:],a[:,0],a[:,-1]]));assert border==0
  sources=[]
  if original.get('approved_exact_idle'):
   sources.append(source_entry('approved_reference/actions/light_1/composite_00.png','exact_approved_idle',export_translation_only=[85,35],source_is_preapproved_game_sprite=True))
  else:
   path=Path('sources')/Path(original['source_file']).name
   assert sha(OUT/path)==original['source_sha256'],(folder,i,'source hash')
   info={k:original[k] for k in ['source_component','source_rect','source_bbox','source_effective_height','source_standing_ruler','source_root','render_origin','scale'] if k in original}
   if folder=='walk' and 'render_origin' in info:info['render_origin'][1]+=40
   if folder=='run_v5':
    # The inherited v4 upper fields are historical only; preserve only the lower transform here.
    if 'source_part_render' in original:info['render_transform']=original['source_part_render']['lower']
    if i in [1,4]:info['source_component']=0 if i==1 else 1
   sources.append(source_entry(path,'locked_lower_body_original' if folder=='run_v5' else 'native_body_original',**info))
  if folder=='run_v5':
   up=Path('sources')/Path(original['upper_source_file']).name
   assert sha(OUT/up)==original['upper_source_sha256']
   sources.append(source_entry(up,'articulated_upper_body_original',source_component=original['upper_source_component'],source_bbox=original['upper_source_bbox'],source_effective_height=original['upper_source_effective_height'],source_standing_ruler=920,scale=original['upper_scale'],render_origin=original['upper_render_origin']))
   sources.append(source_entry('sources/run_v2_contacts_raw.png','fixed_identity_head_and_collar',source_component=0,source_standing_ruler=920,scale=152/920,base_render_origin=[127.47826086956522,123.20869565217393],offset_canvas=original['head_offset_canvas'],head_extraction='provenance/run_v5/head_master_native.png'))
   sources.append(source_entry(f'provenance/run_v4_locked_baseline/composite_{i:02}.png','accepted_locked_lower_pixels',protected_mask=f'run_v5/masks/protected_legs_{i:02}.png'))
   if i in [3,6]:
    part='near' if i==3 else 'far';sources.append(source_entry(f'sources/run_v4_flight_{part}_seam_raw.png','historical_waist_junction_patch_in_locked_baseline',render_scale=0.1349143610013175,bounded_mask=f'provenance/run_v4/qa/seam_patch_mask_{i:02}_game.png'))
  for ss in sources:source_usage.setdefault(ss['path'],[]).append({'action':action,'frame':i,'role':ss['role']})
  # Build explicit portable runtime-facing metadata, rather than leaking stale v4 upper pointers.
  near=f['feet_canvas']['near'];far=f['feet_canvas']['far'];footmap={'near':near,'far':far}
  identity=original.get('leg_identity',{'near':None,'far':None})
  anatomical={'left':None,'right':None}
  for side,meaning in identity.items():
   if meaning in ['anatomical_left','anatomical_right']: anatomical[meaning.removeprefix('anatomical_')]=footmap[side]
  event=f.get('event')
  markers=[] if event is None else [{'name':event,'basis':'existing_authored_event'}]
  if folder=='walk' and i in [1,5]:markers.append({'name':'far_left_foot_contact' if i==1 else 'near_right_foot_contact','basis':'existing_contact_phase'})
  landing=(folder=='jump' and i==6) or (folder=='down' and i==1)
  settle=(folder=='hurt' and i in [5,6]) or (folder=='jump' and i in [7,8]) or (folder=='down' and i==2) or (folder=='recovering' and i==5) or (folder=='victory_v2' and i==6)
  if landing:markers.append({'name':'landing','basis':'existing_ground_contact_phase; runtime collision still authoritative'})
  if settle:markers.append({'name':'settle','basis':'existing_settle_or_approved_idle_phase'})
  preview=f.get('preview_displacement',f.get('preview_displacement_px',[0,0]))
  support=f.get('support_foot');anat=(identity.get(support) or None) if support in ['near','far'] else support
  r={'frame':i,'duration_ms':f['duration_ms'],'start_ms':f['start_ms'],'phase':f['phase'],'canvas':[480,320],'root_canvas':f['root_canvas'],'root_local':f.get('root_local',[0,0]),'feet_canvas':footmap,'leg_identity':identity,'anatomical_feet_canvas':anatomical,'landmark_source_index':{'near':'near','far':'far'},'anatomical_mapping_status':'source_annotated_not_rig_verified' if all(identity.values()) else 'not_explicitly_registered; runtime mapping must be confirmed','feet_local':{k:[v[0]-f['root_canvas'][0],v[1]-f['root_canvas'][1]] for k,v in footmap.items()},'support_foot':support,'support_anatomical':anat,'grounded':f['grounded'],'grip_canvas':f['grip_canvas'],'hands_canvas':f['hands_canvas'],'weapon_angle_degrees':f['weapon_angle_degrees'],'weapon_angle_convention':'clockwise from approved upward-pointing tachi; screen +x right, +y down','sheath_angle_degrees':f.get('sheath_angle_degrees'),'layer_order':LAYERS,'weapon_behind':False,'body_includes_scabbard':True,'layer_files':{n:f'{n}_{i:02}.png' for n in LAYERS},'composite_file':f'composite_{i:02}.png','event':event,'event_markers':markers,'landing':landing,'settle':settle,'loop_next':f['loop_next'],'is_loop_start':bool(old['loop'] and i==1),'is_loop_end':bool(old['loop'] and i==old['frame_count']),'preview_displacement':preview,'preview_displacement_coordinate_space':'canvas_pixels_relative_to_root; preview only','world_delta':f['world_delta'],'world_motion_owner':'runtime_controller','world_travel_preview_only':f.get('world_travel_preview_only',[0,0]),'fx':None,'source_parts':sources}
  if folder=='run_v5':r.update(protected_mask=f'masks/protected_legs_{i:02}.png',editable_upper_cloth_mask=f'masks/editable_upper_cloth_{i:02}.png',editable_weapon_hand_mask=f'masks/editable_weapon_hand_{i:02}.png')
  assert r['start_ms']==time;time+=r['duration_ms'];assert r['root_canvas']==[220,280]
  frames.append(r);checks.append({'frame':i,'recomposition_max_rgba_error':0,'unchanged_approved_art_max_rgba_error':0,'alpha_border_nonzero_pixels':border,'duration_ms':r['duration_ms'],'start_ms':r['start_ms'],'source_hashes_verified':True})
 assert time==old['total_ms']
 mode,destination=terminal[folder]
 meta={'schema_version':'ieyasu-final-v1','hero':'ieyasu06','action':action,'revision_folder':folder,'revision':folder+'_accepted_final','approval':'accepted','approval_basis':APPROVAL,'canvas':[480,320],'canonical_root':[220,280],'coordinate_system':{'origin':'top-left','x':'right','y':'down','units':'pixels','foot_identity':'near/far retain original visual landmark indexes; anatomical left/right are supplied only when explicitly source-annotated, otherwise null pending runtime mapping'},'standing_ruler_target_px':152,'per_frame_bbox_height_normalization':False,'export_resampling':False,'layers':LAYERS,'body_includes_scabbard':True,'scabbard_merge':'sheath composited behind original body at game resolution; no resampling','layer_order':LAYERS,'frame_count':len(frames),'total_ms':time,'loop':old['loop'],'loop_start':1 if old['loop'] else None,'loop_end':len(frames) if old['loop'] else None,'terminal_behavior':{'mode':mode,'destination':destination,'runtime_wiring_verified':False},'ordinary_action_fx':False,'shared_idle':'../idle/registration.json','source_parts_paths_relative_to':'character bundle root, not metadata directory','direct_approved_references':reference_paths,'original_metadata_archive':f'../provenance/original_metadata/{folder}.json','world_motion':{'mode':'runtime_controller','per_frame_delta':[0,0],'preview_motion_not_baked':True,'speed_and_physics_verified':False},'preview_motion':old.get('preview_motion',{'mode':'authored_preview_offsets_only'}),'frames':frames,'runtime_integrated':False,'runtime_validation':'not_run','limitations':['Foot and grip points are authored visual measurements, not skeletal-rig simulation.','Visual acceptance does not validate state-machine, collision, physics, speed, interrupts, input or game playback.','Preserve root alignment and pixel size; do not normalize frame bounding boxes or re-render from preview GIFs.']}
 if folder=='run_v5':meta['lower_body_approval']=old['lower_body_approval'];meta['legacy_preview_variant_note']='world_travel_preview_only values retained for reference; this bundle includes only existing delivered preview files, not an invented world-preview.gif.'
 write(f'{folder}/metadata.json',meta)
 # Existing delivered previews are copied byte-for-byte, captions can show their historical revision text.
 previews=[]
 for p in sorted((SRC/folder).glob('*')):
  if p.is_file() and (p.suffix=='.gif' or p.name in ['idle-comparison.png','idle-walk-comparison.png','numbered-pose-strip.png']):
   cp(p,Path(folder)/'previews'/p.name);previews.append(f'{folder}/previews/{p.name}')
 lp=SRC/'library_manifest.json' if folder=='walk' else SRC/folder/'library_result.json';libs=[]
 if lp.exists():
  dat=json.load(open(lp));dat=dat.get('structuredContent',{}).get('results',dat.get('results',[])) if isinstance(dat,dict) else dat
  libs=[{'file_name':x['file_name'],'library_file_id':x['library_file_id'],'version':x.get('current_version_number',0)} for x in dat]
 report['actions'][action]={'revision':folder,'frame_count':len(frames),'total_ms':time,'checks':checks}
 catalog.append({'action':action,'revision_folder':folder,'approval':'accepted','approval_message_id':APPROVAL['message_id'],'frame_count':len(frames),'total_ms':time,'metadata':f'{folder}/metadata.json','preview_files':previews,'delivered_library_artifacts':libs,'runtime_integrated':False})

# Recheck run v5 protections from actual exported pixels, not prior QA assertions.
oldrun=json.load(open(SRC/'run_v4/metadata.json'))
newrun=json.load(open(OUT/'run_v5/metadata.json'))
for i,f in enumerate(newrun['frames'],1):
 mask=np.array(Image.open(OUT/f'run_v5/masks/protected_legs_{i:02}.png').convert('L'))>0
 delta=np.abs(arr(OUT/f'run_v5/composite_{i:02}.png')-arr(OUT/f'provenance/run_v4_locked_baseline/composite_{i:02}.png'))
 layererr={}
 for n in ['body','weapon','sheath','hand_occlusion']:
  x=arr(OUT/f'provenance/run_v5_original_four_layers/{n}_{i:02}.png');y=arr(OUT/f'provenance/run_v4_locked_baseline/{n}_{i:02}.png');layererr[n]=int(np.abs(x-y)[mask].max())
 check={'frame':i,'protected_rgba_max_error':int(delta[mask].max()),'protected_changed_pixels':int(np.any(delta>0,axis=2)[mask].sum()),'four_layer_protected_errors':layererr,'anchors_unchanged':all(f[k]==oldrun['frames'][i-1][k] for k in ['root_canvas','duration_ms','start_ms','world_delta','preview_displacement']),'near_far_foot_points_unchanged':all(f['feet_canvas'][k]==oldrun['frames'][i-1]['feet_canvas'][k] for k in ['near','far'])}
 assert check['protected_rgba_max_error']==0 and max(layererr.values())==0 and check['anchors_unchanged'] and check['near_far_foot_points_unchanged'];report['run_v5_locked_legs'].append(check)
for name,a,b in [('down_last_to_recovering_first','down/composite_02.png','recovering/composite_01.png'),('recovering_last_to_idle','recovering/composite_05.png','idle/composite.png'),('hurt_last_to_idle','hurt/composite_06.png','idle/composite.png'),('jump_last_to_idle','jump/composite_08.png','idle/composite.png'),('victory_last_to_idle','victory_v2/composite_06.png','idle/composite.png')]:
 value=err(rgba(OUT/a),rgba(OUT/b));assert value==0;report['seams'][name]={'max_rgba_error':value,'root_delta':[0,0]}
report['idle']={'recomposition_max_rgba_error':0,'translation_only':[85,35],'preapproved_combat_source_hash_verified':True}
portrait_expected=rgba(OUT/'approved_reference/actions/light_1_source.png').crop(reg['portrait']['crop'])
assert err(portrait_expected,rgba(OUT/'portrait/portrait.png'))==0
report['portrait']={'original_crop_rgba_max_error':0,'redrawn':False}
raw_inventory=[]
for p in sorted((OUT/'sources').iterdir()):
 if not p.is_file():continue
 im=Image.open(p);im.load();path=rel(p)
 category=('historical_derived_component' if p.name.startswith('frame_') else 'preserved_raw_generation_source') if p.name.endswith('_raw.png') else 'historical_derived_review'
 raw_inventory.append({'path':path,'sha256':sha(p),'bytes':p.stat().st_size,'dimensions':list(im.size),'mode':im.mode,'classification':category,'selected_in_current':path in source_usage,'usage':source_usage.get(path,[]),'original_bytes_match':sha(p)==sha(SRC/'sources'/p.name)})
assert all(x['original_bytes_match'] for x in raw_inventory)
write('source_manifest.json',{'scope':'All 66 files from the preserved source directory; unused/rejected raw originals are historical only. Only current metadata source_parts select art.','files':raw_inventory,'references':[source_entry(p,'approved_identity_or_weapon_reference') for p in reference_paths]})
report['frame_count']=sum(x['frame_count'] for x in catalog);assert report['frame_count']==50
report['accepted_action_count']=9
report['source_originals_byte_exact']=True
report['minimum_recorded_selected_new_figure_height_px']=min(s['source_effective_height'] for row in catalog for f in json.load(open(OUT/row['metadata']))['frames'] for s in f['source_parts'] if 'source_effective_height' in s)
assert report['minimum_recorded_selected_new_figure_height_px']>=600
report['source_height_note']='Selected native figure heights are preserved production measurements checked against their declared source bbox; approved existing idle/portrait/weapon and local seam-patch crops are not newly generated whole figures.'
report['not_run']=['game engine import','runtime animation/state-machine execution','input or interruption tests','collision and jump/launch landing physics','world speed and foot-slide calibration','weapon socket runtime attachment','left-facing mirror or depth-sorting engine tests','anatomical left/right mapping for unannotated near/far landmarks','deployment or Git push']
write('QA.json',report)
write('character_manifest.json',{'schema_version':'ieyasu-final-v1','hero':'ieyasu06','approval':'accepted','approval_basis':APPROVAL,'action_count':9,'frame_count':50,'canvas':[480,320],'root':[220,280],'standing_ruler_px':152,'layers':LAYERS,'body_includes_scabbard':True,'current_run_revision':'run_v5','current_victory_revision':'victory_v2','idle':'idle/registration.json','portrait':'portrait/portrait.png','portrait_provenance':'portrait/provenance.json','actions':catalog,'source_manifest':'source_manifest.json','qa':'QA.json','integrity_manifest':'SHA256SUMS','runtime_integrated':False,'runtime_validation':'not_run','historical_data_policy':'provenance and unselected sources are evidence only, not selectable actions','original_assets_mutated':False})
write('integration_manifest.json',{'schema_version':'ieyasu-integration-v1','character':'ieyasu06','accepted_event':APPROVAL,'runtime_tested':False,'standing_ruler_px':152,'canvas':[480,320],'canonical_root':[220,280],'character_manifest':'character_manifest.json','idle_registration':'idle/registration.json','idle_material_directory':'idle','portrait_registration':'portrait/provenance.json','portrait':'portrait/portrait.png','actions':[{'action':x['action'],'revision':x['revision_folder'],'frame_count':x['frame_count'],'total_duration_ms':x['total_ms'],'loop':json.load(open(OUT/x['metadata']))['loop'],'terminal_hold':x['action'] in ['down','launched'],'terminal_behavior':json.load(open(OUT/x['metadata']))['terminal_behavior'],'metadata':x['metadata'],'material_directory':x['revision_folder'],'accepted_event':APPROVAL['message_id']} for x in catalog],'landmark_contract':'near/far preserve the authored source indexes. Walk has original anatomical annotations; all unannotated anatomical left/right values are null and require runtime mapping confirmation. Do not infer anatomical identity from file names.','runtime_todo':report['not_run']})
(OUT/'README.txt').write_text('''家康 06 最終 Git 展開交接包\n\n整合入口：integration_manifest.json；完整角色索引：character_manifest.json。9 組、50 格，全部依 Sentinel_003f9aaa53ac819191a42c7ac9485ce8 核准。\nrun 必須採 run_v5；victory 採 victory_v2。provenance 內的舊 run_v4、candidate 字樣或舊 QA 狀態只屬歷史，不是目前狀態。\n\n畫布 480×320，root [220,280]，固定 152px 站高尺規。walk 使用既有三層導出，僅比原生畫布向下平移 40px；idle 原核准 520×280 圖只整數平移 [85,35]。沒有按逐格 bbox 拉等高或再次縮圖。\n三透明層順序 body → weapon → hand_occlusion。sheath 已在原遊戲解析度先合到 body 背後，不需第四個 sheath。\n每格 metadata 有毫秒時長、起始時間、root、near/far 腳點與原索引（left/right 僅在原紀錄有標註時提供，否則 null 待確認）、握點、武器角度、前後層、loop、landing/settle、preview 與 world 分離。source_parts 的路徑以本角色包根目錄為準。\npreview GIF 是既有交付原檔；歷史標題文字及用於預覽的位移不能作為 runtime 狀態或世界位移來源。\n\n所有 sources 原檔及核准母圖均保留。未選入的舊稿只作歷史。正式圖像和 50 格三層重組逐像素一致。run_v5 6 格的鎖腿 mask 區域與 run_v4 完全一致。down→recovering→idle 接縫及 hurt/jump/victory 回 idle 已作像素檢查。\nQA.json 是離線檔案、像素、metadata 和 SHA 驗證，沒有遊戲 runtime 測試。\n\n驗證：python validate_bundle.py；依賴 Pillow、NumPy。SHA256SUMS 包含每個交付檔案（自身除外）。\n此工作只建立新展開包，未改動舊素材、舊 zip、站或 Git。\n''')
(OUT/'CODEX_HANDOFF.txt').write_text('''1. 從 character_manifest.json 載入九個 action；run_v5 / victory_v2 是唯一目前版本，勿掃 provenance 當動作。\n2. body 已包含 sheath，依 body→weapon→hand_occlusion 合成；保持 canvas/root 與 152 站高，不按武器或姿勢 bbox 調大小。\n3. 逐格 duration_ms 是播放時長；loop_next=null 的單次動作請遵守 terminal_behavior。down 要 hold，launched 等碰地再接 down，jump 的實際落地由碰撞決定。\n4. preview_displacement、world_travel_preview_only 只供演示；world_delta 全 0，實際行走/跑步速度、擊退和跳躍由 runtime controller 處理，勿重複套位移。\n5. 角度為既有朝上 tachi 的順時針旋轉，畫布 y 向下。腳點/握點為視覺標記；runtime 骨架/武器 socket、深度及朝向鏡像仍需驗。\n6. 尚待 runtime：導入與三層繪製、九狀態與中斷/重播、walk/run 速度與落腳滑動、jump/launched 碰撞落地、down→recovering→idle、握刀遮擋/翻面、實際遊戲幀率與採樣。此包未執行以上測試。\n7. 先跑 validate_bundle.py 和 SHA256SUMS。此角色交接不含 push/runtime；後續由整合工作執行，不把離線 QA 當 runtime 通過。\n''')
# Check all frame source paths, bbox bounds and source-height accounting.
for row in catalog:
 for f in json.load(open(OUT/row['metadata']))['frames']:
  for s in f['source_parts']:
   p=OUT/s['path'];assert p.exists() and sha(p)==s['sha256']
   if 'source_bbox' in s:
    box=s['source_bbox'];w,h=Image.open(p).size;assert 0<=box[0]<box[2]<=w and 0<=box[1]<box[3]<=h
    if 'source_effective_height' in s:assert box[3]-box[1]==s['source_effective_height']
# Integrity generated last by separate validator refresh, avoiding self-reference.
files=[p for p in OUT.rglob('*') if p.is_file() and p.name not in ['SHA256SUMS','FILE_MANIFEST.json'] and '__pycache__' not in p.parts]
assert max(p.stat().st_size for p in files)<100_000_000
write('FILE_MANIFEST.json',{'files':[{'path':rel(p),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(files)],'file_count_excluding_integrity_manifests':len(files),'max_file_bytes':max(p.stat().st_size for p in files),'single_file_limit_bytes':100_000_000})
files=sorted(p for p in OUT.rglob('*') if p.is_file() and p.name!='SHA256SUMS' and '__pycache__' not in p.parts)
(OUT/'SHA256SUMS').write_text(''.join(f'{sha(p)}  {rel(p)}\n' for p in files))
print(json.dumps({'entry':str(OUT/'character_manifest.json'),'actions':9,'frames':50,'run':'run_v5','max_file_bytes':max(p.stat().st_size for p in files),'files':len(files)+1,'total_bytes':sum(p.stat().st_size for p in files),'new_figure_min_height':report['minimum_recorded_selected_new_figure_height_px'],'runtime_tested':False},indent=2))
