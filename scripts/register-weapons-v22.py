"""Crop generated RGBA weapons without repainting, resizing or changing any alpha."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/v22/weapons'
FAMILIES = {
    'swords': (['sword_uchigatana', 'sword_nagamitsu', 'sword_samonnji', 'sword_heshikiri', 'sword_dojigiri'], [0, 334, 668, 1002, 1336, 1672], 780),
    'spears': (['spear_suyari', 'spear_kamayari', 'spear_jumonji', 'spear_nihongo', 'spear_tonbokiri'], [0, 320, 600, 915, 1210, 1536], 640),
    'bows': (['bow_azusa', 'bow_bamboo', 'bow_black_lacquer', 'bow_red_lacquer', 'bow_shigeto'], [0, 350, 645, 930, 1230, 1568], 640),
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def anchors(alpha, grip_y):
    solid = np.array(alpha) > 128
    ys, xs = np.where(solid)
    top_y, bottom_y = int(ys.min()), int(ys.max())
    tip = lambda y: [int(round(np.median(np.where(solid[y])[0]))), y]
    assert solid[grip_y].any(), 'The selected grip row must cross opaque weapon pixels'
    return tip(grip_y), tip(top_y), tip(bottom_y)

def build():
    result = {'version': 'v22', 'notes': 'Generated historical interpretations. Native RGBA pixels and alpha are untouched. Only independent crops; canonical tips point upward. Bowstrings are drawn at runtime.', 'sources': {}, 'items': {}}
    for family, (ids, cuts, grip_y) in FAMILIES.items():
        source = OUT / 'sources' / ('spears-long.png' if family == 'spears' else family + '.png')
        image = Image.open(source)
        assert image.mode == 'RGBA'
        result['sources'][family] = {'file': 'sources/' + source.name, 'sha256': sha(source), 'size': list(image.size)}
        for index, id in enumerate(ids):
            item_image, source_key = image, family
            cut_left, cut_right, item_grip_y = cuts[index], cuts[index + 1], grip_y
            # The approved Nihongo stays pixel-identical to column four. Only
            # Tonbokiri may use its separately redrawn slender full-length PNG.
            override = OUT / 'sources' / 'tonbokiri-long.png'
            if id == 'spear_tonbokiri' and override.exists():
                item_image = Image.open(override)
                assert item_image.mode == 'RGBA'
                source_key = 'tonbokiri'
                result['sources'][source_key] = {'file': 'sources/' + override.name, 'sha256': sha(override), 'size': list(item_image.size)}
                cut_left, cut_right, item_grip_y = 0, item_image.width, round(item_image.height * .66)
            column = item_image.crop((cut_left, 0, cut_right, item_image.height))
            bounds = column.getchannel('A').getbbox()
            left, top, right, bottom = bounds
            rect = [max(cut_left, cut_left + left - 4), max(0, top - 4), min(cut_right, cut_left + right + 4), min(item_image.height, bottom + 4)]
            crop = item_image.crop(rect)
            target = OUT / (id + '.png')
            crop.save(target)
            grip, tip_top, tip_bottom = anchors(crop.getchannel('A'), item_grip_y - rect[1])
            length = tip_bottom[1] - tip_top[1]
            assert length >= 600, (id, length)
            result['items'][id] = {'file': target.name, 'grip': grip, 'tip_top': tip_top, 'tip_bottom': tip_bottom, 'length': length, 'source': source_key, 'rect': rect, 'size': list(crop.size), 'sha256': sha(target)}
            if id == 'spear_tonbokiri':
                result['items'][id].update({'world_length': 223.7, 'proportions_design_cm': {'shaft': 180, 'blade': 43.7, 'width': 3.7}, 'proportions_source': 'https://zh.wikipedia.org/zh-tw/蜻蛉切'})
    (OUT / 'registration.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def verify():
    data = json.loads((OUT / 'registration.json').read_text(encoding='utf-8'))
    assert len(data['items']) == 15
    for source in data['sources'].values():
        assert sha(OUT / source['file']) == source['sha256']
    for id, item in data['items'].items():
        target = OUT / item['file']
        image = Image.open(target)
        source = Image.open(OUT / data['sources'][item['source']]['file'])
        assert image.tobytes() == source.crop(item['rect']).tobytes(), id + ': native pixel/alpha identity'
        assert sha(target) == item['sha256']
        minimum, maximum = image.getchannel('A').getextrema()
        assert image.mode == 'RGBA' and minimum == 0 and maximum >= 250
        assert item['length'] >= 600
        for field in ['grip', 'tip_top', 'tip_bottom']:
            x, y = item[field]
            assert 0 <= x < image.width and 0 <= y < image.height, (id, field)
            assert image.getpixel((x, y))[3] > 128, (id, field, 'anchor misses weapon')
    print('WEAPONS V22 PASS: 15 native RGBA crops, source hashes, alpha identity, >=600px and on-weapon anchors')

if '--check' not in sys.argv:
    build()
verify()
