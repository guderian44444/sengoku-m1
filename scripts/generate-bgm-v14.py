"""Original 80-second battle score; no sampled music or third-party melody.

Deterministic additive/plucked-string, breath-flute and membrane-drum synthesis.
Circular placement and delay tails keep the 48-bar arrangement loop continuous.
"""
import hashlib
import json
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v14"
RATE, BPM, BARS, SEED = 44100, 144, 48, 14041
BEAT = 60 / BPM
SECONDS = BARS * 4 * BEAT
COUNT = round(SECONDS * RATE)
RNG = np.random.default_rng(SEED)
MIX = np.zeros((COUNT, 2), np.float32)
SCORE = []


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def pluck(midi, seconds, bass=False):
    t = np.arange(round(seconds * RATE)) / RATE
    f = hz(midi)
    tone = np.zeros(len(t))
    # Fast upper partial decay supplies the shamisen's bright bachi transient.
    for harmonic in range(1, 13 if not bass else 7):
        partial = f * harmonic * (1 + .00008 * harmonic * harmonic)
        if partial >= RATE * .47:
            continue
        tone += np.sin(2*np.pi*partial*t) * np.exp(-t*(3.0 + harmonic*.85)) / harmonic**.86
    pick = RNG.normal(0, .15, len(t)) * np.exp(-t*250)
    tone = (tone*.37 + pick) * np.minimum(t/.0015, 1)
    tone *= np.minimum((seconds-t)/.04, 1)
    return tone


def flute(midi, seconds):
    t = np.arange(round(seconds * RATE)) / RATE
    f = hz(midi)
    bend = -.16 * np.exp(-t*18)
    vibrato = .07 * np.sin(2*np.pi*5.1*t) * np.minimum(t/.22, 1)
    phase = np.cumsum(f * 2**((bend+vibrato)/12)) * (2*np.pi/RATE)
    breath = sosfilt(butter(2, [1100, 6200], btype="bandpass", fs=RATE, output="sos"), RNG.normal(0, 1, len(t)))
    tone = np.sin(phase) + .21*np.sin(2*phase) + .09*np.sin(3*phase) + .035*np.sin(5*phase)
    envelope = np.minimum(t/.035, 1) * np.minimum((seconds-t)/.09, 1)
    envelope *= .9 + .1*np.sin(np.pi*t/max(seconds,.1))
    return (tone*.43 + breath*.075) * envelope


def drum(high=False):
    seconds = .43 if high else 1.0
    t = np.arange(round(seconds * RATE)) / RATE
    f0 = 145 if high else 48
    phase = 2*np.pi*(f0*t + (10 if high else 15)*(.065*(1-np.exp(-t/.065))))
    body = np.sin(phase)*np.exp(-t*(14 if high else 5.3))
    modes = .35*np.sin(2*np.pi*f0*1.58*t)*np.exp(-t*13)
    modes += .2*np.sin(2*np.pi*f0*2.14*t)*np.exp(-t*22)
    slap = sosfilt(butter(2, 850 if high else 1400, btype="highpass", fs=RATE, output="sos"), RNG.normal(0, 1, len(t)))
    return (body+modes+slap*(.6 if high else .24)*np.exp(-t*70)) * np.minimum(t/.001,1) * .6


def wood():
    t = np.arange(round(.095*RATE))/RATE
    return (np.sin(2*np.pi*1450*t)+.4*np.sin(2*np.pi*2180*t)+RNG.normal(0,.2,len(t)))*np.exp(-t*75)*np.minimum(t/.001,1)*.24


def add(instrument, bar, beat, duration, midi=0, velocity=1, pan=0):
    start = round((bar*4+beat)*BEAT*RATE)
    if instrument == "shamisen":
        tone = pluck(midi, duration*BEAT)
    elif instrument == "bass_string":
        tone = pluck(midi, duration*BEAT, True)
    elif instrument == "bamboo_flute":
        tone = flute(midi, duration*BEAT)
    elif instrument in ["odaiko", "shime"]:
        tone = drum(instrument == "shime")
    else:
        tone = wood()
    gains = np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)]) * velocity
    sound = (tone[:,None] * gains).astype(np.float32)
    first = min(len(sound),COUNT-start)
    MIX[start:start+first] += sound[:first]
    if first < len(sound):
        MIX[:len(sound)-first] += sound[first:]
    SCORE.append({"instrument":instrument,"bar":bar,"beat":beat,"duration_beats":duration,"midi":midi,"velocity":velocity,"pan":pan})


def compose():
    motifs = [
        [(0,74,.75),(1,77,.45),(1.5,79,.45),(2,81,1),(3.25,79,.6)],
        [(0,77,1),(1.5,74,.45),(2,72,.8),(3,74,.8)],
        [(0,79,.55),(.75,81,.65),(2,84,.8),(3,81,.7)],
        [(0,79,1.2),(1.5,77,.45),(2.25,74,1.5)],
        [(0,77,.6),(.75,79,.6),(1.5,81,.4),(2,79,.75),(3,77,.8)],
        [(0,74,.8),(1.25,72,.5),(2,69,.85),(3,72,.75)],
        [(0,74,.45),(.5,77,.45),(1,79,.45),(1.5,81,.45),(2.5,84,1)],
        [(0,81,.8),(1.25,79,.5),(2,77,.45),(2.75,74,1.1)],
    ]
    roots = [50,50,48,46,50,48,46,45]
    for bar in range(BARS):
        section = bar//16
        root = roots[bar%8]
        intensity = [.8,1.0,1.12][section]
        add("bass_string",bar,0,2.6,root-12,.34,-.1)
        add("bass_string",bar,2,1.9,root-5,.23,.12)
        arp = [0,7,12,15,12,7,10,7] if bar%2 == 0 else [0,12,7,15,19,12,7,10]
        if section == 1:
            arp = [12,7,15,12,19,15,12,7]
        for eighth, interval in enumerate(arp):
            velocity = intensity * (.29 if eighth%2 else .42)
            add("shamisen",bar,eighth*.5,.95,root+interval,velocity,-.34)
        if section == 2 and bar%4 in [1,3]:
            for beat in [1.75,3.75]:
                add("shamisen",bar,beat,.5,root+24,.22,.38)
        phrase = motifs[(bar+(2 if section==1 else 0))%8]
        for beat,note,length in phrase:
            if bar%16 in [7,15] and beat < 1:
                continue
            transpose = 12 if section==1 and bar%4==2 else 0
            add("bamboo_flute",bar,beat,length,note+transpose,.35 if section==0 else .42,.16)
        # The last bar resolves gently into the first downbeat; its tail wraps.
        if bar == BARS-1:
            add("bamboo_flute",bar,3.75,1.25,74,.23,.18)
        for beat,accent in [(0,1),(1.5,.6),(2,.82),(3.5,.62)]:
            add("odaiko",bar,beat,1,velocity=accent*intensity*.63)
        for beat in ([1,3] if section==0 else [.75,1,2.75,3]):
            add("shime",bar,beat,.5,velocity=.23*intensity,pan=.23)
        for beat in [.5,1.5,2.5,3.5]:
            add("woodblock",bar,beat,.25,velocity=.17 if section==0 else .23,pan=-.35)
        if bar%4 == 3:
            for beat,accent in [(3,.25),(3.25,.33),(3.5,.43),(3.75,.56)]:
                add("shime",bar,beat,.25,velocity=accent*intensity,pan=.18)
        if bar%16 == 15:
            add("odaiko",bar,3.75,1,velocity=.66)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    compose()
    # Circular delays, not an ending fade, preserve room tails across the loop.
    wet = MIX.copy()
    for seconds,gain in [(.083,.07),(.137,.045),(.211,.032),(.337,.025)]:
        wet += np.roll(MIX,round(seconds*RATE),axis=0)[:,::-1]*gain
    wet -= wet.mean(axis=0)
    wet = np.tanh(wet*.9)
    wet *= .88/np.max(np.abs(wet))
    pcm = np.round(wet*32767).astype('<i2')
    target = OUT / "sengoku-battle-loop.wav"
    with wave.open(str(target),'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    seam = float(np.max(np.abs(wet[0]-wet[-1])))
    spec = {
        "title":"戦鼓の道 / 戰鼓之路", "version":"0.14", "file":target.name,
        "origin":"Original procedural composition and instrument synthesis; no external samples or copied melodies",
        "seconds":SECONDS,"sample_rate":RATE,"channels":2,"bpm":BPM,"bars":BARS,"beats_per_bar":4,"seed":SEED,
        "sections":[{"bars":[0,15],"name":"Theme and response"},{"bars":[16,31],"name":"Rising flute / shifted plucks"},{"bars":[32,47],"name":"Full drums / return to tonic"}],
        "instruments":["bamboo_flute","shamisen","bass_string","odaiko","shime","woodblock"],
        "loop_begin":0,"loop_end":COUNT,"boundary_sample_delta":seam,
        "peak":float(np.max(np.abs(wet))),"rms":float(np.sqrt(np.mean(wet**2))),
        "sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
        "recipe":"scripts/generate-bgm-v14.py","listening_review":"pending",
        "events":SCORE,
    }
    (OUT/'music.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert SECONDS == 80 and seam < .035
    assert len(SCORE)>800 and np.max(np.abs(pcm))<32767
    print(f"PASS: original {SECONDS:.0f}s stereo loop, {len(SCORE)} events, seam delta {seam:.6f}")


if __name__ == '__main__':
    main()
