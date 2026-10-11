"""Four original, reproducible area scores using the existing v14 instrument synth.

The score, tempo, mode, lead phrases and percussion patterns differ by area.
Notes and room tails wrap around the buffer; no ending fade or copied music.
"""
import hashlib
import importlib.util
import json
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v18"
spec = importlib.util.spec_from_file_location("instruments", ROOT / "scripts/generate-bgm-v14.py")
synth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(synth)

SCORES = {
    "siege": {
        "title": "破曉進軍", "bpm": 144, "seed": 18001,
        "mood": "城外進軍、攻城戰；三味線八分音符與大太鼓推進",
        "roots": [50, 50, 53, 48, 50, 53, 48, 45],
        "scale": [0, 3, 5, 7, 10], "arp": [0, 2, 3, 1, 4, 3, 2, 1],
        "lead": [[0, 2, 3, 4], [3, 1, 0, -1], [2, 3, 5, 4], [3, 2, 1, 0]],
        "drums": [(0, .85), (1.5, .52), (2, .72), (3.5, .55)],
        "lead_beats": [0, 1, 2.25, 3], "lead_lengths": [.85, 1.05, .6, .85],
    },
    "town": {
        "title": "町影追兵", "bpm": 120, "seed": 18002,
        "mood": "城下町與曲折道路；陰音階短句、留白與切分鼓點",
        "roots": [52, 50, 52, 48, 52, 55, 50, 47],
        "scale": [0, 1, 5, 7, 8], "arp": [0, 3, 1, 2, 4, 2],
        "lead": [[2, 1, 0], [3, 2, -1], [4, 2, 1], [2, 0, -1]],
        "drums": [(0, .72), (1.75, .4), (2.5, .57)],
        "lead_beats": [.5, 1.75, 3], "lead_lengths": [.75, 1, .8],
    },
    "castle": {
        "title": "石垣烈風", "bpm": 152, "seed": 18003,
        "mood": "二之丸、本丸與城砦交鋒；齊奏重拍與上行尺八",
        "roots": [55, 53, 55, 58, 55, 60, 53, 50],
        "scale": [0, 2, 5, 7, 9], "arp": [0, 3, 5, 2, 3, 6, 4, 3],
        "lead": [[3, 5, 4, 3, 2], [2, 3, 6, 5, 3], [5, 6, 8, 6, 5], [4, 3, 2, 1, 0]],
        "drums": [(0, .95), (.75, .5), (2, .85), (2.75, .52), (3.5, .6)],
        "lead_beats": [0, .75, 1.5, 2.5, 3.25], "lead_lengths": [.65, .6, .85, .55, .7],
    },
    "boss": {
        "title": "天守決戰", "bpm": 168, "seed": 18004,
        "mood": "內室總大將；快速低弦固定音型、重鼓與高音尺八問答",
        "roots": [47, 47, 50, 46, 47, 53, 50, 46],
        "scale": [0, 1, 5, 7, 10], "arp": [0, 2, 3, 0, 2, 4, 3, 2],
        "lead": [[5, 4, 3, 5, 6, 5], [3, 2, 1, 3, 4, 3], [5, 6, 8, 7, 6, 5], [4, 3, 2, 1, 0, 3]],
        "drums": [(0, 1), (.5, .5), (1.5, .65), (2, .9), (3, .72), (3.5, .6)],
        "lead_beats": [0, .5, 1, 2, 2.75, 3.5], "lead_lengths": [.4, .4, .7, .6, .6, .4],
    },
}


def degree(root, scale, step):
    octave, index = divmod(step, len(scale))
    return root + octave * 12 + scale[index]


def compose(key, cfg):
    synth.BPM, synth.BARS = cfg["bpm"], 32
    synth.BEAT = 60 / synth.BPM
    synth.SECONDS = synth.BARS * 4 * synth.BEAT
    synth.COUNT = round(synth.SECONDS * synth.RATE)
    synth.MIX = np.zeros((synth.COUNT, 2), np.float32)
    synth.SCORE = []
    synth.RNG = np.random.default_rng(cfg["seed"])
    add = synth.add
    for bar in range(synth.BARS):
        root = cfg["roots"][bar % 8]
        scale = cfg["scale"]
        response = bar // 8 % 2 == 1
        rising = bar >= 16
        add("bass_string", bar, 0, 2.6, root - 12, .4, -.12)
        add("bass_string", bar, 2, 1.8, root - 5, .29, .12)
        for i, note in enumerate(cfg["arp"]):
            beat = i * .5 if key != "town" else [0, .75, 1.5, 2, 2.75, 3.5][i]
            add("shamisen", bar, beat, .82, degree(root, scale, note), .38 if i % 2 == 0 else .26, -.32)
        if key == "boss":
            for beat in [.5, 1.5, 2.5, 3.5]:
                add("bass_string", bar, beat, .65, root, .27, .24)
        phrase = cfg["lead"][(bar + (1 if rising else 0)) % 4]
        for beat, note, length in zip(cfg["lead_beats"], phrase, cfg["lead_lengths"]):
            if key == "town" and bar % 4 == 1 and beat < 2:
                continue
            register = 12 if key != "town" else 0
            add("bamboo_flute", bar, beat, length, degree(root + register, scale, note), .34 if response else .39, .2)
        if rising and bar % 2 == 1:
            for beat, note in [(1.75, 5), (3.75, 3)]:
                add("shamisen", bar, beat, .45, degree(root, scale, note), .25, .36)
        for beat, strength in cfg["drums"]:
            add("odaiko", bar, beat, 1, velocity=strength * .64)
        for beat in ([1, 3] if key in ["siege", "town"] else [.75, 1, 2.75, 3]):
            add("shime", bar, beat, .5, velocity=.23 if key != "boss" else .32, pan=.26)
        for beat in ([.5, 2.5] if key == "town" else [.5, 1.5, 2.5, 3.5]):
            add("woodblock", bar, beat, .25, velocity=.19, pan=-.38)
        if bar % 4 == 3:
            for beat, strength in [(3, .23), (3.25, .31), (3.5, .42), (3.75, .52)]:
                add("shime", bar, beat, .25, velocity=strength, pan=.18)
        if bar == 31:
            add("bamboo_flute", bar, 3.75, 1.25, cfg["roots"][0] + 12, .22, .2)
    wet = synth.MIX.copy()
    for seconds, gain in [(.073, .08), (.127, .05), (.223, .035), (.347, .022)]:
        wet += np.roll(synth.MIX, round(seconds * synth.RATE), axis=0)[:, ::-1] * gain
    wet -= wet.mean(axis=0)
    wet = np.tanh(wet * .9)
    wet *= .86 / np.max(np.abs(wet))
    pcm = np.round(wet * 32767).astype("<i2")
    target = OUT / f"{key}-loop.wav"
    with wave.open(str(target), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(synth.RATE)
        stream.writeframes(pcm.tobytes())
    result = {**cfg, "file": target.name, "seconds": synth.SECONDS, "bars": synth.BARS,
              "sample_rate": synth.RATE, "channels": 2, "loop_begin": 0, "loop_end": synth.COUNT,
              "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "events": synth.SCORE,
              "boundary_sample_delta": float(np.max(np.abs(wet[0] - wet[-1]))),
              "peak": float(np.max(np.abs(wet))), "rms": float(np.sqrt(np.mean(wet ** 2)))}
    return result


def verify():
    manifest = json.loads((OUT / "music.json").read_text(encoding="utf-8"))
    hashes, fingerprints = set(), set()
    for key, score in manifest["tracks"].items():
        target = OUT / score["file"]
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        assert digest == score["sha256"], key + " checksum mismatch"
        hashes.add(digest)
        with wave.open(str(target), "rb") as stream:
            assert stream.getnchannels() == 2 and stream.getsampwidth() == 2
            pcm = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").reshape(-1, 2)
            assert 32 <= stream.getnframes() / stream.getframerate() <= 80
            assert score["loop_end"] == len(pcm)
        signal = pcm.astype(np.float32) / 32768
        seam = float(np.max(np.abs(signal[0] - signal[-1])))
        typical_step = float(np.quantile(np.abs(np.diff(signal, axis=0)), .999))
        assert seam < .02 and seam <= typical_step, (key, seam, typical_step)
        assert np.max(np.abs(pcm)) < 32767 and .03 < np.sqrt(np.mean(signal ** 2)) < .35
        assert np.sqrt(np.mean(signal[:4410] ** 2)) > .01 and np.sqrt(np.mean(signal[-4410:] ** 2)) > .01
        notes = [(event["beat"], event["midi"]) for event in score["events"] if event["instrument"] == "bamboo_flute"]
        fingerprints.add(json.dumps(notes))
        assert len(score["events"]) >= 600 and len({event["instrument"] for event in score["events"]}) >= 6
        print(f"PASS: {key} {score['seconds']:.2f}s, {len(score['events'])} score events; loop delta {seam:.6f}")
    assert len(hashes) == len(fingerprints) == 4
    print("PASS: four distinct original arrangements; waveform, duration and loop checks. Listening review remains pending.")


def main():
    if "--verify" not in sys.argv:
        OUT.mkdir(parents=True, exist_ok=True)
        tracks = {}
        for key, cfg in SCORES.items():
            tracks[key] = compose(key, cfg)
            print(f"Generated {key}", flush=True)
        manifest = {"version": "0.18", "recipe": "scripts/generate-stage-bgm-v18.py",
                    "instrument_recipe": "scripts/generate-bgm-v14.py",
                    "origin": "Original procedural composition; synthesized instruments; no external samples or melodies",
                    "listening_review": "pending", "tracks": tracks}
        (OUT / "music.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verify()


if __name__ == "__main__":
    main()
