from pathlib import Path
import sys,json,hashlib,io,subprocess,numpy as np
from PIL import Image
sys.path.insert(0,'scripts');from hero_palette_v23 import hsv,masks,sha
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'game/assets/v22';OUT=ROOT/'artifacts/palette-review';OUT.mkdir(parents=True,exist_ok=True);MANIFEST=json.loads((BASE/'color-consistency.json').read_text());
report={'clips':[],'heroes':{},'invariants':{},'material_metrics':{}}
for hero in ['nobunaga','tadakatsu','oichi']:
 reg=json.loads((BASE/hero/'registration.json').read_text())
 def geometry(r):return {'clips':{k:v['frames'] for k,v in r['clips'].items()},'aliases':r['aliases'],'portrait':r['portrait']}
 assert sha(json.dumps(geometry(reg),sort_keys=True).encode())==MANIFEST['registration_geometry_sha256'][hero]
 metrics=[];count=0
 for clip,c in reg['clips'].items():
  fn=c['frames'][0]['file'];old_bytes=subprocess.check_output(['git','show',MANIFEST['base_commit']+':game/assets/v22/'+hero+'/'+fn],cwd=ROOT);assert sha(old_bytes)==MANIFEST['original_runtime_sources'][hero+'/'+fn];old=np.array(Image.open(io.BytesIO(old_bytes)).convert('RGBA'));new=np.array(Image.open(BASE/hero/fn).convert('RGBA'));assert old.shape==new.shape and np.array_equal(old[...,3],new[...,3]);count+=len(c['frames'])
  v=hsv(old);u=hsv(new);h,s,lum=v.transpose(2,0,1);hh=(h+.5)%1-.5;changed=np.any(old[...,:3]!=new[...,:3],axis=2);opaque=old[...,3]>240
  # A representative midtone-only material sample avoids area and lighting mixtures.
  red=opaque&(abs(hh)<.035)&(s>.6)&(lum>.2)
  red_mid=red&(lum>.5)&(lum<.7)
  gold=opaque&(h>.10)&(h<.175)&(s>.35)&(lum>.25)
  skin=opaque&(h>=.0556)&(h<=.09)&(s>=.2)&(s<=.7)&(lum>.25)
  white=opaque&(s<.25)&(lum>.65)
  neutral=opaque&(s<.4)
  masks0=masks(old)[1];affected=sum(masks0[k] for k in (['red_lacquer_and_cloth','gold_trim'] if hero=='nobunaga' else ['red_cloth']))>0
  assert not changed[~affected].any() if hero!='tadakatsu' else not changed.any()
  assert not changed[skin|white|neutral].any(),(hero,clip,'protected material changed')
  if hero=='oichi':assert np.max(np.abs(v[...,2]-u[...,2]))<.00001,(clip,'brightness changed')
  row={'hero':hero,'clip':clip,'frames':len(c['frames']),'changed_pixels':int(changed.sum()),'alpha_unchanged':True,'registration_unchanged':True,'protected_skin_white_neutral_pixels':int((skin|white|neutral).sum()),'protected_changed':int(changed[skin|white|neutral].sum()),'red_s_before':float(np.median(v[...,1][red])),'red_s_after':float(np.median(u[...,1][red])),'red_v85_before':float(np.quantile(v[...,2][red],.85)),'red_v85_after':float(np.quantile(u[...,2][red],.85)),'red_mid_s_before':float(np.median(v[...,1][red_mid])),'red_mid_s_after':float(np.median(u[...,1][red_mid])),'gold_s_before':float(np.median(v[...,1][gold])),'gold_s_after':float(np.median(u[...,1][gold]))}
  report['clips'].append(row);metrics.append(row)
 report['heroes'][hero]={'clips':len(reg['clips']),'frames':count,'changed_sheets':sum(r['changed_pixels']>0 for r in metrics)}
 for key in ['red_s','red_v85','red_mid_s','gold_s']:
  vals={x:np.array([r[key+'_'+x] for r in metrics]) for x in ['before','after']}
  report['material_metrics'][hero+'/'+key]={x:{'range':float(np.ptp(a)),'std':float(np.std(a)),'min':float(a.min()),'max':float(a.max())} for x,a in vals.items()}
weapons=MANIFEST['protected_weapon_sha256'];assert all(sha((ROOT/p).read_bytes())==d for p,d in weapons.items())
report['invariants']={'runtime_clips':sum(v['clips'] for v in report['heroes'].values()),'runtime_frames':sum(v['frames'] for v in report['heroes'].values()),'alpha_and_shapes_unchanged':True,'all_anchors_hand_occluders_and_aliases_unchanged':True,'weapon_files_unchanged':len(weapons),'approved_bow_world_length':json.loads((BASE/'weapons/registration.json').read_text())['items']['bow_awase_yumi']['world_length'],'skin_white_neutral_core_unchanged':True,'originals_retained':'Original sources retained in the recorded Git base and pre-edit backup'}
(OUT/'color-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'heroes':report['heroes'],'invariants':report['invariants'],'metrics':report['material_metrics']},indent=2))
