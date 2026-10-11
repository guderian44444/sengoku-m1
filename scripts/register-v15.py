"""Register original v15 victory drawings using the existing anatomy-aware loader."""
import importlib.util
import json
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('register_v14', SCRIPT / 'register-v14.py')
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)
ROOT = SCRIPT.parent / 'game/assets/v15'
previous.existing.ROOT = ROOT
previous.existing.VERSION = 'v15'


def main():
    actors = {}
    for path in sorted(ROOT.glob('*-clips.json')):
        for name, meta in json.loads(path.read_text(encoding='utf-8-sig')).items():
            assert name not in actors, f'duplicate {name}'
            assert meta['frame_count'] == 12, f'{name}: twelve victory drawings required'
            actors[name] = previous.register(name, meta)
            print(name, len(actors[name]['feet']), 'drawings')
    assert set(actors) == {'oichi-victory', 'nobunaga-victory'}, 'v15 victory scope is Oichi and Nobunaga'
    for name, actor in actors.items():
        assert actor['sheet'] == 'v15_victory' and len(actor['feet']) == 12, name
        drawings = {(actor['frame_files'][str(i)], tuple(actor['regions'][str(i)])) for i in range(12)}
        assert len(drawings) == 12, f'{name}: repeated source drawing'
    (ROOT / 'registration.json').write_text(json.dumps({'version': '0.15', 'actors': actors}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
