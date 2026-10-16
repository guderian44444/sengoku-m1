from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,copy,hashlib
B=Path(__file__).parent;OUT=B/'three_layer_export';OUT.mkdir(exist_ok=True)
ACTIONS=['walk','hurt','stunned','jump','launched','down','recovering','victory_v2']
report={'status':'technical_checks_only_not_user_approval','canvas':[480,320],'root':[220,280],'standing_ruler':152,'three_layers':['body','weapon','hand_occlusion'],'body_includes':'approved scabbard behind character, merged at game resolution without resampling','actions':{},'seams':{}}
preview=[];catalog=[]
for act in ACTIONS:
 p=B/act;out=OUT/act;out.mkdir(exist_ok=True);m=json.loads((p/'metadata.json').read_text());frames=[];offset=(0,40) if act=='walk' else (0,0);tests=[]
 for f in m['frames']:
  i=f['frame'];lays={n:Image.open(p/f'{n}_{i:02}.png').convert('RGBA') for n in ['sheath','body','weapon','hand_occlusion','composite']}
  original=Image.new('RGBA',lays['body'].size)
  for n in ['sheath','body','weapon','hand_occlusion']:original.alpha_composite(lays[n])
  assert np.array_equal(np.array(original),np.array(lays['composite'])),(act,i,'original four layer mismatch')
  merged=Image.new('RGBA',original.size);merged.alpha_composite(lays['sheath']);merged.alpha_composite(lays['body'])
  export={}
  for n,im in [('body',merged),('weapon',lays['weapon']),('hand_occlusion',lays['hand_occlusion'])]:
   can=Image.new('RGBA',(480,320));can.alpha_composite(im,offset);can.save(out/f'{n}_{i:02}.png');export[n]=can
  co=Image.new('RGBA',(480,320))
  for n in ['body','weapon','hand_occlusion']:co.alpha_composite(export[n])
  ref=Image.new('RGBA',(480,320));ref.alpha_composite(lays['composite'],offset)
  diff=np.abs(np.array(co).astype('int16')-np.array(ref).astype('int16'));assert diff.max()==0,(act,i,'three layer mismatch')
  co.save(out/f'composite_{i:02}.png');a=np.array(co)[:,:,3];border=int(np.count_nonzero(np.r_[a[0],a[-1],a[:,0],a[:,-1]]));assert border==0
  tests.append({'frame':i,'recomposition_max_rgba_error':int(diff.max()),'nonzero_border_pixels':border,'alpha_range':[int(a.min()),int(a.max())],'transparent_pixels':int((a==0).sum()),'bbox':list(co.getbbox())})
  r=copy.deepcopy(f);r['source_file']='../'+r['source_file'];r['layer_order']=['body','weapon','hand_occlusion'];r['original_four_layer_dir']='../../'+act;r['export_translation_only']=list(offset)
  for key in ['root_canvas','grip_canvas','render_origin']:
   if key in r:r[key]=[r[key][0]+offset[0],r[key][1]+offset[1]]
  for key in ['feet_canvas']:
   if key in r:r[key]={k:[v[0]+offset[0],v[1]+offset[1]] for k,v in r[key].items()}
  if 'hands_canvas' in r:r['hands_canvas']=[[v[0]+offset[0],v[1]+offset[1]] for v in r['hands_canvas']]
  frames.append(r)
 em=copy.deepcopy(m);em['layers']=['body','weapon','hand_occlusion'];em['frames']=frames;em['body_includes_scabbard']=True;em['canvas']=[480,320];em['canonical_root']=[220,280];em['original_metadata']='../../'+act+'/metadata.json';em['export_resampling']=False;(out/'metadata.json').write_text(json.dumps(em,indent=2))
 report['actions'][act]={'frame_count':len(frames),'tests':tests,'new_source_min_height':min(f['source_effective_height'] for f in frames if not f.get('approved_exact_idle'))}
 lp=B/'library_manifest.json' if act=='walk' else p/'library_result.json';r=json.loads(lp.read_text());r=r.get('structuredContent',{}).get('results',[]) if isinstance(r,dict) else r
 catalog.append({'action':m['action'],'revision_folder':act,'status':'candidate_pending_user','frames':len(frames),'duration_ms':m['total_ms'],'metadata':str((p/'metadata.json').resolve()),'three_layer_metadata':str((out/'metadata.json').resolve()),'library':[{'file_name':x['file_name'],'library_file_id':x['library_file_id']} for x in r]})
 idx=min(len(frames),max(2,len(frames)//2));im=Image.open(out/f'composite_{idx:02}.png');card=Image.new('RGB',(960,320));
 for k,bg in enumerate(['#eeeeee','#252b34']):
  bgim=Image.new('RGBA',(480,320),bg);bgim.alpha_composite(im);card.paste(bgim.convert('RGB'),(k*480,0));ImageDraw.Draw(card).text((k*480+12,10),act+' alpha edge '+('light' if k==0 else 'dark'),fill='black' if k==0 else 'white')
 preview.append(card)
# Pixel exact seam tests and root-aligned visualization
idle=Image.new('RGBA',(480,320));idle.alpha_composite(Image.open(B/'idle/composite.png').convert('RGBA'),(85,35));idle.save(OUT/'approved_idle.png')
x=Image.open(OUT/'down/composite_02.png');y=Image.open(OUT/'recovering/composite_01.png');z=Image.open(OUT/'recovering/composite_05.png')
report['seams']['down_last_to_recovering_first']={'max_rgba_error':int(np.abs(np.array(x).astype('int16')-np.array(y).astype('int16')).max()),'root_delta':[0,0]}
report['seams']['recovering_last_to_approved_idle']={'max_rgba_error':int(np.abs(np.array(z).astype('int16')-np.array(idle).astype('int16')).max()),'root_delta':[0,0]}
assert all(v['max_rgba_error']==0 for v in report['seams'].values())
qa=B/'qa_eight_actions';qa.mkdir(exist_ok=True)
sheet=Image.new('RGB',(1920,1280))
for i,im in enumerate(preview):sheet.paste(im,((i%2)*960,(i//2)*320))
sheet.save(qa/'alpha_light_dark.png');ss=Image.new('RGB',(1920,320),'#252b34')
for i,(im,label) in enumerate([(x,'DOWN last'),(y,'RECOVERING first - exact match'),(z,'RECOVERING last'),(idle,'APPROVED IDLE - exact match')]):ss.paste(im,(i*480,0),im);ImageDraw.Draw(ss).text((i*480+12,10),label,fill='white')
ss.save(qa/'seams.png')
seq=[('down',1,130),('down',2,500),('recovering',2,200),('recovering',3,190),('recovering',4,180),('recovering',5,600)];ims=[]
for act,i,d in seq:
 im=Image.new('RGBA',(480,320),'#252b34');im.alpha_composite(Image.open(OUT/act/f'composite_{i:02}.png'));im=im.convert('RGB');ImageDraw.Draw(im).text((12,10),f'{act} / {i}',fill='white');ims.append(im)
ims[0].save(qa/'down_recovering_idle_once.gif',save_all=True,append_images=ims[1:],duration=[t[2] for t in seq],disposal=2)
(qa/'report.json').write_text(json.dumps(report,indent=2));(B/'eight_action_catalog.json').write_text(json.dumps(catalog,indent=2));print(json.dumps({'actions':len(ACTIONS),'frames':sum(v['frame_count'] for v in report['actions'].values()),'seams':report['seams'],'all_recomposition_error':0,'all_alpha_border_pixels':0},indent=2))
