"""Deterministic original camp bell and sword-air cues; no third-party samples."""
from array import array
from pathlib import Path
import hashlib
import json
import math
import random
import wave

DEST = Path(__file__).resolve().parents[1] / "game/audio/stage3"
RATE = 44100
DEST.mkdir(parents=True, exist_ok=True)
rng = random.Random(31016)
manifest = {}
for name, seconds in [("alarm", 2.4), ("bell_fall", 1.5), ("sword_air", .65)]:
    samples = []
    filtered = 0.0
    for index in range(round(seconds * RATE)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        filtered = .9 * filtered + .1 * noise
        if name == "alarm":
            # Periodic tails overlap across the loop boundary like a struck bronze bell.
            value = 0.0
            for strike in range(4):
                age = t + strike * seconds
                for frequency, decay, weight in [(392,1.5,.5),(785,1.1,.26),(1058,.8,.2),(1547,.55,.14),(2100,.3,.06)]:
                    value += weight * math.sin(math.tau * frequency * age) * math.exp(-age/decay) * min(1, age/.003)
            value += noise * .16 * math.exp(-t*85) * min(1,t/.002)
        elif name == "bell_fall":
            value = (math.sin(math.tau*147*t)*.6 + filtered*1.8 + math.sin(math.tau*413*t)*.15) * math.exp(-t*5) * min(1,t/.003)
        else:
            envelope = math.sin(math.pi*min(1,t/seconds)) ** 1.5
            value = (noise-filtered)*.7*envelope + math.sin(math.tau*(340*t-110*t*t))*.12*envelope
        samples.append(value)
    peak = max(abs(s) for s in samples)
    pcm = array("h", (round(s/peak*.78*32767) for s in samples))
    if name != "alarm":
        for index in range(220): pcm[-index-1] = round(pcm[-index-1]*index/220)
    assert max(abs(s) for s in pcm) <= 25559 and len(pcm) == round(seconds*RATE)
    if name == "alarm": assert abs(pcm[0]-pcm[-1]) < 1500
    target = DEST / (name+".wav")
    with wave.open(str(target), "wb") as output:
        output.setparams((1,2,RATE,len(pcm),"NONE","not compressed"))
        output.writeframes(pcm.tobytes())
    manifest[name] = {"file":target.name,"seconds":seconds,"sample_rate":RATE,"frames":len(pcm),"peak":max(abs(s) for s in pcm)/32768,"sha256":hashlib.sha256(target.read_bytes()).hexdigest(),"loop":name=="alarm"}
(DEST / "manifest.json").write_text(json.dumps({"source":"Original procedural synthesis; scripts/generate-stage3-audio.py", "cues":manifest},indent=2)+"\n",encoding="utf-8")
print("STAGE3 AUDIO PASS: 3 original cues, peak and loop-boundary checks")
