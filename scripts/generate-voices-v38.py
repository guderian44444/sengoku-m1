"""Re-perform three mature heroes and Oichi's five specified combat cries.

Uses local CustomVoice with a mature male preset and event-specific performance.
Pitch screening ranks candidate takes; perceived voice quality needs listening.
"""
import importlib.util
import json
import math
import shutil
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'artifacts/weapon-audio-v38/voices-r2'
OUT = ROOT / 'game/audio/v38/voices'
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT/'artifacts/voice-v11-runtime/packages'))
spec = importlib.util.spec_from_file_location('v31', ROOT/'scripts/generate-voices-v31.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
voice = old.voice
voice.OUT, voice.CACHE, voice.KEY_TAG = CACHE/'candidate', CACHE, 'v38'
voice.OUT.mkdir(exist_ok=True)
voice.pipeline.FILTER = voice.pipeline.FILTER.replace('equalizer=f=1800:t=q:w=1:g=2,', '')
voice.pipeline.FILTER = voice.pipeline.FILTER.replace('lowpass=f=8200,', 'lowpass=f=5800,')
BASE = ('A mature Japanese male samurai commander, aged 45, with a dark, weighty low baritone. '
        'Speak firmly from the chest, grounded resonance and a little gravel. Maintain the same deep register '
        'for dialogue, exertion and pain. No falsetto, no squeal, no rising thin voice, no singing. '
        'Force comes from breath and articulation, never from raising the pitch. ')
PROFILES = {
    'nobunaga': ('Uncle_Fu', '一位五十多岁的日本男性武将，低沉浑厚的胸腔男低音，粗粝沙哑的声线。苍劲有力，成熟威严。'),
    'ieyasu': ('Uncle_Fu', '一位五十多岁的日本男性将领，成熟浑厚的低男声，圆润厚重的胸腔共鸣，带明显沙哑颗粒。老练坚毅，语气沉着笃定。'),
    'mitsuhide': ('Uncle_Fu', '一位五十五岁的日本和尚，成熟稳重，深沉浑厚的男低音，胸腔共鸣厚实，喉音粗哑。沉静庄严，语调平稳，像阅历深厚的住持。'),
    'oichi': ('Ono_Anna', 'A mature Japanese female warrior with a firm strong alto voice and chest resonance. '
        'Assertive, athletic, dry and decisive articulation. '),
}
LOW_DELIVERY = '用自然低音说话，语气坚定有力，日语发音清晰。'
MALE_EVENTS = {
    'intro': '',
    'attack': '挥动武器时从腹部爆发的一声低沉嘶吼，粗哑有力。元音充分发声，胸腔震动，约0.4秒，短促爆发后果断收声。',
    'heavy': '全力重击时一声粗哑低吼，拼尽全力，沉重强劲的胸腔爆发。元音充分发声，约0.4秒，干脆有力地收声。',
    'hurt': '突然遭受重击，痛苦地发出一声短促而低沉的闷哼。喉部收紧，约0.4秒，立刻收声。',
    'special': '以低沉沙哑的胸腔声音喊出招式名称，苍劲有力，重音明确，气势威严。',
    'victory': '经历大战获胜后，以沉稳而有力的低音宣布胜利，成熟自信，声线粗哑厚实。',
    'defeat': '战败倒地，忍着痛苦以低沉沙哑的声音说出遗憾，字句清楚而疲惫。',
    'boss_defeat': '用浑厚沙哑的低音宣布敌将已被讨取，坚定有力，成熟威严。',
}
BOSSES = [
    ('iio_sadamune', '飯尾定宗', '渡し場を守れ！槍隊、道を塞げ！弓兵、後ろを押さえろ！', 'Aiden'),
    ('sakuma_nobumori', '佐久間信盛', '兵糧を置いていけ！前後から挟み、退路を断て！', 'Eric'),
    ('sakuma_morishige', '佐久間盛重', '佐久間盛重、ここにあり！丸根の門は、通さぬ！', 'Ryan'),
]
SPEAKERS = {a: p[0] for a, p in PROFILES.items()} | {a: s for a, _, _, s in BOSSES}
MALE_PITCH_SEMITONES = -3
KENNYO_LINES = {
    ('intro', 0): ('本願寺顕如。仏の教えとともに、進もう。', '本願寺顯如。遵循佛法，向前邁進。'),
    ('special', 0): ('南無阿弥陀仏！', '南無阿彌陀佛！'),
    ('victory', 2): ('仏の加護が、道を照らす。', '佛的庇佑，照亮前路。'),
}


def repaired_jobs():
    for actor, (_, identity) in PROFILES.items():
        for _, event, index, text, _, short, subtitle in old.jobs(actor):
            if actor == 'oichi' and not (event == 'heavy' or event == 'attack' and index in [1, 2]):
                continue
            if actor == 'nobunaga' and event == 'hurt' and index == 2:
                text = 'ぐはっ！'
            if actor == 'mitsuhide' and (event,index) in KENNYO_LINES:
                text, subtitle = KENNYO_LINES[event,index]
            if actor == 'oichi':
                delivery = ('One sharp fully voiced karate kiai, one compact burst lasting 0.3 seconds. '
                    'Strong diaphragm support, hard onset and immediate clipped cutoff. ')
                if event == 'heavy': delivery += 'Maximum physical effort, forceful strained attack. '
            else:
                delivery = MALE_EVENTS[event]
                if actor == 'mitsuhide' and event in ['attack','heavy']:
                    delivery += '低沉的喉音嘶吼，强烈而厚重的胸腔震动。'
            instruction = identity + (LOW_DELIVERY if actor != 'oichi' else '') + delivery
            yield actor, event, index, text, instruction, short, subtitle


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
    candidates = []
    for retry in range(12):
        take_seed = 307492 + retry * 100003 + int(target.stem.rsplit('-', 1)[-1])
        torch.manual_seed(take_seed)
        short = any('_'+event+'_' in target.name for event in ['attack','heavy','hurt'])
        args = dict(text=text, language='Japanese', instruct=instruction,
                    non_streaming_mode=True, max_new_tokens=24 if short else 192)
        wavs, rate = voice.pipeline.MODEL.generate_custom_voice(speaker=SPEAKERS[actor], **args)
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
        voice.write_json(candidate.with_suffix('.json'), {'seed': take_seed, **measured})
        # Rough exertion is often aperiodic; do not mistake missing f0 for a low voice.
        score = measured['median_hz'] if measured['voiced_frames'] >= 3 else 700
        candidates.append((score, candidate, measured))
        if actor not in PROFILES or score <= (280 if actor == 'oichi' else 180) or len(candidates) >= 2:
            break
        print('COMPARE TAKE', target.name, measured, flush=True)
    if not candidates: raise ValueError(f'No complete compact take for {target.name}')
    _, chosen, measured = min(candidates, key=lambda row: row[0])
    target.write_bytes(chosen.read_bytes())
    print('SELECT TAKE', target.name, measured, flush=True)


def main():
    voice.pipeline.render_audio = render_audio
    ffmpeg = voice.ffmpeg_executable()
    base = json.loads((ROOT/'game/audio/v31/manifest.json').read_text('utf-8'))
    current = json.loads((OUT/'manifest.json').read_text('utf-8')) if (OUT/'manifest.json').exists() else {}
    generated = {k: c for k, c in current.get('clips', {}).items() if c['actor'] not in PROFILES}
    pools = {a: json.loads(json.dumps(base['actors'][a])) for a in PROFILES}
    intros = current.get('stage_boss_intros', {})
    for clip in generated.values():
        shutil.copyfile(ROOT/'game'/clip['file'][6:], voice.OUT/Path(clip['file']).name)
    jobs = list(repaired_jobs())
    for actor, name, text, _ in BOSSES:
        if name not in intros:
            jobs.insert(0, (actor, 'intro', 0, text, BASE + 'A loud battlefield challenge, crisp commands, urgent and stern.', False, name))
    for job in jobs:
        key, clip = voice.make_clip(ffmpeg, job)
        raw = ROOT/clip['raw_source']
        chosen = [p for p in raw.parent.glob(raw.stem+'-register-*.wav')
                  if p.stem.rsplit('-',1)[-1].isdigit() and voice.sha(p)==clip['raw_sha256']]
        assert len(chosen)==1, key
        selection = json.loads(chosen[0].with_suffix('.json').read_text('utf-8'))
        clip.update(attempt_seed=clip['seed'], seed=selection['seed'],
                    selected_source=str(chosen[0].relative_to(ROOT)).replace('\\','/'))
        if job[0] in ['nobunaga', 'ieyasu', 'mitsuhide']:
            original = voice.OUT/clip['file']
            adjusted = CACHE/(key+'-pitch.wav')
            filters = f'rubberband=tempo=1:pitch={2**(MALE_PITCH_SEMITONES/12):.8f}:formant=shifted,alimiter=limit=0.85:level=false'
            if job[5]: filters += ',apad=whole_dur=0.30'
            voice.convert(ffmpeg, original, adjusted, filters)
            after = voice.metrics(adjusted)
            assert abs(after['seconds']-clip['seconds']) < .015 and after['clipped_fraction']==0, key
            assert not job[5] or .30<=after['seconds']<=.50, key
            clip.update(unpitched_sha256=clip['sha256'], offline_pitch_semitones=MALE_PITCH_SEMITONES,
                        seconds=after['seconds'], metrics=after, sha256=voice.sha(adjusted),
                        post_filter=clip['post_filter']+'; then '+filters)
            shutil.copyfile(adjusted, original)
        measured = pitch(voice.OUT/clip['file'])
        clip.update(file='res://audio/v38/voices/'+clip['file'],
                    backend='Qwen3-TTS-12Hz-1.7B-CustomVoice', speaker=SPEAKERS[job[0]],
                    pitch_screen=measured, playback_pitch=1.0)
        generated[key] = clip
        if job[0] in PROFILES: pools[job[0]][job[1]][job[2]] = key
        else:
            name = next(name for actor, name, _, _ in BOSSES if actor == job[0])
            intros[name] = {'name': name, 'line_key': key, 'ticks': math.ceil(clip['seconds']*60)+18}
        voice.write_json(CACHE/'generated.json', generated)
    assert len(generated) == 56 and len(intros) == 3
    for actor in PROFILES: pools[actor]['guard'] = pools[actor]['heavy'].copy()
    manifest = {'version': 38, 'voice_revision': 'r2-mature-forceful', 'clips': generated, 'actors': pools,
                'named_calls': {a: p['special'] for a, p in pools.items()}, 'stage_boss_intros': intros,
                'hero_voice_profiles': {a: {**base['hero_voice_profiles'][a], 'speaker': p[0], 'description': p[1]} for a,p in PROFILES.items()},
                'listening_review': 'Human audition pending; pitch screening is not subjective acceptance.'}
    manifest['hero_voice_profiles']['mitsuhide']['name'] = '本願寺顯如'
    # Validate the complete candidate bank before replacing any active recording.
    for key, clip in generated.items():
        assert voice.sha(voice.OUT/Path(clip['file']).name) == clip['sha256'], key
    for clip in generated.values():
        shutil.copyfile(voice.OUT/Path(clip['file']).name, OUT/Path(clip['file']).name)
    voice.write_json(OUT/'manifest.json.tmp', manifest)
    (OUT/'manifest.json.tmp').replace(OUT/'manifest.json')
    for name, keys in [(a, [k for k,c in generated.items() if c['actor']==a]) for a in PROFILES]:
        chunks = []
        for key in keys:
            with wave.open(str(ROOT/'game'/generated[key]['file'][6:])) as src: chunks.append(src.readframes(src.getnframes()))
            chunks.append(b'\0\0'*int(voice.RATE*.45))
        with wave.open(str(CACHE/(name+'-preview.wav')), 'wb') as dst:
            dst.setparams((1, 2, voice.RATE, 0, 'NONE', 'not compressed')); dst.writeframes(b''.join(chunks))
    print('VOICE REPAIR R2 PASS: 53 re-performed cues, 3 chapter-two introductions preserved', flush=True)


if __name__ == '__main__': main()
