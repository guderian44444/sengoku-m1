"""Build the current Windows playtest from runtime registrations, never from a tree copy."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
HEROES = ('nobunaga', 'oichi', 'hideyoshi', 'ieyasu', 'mitsuhide', 'tadakatsu')
FILES = set()


def add(path):
    path = Path(path).resolve()
    assert path.is_relative_to(ROOT), f'Outside project: {path}'
    assert path.is_file(), f'Missing runtime dependency: {path}'
    relative = path.relative_to(ROOT).as_posix()
    assert not any(p in relative.split('/') for p in ('archive', 'prototypes', '.godot', 'sources', 'tests')), relative
    assert not relative.endswith(('.import', '.uid')), relative
    FILES.add(relative)


def references(value, folder):
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ('sources', 'provenance'): continue
            references(item, folder)
    elif isinstance(value, list):
        for item in value: references(item, folder)
    elif isinstance(value, str) and re.fullmatch(r'[^\n]+\.(png|wav|ogg|ttf|otf)', value):
        add(ROOT/'game'/value[6:] if value.startswith('res://') else folder/value)


def registration(relative, field=None):
    path = ROOT/relative
    add(path)
    data = json.loads(path.read_text('utf-8-sig'))
    if relative == 'game/vfx/v2/catalog.json':
        for item in data[field].values(): add(ROOT/'game'/item['texture'][6:])
    elif field == 'items' or relative in ('game/audio/v31/manifest.json','game/audio/v38/voices/manifest.json'):
        for item in data[field].values():
            add(ROOT/'game'/item['file'][6:] if item['file'].startswith('res://') else path.parent/item['file'])
    else:
        references(data[field] if field else data, path.parent)


def runtime_files():
    for relative in ('game/project.godot', 'game/main.tscn', 'game/main.gd'):
        add(ROOT/relative)
    for folder in ('game/core', 'game/render', 'game/ui'):
        for path in (ROOT/folder).glob('*.gd'): add(path)
    for path in (ROOT/'game/data').glob('*.json'): add(path)
    for relative in (
        'assets/v03/castle-road-weather-v03.png', 'assets/v03/scenery-sprites-v03.png',
        'assets/v03/castle-road-day-v03.png', 'assets/v04/scenery/villager-walk-run.png',
        'assets/v05/scenery/villager-walk-run.png', 'assets/v05/scenery/registration.json',
        'assets/v20/title/title-background.png', 'assets/current/ui/title-logo-v34.png',
        'assets/current/ui/title-logo-v34.txt',
        'assets/v20/fonts/NotoSerifTC-VF.ttf', 'assets/current/fonts/SengokuReferenceFallback.otf',
        'assets/current/fonts/MasaFont-Regular.ttf',
        'assets/current/ui/scroll02/scroll02_blank.png',
        'assets/v22/weapons/encyclopedia.json', 'audio/v27/deaths.json',
        'audio/v35/music.json', 'audio/v35/CREDITS.txt', 'audio/v35/CC-BY-SA-4.0.txt',
    ): add(ROOT/'game'/relative)
    for version in ('v09','v10','v11','v14','v19/enemies','v31/enemies','v34/enemies'):
        registration(f'game/assets/{version}/registration.json','actors')
    for extra in ('boss','troop'): registration(f'game/assets/v10/{extra}-registration.json','actors')
    for relative in ('assets/v18/registration.json','assets/v19/scenery/registration.json',
                     'assets/v32/enemies/registration.json'):
        registration('game/'+relative)
    for scene in ('supply_road','riverbank','granary','switchback','marune_gate','supply_court'):
        add(ROOT/f'game/assets/v29/stage2/{scene}.png')
    stage4 = ROOT/'game/assets/stage4'
    add(stage4/'runtime-files.json')
    for relative,digest in json.loads((stage4/'runtime-files.json').read_text('utf-8')).items():
        path = stage4/relative
        assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, path
        add(path)
    hot = ROOT/'game/audio/local-stage4/s04_hot.ogg'
    assert hashlib.sha256(hot.read_bytes()).hexdigest() == 'c52705340bfa48fad98ad775f59b0b62f84a1df4dcd139d8008b2830d60dab3e'
    add(hot)
    registration('game/assets/stage3/enemies/registration.json')
    add(ROOT/'game/assets/stage3/enemies/SHA256.json')
    for scene in ('rain_camp','barrier_camp','command_front','command_inside','props'):
        add(ROOT/f'game/assets/stage3/{scene}.png')
    registration('game/audio/stage3/manifest.json')
    music = ROOT/'game/audio/peritune-campaign-v1'
    for name in ('manifest.json','CREDITS.txt','source-library.json'): add(music/name)
    for cue in json.loads((music/'manifest.json').read_text('utf-8'))['assets']:
        path = music/(cue['id']+'.ogg')
        add(path)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == cue['sha256'], path
    for path in (ROOT/'game/assets/v21/treasures').glob('*.png'):
        if 'source' not in path.name: add(path)
    registration('game/assets/v22/weapons/registration.json','items')
    for hero in HEROES:
        registration(f'game/assets/current/heroes/{hero}/registration.json')
        registration(f'game/assets/v33/{hero}/registration.json','clips')
    registration('game/audio/v31/manifest.json','clips')
    registration('game/audio/v38/weapons/manifest.json','cues')
    registration('game/audio/v38/voices/manifest.json','clips')
    registration('game/audio/weapons-v3/manifest.json','cues')
    registration('game/audio/props-v41/manifest.json','cues')
    add(ROOT/'game/audio/props-v41/CREDITS.txt')
    add(ROOT/'docs/STAGE03-V41.md')
    add(ROOT/'docs/STAGE04-REBUILD-20261018.md')
    for folder in ('game/audio/title-amenoshita-v1','game/audio/weapons-v3'):
        for path in (ROOT/folder).iterdir():
            if path.suffix.lower() in ('.txt','.md','.json','.ogg'): add(path)
    add(ROOT/'game/audio/v38/weapons/CREDITS.txt')
    for relative in re.findall(r'"res://(audio/[^"\n]+\.wav)"',(ROOT/'game/render/combat_audio.gd').read_text('utf-8')):
        add(ROOT/'game'/relative)
    for relative in ('vfx/vfx_player.gd','vfx/v2/curve_player.gd','vfx/v2/phase_curves.gd',
                     'vfx/v2/effect_emitter.gd','vfx/v2/weapon_motion.gd',
                     'vfx/v2/audio/effect_audio_controller.gd','vfx/v2/effect_recipes.json'):
        add(ROOT/'game'/relative)
    registration('game/vfx/v2/catalog.json','effects')
    registration('game/vfx/v2/audio/manifest.json','assets')
    for folder in ('game/assets/v20/fonts','game/assets/current/fonts'):
        for path in (ROOT/folder).iterdir():
            if path.suffix.lower() in ('.txt','.md'): add(path)
    for relative in ('README-試玩.md','docs/COMBAT-V33.md','docs/UI-V34.md','docs/STAGE03-INTEGRATION-20261016.md','docs/MUSIC-CAMPAIGN-V1.md','docs/AUDIO-UI-V40.md','docs/COMBAT-V39.md','啟動戰鬥原型.cmd',
                     '啟動新版雙人試戰.cmd','啟動鍵盤練習場.cmd','啟動雙人合作.cmd','啟動素材循環展示.cmd'):
        add(ROOT/relative)
    for path in (ROOT/'tools/godot-4.7.2').iterdir():
        if path.suffix.lower() in ('.exe','.txt','.md'): add(path)
    assert all('controls-v11' not in p for p in FILES)
    assert all(not re.search(r'game/assets/v\d+/(?:nobunaga|oichi|hideyoshi|ieyasu|mitsuhide|tadakatsu)',p) or p.startswith('game/assets/v33/') for p in FILES)
    return sorted(FILES)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--stage-only',action='store_true')
    args=parser.parse_args()
    paths=runtime_files()
    out=ROOT/'artifacts/current-v33'
    stage=out/'Windows'
    # A fresh destination prevents obsolete files surviving a subsequent build.
    if stage.exists():
        assert stage.resolve().is_relative_to((ROOT/'artifacts/current-v33').resolve())
        shutil.rmtree(stage)
    stage.mkdir(parents=True)
    records=[]
    for relative in paths:
        src=ROOT/relative;dst=stage/relative;dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(src,dst)
        digest=hashlib.sha256(dst.read_bytes()).hexdigest()
        records.append(dict(path=relative,bytes=dst.stat().st_size,sha256=digest))
    manifest=dict(version='0.33.0',playable=list(HEROES),files=records)
    (stage/'runtime-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n','utf-8')
    (out/'runtime-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n','utf-8')
    if not args.stage_only:
        package=out/'吞食戰國-v0.33-Windows.zip'
        with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
            for relative in paths+['runtime-manifest.json']: z.write(stage/relative,relative)
        with zipfile.ZipFile(package) as z:
            assert z.testzip() is None
            assert set(z.namelist()) == set(paths+['runtime-manifest.json'])
        digest=hashlib.sha256(package.read_bytes()).hexdigest()
        package.with_suffix('.zip.sha256').write_text(digest+'  '+package.name+'\n','utf-8')
        print(package,package.stat().st_size,'bytes',digest)
    print(len(records),'runtime files;',stage)


if __name__=='__main__': main()
