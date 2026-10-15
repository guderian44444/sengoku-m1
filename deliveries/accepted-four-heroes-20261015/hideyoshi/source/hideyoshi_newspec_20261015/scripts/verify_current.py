from pathlib import Path
from PIL import Image
import json,hashlib
P=Path(__file__).resolve().parents[1];m=json.loads((P/'review_manifest.json').read_text());out=[]
for a in m['actions']:
 g=Image.open(a['gif']);ds=[]
 for i in range(g.n_frames):g.seek(i);g.convert('RGB').load();ds.append(g.info['duration'])
 assert g.n_frames==a.get('preview_frame_count',a['frame_count']),a['id'];assert sum(ds)==a.get('preview_duration_ms',a['duration_ms']),(a['id'],ds)
 meta=json.loads(Path(a['metadata']).read_text());r={'id':a['id'],'revision':a.get('revision'),'frames':g.n_frames,'actor_frame_count':a['frame_count'],'actor_duration_ms':a['duration_ms'],'duration_ms':sum(ds),'gif_sha256':hashlib.sha256(Path(a['gif']).read_bytes()).hexdigest(),'decoded_all_frames':True,'visual_method':'contact-sheet inspection plus decoded GIF frames; no claim of browser playback'}
 out.append(r)
(P/'verified_gifs.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print('PASS',len(out),'actions',sum(x['frames'] for x in out),'frames')
