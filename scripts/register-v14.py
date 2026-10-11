"""Register original v14 art with measured anatomy and per-action enemy clips."""
import copy
import importlib.util
import json
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent
saved_argv = sys.argv
sys.argv = [str(SCRIPT / 'register-v12.py'), 'v13']
spec = importlib.util.spec_from_file_location('register_existing', SCRIPT / 'register-v12.py')
existing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(existing)
sys.argv = saved_argv
existing.ROOT = SCRIPT.parent / 'game/assets/v14'
existing.VERSION = 'v14'


def register(name, meta):
    source = copy.deepcopy(meta)
    if source.get('frame_count') in (1, 6):
        source['part'] = True
    item = existing.register(name, source)
    if meta.get('target') == 'prop':
        item.pop('hero', None)
        item.pop('sheet', None)
        assert meta.get('groups'), f'{name}: prop groups required'
        assert all(indices and all(0 <= i < len(item['feet']) for i in indices) for indices in meta['groups'].values()), f'{name}: invalid prop groups'
        item.update(target='prop', groups=meta['groups'])
    elif 'kind' in meta:
        item.pop('groups', None)
        item.pop('hero', None)
        item.update(target='enemy_clip', key=':'.join([meta.get('faction', 'mori'), meta['kind'], meta['sheet']]), sheet=meta['sheet'])
    if 'frame_ticks' in meta:
        ticks = meta['frame_ticks']
        assert len(ticks) == len(item['feet']) and ticks[0] == 0 and all(a < b for a, b in zip(ticks, ticks[1:])), f'{name}: invalid pose timing'
        item['frame_ticks'] = ticks
    if 'select' in meta:
        chosen = meta['select']
        assert chosen and len(chosen) == len(set(chosen))
        assert all(0 <= i < len(item['feet']) for i in chosen)
        item['columns'], item['rows'] = len(chosen), 1
        item['feet'] = [item['feet'][i] for i in chosen]
        for field in ('regions', 'hands', 'blades', 'frame_files'):
            if field in item:
                item[field] = {str(n): item[field][str(i)] for n, i in enumerate(chosen) if str(i) in item[field]}
        if 'body_heights' in item:
            item['body_heights'] = [item['body_heights'][i] for i in chosen]
        item['unplanted'] = list(range(len(chosen)))
    return item


def main():
    actors = {}
    for path in sorted(existing.ROOT.glob('*-clips.json')):
        for name, meta in json.loads(path.read_text(encoding='utf-8-sig')).items():
            assert name not in actors, f'duplicate {name}'
            actors[name] = register(name, meta)
            print(name, len(actors[name]['feet']), 'drawings')
    assert actors, 'No accepted clips'
    output = {'version': '0.14', 'actors': actors}
    (existing.ROOT / 'registration.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
