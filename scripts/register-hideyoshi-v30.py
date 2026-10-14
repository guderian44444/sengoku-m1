"""Activate the reviewed asset package without changing its authored PNGs or proposal."""
import argparse
import copy
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
    for frame in registration['clips']['idle']['frames']:
        frame['weapon_angle'] = 0
    for version in ['v30', 'v32']:
        revision = json.loads((ASSETS / f'revisions/{version}/registration.json').read_text(encoding='utf-8'))
        for clip, row in revision['clips'].items():
            assert len(row['frames']) == 6
            for frame in row['frames']:
                assert hashlib.sha256((ASSETS / frame['file']).read_bytes()).hexdigest() == frame['body_sha256']
            registration['clips'][clip] = row
    registration['clips']['dash_heavy'] = copy.deepcopy(registration['clips']['heavy1'])
    fan_frames = registration['clips']['charged_slam']['frames']
    registration['clips']['charge_slam'] = {'frames': [copy.deepcopy(fan_frames[index]) for index in [0, 0, 1, 1, 2, 2]]}
    calibration = json.loads((ASSETS / 'revisions/v32/standing-scale.json').read_text(encoding='utf-8'))
    reference = calibration['reference']
    assert hashlib.sha256((ASSETS / reference['file']).read_bytes()).hexdigest() == reference['sha256']
    assert registration['clips'].keys() == calibration['clips'].keys()
    for clip, row in registration['clips'].items():
        scale = calibration['clips'][clip]
        assert len(scale['source_resolution']) == len(scale['source_sha256']) == len(row['frames']) == 6
        for index, frame in enumerate(row['frames']):
            assert frame['body_sha256'] == scale['source_sha256'][index], f'Scale/source drift: {clip}/{index+1}'
            resolution = scale['source_resolution'][index]
            assert 1 <= resolution <= 2.25 and 45 <= scale['head_width_px'] <= 90
            frame['body_height'] = round(reference['body_height_px'] * scale['head_width_px'] / reference['head_width_px'] * resolution, 3)
            frame['scale_ruler'] = {'head_width_px': scale['head_width_px'] * resolution,
                'idle_head_width_px': reference['head_width_px'], 'reference_body_height_px': reference['body_height_px'],
                'source_resolution': resolution, 'reference_clip': 'idle', 'reference_frame': 1}
    registration.update(complete=True, status='Installed native runtime registration',
        portrait={'file': 'ui/portrait.png', 'rect': [0, 0, 1312, 1199]}, aliases={},
        weapon_flip_x=False,
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
    print('HIDEYOSHI REGISTRATION PASS: 39 clips / 234 frames; source SHA preserved, runtime revision verified')
