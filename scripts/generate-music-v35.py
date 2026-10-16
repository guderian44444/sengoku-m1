"""Render scene-specific acoustic scores from verified recorded instrument samples.

Run fetch-music-v35.py first. numpy, scipy and soundfile are build-only dependencies.
The new melodies reference the requested historical-game mood, not an OST transcription.
"""
import argparse
from collections import Counter
from functools import lru_cache
import hashlib
import html
import json
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools/music-v35-python'))
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, butter, sosfilt

SOURCES = ROOT/'assets/music-v35-sources'
OUT = ROOT/'game/audio/v35'
RATE = 44100
# title, tempo, tonic, scale, melodic phrase, energy, lead
SCORES = {
    'legacy': ('天下布武', 104, 50, [0,2,3,7,8], [0,2,3,4,3,2,0,-1,0,3,5,4,3,1,2,0], .7, 'violin'),
    'bamboo': ('竹霧潛行', 82, 50, [0,1,5,7,10], [3,2,0,-1,0,2,1,0,3,4,5,3,2,1,0,-1], .25, 'flute'),
    'town': ('城下行旅', 114, 55, [0,2,5,7,9], [0,2,3,2,1,0,1,2,3,4,5,3,4,2,1,0], .45, 'harp'),
    'siege': ('雨道進軍', 132, 50, [0,2,3,7,8], [0,0,2,3,4,3,2,0,3,4,5,4,3,2,1,0], .82, 'violin'),
    'castle': ('破寨之陣', 144, 50, [0,1,5,7,8], [0,3,2,3,5,4,3,2,3,5,6,5,4,3,1,0], .9, 'violin'),
    'camp': ('夕照兵糧', 96, 53, [0,2,5,7,9], [2,0,1,2,3,2,0,-1,0,2,4,3,2,1,0,-1], .4, 'harp'),
    'courtyard': ('池石微風', 78, 50, [0,2,3,7,8], [4,3,2,0,1,2,0,-1,0,2,3,5,4,3,2,0], .22, 'flute'),
    'river': ('川岸伏兵', 108, 50, [0,1,5,7,10], [0,2,1,0,-1,0,2,3,4,3,2,1,3,2,0,-1], .58, 'flute'),
    'miniboss': ('陣將交鋒', 150, 50, [0,1,5,7,8], [0,0,3,2,4,3,2,1,3,4,5,6,5,3,2,0], .95, 'violin'),
    'boss': ('大將決戰', 164, 50, [0,2,3,7,8], [0,3,4,3,2,0,2,3,5,6,5,4,3,4,2,0], 1.0, 'violin'),
}


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def load_bank():
    bank = {}
    for row in json.loads((SOURCES/'manifest.json').read_text('utf-8'))['samples']:
        path = SOURCES/row['file']
        assert digest(path) == row['sha256'], path
        instrument = row['instrument']
        if not instrument: continue
        data, rate = sf.read(path, dtype='float32', always_2d=True)
        assert len(data) > 100 and np.isfinite(data).all()
        data = data.mean(axis=1)
        if rate != RATE:
            common = math.gcd(rate, RATE)
            data = resample_poly(data, RATE//common, rate//common)
        data -= data.mean()
        audible = np.flatnonzero(np.abs(data) > np.max(np.abs(data))*.004)
        data = data[max(0,int(audible[0])-80):]
        data *= .65/max(float(np.max(np.abs(data))),.001)
        note = 0
        match = re.search(r'_([A-G])(#?)(\d)_',path.name)
        if match:
            # VSCO names middle C C3; MIDI calls it C4.
            note = (int(match[3])+2)*12 + {'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[match[1]] + bool(match[2])
        bank.setdefault(instrument,[]).append((note,data.astype(np.float32),row['file']))
    assert set(bank) == {'violin','violin_short','cello','cello_short','harp','flute','bass_drum','taiko_low','taiko_high','sticks'}
    return bank


def compose(key, cfg, bank):
    title, bpm, tonic, scale, phrase, energy, lead = cfg
    bars = 24 if key in ['bamboo','courtyard','camp','legacy'] else 32
    beat = 60/bpm
    count = round(bars*4*beat*RATE)
    mix = np.zeros((count,2),np.float32)
    rng = np.random.default_rng(35000+list(SCORES).index(key))
    events = []
    turns = Counter()

    @lru_cache(maxsize=512)
    def tone(instrument, midi, variant, length):
        choices = bank[instrument]
        nearest = min(abs(note-midi) for note,_,_ in choices)
        choices = [row for row in choices if abs(row[0]-midi) == nearest]
        note, raw, source = choices[variant%len(choices)]
        ratio = 2**((midi-note)/12) if note else 1
        data = resample_poly(raw,10000,round(10000*ratio)) if abs(ratio-1)>.0001 else raw.copy()
        if note:
            size = min(len(data),round((length+.12)*RATE))
            data = data[:size].copy()
            fade = min(round(.12*RATE),len(data)//3)
            data[-fade:] *= np.linspace(1,0,fade)
        attack = min(60,len(data))
        data[:attack] *= np.linspace(0,1,attack)
        data[-min(120,len(data)):] *= np.linspace(1,0,min(120,len(data)))
        return data, source

    def add(inst, bar, when, duration, midi=0, velocity=.5, pan=0):
        turns[inst] += 1
        data, source = tone(inst,int(midi),turns[inst]%2,round(duration*beat,4))
        onset = ((bar*4+when)*beat + rng.uniform(-.007,.007))%(count/RATE)
        start = round(onset*RATE)%count
        vel = velocity*rng.uniform(.94,1.04)
        gains = np.sqrt(np.array([(1-pan)/2,(1+pan)/2]))*vel
        sound = data[:,None]*gains
        assert len(sound)<count
        first = min(count-start,len(sound))
        mix[start:start+first] += sound[:first]
        if first<len(sound): mix[:len(sound)-first] += sound[first:]
        events.append({'instrument':inst,'beat':round(bar*4+when,4),'seconds':round(onset,5),'duration_beats':duration,'midi':midi,'velocity':round(vel,4),'sample':source})

    def pitch(degree):
        octave, index = divmod(degree,len(scale))
        return tonic+12+octave*12+scale[index]

    for bar in range(bars):
        section = bar//8
        swell = [.78,.96,1.04,.88][section]
        root = tonic+[0,0,-2,-5,0,3,-2,-5][bar%8]
        add('cello',bar,0,3.8,root-12,.35*swell,-.12)
        add('violin',bar,.05,3.6,root+7,.14*swell,.24)
        # Rhythmic bowed strings carry the battle pulse; no synth bass or four-on-the-floor kick.
        pulses = [0,1.5,2,3] if energy>.65 else [0,2.5]
        for j, when in enumerate(pulses):
            add('cello_short',bar,when,.38,root+(7 if j%2 else 0),(.35+energy*.22)*swell,-.24)
            if energy>.7 and section != 0:
                add('violin_short',bar,when+.01,.34,root+19,.20*swell,.3)
        if key in ['bamboo','courtyard']:
            pattern = [(0,1.4),(2.25,1.35)] if bar%4 != 3 else [(0,2.4)]
        elif key in ['town','camp']:
            pattern = [(0,.7),(.75,.65),(1.75,.8),(3, .8)]
        else:
            pattern = [(0,.85),(1,.65),(2,1.1),(3.5,.4)] if bar%2==0 else [(0,1.4),(1.75,.65),(2.75,1.0)]
        for j,(when,duration) in enumerate(pattern):
            degree = phrase[((bar%8)*2+j)%len(phrase)]
            if section == 2 and bar%4 in [1,2]: degree += 5
            if bar%8==7 and j==len(pattern)-1: degree=0
            add(lead,bar,when,duration,pitch(degree),(.58 if lead=='violin' else .72)*swell,.14)
            if energy>.85 and section==2:
                add('violin_short',bar,when,.5,pitch(degree)-12,.25,-.25)
        for j,when in enumerate([.5,2.5] if energy<.6 else [.5,1.5,2.5,3.5]):
            add('harp',bar,when,.85,root+12+[0,7,12,7][j],.26*swell,-.35)
        if energy<.3:
            if bar%4==0: add('taiko_low',bar,0,2,velocity=.17,pan=-.1)
            if bar%4==2: add('sticks',bar,3,1,velocity=.1,pan=.3)
        else:
            add('taiko_low',bar,0,2,velocity=(.42+.35*energy)*swell,pan=-.18)
            add('taiko_high',bar,2,1,velocity=(.3+.3*energy)*swell,pan=.25)
            for when in ([1.5,3.5] if energy>.6 else [3.25]):
                add('taiko_high',bar,when,.5,velocity=.27*energy*swell,pan=.27)
            if energy>.65:
                if bar%2==0: add('bass_drum',bar,0,2,velocity=.48*energy)
                for when in [1,2.75,3.25]: add('sticks',bar,when,.2,velocity=.15*energy,pan=-.32)
            if bar%4==3:
                for j in range(4 if energy>.7 else 2):
                    add('taiko_high',bar,3+j*.25,.2,velocity=(.18+j*.045)*energy,pan=(-.25 if j%2 else .25))
    # Circular room reflections preserve the tail across a complete musical repeat.
    dry = mix.copy()
    for delay,gain in [(.067,.10),(.113,.075),(.191,.045),(.307,.025)]:
        mix += np.roll(dry,round(delay*RATE),axis=0)[:,::-1]*gain
    sos = butter(2,32,fs=RATE,btype='highpass',output='sos')
    mix = sosfilt(sos,np.concatenate([mix[-RATE:],mix]))[RATE:]
    mix -= mix.mean(axis=0)
    target_rms = .115 if energy<.3 else (.165 if energy>.8 else .14)
    mix *= min(.88/np.max(np.abs(mix)),target_rms/np.sqrt(np.mean(mix**2)))
    path = OUT/f'{key}-loop.wav'
    sf.write(path,mix,RATE,subtype='PCM_16')
    sf.write(ROOT/f'artifacts/music-v35/{key}-preview.wav',mix[:RATE*24],RATE,subtype='PCM_16')
    return {'title':title,'bpm':bpm,'bars':bars,'seconds':len(mix)/RATE,'file':path.name,'sha256':digest(path),
            'peak':float(np.max(np.abs(mix))),'rms':float(np.sqrt(np.mean(mix**2))),
            'boundary_sample_delta':float(np.max(np.abs(mix[0]-mix[-1]))),
            'instruments':dict(Counter(e['instrument'] for e in events)),'score':events}


def verify(manifest):
    assert set(manifest['tracks'])==set(SCORES)
    hashes=set()
    for key,row in manifest['tracks'].items():
        path=OUT/row['file']
        assert digest(path)==row['sha256'],key
        data,rate=sf.read(path,always_2d=True)
        assert rate==RATE and data.shape[1]==2 and 40<len(data)/rate<100,key
        assert np.isfinite(data).all() and np.max(np.abs(data))<.91,key
        assert .04<np.sqrt(np.mean(data**2))<.19,key
        assert np.max(np.abs(data[0]-data[-1]))<.025,(key,'loop seam')
        assert len(set(e['midi'] for e in row['score'] if e['midi']))>=12,key
        assert all(np.sqrt(np.mean(chunk**2))>.008 for chunk in np.array_split(data,int(len(data)/RATE))),key
        assert any(e['instrument'].startswith('taiko') for e in row['score']),key
        hashes.add(row['sha256'])
    assert len(hashes)==len(SCORES)
    print(f'MUSIC V35 PASS: {len(hashes)} distinct acoustic loops, source hashes, levels, notes and seams')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if args.check:
        verify(json.loads((OUT/'music.json').read_text('utf-8')))
        return
    OUT.mkdir(parents=True,exist_ok=True)
    (ROOT/'artifacts/music-v35').mkdir(parents=True,exist_ok=True)
    bank=load_bank()
    tracks={}
    for key,cfg in SCORES.items():
        tracks[key]=compose(key,cfg,bank)
        print(f'{key}: {tracks[key]["seconds"]:.1f}s, {len(tracks[key]["score"])} notes',flush=True)
    manifest={'version':'v35','recipe':'scripts/generate-music-v35.py','license':'CC-BY-SA-4.0',
              'origin':'New scene compositions; recorded SCC Taiko Drums and VSCO 2 CE instruments. No game OST audio or note-for-note transcription.',
              'reference_direction':['吞食天地 II 赤壁之戰','三國志','信長之野望','無雙'],
              'listening_review':'pending user audition; technical checks do not certify musical taste',
              'sources':'assets/music-v35-sources/manifest.json','tracks':tracks}
    (OUT/'music.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    verify(manifest)
    cards=''.join(f'<section><h2>{html.escape(row["title"])} · {row["bpm"]} BPM</h2><audio controls preload="none" src="{key}-preview.wav"></audio></section>' for key,row in tracks.items())
    (ROOT/'artifacts/music-v35/preview.html').write_text('<!doctype html><meta charset="utf-8"><title>戰國鼓弦試聽</title><style>body{background:#221b15;color:#ead9b5;max-width:900px;margin:40px auto;font-family:serif}section{padding:16px;border-bottom:1px solid #69543b}audio{width:100%}</style><h1>戰國鼓弦試聽</h1><p>每段 24 秒。實錄太鼓、大鼓、弦樂、豎琴與長笛；新作旋律，尚待真人試聽。</p>'+cards,encoding='utf-8')


if __name__=='__main__': main()
