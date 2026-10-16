from pathlib import Path
import json,hashlib,argparse
from PIL import Image
import numpy as np
parser=argparse.ArgumentParser();parser.add_argument('--integration',action='store_true');args=parser.parse_args()
root=Path(__file__).resolve().parents[2];v=root/'game/vfx/v2';cat=json.load(open(v/'catalog.json'))['effects'];recipes=json.load(open(v/'effect_recipes.json'))['recipes'];audio=json.load(open(v/'audio/manifest.json'))['assets'];report={'assets':{},'recipe_count':len(recipes),'audio_cues':len(audio),'limitations':['This validator does not perform native GPU capture or listening','No battle hitbox, reload or penetration changes']}
for id,spec in cat.items():
 p=root/'game'/spec['texture'].removeprefix('res://');assert p.is_file(),id;sha=hashlib.sha256(p.read_bytes()).hexdigest();assert sha==spec['sha256'],id
 im=Image.open(p);assert im.mode=='RGBA',id;a=np.asarray(im.getchannel('A'));assert a.min()==0 and a.max()>150 and ((a>0)&(a<255)).any(),id
 assert spec['frames']==1 and spec.get('columns',1)==1,id
 assert tuple(spec['cell'])==im.size,id
 report['assets'][id]={'size':im.size,'sha256':sha,'frames':1,'partial_alpha_fraction':float(((a>0)&(a<255)).mean()),'clear_fraction':float((a==0).mean()),'gpu_rgba_bytes':im.width*im.height*4}
for id,recipe in recipes.items():
 assert recipe['initial_phase'] in recipe['phases'],id
 for name,phase in recipe['phases'].items():
  assert phase['duration_ticks']>0,(id,name)
  assert not phase.get('next') or phase['next'] in recipe['phases'],(id,name)
  for layer in phase.get('layers',[]):assert layer['effect'] in cat,(id,layer['effect'])
  for curves in [phase.get('curves',{})]+[l.get('curves',{}) for l in phase.get('layers',[])]:
   for keys in curves.values():
    assert all(len(k)==2 and 0<=k[0]<=1 for k in keys),(id,keys)
    assert all(a[0]<b[0] for a,b in zip(keys,keys[1:])),(id,keys)
 for key in recipe.get('audio',{}).values():
  for variant in range(4):assert key.replace('{variant}',str(variant)) in audio,(id,key)
 if recipe.get('hit_effect'):assert recipe['hit_effect'] in cat,id
for key,s in audio.items():
 for fmt in ['wav','ogg']:assert (v/'audio'/s[fmt]).is_file(),(key,fmt)
base=json.load(open(v/'provenance/v1-base-files.json'))
repairs=json.load(open(root/'docs/vfx-native-repairs-v30.json'))['files'] if args.integration else {}
unchanged=0;repaired=[]
for entry in base['files']:
 actual=hashlib.sha256((root/entry['path']).read_bytes()).hexdigest()
 if actual==entry['sha256']:unchanged+=1;continue
 repair=repairs.get(entry['path'],{})
 assert repair.get('source_sha256')==entry['sha256'] and repair.get('runtime_sha256')==actual,('unreviewed v1 change',entry['path'])
 repaired.append(entry['path'])
for path,repair in repairs.items():assert hashlib.sha256((root/path).read_bytes()).hexdigest()==repair['runtime_sha256'],('native repair changed',path)
report['v1_unchanged_files']=unchanged;report['reviewed_v1_native_repairs']=repaired;report['gpu_rgba_bytes_total']=sum(x['gpu_rgba_bytes'] for x in report['assets'].values());report['checks']=['All RGBA/partial alpha/source hashes','Honest one author frame per base','All recipe textures/audio keys present','Sorted finite-domain scalar curves','Original v1 freeze or explicitly hashed native mesh repair']
(root/('docs/shared-vfx-v30-validation.json' if args.integration else 'docs/shared-vfx-v2-validation.json')).write_text(json.dumps(report,indent=2))
print(f'PASS {len(cat)} bases, {len(recipes)} recipes, {len(audio)} audio keys, {unchanged} v1 files unchanged, {len(repaired)} reviewed native repairs')
