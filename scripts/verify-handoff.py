#!/usr/bin/env python3
"""Read-only final snapshot verification, including GitHub ZIP checkouts.
48 weapons + Nobunaga v25 + Oichi v26.
No engine, third-party Python packages, Git history, or user save access needed.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
def read(rel):
    return json.loads((ROOT / rel).read_text(encoding='utf-8'))
V26 = read('game/assets/v26/oichi-skirt.json')
OVERLAY = V26['approved_overlay']
assert set(OVERLAY) == {item['file'] for item in V26['sources'].values()} | {'game/assets/v22/oichi/registration.json'}
assert len(OVERLAY) == 18 and all(path.startswith('game/assets/v22/oichi/') for path in OVERLAY)
def approved_hash(rel, expected):
    if rel not in OVERLAY:
        return expected
    pair = OVERLAY[rel]
    assert expected in (pair['before_sha256'], pair['after_sha256']), f'Unexpected v26 base: {rel}'
    return pair['after_sha256']
def verify(rel, expected):
    expected = approved_hash(rel, expected)
    path = ROOT / rel
    assert path.is_file(), f'Missing required source: {rel}'
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    assert actual == expected, f'SHA mismatch: {rel}'

reg = read('game/assets/v22/weapons/registration.json')
ency = read('game/assets/v22/weapons/encyclopedia.json')
assert len(reg['items']) == 48 and set(reg['items']) == set(ency)
for item in reg['items'].values():
    verify('game/assets/v22/weapons/' + item['file'], item['sha256'])
for item in reg['sources'].values():
    verify('game/assets/v22/weapons/' + item['file'], item['sha256'])
for item in read('game/assets/v24/weapons/art-spec30.json')['items']:
    verify(item['raw_source'], item['source_sha256'])

v25 = read('game/assets/v25/nobunaga-dark-red.json')
for rel, digest in v25['protected_sha256'].items():
    verify(rel, digest)
for rel, pair in v25['approved_overlay'].items():
    verify(rel, pair['after_sha256'])
for clip, digest in v25['unchanged_clips'].items():
    verify(f'game/assets/v22/nobunaga/{clip}.png', digest)
for clip, item in v25['clips'].items():
    verify(item['cape_mask'], item['cape_mask_sha256'])
    if 'chest_mask' in item:
        verify(item['chest_mask'], item['chest_mask_sha256'])
assert len(v25['clips']) == 17 and len(v25['unchanged_clips']) == 8

historical = read('artifacts/nobunaga-dark-red-v25/final-character-protection.json')
for rel, digest in historical['files'].items():
    verify(rel, digest)
characters = read('game/assets/v26/final-character-protection.json')
for rel, digest in characters['files'].items():
    verify(rel, digest)
clips = frames = 0
for hero in ('nobunaga', 'oichi', 'tadakatsu'):
    data = read(f'game/assets/v22/{hero}/registration.json')
    clips += len(data['clips'])
    frames += sum(len(clip['frames']) for clip in data['clips'].values())
assert (clips, frames) == (77, 462)
assert (characters['hero_clips'], characters['hero_frames']) == (77, 462)

local_photos = []
photo_entries = set()
for weapon_id, entry in ency.items():
    assert entry['sources'], f'Missing historical source: {weapon_id}'
    for ref in entry.get('reference_images', []):
        local = ref.get('local_path', '')
        if local:
            assert local.startswith('res://assets/v22/weapons/references/') and '..' not in local
            assert ref.get('embed_allowed') is True and str(ref.get('license', '')).lower() in ('cc0', 'cc0 / public domain')
            assert (ROOT / 'game' / local.removeprefix('res://')).is_file()
            local_photos.append(local)
            photo_entries.add(weapon_id)
assert len(local_photos) == 3 and len(photo_entries) == 2
for clip, item in V26['sources'].items():
    verify(item['file'], item['after_sha256'])
    for key in ('diff_mask', 'before_patch', 'after_patch'):
        verify(item[key], item[key + '_sha256'])
for rel, digest in V26['protected_assets_sha256'].items():
    verify(rel, digest)
assert V26['audit_summary']['modified'] == 81
assert V26['audit_summary'].get('retained_generation_blocked', 0) == 0
assert V26['blocked_clips'] == []
assert V26['conservative_redesign_clips'] == ['jump', 'low_sweep']
print('PASS final handoff: 48 weapons; 77 clips / 462 frames; Nobunaga v25 exact; Oichi v26 81 modified + 75 retained; 12 conservative redesign frames; 3 CC0 photos across 2 entries; approved SHA chain intact')
