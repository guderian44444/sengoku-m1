from pathlib import Path
from PIL import Image
import json, hashlib
P=Path(__file__).resolve().parent
hashes=json.loads((P/'SHA256SUMS.json').read_text());bad=[]
for name,expected in hashes.items():
 f=P/name
 if not f.exists() or hashlib.sha256(f.read_bytes()).hexdigest()!=expected:bad.append(name)
assert not bad,bad
acts=json.loads((P/'ACTION_MANIFEST.json').read_text());assert len(acts)==17
for a in acts:
 for k in ['asset_directory','metadata','preview','representative']:assert (P/a[k]).exists(),(a['id'],k)
 im=Image.open(P/a['preview']);ms=0
 for i in range(im.n_frames):im.seek(i);ms+=im.info.get('duration',0)
 assert ms==a['duration_ms'],(a['id'],ms,a['duration_ms'])
 print(a['id'],a['playback_keys'],'keys',ms,'ms')
print('PASS',len(hashes),'files; 17 action links and preview durations')
