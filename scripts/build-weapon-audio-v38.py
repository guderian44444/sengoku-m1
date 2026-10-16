"""Cut and mix licensed foley into short combat cues; keep source hashes and edit recipes."""
from pathlib import Path
import hashlib
import json
import math
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools/music-v35-python'))
import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

SOURCE = ROOT/'artifacts/weapon-audio-v38/source'
OUT = ROOT/'game/audio/v38/weapons'
CACHE = ROOT/'artifacts/weapon-audio-v38'
RATE = 44100
PACKS = {
    'medieval': ('medieval_sfx_textures_1_of_2.7z', 'Ben Jaszczak and Brian Nelson / Still North Media',
                 'https://opengameart.org/content/medieval-sound-effects-weapon-textures', 'b5e2b2c86d811d983d15dbf8453df6a25275a2a0dc4e88e0dc5e1cb3046fd4ae'),
    'sword': ('sword_-_starninjas_1.zip', 'StarNinjas',
              'https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes', '87a1fe1cfeee5f282fe06a7a9c25ab9ebf24b7674fe19171b7f2762dffb628c1'),
    'clash': ('sword_clash_-_starninjas_0.zip', 'StarNinjas',
              'https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes', 'f363c80ea1627548d336370750651b0d2d092978148ecfb3642717c2efb54b6b'),
    'body': ('independent_nu_ljudbank-hits_and_punches.7z', 'Independent.nu (submitted by qubodup)',
             'https://opengameart.org/node/2558', '641c65d2e1a00002171c23e2c6fa14e925ae4c12db09d3f79d130a4538916032'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(pack, name, cut=None, speed=1.0, lowpass=None):
    path = SOURCE/Path(PACKS[pack][0]).stem/name
    data, rate = sf.read(path, always_2d=True)
    x = data.mean(axis=1)
    if cut: x = x[round(cut[0]*rate):round(cut[1]*rate)]
    ratio = round(rate*speed)
    divisor = math.gcd(RATE, ratio)
    x = resample_poly(x, RATE//divisor, ratio//divisor)
    x = sosfilt(butter(2, 65, 'highpass', fs=RATE, output='sos'), x)
    if lowpass: x = sosfilt(butter(2, lowpass, fs=RATE, output='sos'), x)
    # Keep the attack and short tail; do not ship the pauses between recorded takes.
    active = np.flatnonzero(np.abs(x) > np.max(np.abs(x))*.018)
    assert len(active), path
    x = x[max(0,active[0]-round(.003*RATE)):min(len(x),active[-1]+round(.035*RATE))]
    x /= max(np.max(np.abs(x)), .0001)
    return x, {'pack':pack, 'file':name, 'sha256':sha(path), 'cut_seconds':cut,
               'speed':speed, 'lowpass_hz':lowpass}


def mix(parts, limit=.7):
    count = min(round(limit*RATE), max(len(x) for _, (x, _) in parts))
    x = np.zeros(count)
    for gain, (source, _) in parts:
        n = min(count, len(source))
        x[:n] += gain*source[:n]
    x[:88] *= np.linspace(0, 1, 88)
    tail = min(round(.025*RATE), count//4)
    x[-tail:] *= np.linspace(1, 0, tail)
    x *= .63/max(np.max(np.abs(x)), .0001)
    return x, [{'mix_gain':gain, **source} for gain, (_, source) in parts]


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'version':38, 'license':'CC0-1.0', 'sample_rate':RATE, 'sources':{}, 'cues':{}}
    for key, (filename, author, url, digest) in PACKS.items():
        assert sha(SOURCE/filename)==digest, filename
        manifest['sources'][key] = {'archive':filename, 'sha256':digest, 'author':author,
            'page':url, 'download':'https://opengameart.org/sites/default/files/'+filename,
            'license':'CC0-1.0', 'license_url':'https://creativecommons.org/publicdomain/zero/1.0/'}
    katana = [(.35,.54),(1.34,1.51),(2.30,2.48),(3.47,3.62),(4.54,4.69)]
    bow = [(.09,.24),(.43,.57),(.76,.91),(1.24,1.39),(2.07,2.21)]
    recurve = [(.20,.33),(1.89,2.03),(2.42,2.55),(2.94,3.08),(3.39,3.53)]
    passing = [(.04,.42),(.69,1.13),(1.41,1.92),(2.09,2.60),(2.70,3.28)]
    for i in range(5):
        wind = load('medieval','Katana Swing.wav',katana[i])
        broad = load('medieval','Katana Swing.wav',katana[i],.78,5200)
        blade = load('sword',f'sword - StarNinjas/sword.{i+1}.ogg')
        clash = load('clash',f'sword_clash.{i+1}.ogg')
        body = load('body',f'hits/hit{i+1:02}.mp3.flac',lowpass=6500)
        heavy = load('body',f'hits/hit{i+6:02}.mp3.flac',speed=.90,lowpass=4600)
        shot = load('medieval','English Longbow Shoot.wav',bow[i])
        strong_shot = load('medieval','Scythian Recurve Shoot.wav',recurve[i])
        flight = load('medieval','Scythian Recurve Heavy Arrow Pass.wav',passing[i],1.25)
        recipes = {
            'sword_whoosh': ([(1,wind)],-17,.35),
            'sword_heavy_whoosh': ([(1,broad),(.08,clash)],-15,.45),
            'hit': ([(.8,blade),(.55,body)],-17,.40),
            'heavy_hit': ([(.65,blade),(1,heavy)],-13,.55),
            'spear_wind': ([(1,load('medieval','Katana Swing.wav',katana[i],.92,7500))],-17,.35),
            'spear_hit': ([(.25,blade),(1,body)],-17,.32),
            'spear_heavy_hit': ([(.35,blade),(1,heavy)],-13,.46),
            'blunt_whoosh': ([(1,load('medieval','Katana Swing.wav',katana[i],.70,3300))],-17,.42),
            'blunt_hit': ([(1,body)],-17,.42),
            'blunt_heavy_hit': ([(1,heavy),(.25,body)],-13,.55),
            'bow_release': ([(1,shot),(.12,wind)],-15,.30),
            'bow_heavy_release': ([(1,strong_shot),(.28,flight)],-14,.45),
            'arrow_hit': ([(1,load('body',f'hits/hit{i+16:02}.mp3.flac',speed=1.15,lowpass=4800)),(.12,shot)],-17,.28),
            'shield_hit': ([(1,clash),(.18,body)],-16,.65),
            'guard_break': ([(1,load('clash',f'sword_clash.{i+6}.ogg',speed=.85)),(.25,heavy)],-14,.75),
        }
        for cue, (parts,gain,limit) in recipes.items():
            x, edits = mix(parts,limit)
            path = OUT/f'{cue}_{i}.wav'
            sf.write(path,x,RATE,subtype='PCM_16')
            decoded, sr = sf.read(path)
            assert sr==RATE and .05<len(decoded)/RATE<.8 and abs(decoded).max()<.64
            assert np.sqrt(np.mean(decoded**2))>.01
            manifest['cues'].setdefault(cue,{'gain_db':gain,'variants':[]})['variants'].append(
                {'file':path.name,'sha256':sha(path),'seconds':len(decoded)/RATE,'sources':edits})
    for alias, cue in [('guard','shield_hit'),('kick_whoosh','blunt_whoosh')]:
        manifest['cues'][alias] = manifest['cues'][cue]
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    credits = ['Weapon foley v38 / 武器打擊音效', 'All source recordings: CC0 1.0 Universal.',
               'https://creativecommons.org/publicdomain/zero/1.0/', '',
               'Edits: isolated takes, silence trim, resampling, EQ, layered impacts, fades and peak normalization.',
               'Source recordings and edits are identified per WAV in manifest.json. No movie soundtrack excerpts.', '']
    for source in manifest['sources'].values(): credits += [source['author'],source['page'],source['download'],'']
    (OUT/'CREDITS.txt').write_text('\n'.join(credits),encoding='utf-8')
    chunks=[]; chapters=[]; seconds=0
    for cue in ['sword_whoosh','hit','heavy_hit','shield_hit','blunt_whoosh','blunt_hit','blunt_heavy_hit','spear_wind','spear_hit','bow_release','bow_heavy_release','arrow_hit']:
        chapters.append({'cue':cue,'seconds':seconds})
        for take in manifest['cues'][cue]['variants'][:2]:
            x,_=sf.read(OUT/take['file']); gap=np.zeros(round(.20*RATE))
            chunks.extend([x*.75,gap]);seconds+=(len(x)+len(gap))/RATE
        chunks.append(np.zeros(round(.45*RATE))); seconds+=.45
    sf.write(CACHE/'weapons-preview.wav',np.concatenate(chunks),RATE,subtype='PCM_16')
    (CACHE/'preview-chapters.json').write_text(json.dumps(chapters,indent=2)+'\n')
    print('WEAPON AUDIO BUILD PASS: 75 unique WAVs, 17 cue routes, 5 takes per route')


if __name__=='__main__': build()
