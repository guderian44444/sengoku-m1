"""Lossless atlas packing of 2x-screen derivatives; approved masters stay untouched."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'game/assets/stage5'
OUTPUT = ROOT / 'game/assets/stage5-runtime'
PAGE = 2048
PAD = 2


def sha(data):
    return hashlib.sha256(data).hexdigest()


def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    previous = json.loads((OUTPUT/'manifest.json').read_text('utf8')).get('pages',{}) if (OUTPUT/'manifest.json').exists() else {}
    actors = json.loads((SOURCE / 'actors.json').read_text('utf8'))
    actors.update(json.loads((SOURCE.parent/'stage5-farmers/actors.json').read_text('utf8')))
    heights = json.loads((SOURCE / 'display.json').read_text('utf8'))['height']
    heights.update(sickle_farmer=146,hunting_bow_farmer=146)
    props = json.loads((SOURCE / 'props/manifest.json').read_text('utf8'))
    sources = {}

    def add(path, group, scale, crop=None):
        entry = (group, min(1.0, scale), crop)
        assert path not in sources or sources[path] == entry, path
        sources[path] = entry

    for role, clips in actors.items():
        for spec in clips.values():
            for frame in spec['frames']:
                for row in [frame] + frame.get('layers_before', []) + frame.get('layers_after', []):
                    add(row['path'], role, 2 * heights[role] / row['body_height'], row.get('crop'))
    for pattern in ['hachiya/hachiya_actions/fx_v3/frames/*.png', 'hachiya/hachiya_actions/secondary_fx_v2/*.png']:
        for path in sorted(SOURCE.glob(pattern)):
            add(path.relative_to(SOURCE).as_posix(), 'hachiya', 2 * heights['hachiya'] / 1015)
    for path in ['natsume/skills/sources/8f3c72ed36c58bb2.png', 'natsume/fx_patch_v3/natsume-diag-fx-native-crop.png', 'natsume/fx_patch_v3/natsume-down-fx-native-crop.png']:
        add(path, 'natsume', 2 * heights['natsume'] * 1.25 / 691.2)
    arrow = json.loads((SOURCE.parent/'stage5-farmers/arrow.json').read_text('utf8'))
    add(arrow['path'],'hunting_bow_farmer',2*146/810,arrow['crop'])
    for kind, folder in [('flags', 'flags'), ('destructibles', 'destructibles')]:
        for prop in props[kind]:
            for path in sorted((SOURCE / 'props' / folder / prop['id']).rglob('*.png')):
                add(path.relative_to(SOURCE).as_posix(), 'prop_'+prop['id'], 2 * prop['draw_scale'])

    manifest = {'schema': 1, 'screen_oversampling': 2, 'masters': '../stage5', 'entries': {}, 'pages': {}, 'groups': {}}
    groups = {}
    unique = {}
    for path, (group, scale, declared_crop) in sorted(sources.items()):
        raw = (SOURCE / path).read_bytes()
        with Image.open(SOURCE / path) as original:
            source = original.convert('RGBA')
        bounds = source.getbbox(alpha_only=True)
        if bounds is None:
            bounds = (0, 0, 1, 1)
        if declared_crop:
            x, y, w, h = map(int, declared_crop)
            assert source.getchannel('A').getbbox() is None or (bounds[0] >= x and bounds[1] >= y and bounds[2] <= x+w and bounds[3] <= y+h), path
        crop = [bounds[0], bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]]
        image = source.crop(bounds)
        dimensions = (max(1, math.ceil(image.width * scale)), max(1, math.ceil(image.height * scale)))
        # Premultiplied resize avoids dark/white fringes around transparent blade trails.
        image = image.convert('RGBa').resize(dimensions, Image.Resampling.LANCZOS).convert('RGBA')
        digest = sha(str(image.size).encode() + image.tobytes())
        key = group + '/' + digest
        manifest['entries'][path] = {'page': '', 'region': [], 'crop': crop, 'canvas': list(source.size), 'source_sha256': sha(raw), 'pixels_sha256': digest}
        if key in unique:
            unique[key]['paths'].append(path)
        else:
            item = {'image': image, 'paths': [path], 'digest': digest}
            unique[key] = item
            groups.setdefault(group, []).append(item)

    for group, items in sorted(groups.items()):
        # Deterministic first-fit shelves, two transparent pixels around each region.
        pages = []
        for item in sorted(items, key=lambda v: (-v['image'].height, -v['image'].width, v['digest'])):
            image = item['image']; w, h = image.width+PAD*2, image.height+PAD*2
            assert max(w, h) <= PAGE, (group, image.size)
            placement = None
            for page_index, page in enumerate(pages):
                for shelf in page['shelves']:
                    if h <= shelf['height'] and shelf['x']+w <= PAGE:
                        placement = (page_index, shelf['x'], shelf['y']); shelf['x'] += w; break
                if placement: break
                y = sum(s['height'] for s in page['shelves'])
                if y+h <= PAGE:
                    page['shelves'].append({'x': w, 'y': y, 'height': h}); placement = (page_index, 0, y); break
            if placement is None:
                pages.append({'shelves': [{'x': w, 'y': 0, 'height': h}], 'items': []})
                placement = (len(pages)-1, 0, 0)
            page_index, x, y = placement
            pages[page_index]['items'].append((item, x+PAD, y+PAD))
        manifest['groups'][group] = []
        for index, page in enumerate(pages):
            width = max(x+item['image'].width+PAD for item,x,y in page['items'])
            height = max(y+item['image'].height+PAD for item,x,y in page['items'])
            canvas = Image.new('RGBA', (width,height))
            name = f'{group}-{index:02}.png'
            for item,x,y in page['items']:
                canvas.paste(item['image'], (x,y))
                for path in item['paths']:
                    manifest['entries'][path].update(page=name, region=[x,y,*item['image'].size])
            canvas.save(OUTPUT / name, compress_level=6)
            manifest['pages'][name] = {'width':width, 'height':height, 'rgba_bytes':width*height*4, 'sha256':sha((OUTPUT/name).read_bytes())}
            manifest['groups'][group].append(name)
        print(group, 'pages', len(pages), 'MiB', round(sum(manifest['pages'][p]['rgba_bytes'] for p in manifest['groups'][group])/2**20, 2), flush=True)
    (OUTPUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf8')
    for name in previous.keys()-manifest['pages'].keys():
        path=(OUTPUT/name).resolve()
        assert path.parent==OUTPUT.resolve() and path.suffix=='.png'
        path.unlink(missing_ok=True)
    hashes={p.relative_to(OUTPUT).as_posix():sha(p.read_bytes()) for p in sorted(OUTPUT.iterdir()) if p.name=='manifest.json' or p.name in manifest['pages']}
    (OUTPUT/'runtime-files.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf8')
    print('sources', len(sources), 'unique images', len(unique), 'pages', len(manifest['pages']), flush=True)


if __name__ == '__main__':
    build()
