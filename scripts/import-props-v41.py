"""Build CC0 recorded impacts; source downloads stay outside the runtime package."""
import hashlib
import json
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts/stage03-v41/sources'
OUT = ROOT / 'game/audio/props-v41'
RATE = 48000

def read(path, start=0, end=None, speed=1.0):
    a, rate = sf.read(path, always_2d=True)
    a = a.mean(axis=1)[int(start*rate):None if end is None else int(end*rate)]
    a -= a.mean()
    a = np.interp(np.arange(0, len(a), rate*speed/RATE), np.arange(len(a)), a)
    a /= max(float(np.max(abs(a))), 0.001)
    a[:96] *= np.linspace(0, 1, 96)
    n = min(2400, len(a)//4)
    a[-n:] *= np.linspace(1, 0, n)
    return a

def mix(parts, seconds):
    a = np.zeros(int(seconds*RATE))
    for sample, offset, gain in parts:
        start = int(offset*RATE)
        n = min(len(sample), len(a)-start)
        a[start:start+n] += sample[:n]*gain
    a = np.tanh(a*1.4)
    a *= .89 / max(float(np.max(abs(a))), .001)
    a[-2400:] *= np.linspace(1, 0, 2400)
    return a

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cues, records = {}, {}
    chop = SOURCE / 'chop-tree-fall.ogg'
    for material in ['wood', 'box', 'wicker', 'stone', 'ceramic']:
        for action in ['hit', 'break']:
            cue = material+'_'+action
            cues[cue] = []
            for variant in range(3):
                impact = read(chop, 0, .82, .86+variant*.06)
                wood = read(SOURCE/'Hits/Wood Hits 2.wav', [0,.38,.73][variant], [.34,.70,1.07][variant], .80)
                hard = read(SOURCE/'Hits/Hard Hits.wav', [0,.54,1.08][variant], [.47,1.02,1.51][variant], .85)
                body = read(chop, 1.57, 2.45, .88)
                parts = [(impact,0,1.0),(wood,.012,.55),(body,.045,.40)]
                if material in ['stone','ceramic']: parts = [(hard,0,1),(impact,.01,.28),(body,.05,.45)]
                if material == 'wicker': parts = [(wood,0,.8),(impact,.008,.65),(body,.07,.3)]
                seconds = 1.15
                if action == 'break':
                    parts += [(read(chop,.65,2.55,.9),.13,.7),(wood,.21,.35)]
                    seconds = 2.25
                parts += [(parts[0][0],.09,.14),(parts[0][0],.19,.07)]
                data = mix(parts,seconds)
                name = f'{cue}-{variant+1}.wav'
                sf.write(OUT/name,data,RATE,subtype='PCM_16')
                cues[cue].append(name)
                records[name] = {'seconds':seconds,'sha256':hashlib.sha256((OUT/name).read_bytes()).hexdigest()}
    bell = read(ROOT/'game/audio/stage3/bell_fall.wav',speed=.8)
    data = mix([(bell,0,.85),(read(chop,1.57,2.5,.75),0,.8),(bell,.16,.22),(bell,.36,.1)],2.6)
    sf.write(OUT/'bell_fall.wav',data,RATE,subtype='PCM_16')
    cues['bell_fall'] = ['bell_fall.wav']
    records['bell_fall.wav'] = {'seconds':2.6,'sha256':hashlib.sha256((OUT/'bell_fall.wav').read_bytes()).hexdigest()}
    for name, rec in records.items():
        a,sr = sf.read(OUT/name)
        assert sr == RATE and abs(len(a)/sr-rec['seconds']) < 1/RATE and np.max(abs(a)) < .9
        assert np.sqrt(np.mean(a[:int(.3*RATE)]**2)) > .035, name
    (OUT/'manifest.json').write_text(json.dumps({'version':41,'cues':cues,'files':records},indent=2)+'\n',encoding='utf-8')
    (OUT/'CREDITS.txt').write_text('Recorded impact sources (CC0):\n'
        'tree chop fall thud — kheetor, 2025-09-19\nhttps://opengameart.org/content/tree-chop-fall-thud\n'
        'Hit sounds — pauliuw, 2010-11-14\nhttps://opengameart.org/content/hit-sounds\n'
        'License: https://creativecommons.org/publicdomain/zero/1.0/\n'
        'Edits: isolated chops, wood/solid impacts, lower pitch, reflections, normalization.\n'
        'Bell also uses existing project stage3/bell_fall.wav, layered with recorded tree landing.\n'
        'Recipe: scripts/import-props-v41.py. Sources: artifacts/stage03-v41/sources.\n',encoding='utf-8')
    print(f'PROPS V41 PASS: {len(records)} PCM files, no clipped samples, audible transients')

if __name__ == '__main__': main()
