"""Check the delivery route without generating or accepting any synthetic speech."""
import importlib.util
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('voices_v31',ROOT/'scripts/generate-voices-v31.py')
revision = importlib.util.module_from_spec(spec)
spec.loader.exec_module(revision)
jobs = [j for actor in revision.source['actors'] for j in revision.jobs(actor)]
assert len(jobs) == 96
assert len({(j[0],j[1],j[2]) for j in jobs}) == 96
for actor,event,index,text,instruction,short,subtitle in jobs:
    profile = revision.source['actors'][actor]
    assert instruction == profile['description']+' Fixed speaker preset '+profile['speaker']+'. Performance: '+revision.source['delivery'][event]
    assert short == (event in ['attack','heavy','hurt'])
    assert text and 'flat intonation' not in instruction and 'not shouting' not in instruction
assert revision.source['actors']['oichi']['hurt'] == ['痛っ！','くっ！','うっ！']
assert 'highpass=f=60' in revision.voice.pipeline.FILTER

class Probe:
    calls = []
    def generate_custom_voice(self,**kwargs):
        self.calls.append(kwargs)
        return [np.zeros(2400,dtype=np.float32)],24000

probe = Probe()
revision.voice.pipeline.MODEL = probe
target = ROOT/'artifacts/voice-v31/tadakatsu_v31_instruction-probe.wav'
target.parent.mkdir(parents=True,exist_ok=True)
for event in ['heavy','hurt','victory']:
    job = next(j for j in jobs if j[0]=='tadakatsu' and j[1]==event)
    revision.voice.pipeline.render_audio(job[3],job[4],target,123)
    assert probe.calls[-1]['instruct'] == job[4] and probe.calls[-1]['language'] == 'Japanese'
    assert probe.calls[-1]['speaker'] == revision.source['actors']['tadakatsu']['speaker']
assert len({c['instruct'] for c in probe.calls}) == 3
assert len({p['speaker'] for p in revision.source['actors'].values()}) == 6
print('VOICE V31 INSTRUCTION ROUTE PASS: 96 jobs; six fixed speakers; exertion, pain and triumph reach CustomVoice independently; no audio audition claimed')
