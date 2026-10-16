#!/usr/bin/env python3
"""Read-only file checks. Does not run or validate a game engine."""
from pathlib import Path
import json,hashlib
B=Path(__file__).resolve().parent
errors=[]
for line in (B/'SHA256SUMS').read_text().splitlines():
 expected,name=line.split('  ',1);p=B/name
 if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected:errors.append('checksum: '+name)
m=json.loads((B/'integration_manifest.json').read_text())
assert m['runtime_tested'] is False
assert len(m['actions'])==9
frames=0
for action,item in m['actions'].items():
 d=json.loads((B/item['metadata']).read_text());rows=d['frames'];frames+=len(rows)
 assert len(rows)==item['frame_count']
 assert sum(f['integration']['duration_ms'] for f in rows)==item['total_duration_ms']
 assert d['accepted_event']==m['accepted_event']
 for f in rows:
  r=f['integration']
  for path in list(r['layers'].values())+[r['composite'],r['source']['path']]:
   if not (B/path).is_file():errors.append('missing: '+path)
  if hashlib.sha256((B/r['source']['path']).read_bytes()).hexdigest()!=r['source']['sha256']:errors.append('source hash: '+r['source']['path'])
  assert {'near','far','left','right'}==set(r['feet_canvas_px'])
  assert r['events'] and r['root_canvas_px'] and r['weapon_anchor_canvas_px']
assert frames==m['total_frames']
for p in B.rglob('*'):
 if p.is_file() and p.stat().st_size>=100_000_000:errors.append('over100MB: '+str(p.relative_to(B)))
assert not list(B.rglob('*.zip'))
if errors:raise SystemExit('\n'.join(errors))
print(m['character']+': file validation passed; '+str(frames)+' frames; runtime_tested=false')
