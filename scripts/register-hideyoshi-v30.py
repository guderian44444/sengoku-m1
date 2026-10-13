"""Activate the reviewed asset package without changing its authored PNGs or proposal."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'game/assets/v27/hideyoshi'

def build():
    registration = json.loads((ASSETS / 'registration.proposed.json').read_text(encoding='utf-8'))
    placement = json.loads((ASSETS / 'equipment-placement.json').read_text(encoding='utf-8'))
    assert registration['hero'] == 'hideyoshi' and len(registration['clips']) == 39
    for clip, row in registration['clips'].items():
        assert len(row['frames']) == 6
        for index, frame in enumerate(row['frames']):
            body = ASSETS / frame['file']
            assert hashlib.sha256(body.read_bytes()).hexdigest() == frame['body_sha256']
            assert (ASSETS / frame['hand_foreground_file']).is_file()
            frame['weapon_grip_offsets'] = {key: values[index]['weapon_grip_offset_normalized']
                for key, values in placement['clips'][clip].items()}
    registration.update(complete=True, status='Installed native runtime registration',
        portrait={'file': 'ui/portrait.png', 'rect': [0, 0, 1312, 1199]}, aliases={},
        weapon_flip_x=True,
        hilt_geometry=placement['guard_and_handle_native_pixels'])
    return json.dumps(registration, ensure_ascii=False, indent=2) + '\n'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = ASSETS / 'registration.json'
    result = build()
    if args.check:
        assert output.read_text(encoding='utf-8') == result, 'Runtime registration drift'
    else:
        output.write_text(result, encoding='utf-8')
    print('HIDEYOSHI REGISTRATION PASS: 39 clips / 234 frames; authored bodies and grips retained')
