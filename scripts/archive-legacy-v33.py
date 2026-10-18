"""Preserve retired hero art outside the runtime; never touch saves or Git worktrees."""
from pathlib import Path
import hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT/'archive/legacy-before-v33'
HEROES = ('nobunaga','oichi','hideyoshi','ieyasu','mitsuhide','tadakatsu')
COMMON = ('idle','walk','run','jump','hurt','stunned','down','recovering','launched','victory')


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(path):
    dest=ARCHIVE/path.relative_to(ROOT)
    dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists(): shutil.copy2(path,dest)


def main():
    ARCHIVE.mkdir(parents=True,exist_ok=True)
    # Approved generation inputs remain reproducible, separately from shipped art.
    reference=ROOT/'prototypes/nobunaga-combat-set-v1/sources/formal-reference'
    reference.mkdir(exist_ok=True)
    for name in ['registration.json','idle.png','light1.png','light3.png','heavy2.png','air_light.png','air_heavy.png','run.png']:
        source=ROOT/'game/assets/v22/nobunaga'/name
        if source.exists() and not (reference/name).exists(): shutil.copy2(source,reference/name)
    for hero,version in [('nobunaga','v22'),('oichi','v27')]:
        src=ROOT/'game/assets'/version/hero
        dest=ROOT/'game/assets/current/heroes'/hero
        if dest.exists(): continue
        reg=json.loads((src/'registration.json').read_text('utf-8'))
        reg['clips']={k:v for k,v in reg['clips'].items() if k in COMMON}
        reg['aliases']={k:v for k,v in reg.get('aliases',{}).items() if v in COMMON}
        reg.update(version='current',complete=True,origin=f'{version}/{hero}',role='current locomotion and reactions; no legacy attacks')
        files={reg['portrait']['file']}
        for clip in reg['clips'].values():
            for f in clip['frames']:
                files.add(f['file'])
                if 'hand_foreground_file' in f: files.add(f['hand_foreground_file'])
        dest.mkdir(parents=True)
        for name in files:
            (dest/name).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/name,dest/name)
            assert digest(src/name)==digest(dest/name)
        (dest/'registration.json').write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n','utf-8')
    for relative in ['README.md','README-試玩.md','scripts/package-native.ps1','scripts/test-v19.mjs',
            'game/core/battle.gd','game/main.gd','game/render/art_assets.gd','game/render/frame_animation.gd',
            'game/render/battle_view.gd','game/render/art_demo.gd','game/render/layered_hero_source.gd']:
        snapshot(ROOT/relative)
    candidates=set()
    assets=ROOT/'game/assets'
    for p in assets.rglob('*'):
        if not p.is_file() or p.relative_to(assets).parts[0] in ['current','v33']: continue
        if p.is_relative_to(assets/'v22/weapons'): continue
        if p.relative_to(assets).parts[0] in ['v24','v25','v26'] or any(h in p.relative_to(assets).as_posix().lower() for h in HEROES):
            candidates.add(p)
    for relative in ['game/controls-v11.json','game/assets/v10/hero-registration.json']:
        if (ROOT/relative).exists(): candidates.add(ROOT/relative)
    for p in ROOT.glob('*.tar.gz'): candidates.add(p)
    # Filter shared enemy/scenery registries before moving their retired hero PNGs.
    for path in assets.glob('*/registration.json'):
        reg=json.loads(path.read_text('utf-8'))
        if 'actors' not in reg: continue
        actors=reg['actors']
        kept={k:v for k,v in actors.items() if v.get('target')!='hero' and not any(h in k for h in HEROES)}
        if len(kept)!=len(actors):
            snapshot(path);reg['actors']=kept
            path.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n','utf-8')
    records=[]
    for path in sorted(candidates):
        resolved=path.resolve(strict=True)
        assert resolved.is_relative_to(ROOT) and not resolved.is_relative_to(ARCHIVE)
        assert resolved.is_relative_to(assets) or path.name.endswith('.tar.gz') or path==ROOT/'game/controls-v11.json'
        dest=ARCHIVE/path.relative_to(ROOT)
        assert dest.resolve().is_relative_to(ARCHIVE.resolve())
        records.append(dict(source=path.relative_to(ROOT).as_posix(),archive=dest.relative_to(ROOT).as_posix(),bytes=path.stat().st_size,sha256=digest(path)))
    manifest=ARCHIVE/'archive-manifest.json'
    previous=json.loads(manifest.read_text('utf-8'))['files'] if manifest.exists() else []
    manifest.write_text(json.dumps({'complete':False,'files':previous+records},ensure_ascii=False,indent=2)+'\n','utf-8')
    for record in records:
        src=ROOT/record['source'];dest=ROOT/record['archive'];dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():
            assert digest(dest)==record['sha256'];src.unlink()
        else: shutil.move(str(src),str(dest))
        assert digest(dest)==record['sha256']
    manifest.write_text(json.dumps({'complete':True,'files':previous+records},ensure_ascii=False,indent=2)+'\n','utf-8')
    print('Archived',len(records),'files;',round(sum(r['bytes'] for r in records)/1024**2,1),'MiB; hashes verified')


if __name__=='__main__': main()
