"""Collect the exact accepted imagegen recipes by matching original PNG bytes."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'game/assets/v14'


def records(value):
    if isinstance(value, dict):
        if isinstance(value.get('source'), str) and value.get('prompt'):
            yield value
        for child in value.values():
            yield from records(child)
    elif isinstance(value, list):
        for child in value:
            yield from records(child)


def main():
    digests = {}

    def digest(path):
        path = Path(path)
        if path not in digests:
            digests[path] = hashlib.sha256(path.read_bytes()).hexdigest()
        return digests[path]

    recipes = {}
    for folder in (ART, ROOT / 'artifacts/art-native-v14'):
        for path in sorted(folder.glob('*provenance.json')):
            for record in records(json.loads(path.read_text(encoding='utf-8-sig'))):
                source = Path(record['source'])
                if source.is_file():
                    recipes[digest(source)] = record
    registration = json.loads((ART / 'registration.json').read_text(encoding='utf-8'))
    filenames = set()
    for spec in registration['actors'].values():
        filenames.update([spec['file'], *spec.get('frame_files', {}).values()])
    accepted = []
    for filename in sorted(filenames):
        checksum = digest(ART / filename)
        assert checksum in recipes, f'No exact original imagegen recipe for {filename}'
        picture = Image.open(ART / filename)
        assert picture.mode == 'RGBA', f'No alpha: {filename}'
        alpha = np.asarray(picture.getchannel('A'))
        assert (alpha == 0).mean() > .15 and alpha.max() > 200, f'Invalid alpha: {filename}'
        accepted.append({'file': filename, 'sha256': checksum, 'original_bytes_unchanged': True,
                         'size': list(picture.size), 'transparent_fraction': float((alpha == 0).mean()),
                         'recipe': recipes[checksum]})
    result = {'version': '0.14', 'tool': 'builtin image_gen', 'accepted_pngs': accepted,
              'registration_sha256': digest(ART / 'registration.json')}
    (ART / 'prompts.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {len(accepted)} registered PNGs match exact original imagegen bytes and recipes; alpha verified')


if __name__ == '__main__':
    main()
