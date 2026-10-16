import pathlib,json,hashlib,subprocess as sp,numpy as np,zipfile
P=pathlib.Path(__file__).parent;V1=P.parent/'weapon_sfx_v2';qa=[]
for p in sorted((P/'processed').glob('*/*')):
 x=np.frombuffer(sp.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','1','-ar','48000','-']),dtype='<f4');peak=float(np.max(abs(x)))
 qa.append(dict(file=str(p.relative_to(P)),samples=len(x),seconds=len(x)/48000,decoded_peak_dbfs=20*float(np.log10(peak)),clipped_samples=int(np.sum(abs(x)>=1)),finite=bool(np.isfinite(x).all())))
assert len(qa)==196 and all(q['clipped_samples']==0 and q['finite'] for q in qa)
checks=[]
for p in sorted((P/'processed').glob('*/*')):
 if (V1/p.relative_to(P)).exists():
  assert p.read_bytes()==(V1/p.relative_to(P)).read_bytes();checks.append(str(p.relative_to(P)))
x=np.frombuffer(sp.check_output(['ffmpeg','-v','error','-i',str(P/'Sengoku_All_Weapons_Preview_v3.mp3'),'-f','f32le','-ac','1','-ar','48000','-']),dtype='<f4');assert np.max(abs(x))<1
(P/'docs/QA.json').write_text(json.dumps(dict(status='196 files decoded; finite; zero digital clipping; 64 v2 files verified bit-identical',subjective_listening=False,runtime_validation=False,unchanged_files=checks,preview_decoded_peak_dbfs=20*float(np.log10(max(abs(x)))),files=qa),indent=2))
files=[p for p in P.rglob('*') if p.is_file() and (not ('originals' in p.parts) or p.suffix=='.zip') and p.name not in ['preview.wav','SHA256SUMS.txt']]
(P/'SHA256SUMS.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(P)) for p in files)+'\n');files.append(P/'SHA256SUMS.txt')
out=P.parent/'Sengoku_All_Weapons_SFX_v3.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,str(p.relative_to(P)))
with zipfile.ZipFile(out) as z:assert z.testzip() is None
print(out.resolve(),out.stat().st_size,len(files),'max decoded peak',max(q['decoded_peak_dbfs'] for q in qa),'unchanged files',len(checks))
