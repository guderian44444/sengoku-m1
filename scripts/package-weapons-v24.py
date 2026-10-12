#!/usr/bin/env python3
"""Bounded 15 MB overlay packages; never include caches or third-party photos."""
from pathlib import Path
import json,zipfile,hashlib,shutil

ROOT=Path(__file__).resolve().parents[1];DATA=ROOT/'game/assets/v24/weapons'
OUT=ROOT/'artifacts/weapon-expansion-v24';DEST=OUT/'delivery';DEST.mkdir(exist_ok=True)
MAX_BYTES=15_000_000
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
items=json.loads((DATA/'art-spec30.json').read_text())['items'];reg=json.loads((ROOT/'game/assets/v22/weapons/registration.json').read_text())
base=json.loads((DATA/'base-file-sha256.json').read_text())
core=[ROOT/p for p in base]
core += [ROOT/p for p in ['game/tests/test_weapon_expansion_v24.gd','scripts/build-weapon-catalog-v24.py','scripts/prepare-weapon-art-v24.py','scripts/test-weapon-art-v24.py','scripts/preview-weapons-v24.py','scripts/package-weapons-v24.py','docs/weapon-expansion-v24.md']]
core += [p for p in (ROOT/'game/assets/v24').rglob('*') if p.is_file() and '/raw/' not in str(p) and p.suffix not in ['.import','.uid']]
core=sorted(set(core))
runtime={}
for family in ['sword','spear','bow']:
 files=[]
 for item in items:
  if item['family']!=family:continue
  id=item['id'];files.extend(ROOT/'game/assets/v22/weapons'/name for name in [reg['items'][id]['file'],reg['sources'][id]['file']])
 runtime[family]=sorted(files+(core if family=='sword' else []))
allruntime=sorted(set(p for group in runtime.values() for p in group))
install={'base_description':'2ac0688 + approved 18-weapon/encyclopedia expansion + finalized three-character palette correction','base_sha256':base,'runtime_sha256':{str(p.relative_to(ROOT)):sha(p) for p in allruntime},'preserved_characters':json.loads((DATA/'characters-protected-before.json').read_text())['files'],'preserved_18_weapons':json.loads((DATA/'protected-before.json').read_text()),'required_packages':['sengoku-v24-runtime-sword-core.zip','sengoku-v24-runtime-spear.zip','sengoku-v24-runtime-bow.zip']}
(DEST/'install-manifest.json').write_text(json.dumps(install,ensure_ascii=False,indent=2)+'\n')
(DEST/'verify-installed-v24.py').write_text('''#!/usr/bin/env python3
from pathlib import Path
import json,hashlib,sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
manifest=json.loads((Path(__file__).parent/'install-manifest.json').read_text())
expected=manifest['runtime_sha256'] if '--base' not in sys.argv else manifest['base_sha256']
if '--base' not in sys.argv:
 expected={**expected,**manifest['preserved_characters'],**manifest['preserved_18_weapons']}
errors=[]
for path,digest in expected.items():
 p=root/path
 if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:errors.append(path)
if errors:
 print('Files missing or different:\\n'+'\\n'.join(errors));raise SystemExit(1)
print('PASS: '+str(len(expected))+' exact files; '+('base ready' if '--base' in sys.argv else 'runtime installed and approved art unchanged'))
''')
readme='''吞食戰國 v24：新增刀、槍、弓各10件，共48件

必裝：三個 runtime ZIP 全部解壓到同一個已完成前輪18件＋校色的專案根目錄。
順序：sword-core、spear、bow。保留原有game/scripts/docs，不另建一層專案資料夾。
這是增量，不能單獨啟動。先備份自行修改的檔案；不是整個repo。

檢查基礎版本（覆蓋前）：python verify-installed-v24.py /your/project --base
檢查完成安裝（覆蓋後）：python verify-installed-v24.py /your/project

raw-originals三包是30張imagegen原始圖，只在重建美術/驗證來源時需要；正常遊戲已附完成的sprite和alpha處理後來源。
attack-review包是30張普通/重擊雙向逐格圖、總覽及QA，不放進遊戲也能用。
三段MP4各30秒，每把都有兩招六格雙向；它們是素材合成，非實機錄影。

史料與遊戲能力分開；新照片未得重製授權，只附來源入口，不包研究照片。
每張原創美術均獨立生成。alpha清理、原圖/裁切SHA、握點、tip、尺度可重現。
原18件及三人462格像素／角色登錄保留。弓保持約172世界單位。
font fallback補齊匂等20字，附OFL，原主字型不變。

本輪QA結果見QA-SUMMARY.txt。未做原生視窗、人手控制器或實機網路驗收。
原projectile_v12基線62fail仍存在，不能說全專案測試皆通過。
'''
(DEST/'README-安裝.txt').write_text(readme)
packages=[]
def write_zip(name,files,extras=()):
 path=DEST/name
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in files:
   assert p.is_file() and p.suffix not in ['.import','.uid','.pyc']
   z.write(p,str(p.relative_to(ROOT)))
  for p in extras:z.write(p,p.name)
 assert path.stat().st_size<MAX_BYTES,(name,path.stat().st_size)
 packages.append({'file':name,'bytes':path.stat().st_size,'sha256':sha(path),'entries':len(files)+len(extras)})
extra=[DEST/'README-安裝.txt',DEST/'install-manifest.json',DEST/'verify-installed-v24.py']
if (OUT/'QA-SUMMARY.txt').exists():extra.append(OUT/'QA-SUMMARY.txt')
for family,files in runtime.items():write_zip('sengoku-v24-runtime-'+family+('-core' if family=='sword' else '')+'.zip',files,extra if family=='sword' else [])
for family in ['sword','spear','bow']:write_zip('sengoku-v24-raw-originals-'+family+'.zip',[ROOT/x['raw_source'] for x in items if x['family']==family])
review=sorted(OUT.glob('*/*-attacks.png'))+[OUT/'weapon-30-overview.png',OUT/'composition-audit-all.json',OUT/'art-validation.json']
for p in ['QA-SUMMARY.txt','video-validation.json','independent-review.json','test-summary.json']:
 if (OUT/p).exists():review.append(OUT/p)
if (OUT/'test-summary.json').exists():
 tests=json.loads((OUT/'test-summary.json').read_text())
 for test in tests['selected_groups']:
  folder=(ROOT/test['report']).parent
  review.extend([ROOT/test['report'],folder/(test['name']+'.log')])
 review.extend([ROOT/tests['legacy_separate']['report'],ROOT/'artifacts/native-v24/legacy-projectile/projectile_v12.log'])
review=sorted(set(review))
if (DEST/'clean-overlay-verification.json').exists():review.append(DEST/'clean-overlay-verification.json')
write_zip('sengoku-v24-attack-review.zip',review)
# Validate archives, path safety, exact payload bytes, and the complete union.
expected={str(p.relative_to(ROOT)):sha(p) for p in allruntime}
seen={}
for spec in packages:
 with zipfile.ZipFile(DEST/spec['file']) as z:
  assert z.testzip() is None
  for name in z.namelist():
   assert not name.startswith('/') and '..' not in Path(name).parts
   if name in expected:
    digest=hashlib.sha256(z.read(name)).hexdigest();assert digest==expected[name];seen[name]=digest
assert seen==expected
result={'packages':packages,'runtime_files':len(expected),'runtime_archive_union_matches_source':True,'per_file_limit_bytes':MAX_BYTES,'source_photos_included':False,'cache_or_user_save_files_included':False}
(DEST/'package-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
