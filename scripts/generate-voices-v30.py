"""Give every playable hero a designed reference and reuse that speaker for all cues.

Uses the existing local VoiceDesign runtime, the official Base checkpoint and
v15's silence-only processing, compact-shout validation and provenance cache.
The manifest is published only after all six complete actor pools validate.
"""
import argparse
import gc
import hashlib
import html
import importlib.util
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/audio/v30'
CACHE = ROOT / 'artifacts/voice-v30'
os.environ.setdefault('NUMBA_CACHE_DIR', str(CACHE / 'numba-cache'))
os.environ.setdefault('MPLCONFIGDIR', str(CACHE / 'mpl-cache'))
spec = importlib.util.spec_from_file_location('voice_v15', ROOT / 'scripts/generate-voices-v15.py')
voice = importlib.util.module_from_spec(spec)
spec.loader.exec_module(voice)
voice.OUT, voice.CACHE, voice.KEY_TAG = OUT, CACHE, 'v30'
profiles = json.loads((OUT / 'profiles.json').read_text(encoding='utf-8'))['actors']
old_root = ROOT / 'game/audio/v27'
previous = json.loads((old_root / 'manifest.json').read_text(encoding='utf-8'))


def reference_clips(ffmpeg):
    import librosa
    import numpy as np
    import soundfile as sf
    result = {}
    pitch = {}
    ranges = {'nobunaga':(95,205),'oichi':(185,330),'hideyoshi':(160,365),'ieyasu':(85,170),'mitsuhide':(135,235),'tadakatsu':(60,135)}
    for actor, profile in profiles.items():
        text = profile.get('intro', previous['clips'][previous['actors'][actor]['intro'][0]]['text'])
        for candidate in range(6):
            description = profile['description'] + (f' Voice candidate {candidate}.' if candidate else '')
            key, clip = voice.make_clip(ffmpeg, (actor, 'intro', 0, text, description, False, None))
            assert 2 < clip['seconds'] < 7, 'Speaker reference must contain a full voiced phrase'
            audio, sr = sf.read(OUT / clip['file'])
            f0, voiced, _ = librosa.pyin(audio, fmin=55, fmax=450, sr=sr, frame_length=2048, hop_length=256)
            values = f0[voiced & np.isfinite(f0)]
            median = float(np.median(values)) if len(values) else 0
            if ranges[actor][0] <= median <= ranges[actor][1]:
                pitch[actor] = median
                break
            print(f'RETRY REFERENCE {actor}: measured voiced pitch {median:.1f} Hz misses its character range', flush=True)
        else:
            raise ValueError(actor + ': no reference in its requested voice range')
        clip['category'] = 'character_dialogue'
        result[actor] = (key, clip)
    voice.write_json(CACHE / 'reference-pitch.json', pitch)
    return result


def generate_cloned(ffmpeg, references, selected):
    import torch
    import soundfile as sf
    from qwen_tts import Qwen3TTSModel
    voice.pipeline.MODEL = None
    gc.collect()
    torch.cuda.empty_cache()
    source = json.loads((CACHE / 'base-model-source.json').read_text(encoding='utf-8'))
    assert json.loads((CACHE / 'base-model/config.json').read_text(encoding='utf-8'))['tts_model_type'] == 'base'
    clone = Qwen3TTSModel.from_pretrained(str(CACHE / 'base-model'), device_map='cuda', dtype=torch.bfloat16, attn_implementation='sdpa')
    result = {key: clip for key, clip in references.values()}
    embeddings = {}
    failures = []
    for actor, profile in profiles.items():
        if selected and actor not in selected:
            continue
        ref_key, reference = references[actor]
        prompt = clone.create_voice_clone_prompt(ref_audio=str(OUT / reference['file']), ref_text=reference['text'], x_vector_only_mode=False)
        embedding = prompt[0].ref_spk_embedding.detach().float().cpu()
        embeddings[actor] = (embedding / embedding.norm()).tolist()
        def render(text, _description, target, seed):
            torch.manual_seed(seed)
            wavs, rate = clone.generate_voice_clone(text=text, language='Japanese', voice_clone_prompt=prompt, non_streaming_mode=True, max_new_tokens=128)
            sf.write(str(target), wavs[0], rate, subtype='PCM_16')
        voice.pipeline.render_audio = render
        description = profile['description'] + ' Fixed synthetic reference SHA256 ' + reference['sha256'] + '; Base revision ' + source['revision']
        jobs = [(event, index, text, True, None) for event in ['attack','heavy','hurt'] for index, text in enumerate(profile[event])]
        for event in ['special', 'defeat', 'boss_defeat']:
            text = previous['clips'][previous['actors'][actor][event][0]]['text']
            jobs.append((event, 0, text, False, None))
        texts = profile.get('victories', [previous['clips'][key]['text'] for key in previous['actors'][actor]['victory']])
        subtitles = profile.get('victory_subtitles', [previous['clips'][key].get('subtitle','') for key in previous['actors'][actor]['victory']])
        jobs.extend(('victory', index, text, False, subtitles[index]) for index, text in enumerate(texts))
        for event, index, text, short, subtitle in jobs:
            try:
                key, clip = voice.make_clip(ffmpeg, (actor, event, index, text, description, short, subtitle))
            except ValueError as error:
                failures.append(str(error))
                print('PENDING:', error, flush=True)
                continue
            clip.update(backend='Qwen3-TTS-12Hz-1.7B-Base', model_revision=source['revision'], reference_key=ref_key, reference_sha256=reference['sha256'], category='short_burst' if short else ('named_move_dialogue' if event == 'special' else 'character_dialogue'))
            result[key] = clip
            accepted_path = CACHE / (key + '-accepted.json')
            accepted = json.loads(accepted_path.read_text(encoding='utf-8'))
            accepted['clip'] = clip
            voice.write_json(accepted_path, accepted)
        print('COMPLETE HERO:', actor, flush=True)
    voice.write_json(CACHE / 'reference-embeddings.json', embeddings)
    for path in CACHE.glob('*_v30_*.json'):
        record = json.loads(path.read_text(encoding='utf-8'))
        if 'Fixed synthetic reference SHA256' in record.get('instruction',''):
            record.update(backend='Qwen3-TTS-12Hz-1.7B-Base', model_revision=source['revision'])
            voice.write_json(path, record)
    if failures:
        raise ValueError('Incomplete voice pools; existing manifest retained: ' + '; '.join(failures))
    return result


def publish(generated):
    manifest = json.loads(json.dumps(previous))
    for clip in manifest['clips'].values():
        path = (old_root / clip['file']).resolve()
        assert path.is_file() and path.is_relative_to(ROOT / 'game/audio')
        clip['file'] = os.path.relpath(path, OUT).replace('\\','/')
    for actor, profile in profiles.items():
        pools = {event: [key for key, clip in generated.items() if clip['actor'] == actor and clip['event'] == event] for event in ['intro','attack','heavy','hurt','special','victory','defeat','boss_defeat']}
        assert all(len(pools[event]) == (3 if event in ['attack','heavy','hurt','victory'] else 1) for event in pools), actor
        pools['guard'] = pools['heavy'].copy()
        manifest['actors'][actor] = pools
        manifest.setdefault('named_calls',{})[actor] = pools['special'].copy()
    assert len(generated) == 96
    assert len({clip['sha256'] for clip in generated.values()}) == 96
    assert all(voice.sha(OUT / clip['file']) == clip['sha256'] and voice.sha(ROOT / clip['raw_source']) == clip['raw_sha256'] for clip in generated.values())
    manifest['clips'].update(generated)
    manifest.update(version='0.30', hero_voice_profiles=profiles, backend='Six original designed speakers; all hero cues reuse their own synthetic reference', hero_pitch_scale=1.0, listening_review='Human audition pending; routing, source hashes, uniqueness and PCM bounds checked')
    temporary = OUT / 'manifest.json.tmp'
    voice.write_json(temporary, manifest)
    temporary.replace(OUT / 'manifest.json')
    return manifest


def preview(manifest):
    import wave
    rows, combined, chapters, cursor = [], [], [], 0
    for actor, profile in profiles.items():
        actor_chunks = []
        sections = []
        for event in ['intro','attack','heavy','hurt','special','victory','defeat','boss_defeat']:
            clips = []
            for key in manifest['actors'][actor][event]:
                clip = manifest['clips'][key]
                path = OUT / clip['file']
                with wave.open(str(path)) as source:
                    data = source.readframes(source.getnframes())
                actor_chunks += [data, b'\0\0' * int(voice.RATE * .4)]
                chapters.append({'actor':actor,'event':event,'key':key,'start_seconds':cursor/voice.RATE,'seconds':clip['seconds']})
                combined += [data, b'\0\0' * int(voice.RATE * .6)]
                cursor += len(data)//2 + int(voice.RATE * .6)
                clips.append(f'<div>{html.escape(clip["text"])} <small>{clip["seconds"]:.3f}s</small><br><audio controls preload="none" src="../../game/audio/v30/{html.escape(clip["file"])}"></audio></div>')
            sections.append(f'<tr><th>{event}</th><td>{"".join(clips)}</td></tr>')
        path = CACHE / (actor + '-preview.wav')
        with wave.open(str(path), 'wb') as target:
            target.setparams((1,2,voice.RATE,0,'NONE','not compressed'))
            target.writeframes(b''.join(actor_chunks))
        rows.append(f'<section><h2>{profile["name"]}</h2><p>{profile["character"]}</p><audio controls preload="none" src="{actor}-preview.wav"></audio><table>{"".join(sections)}</table></section>')
    with wave.open(str(CACHE / 'six-heroes-preview.wav'), 'wb') as target:
        target.setparams((1,2,voice.RATE,0,'NONE','not compressed'))
        target.writeframes(b''.join(combined))
    voice.write_json(CACHE / 'preview-chapters.json', chapters)
    (CACHE / 'preview.html').write_text('<!doctype html><meta charset="utf-8"><title>六名武將獨立聲線</title><style>body{font:18px system-ui;background:#172329;color:#eee;padding:24px}table{width:100%}th,td{padding:12px;border-bottom:1px solid #456;vertical-align:top}audio{width:330px}td div{display:inline-block;margin:8px}section{margin:35px 0}</style><h1>六名武將獨立聲線</h1><p>每人固定一個原創合成參考聲線；短喊、台詞、必殺和勝利各自生成。數值檢查已完成，表演與聽感仍需真人試聽。</p>' + ''.join(rows), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--references-only', action='store_true')
    parser.add_argument('--actors', help='Partial generation without publishing; comma-separated hero IDs')
    args = parser.parse_args()
    selected = args.actors.split(',') if args.actors else []
    assert all(actor in profiles for actor in selected), 'Unknown hero'
    ffmpeg = voice.ffmpeg_executable()
    references = reference_clips(ffmpeg)
    voice.write_json(CACHE / 'references.json', {actor: {'key':key, **clip} for actor,(key,clip) in references.items()})
    if args.references_only:
        print('SIX HERO REFERENCES PASS', flush=True)
        return
    generated = generate_cloned(ffmpeg, references, selected)
    if not selected:
        manifest = publish(generated)
        preview(manifest)
        print('SIX HERO VOICES PASS: 96 unique hero cues, 54 compact shouts, six fixed synthetic speakers', flush=True)


if __name__ == '__main__':
    main()
