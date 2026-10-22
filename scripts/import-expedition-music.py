"""Import two pinned official PeriTune loops; retain all existing campaign audio."""
import hashlib
import io
import json
from pathlib import Path
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools/music-v35-python'))
import numpy as np
import soundfile as sf

OUT = ROOT/'game/audio/peritune-campaign-v1'
CACHE = ROOT/'artifacts/stages07-10-music'
TRACKS = [
    ('s07_mountain_approach', 'Oboro2', '2019/04/10/oboro2',
     'https://peritune.com/loop/PerituneMaterial_Oboro2_loop.zip',
     '0fd31e9043650a65cb2927bfac77d207c8ac1d0a9dc4b1de069ea7b555f2c084',
     'PerituneMaterial_Oboro2_loop.ogg', .10, 85),
    ('s08_castle_battle', 'Amenoshita', '2015/07/03/amenoshita',
     'https://peritune.com/music/PerituneMaterial_Amenoshita_loop.mp3',
     'a701798da3a42ad3d4cd39e8d0ec99f52f081b2f0388f5f759171c93a7b45ce4',
     'PerituneMaterial_Amenoshita_loop.mp3', .14, None),
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((OUT/'manifest.json').read_text('utf-8'))
    for key, title, page, url, expected, member, rms, bpm in TRACKS:
        source = CACHE/url.rsplit('/', 1)[1]
        raw = source.read_bytes() if source.exists() else urllib.request.urlopen(url, timeout=60).read()
        assert digest(raw)==expected, f'Official source changed: {url}'
        if not source.exists(): source.write_bytes(raw)
        if source.suffix=='.zip':
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                raw=archive.read(member)
        samples, rate = sf.read(io.BytesIO(raw), dtype='float32', always_2d=True)
        assert samples.shape[1]==2 and 60 < len(samples)/rate < 240 and np.isfinite(samples).all(), key
        gain = min(.56/np.max(np.abs(samples)), rms/np.sqrt(np.mean(samples**2)))
        samples *= gain
        taper = round(rate*.002)
        samples[:taper] *= np.linspace(0, 1, taper)[:,None]
        samples[-taper:] *= np.linspace(1, 0, taper)[:,None]
        path=OUT/(key+'.ogg')
        # libsndfile's Windows Vorbis encoder can exhaust its stack on one full-song write.
        with sf.SoundFile(path, 'w', samplerate=rate, channels=2, format='OGG', subtype='VORBIS') as output:
            for start in range(0, len(samples), rate): output.write(samples[start:start+rate])
        decoded, decoded_rate = sf.read(path, always_2d=True)
        peak = float(np.max(np.abs(decoded)))
        jump = float(np.max(np.abs(decoded[0]-decoded[-1])))
        assert decoded_rate==rate and len(decoded)==len(samples) and peak<.65 and jump<.03, key
        assert all(np.sqrt(np.mean(chunk**2))>.001 for chunk in np.array_split(decoded, int(len(decoded)/rate))), key
        row = dict(id=key, file=path.name, original_title=title,
                   source_page='https://peritune.com/blog/'+page+'/', source_file=member,
                   source_sha256=digest(raw), download_url=url, download_sha256=expected,
                   sha256=digest(path.read_bytes()), license='CC BY 4.0',
                   license_url='https://creativecommons.org/licenses/by/4.0/',
                   creator='PeriTune / Sei Mutsuki', loop=True, loop_start_seconds=0,
                   loop_end_seconds=len(samples)/rate, duration_seconds=len(samples)/rate,
                   sample_rate=rate, frames=len(samples), bpm_author=bpm,
                   edits=f'Full official loop retained; static gain {20*np.log10(gain):.3f} dB; 2ms edge tapers; OGG re-encode. No tempo or pitch change.',
                   peak_dbfs_after_decode=20*np.log10(peak), boundary_jump_after_decode=jump,
                   verified_decode=True, auditory_review='Human listening pending; composer instrumentation and decoded PCM checked.')
        manifest['assets']=[r for r in manifest['assets'] if r['id']!=key]+[row]
        print(f'{key}: {len(samples)/rate:.3f}s; peak {row["peak_dbfs_after_decode"]:.2f}dBFS; seam {jump:.6f}; {row["sha256"]}')
    manifest['version']='1.2'
    manifest['scope']='Stages 01-03 and 07-10; runtime cue selection in core/campaign_music.gd.'
    manifest['stage07_10_scene_map']={
        '7': {'opening':'s07_mountain_approach','combat':'s01_matsui_boss','boss':'s01_matsui_boss'},
        '8': {'combat':'s08_castle_battle','boss':'s08_castle_battle'},
        '9': {'combat':'s03_camp_battle','boss':'s03_camp_battle'},
        '10': {'combat':'s02_sakuma_boss','boss':'s02_sakuma_boss'},
        'victory': 's07_mountain_approach',
        'note':'Each chapter has a different Japanese orchestral battle melody; gain rises for the final commander without restarting the loop. Stage 7 begins with Oboro2 and switches permanently on first contact. All four victories crossfade to Oboro2; no Celtic stinger.'}
    (OUT/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__=='__main__': main()
