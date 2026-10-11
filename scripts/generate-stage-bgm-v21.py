"""Distinct original area/boss arrangements; no external samples or melodies.

Uses the existing string/drum synth, adds a soft xiao-like breath pipe and
metal jingles, and wraps note/reverb tails across the complete PCM loop.
"""
import hashlib
import importlib.util
import json
import sys
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v21"
spec = importlib.util.spec_from_file_location("instruments", ROOT / "scripts/generate-bgm-v14.py")
synth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(synth)

SCORES = {
    "bamboo": {"title": "竹霧簫行", "bpm": 72, "bars": 16, "seed": 21001,
               "mood": "竹林與池石庭園；低音簫長句、呼吸留白、疏落撥弦，無戰鼓",
               "roots": [50, 50, 53, 48, 50, 55, 48, 45], "peak": .64, "max_rms": .085},
    "town": {"title": "市集鈴鼓", "bpm": 124, "bars": 32, "seed": 21002,
             "mood": "山腳市集；金屬鈴鼓、歡快小鈴、三味線切分問答",
             "roots": [57, 55, 57, 60, 57, 62, 55, 52], "peak": .82, "max_rms": .14},
    "miniboss": {"title": "陣將逼近", "bpm": 152, "bars": 32, "seed": 21003,
                 "mood": "小王登場；緊繃反覆低弦、太鼓重拍與締太鼓滾奏",
                 "roots": [50, 49, 50, 53, 50, 55, 49, 48], "peak": .86, "max_rms": .17},
    "boss": {"title": "大將戰鼓", "bpm": 174, "bars": 32, "seed": 21004,
             "mood": "大王決戰；低沉大太鼓與左右對鼓、急促低弦、短促高笛回應",
             "roots": [47, 46, 47, 50, 47, 53, 46, 45], "peak": .9, "max_rms": .21},
}


def custom_tone(instrument, midi, seconds):
    t = np.arange(round(seconds * synth.RATE)) / synth.RATE
    if instrument == "xiao":
        bend = -.18 * np.exp(-t * 9) + .05 * np.sin(2 * np.pi * 4.4 * t) * np.minimum(t / .4, 1)
        phase = np.cumsum(synth.hz(midi) * 2 ** (bend / 12)) * (2 * np.pi / synth.RATE)
        breath = sosfilt(butter(2, [650, 3300], btype="bandpass", fs=synth.RATE, output="sos"), synth.RNG.normal(0, 1, len(t)))
        envelope = np.minimum(t / .11, 1) * np.minimum((seconds - t) / .2, 1)
        return (.43 * np.sin(phase) + .045 * np.sin(2 * phase) + .035 * breath) * envelope
    if instrument == "bell":
        tone = sum(np.sin(2 * np.pi * synth.hz(midi) * ratio * t) * np.exp(-t * decay) * gain
                   for ratio, decay, gain in [(1, 3.8, .24), (2.71, 6.2, .09), (4.08, 9, .045)])
    else:
        # Several inharmonic disk modes plus a short hiss create a shaken jingle.
        tone = np.zeros(len(t))
        for frequency in [2137, 2981, 3877, 5101, 6733]:
            tone += np.sin(2 * np.pi * frequency * t + synth.RNG.uniform(-.2, .2)) * .055 * np.exp(-t * 17)
        hiss = sosfilt(butter(2, 4200, btype="highpass", fs=synth.RATE, output="sos"), synth.RNG.normal(0, .18, len(t)))
        tone += hiss * np.exp(-t * 22)
        if instrument == "tambourine":
            tone += .22 * np.sin(2 * np.pi * 187 * t) * np.exp(-t * 32)
    return tone * np.minimum(t / .001, 1) * np.minimum((seconds - t) / .025, 1)


def add(instrument, bar, beat, duration, midi=0, velocity=1, pan=0):
    if instrument not in ["xiao", "bell", "tambourine", "jingle"]:
        return synth.add(instrument, bar, beat, duration, midi, velocity, pan)
    start = round((bar * 4 + beat) * synth.BEAT * synth.RATE)
    tone = custom_tone(instrument, midi, duration * synth.BEAT)
    gains = np.sqrt(np.array([1 - pan, 1 + pan]) / 2) * velocity
    sound = (tone[:, None] * gains).astype(np.float32)
    first = min(len(sound), synth.COUNT - start)
    synth.MIX[start:start + first] += sound[:first]
    if first < len(sound): synth.MIX[:len(sound) - first] += sound[first:]
    synth.SCORE.append({"instrument": instrument, "bar": bar, "beat": beat,
                        "duration_beats": duration, "midi": midi, "velocity": velocity, "pan": pan})


def compose(key, cfg):
    synth.BPM, synth.BARS = cfg["bpm"], cfg["bars"]
    synth.BEAT = 60 / synth.BPM
    synth.SECONDS = synth.BARS * 4 * synth.BEAT
    synth.COUNT = round(synth.SECONDS * synth.RATE)
    synth.MIX = np.zeros((synth.COUNT, 2), np.float32)
    synth.SCORE = []
    synth.RNG = np.random.default_rng(cfg["seed"])
    for bar in range(synth.BARS):
        root = cfg["roots"][bar % 8]
        response = (bar // 8) % 2
        if key == "bamboo":
            phrase = [[(0, 12, 2.7), (3, 19, 1.65)], [(.65, 17, 2.5)],
                      [(0, 15, 1.5), (2, 12, 2.65)], [(1, 7, 2.5)]][bar % 4]
            for beat, interval, duration in phrase:
                add("xiao", bar, beat, duration, root + interval + response * 2, .68, -.12)
            for beat, interval in [(0, 0), (2.5, 7)]:
                add("shamisen", bar, beat, 1.8, root + interval, .1, .3)
            if bar % 4 == 2: add("bell", bar, 3.5, 2.5, root + 24, .075, -.4)
        elif key == "town":
            add("bass_string", bar, 0, 1.3, root - 12, .31, -.1)
            add("bass_string", bar, 2, 1.1, root - 5, .23, .1)
            for beat, interval in [(0, 0), (.75, 7), (1.5, 12), (2, 9), (2.75, 7), (3.5, 12)]:
                add("shamisen", bar, beat, .65, root + interval + 12 * response, .36, -.3)
            for beat in [.25, .75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75]:
                add("jingle", bar, beat, .7, velocity=.58 if beat % 1 > .5 else .38, pan=.42)
            for beat in [0, 1.5, 2, 3.5]:
                add("tambourine", bar, beat, .8, velocity=.68, pan=-.28)
            for beat, interval in [(1, 19), (2.5, 24), (3.25, 21 if bar % 2 else 19)]:
                add("bell", bar, beat, 1.2, root + interval, .25, .2)
            if bar % 2 == 0:
                for beat, interval in [(0, 12), (1, 16), (2, 19), (3, 16)]:
                    add("bamboo_flute", bar, beat, .7, root + interval, .2, .05)
            for beat in [1, 3]: add("woodblock", bar, beat, .25, velocity=.24, pan=-.35)
        else:
            final = key == "boss"
            pulse = [0, 7, 0, 1, 0, 12, 7, 1] if final else [0, 7, 12, 1, 0, 7, 13, 7]
            for i, interval in enumerate(pulse):
                add("bass_string", bar, i * .5, .8, root - 12 + interval, .38 if i % 2 == 0 else .26, -.13)
                if i % 2 == 0 or response:
                    add("shamisen", bar, i * .5, .55, root + interval + 12, .2, .24)
            accents = [(0, .96), (.75, .53), (1.5, .68), (2, .9), (2.75, .6), (3.5, .72)] if final else [(0, .9), (1.5, .56), (2, .77), (3.5, .58)]
            for beat, strength in accents:
                add("odaiko", bar, beat, 1, velocity=strength, pan=-.17 if beat < 2 else .17)
            for beat in ([.5, 1, 1.75, 2.5, 3, 3.75] if final else [1, 2.75, 3]):
                add("shime", bar, beat, .5, velocity=.43 if final else .33, pan=.3)
            if bar % 4 in [1, 3]:
                for i in range(4 if not final else 8):
                    add("shime", bar, 3 + i * (0.25 if not final else .125), .3, velocity=.22 + i * .045, pan=(-.24 if i % 2 else .24))
            if bar % 2 == (1 if final else 0):
                for beat, interval in [(0, 24), (.75, 25), (2, 31), (3, 29 if response else 24)]:
                    add("bamboo_flute", bar, beat, .5 if final else .85, root + interval, .24 if final else .26, .12)
    # The last phrase carries into the first downbeat instead of fading to silence.
    add("xiao" if key == "bamboo" else "bamboo_flute", synth.BARS - 1, 3.5,
        2.5 if key == "bamboo" else 1.5, cfg["roots"][0] + 12, .32 if key == "bamboo" else .16, -.12)
    wet = synth.MIX.copy()
    delays = [(.143, .15), (.327, .1), (.619, .06)] if key == "bamboo" else [(.073, .07), (.137, .045), (.223, .03)]
    for seconds, gain in delays:
        wet += np.roll(synth.MIX, round(seconds * synth.RATE), axis=0)[:, ::-1] * gain
    wet -= wet.mean(axis=0)
    wet = np.tanh(wet * .9)
    wet *= min(cfg["peak"] / np.max(np.abs(wet)), cfg["max_rms"] / np.sqrt(np.mean(wet ** 2)))
    pcm = np.round(wet * 32767).astype("<i2")
    target = OUT / f"{key}-loop.wav"
    with wave.open(str(target), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(synth.RATE)
        stream.writeframes(pcm.tobytes())
    return {**cfg, "file": target.name, "seconds": synth.SECONDS,
            "sample_rate": synth.RATE, "channels": 2, "loop_begin": 0, "loop_end": synth.COUNT,
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "events": synth.SCORE,
            "boundary_sample_delta": float(np.max(np.abs(wet[0] - wet[-1]))), "peak": float(np.max(np.abs(wet))),
            "rms": float(np.sqrt(np.mean(wet ** 2)))}


def verify():
    manifest = json.loads((OUT / "music.json").read_text(encoding="utf-8"))
    fingerprints = set()
    for key, score in manifest["tracks"].items():
        target = OUT / score["file"]
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        assert digest == score["sha256"], key + " checksum mismatch"
        fingerprints.add(digest)
        with wave.open(str(target), "rb") as stream:
            assert stream.getnchannels() == 2 and stream.getsampwidth() == 2
            assert stream.getframerate() == 44100 and 32 <= stream.getnframes() / 44100 <= 80
            pcm = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").reshape(-1, 2)
        assert score["loop_end"] == len(pcm)
        signal = pcm.astype(np.float32) / 32768
        seam = float(np.max(np.abs(signal[0] - signal[-1])))
        assert seam < .02 and seam < np.quantile(np.abs(np.diff(signal, axis=0)), .999), (key, seam)
        assert np.max(np.abs(pcm)) < 32767 and .03 < np.sqrt(np.mean(signal ** 2)) < .35
        assert np.sqrt(np.mean(signal[:4410] ** 2)) > .01 and np.sqrt(np.mean(signal[-4410:] ** 2)) > .01
        instruments = {event["instrument"] for event in score["events"]}
        if key == "bamboo": assert "xiao" in instruments and not instruments.intersection({"odaiko", "shime", "tambourine"})
        if key == "town": assert {"tambourine", "jingle", "bell"}.issubset(instruments)
        if key in ["miniboss", "boss"]: assert {"odaiko", "shime"}.issubset(instruments)
        print(f"PASS: {key}, {score['bpm']} BPM / {score['seconds']:.2f}s, {len(score['events'])} events, seam {seam:.6f}, RMS {score['rms']:.3f}")
    assert len(fingerprints) == 4
    assert SCORES["bamboo"]["bpm"] < SCORES["town"]["bpm"] < SCORES["miniboss"]["bpm"] < SCORES["boss"]["bpm"]
    print("PASS: four distinct original timbres/arrangements and seamless PCM loops. Human listening review remains pending.")


if __name__ == "__main__":
    if "--verify" not in sys.argv:
        OUT.mkdir(parents=True, exist_ok=True)
        tracks = {}
        for key, cfg in SCORES.items():
            tracks[key] = compose(key, cfg)
            print("Generated " + key, flush=True)
        manifest = {"version": "0.21", "recipe": "scripts/generate-stage-bgm-v21.py",
                    "instrument_recipe": "scripts/generate-bgm-v14.py",
                    "origin": "Original procedural compositions and synthesized instruments; no external recordings or copied melodies",
                    "listening_review": "pending human audition; waveform tests do not establish musical taste or instrument realism",
                    "tracks": tracks}
        (OUT / "music.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verify()
