"""Prepare body cuts and pure metal parries from credited foley, without changing old takes."""
from pathlib import Path
import hashlib
import io
import json
import math
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/music-v35-python'))
import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

RATE = 48000
OUT = ROOT / 'game/audio/weapons-v3'
ARCHIVE = ROOT / 'artifacts/roar-monk-impact-20261018/source/fleshy_fight_sounds.zip'
CLASH = ROOT / 'artifacts/weapon-audio-v38/source/sword_clash_-_starninjas_0'
ARCHIVE_SHA = '53fbfaafa489ee7991fdf53ffeee1ac796f9ef667a489d5e8de6c6c4ccf748da'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def prepare(data, speed):
    samples, rate = sf.read(io.BytesIO(data), always_2d=True)
    ratio = round(rate * speed)
    divisor = math.gcd(RATE, ratio)
    x = resample_poly(samples.mean(axis=1), RATE // divisor, ratio // divisor)
    x = sosfilt(butter(2, 75, 'highpass', fs=RATE, output='sos'), x)
    active = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .018)
    assert len(active), 'Silent source'
    x = x[max(0, active[0] - 144):min(len(x), active[-1] + 1440)]
    x = x[:round(.55 * RATE)]
    x[:48] *= np.linspace(0, 1, 48)
    x[-960:] *= np.linspace(1, 0, 960)
    x *= .707 / np.max(np.abs(x))
    assert len(x) > .04 * RATE and np.isfinite(x).all() and np.max(np.abs(x)) < 1
    return x


def build():
    assert digest(ARCHIVE.read_bytes()) == ARCHIVE_SHA, 'Unexpected source archive'
    manifest = json.loads((OUT / 'manifest.json').read_text('utf-8'))
    sources = {
        'body_slash': {'author': 'Will Leamon', 'credit': 'Additional Sound FX by Will Leamon',
            'page': 'https://opengameart.org/content/fleshy-fight-sounds', 'license': 'OGA-BY-3.0',
            'license_url': 'http://static.opengameart.org/OGA-BY-3.0.txt', 'archive_sha256': ARCHIVE_SHA},
        'metal_parry': {'author': 'StarNinjas', 'license': 'CC0-1.0',
            'page': 'https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes',
            'license_url': 'https://creativecommons.org/publicdomain/zero/1.0/'}}
    with zipfile.ZipFile(ARCHIVE) as archive:
        for cue, recipes in {
            'body_slash': [('sword-1a.wav', 1.0), ('sword-1b.wav', 1.0), ('sword-1b.wav', .91)],
            'metal_parry': [(f'sword_clash.{i}.ogg', 1.0) for i in range(1, 4)]}.items():
            variants = []
            for index, (name, speed) in enumerate(recipes, 1):
                raw = archive.read(name) if cue == 'body_slash' else (CLASH / name).read_bytes()
                x = prepare(raw, speed)
                path = OUT / f'{cue}_{index:02}.wav'
                sf.write(path, x, RATE, subtype='PCM_16')
                variants.append({'file': path.name, 'sha256': digest(path.read_bytes()),
                    'source_file': name, 'source_sha256': digest(raw), 'speed': speed,
                    'seconds': round(len(x) / RATE, 6)})
            sources[cue]['variants'] = variants
            manifest['cues'][cue] = {'loop': False, 'variants': [
                {'file': v['file'], 'sha256': v['sha256']} for v in variants]}
    (OUT / 'body-impact-sources-20261018.json').write_text(json.dumps({
        'sample_rate': RATE, 'processing': 'Mono, 75 Hz highpass, silence trimmed, 550 ms maximum, faded edges, peak -3 dBFS; speed as recorded.',
        'sources': sources}, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    (OUT / 'CREDITS-BODY-20261018.txt').write_text(
        'Additional Sound FX by Will Leamon\nFleshy Fight Sounds: https://opengameart.org/content/fleshy-fight-sounds\n'
        'License: OGA-BY 3.0 - http://static.opengameart.org/OGA-BY-3.0.txt\n'
        'body_slash_01..03.wav adapt sword-1a / sword-1b; trimmed, mono, filtered, normalized and pitch varied.\n\n'
        'Metal parries by StarNinjas: https://opengameart.org/users/starninjas\n'
        'https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes\n'
        'License: CC0 1.0 - https://creativecommons.org/publicdomain/zero/1.0/\n'
        'metal_parry_01..03.wav adapt sword_clash.1..3.ogg; trimmed, mono, filtered and normalized.\n'
        'Recipes and original/output hashes: body-impact-sources-20261018.json.\n', 'utf-8')
    print('Prepared 3 body cuts and 3 metal parries; original banks retained.')


if __name__ == '__main__':
    build()
