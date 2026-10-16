"""Repair Nobunaga's register and supply the three named chapter-two introductions.

Uses the existing local CustomVoice pipeline; original takes remain untouched.
Pitch screening detects high-register outliers, not perceived voice quality.
"""
import importlib.util
import json
import math
import os
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'artifacts/weapon-audio-v38/voices'
OUT = ROOT / 'game/audio/v38/voices'
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT/'artifacts/voice-v11-runtime/packages'))
spec = importlib.util.spec_from_file_location('v31', ROOT/'scripts/generate-voices-v31.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
voice = old.voice
voice.OUT, voice.CACHE, voice.KEY_TAG = OUT, CACHE, 'v38'
voice.pipeline.FILTER = voice.pipeline.FILTER.replace('equalizer=f=1800:t=q:w=1:g=2,', '')
BASE = ('A mature Japanese male samurai commander, aged 45, with a dark, weighty low baritone. '
        'Speak firmly from the chest, grounded resonance and a little gravel. Maintain the same deep register '
        'for dialogue, exertion and pain. No falsetto, no squeal, no rising thin voice, no singing. '
        'Force comes from breath and articulation, never from raising the pitch. ')
BOSSES = [
    ('iio_sadamune', '飯尾定宗', '渡し場を守れ！槍隊、道を塞げ！弓兵、後ろを押さえろ！', 'Aiden'),
    ('sakuma_nobumori', '佐久間信盛', '兵糧を置いていけ！前後から挟み、退路を断て！', 'Eric'),
    ('sakuma_morishige', '佐久間盛重', '佐久間盛重、ここにあり！丸根の門は、通さぬ！', 'Ryan'),
]
SPEAKERS = {'nobunaga': 'Ryan', **{a: s for a, _, _, s in BOSSES}}


def pitch(path):
    import librosa
    import numpy as np
    audio, rate = librosa.load(path, sr=16000)
    f0, voiced, _ = librosa.pyin(audio, fmin=60, fmax=650, sr=rate, frame_length=1024, hop_length=256)
    values = f0[voiced & np.isfinite(f0)]
    return {'voiced_frames': int(len(values)), 'median_hz': float(np.median(values)) if len(values) else None,
            'p90_hz': float(np.percentile(values, 90)) if len(values) else None}


def render_audio(text, instruction, target, seed):
    import torch
    import soundfile as sf
    from qwen_tts import Qwen3TTSModel
    actor = target.name.split('_v38_', 1)[0]
    if voice.pipeline.MODEL is None:
        voice.pipeline.MODEL = Qwen3TTSModel.from_pretrained(str(old.CACHE/'custom-model'),
            device_map='cuda', dtype=torch.bfloat16, attn_implementation='sdpa')
    for retry in range(12):
        torch.manual_seed(seed + retry * 100003)
        short = any('_'+event+'_' in target.name for event in ['attack','heavy','hurt'])
        wavs, rate = voice.pipeline.MODEL.generate_custom_voice(text=text, language='Japanese',
            speaker=SPEAKERS[actor], instruct=instruction, non_streaming_mode=True, max_new_tokens=64 if short else 192)
        candidate = target.with_name(target.stem + f'-register-{retry}.wav')
        sf.write(candidate, wavs[0], rate, subtype='PCM_16')
        trimmed = candidate.with_name(candidate.stem+'-screen.wav')
        voice.convert(voice.ffmpeg_executable(),candidate,trimmed,voice.pipeline.FILTER)
        metrics = voice.metrics(trimmed)
        tempo = min(1.18,max(.88,metrics['seconds']/.42)) if short else 1.0
        if short and (not .30<=metrics['seconds']/tempo<=.50 or metrics['bursts_separated_by_100ms']!=1):
            print('SHORT TAKE RETRY',target.name,metrics['seconds'],flush=True)
            continue
        final = candidate.with_name(candidate.stem+'-screen-final.wav')
        gain = min(2.5,.80/max(metrics['peak'],.001))
        voice.convert(voice.ffmpeg_executable(),trimmed,final,f'atempo={tempo:.6f},volume={gain:.6f},alimiter=limit=0.85:level=false')
        measured = pitch(final)
        voice.write_json(candidate.with_suffix('.json'), {'seed': seed + retry * 100003, **measured})
        limit = 260 if short else 230
        if actor != 'nobunaga' or measured['median_hz'] is None or (measured['median_hz'] <= limit and measured['p90_hz'] <= 360):
            target.write_bytes(candidate.read_bytes())
            return
        print('HIGH REGISTER RETRY', target.name, measured, flush=True)
    raise ValueError(f'No consistent low-register take for {target.name}')


def main():
    voice.pipeline.render_audio = render_audio
    ffmpeg = voice.ffmpeg_executable()
    generated, pools, intros = {}, {}, {}
    jobs = []
    for actor, event, index, text, _, short, subtitle in old.jobs('nobunaga'):
        delivery = ('One very short forceful chest-voice grunt, a single syllable, about 0.4 seconds. '
                    'A sudden pained grunt.' if event == 'hurt' else
                    'One very short forceful chest-voice exertion, about 0.4 seconds. No drawn-out yell.') if short else old.source['delivery'][event]
        instruction = BASE + delivery
        if event == 'hurt':
            instruction = BASE + old.source['delivery']['hurt']
            if index == 2:
                text = 'ぐはっ！'
                instruction += ' A firm tight cutoff without any pitch rise.'
        jobs.append((actor, event, index, text, instruction, short, subtitle))
    for actor, name, text, _ in BOSSES:
        jobs.insert(0, (actor, 'intro', 0, text, BASE + 'A loud battlefield challenge, crisp commands, urgent and stern.', False, name))
    for job in jobs:
        retained = job[0]=='nobunaga' and job[1]=='hurt' and job[2]<2
        if retained:
            current = json.loads((ROOT/'game/audio/v31/manifest.json').read_text('utf-8'))
            previous = current['clips'][current['actors']['nobunaga']['hurt'][job[2]]]
            key = f'nobunaga_v38_hurt_{job[2]}'
            clip = dict(previous)
            source = ROOT/'game/audio/v31'/clip['file']
            target = OUT/(key+'.wav')
            target.write_bytes(source.read_bytes())
            clip.update(file=target.name, origin='Retained stable original chest-voice hurt take, byte identical',
                        inherited_from=str(source.relative_to(ROOT)).replace('\\','/'))
        else:
            key, clip = voice.make_clip(ffmpeg, job)
            raw = ROOT/clip['raw_source']
            chosen = [p for p in raw.parent.glob(raw.stem+'-register-*.wav')
                      if p.stem.rsplit('-',1)[-1].isdigit() and voice.sha(p)==clip['raw_sha256']]
            assert len(chosen)==1, key
            selection = json.loads(chosen[0].with_suffix('.json').read_text('utf-8'))
            clip.update(attempt_seed=clip['seed'], seed=selection['seed'],
                        selected_source=str(chosen[0].relative_to(ROOT)).replace('\\','/'))
        measured = pitch(OUT/clip['file'])
        if job[0] == 'nobunaga' and not retained and measured['median_hz'] is not None:
            assert measured['median_hz'] <= (260 if job[5] else 230) and measured['p90_hz'] <= 360, (key, measured)
        clip.update(file='res://audio/v38/voices/'+clip['file'], backend='Qwen3-TTS-12Hz-1.7B-CustomVoice',
                    speaker=SPEAKERS[job[0]], pitch_screen=measured, playback_pitch=1.0)
        generated[key] = clip
        if job[0] == 'nobunaga': pools.setdefault(job[1], []).append(key)
        else:
            name = next(name for actor, name, _, _ in BOSSES if actor == job[0])
            intros[name] = {'name': name, 'line_key': key, 'ticks': math.ceil(clip['seconds']*60)+18}
        voice.write_json(CACHE/'generated.json', generated)
    assert len(generated) == 19 and len(intros) == 3
    pools['guard'] = pools['heavy'].copy()
    manifest = {'version': 38, 'clips': generated, 'actors': {'nobunaga': pools},
                'named_calls': {'nobunaga': pools['special']}, 'stage_boss_intros': intros,
                'listening_review': 'Human audition pending; pitch screening is not subjective acceptance.'}
    voice.write_json(OUT/'manifest.json.tmp', manifest)
    (OUT/'manifest.json.tmp').replace(OUT/'manifest.json')
    for name, keys in [('nobunaga', [k for k,c in generated.items() if c['actor']=='nobunaga']),
                       ('stage2-intros', [k for k,c in generated.items() if c['actor']!='nobunaga'])]:
        chunks = []
        for key in keys:
            with wave.open(str(ROOT/'game'/generated[key]['file'][6:])) as src: chunks.append(src.readframes(src.getnframes()))
            chunks.append(b'\0\0'*int(voice.RATE*.45))
        with wave.open(str(CACHE/(name+'-preview.wav')), 'wb') as dst:
            dst.setparams((1, 2, voice.RATE, 0, 'NONE', 'not compressed')); dst.writeframes(b''.join(chunks))
    print('VOICE REPAIR PASS: 14 re-performed Nobunaga cues, 2 stable original hurt takes, 3 named chapter-two introductions', flush=True)


if __name__ == '__main__': main()
