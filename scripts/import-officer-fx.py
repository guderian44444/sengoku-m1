"""Verify power_v4 source bytes and install only cosmetic attachments."""
from pathlib import Path
import argparse, hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def install(source):
    source = source.resolve()
    declared = json.loads((source/'SHA256.json').read_text('utf-8-sig'))
    for rel, expected in declared.items():
        path = (source/rel).resolve()
        assert path.is_relative_to(source) and sha(path) == expected, rel
    moves = json.loads((source/'all_moves_manifest.json').read_text('utf-8-sig'))
    assert len(moves) == 39 and sum(m['new_fx_enabled'] for m in moves) == 32
    files = {}; originals = {}
    target = ROOT/'game/assets/officer-fx-power-v4'
    def keep(rel):
        dest = target/rel; dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source/rel,dest); files[rel] = sha(dest)
    for move in moves:
        for frame in move['frames']:
            rel = frame['source_path']
            actual = sha(ROOT/rel)
            assert actual == frame['source_sha256'], f'Current actor differs: {rel}'
            originals[rel] = actual
        for fx in move.get('fx_by_pose',[]): keep(move['id']+'/'+fx['path'])
    for rel in ['all_moves_manifest.json','anchor_exceptions.json','actor_coverage.json','README.md']:
        keep(rel)
    evidence = {'source_manifest_sha256':sha(source/'SHA256.json'),'verified_package_files':len(declared),'moves':39,'enabled':32,'preserve_existing':7,'original_source_files':originals,'runtime_files':files,'policy':'render only; original actor bytes and damage extents unchanged'}
    (target/'runtime-files.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'verified_package_files':len(declared),'original_files':len(originals),'runtime_files':len(files),'bytes':sum((target/x).stat().st_size for x in files)}))
if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);install(p.parse_args().source)
