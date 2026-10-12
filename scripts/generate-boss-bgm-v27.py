"""A faster original final-boss arrangement using the existing instrument synth."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('stage_score', ROOT / 'scripts/generate-stage-bgm-v21.py')
score = importlib.util.module_from_spec(spec)
spec.loader.exec_module(score)
score.OUT = ROOT / 'game/audio/v27'
score.OUT.mkdir(parents=True, exist_ok=True)
cfg = dict(score.SCORES['boss'], title='大將決戰・急鼓', bpm=196, seed=27001,
           roots=[45, 44, 45, 48, 45, 51, 44, 43], peak=.92, max_rms=.23, urgent=True,
           mood='急促低弦、半音張力、連續締太鼓與大太鼓重擊')
track = score.compose('boss', cfg)
assert track['boundary_sample_delta'] < .02 and track['peak'] < 1
(score.OUT / 'music.json').write_text(json.dumps({'version':'0.27','recipe':'scripts/generate-boss-bgm-v27.py',
    'origin':'Original procedural score and synthesized instruments', 'listening_review':'pending human audition',
    'tracks':{'boss':track}},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f"Generated boss score: {track['bpm']} BPM, {track['seconds']:.2f}s, RMS {track['rms']:.3f}")
