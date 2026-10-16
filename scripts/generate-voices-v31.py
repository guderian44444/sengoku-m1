"""Generate performed hero cues with fixed CustomVoice speakers and event instructions.

v30's Base clone callback ignored delivery instructions. This revision calls
CustomVoice directly for each cue and retains v30 for paired audition.
"""
import argparse
import html
import importlib.util
import json
import os
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/audio/v31'
CACHE = ROOT / 'artifacts/voice-v31'
os.environ.setdefault('NUMBA_CACHE_DIR', str(CACHE / 'numba-cache'))
os.environ.setdefault('MPLCONFIGDIR', str(CACHE / 'mpl-cache'))
os.environ.setdefault('HF_HUB_OFFLINE', '1')
os.environ.setdefault('TRANSFORMERS_OFFLINE', '1')
spec = importlib.util.spec_from_file_location('voice_v15', ROOT / 'scripts/generate-voices-v15.py')
voice = importlib.util.module_from_spec(spec)
spec.loader.exec_module(voice)
voice.OUT, voice.CACHE, voice.KEY_TAG = OUT, CACHE, 'v31'
voice.MAX_ATTEMPTS = 24
# Preserve the bass fundamental while keeping the established silence-only trim.
voice.pipeline.FILTER = voice.pipeline.FILTER.replace('highpass=f=100,', 'highpass=f=60,')
source = json.loads((OUT / 'profiles.json').read_text(encoding='utf-8'))
model_source = json.loads((CACHE / 'custom-model-source.json').read_text(encoding='utf-8'))
voice.pipeline.REVISION = model_source['revision']
previous = json.loads((ROOT / 'game/audio/v30/manifest.json').read_text(encoding='utf-8'))
EVENTS = ['intro','attack','heavy','hurt','special','victory','defeat','boss_defeat']
LABELS = {'intro':'登場：堅定準備出戰','attack':'發力：短促用力','heavy':'重手：爆發全力',
          'hurt':'受傷：突然疼痛','special':'必殺：激昂喊招','victory':'勝利：自信振奮',
          'defeat':'敗北：痛苦與不甘','boss_defeat':'討取：激昂戰吼'}

def render_audio(text,instruction,target,seed):
    import torch
    import soundfile as sf
    from qwen_tts import Qwen3TTSModel
    actor = target.name.split('_v31_',1)[0]
    assert actor in source['actors']
    if voice.pipeline.MODEL is None:
        voice.pipeline.MODEL = Qwen3TTSModel.from_pretrained(str(CACHE/'custom-model'),device_map='cuda',dtype=torch.bfloat16,attn_implementation='sdpa')
    torch.manual_seed(seed)
    wavs,rate = voice.pipeline.MODEL.generate_custom_voice(text=text,language='Japanese',
        speaker=source['actors'][actor]['speaker'],instruct=instruction,non_streaming_mode=True,max_new_tokens=128)
    sf.write(target,wavs[0],rate,subtype='PCM_16')

voice.pipeline.render_audio = render_audio

def jobs(actor):
    profile = source['actors'][actor]
    for event in EVENTS:
        old_keys = previous['actors'][actor][event]
        for index, old_key in enumerate(old_keys):
            old = previous['clips'][old_key]
            text = profile[event][index] if event in ['attack','heavy','hurt'] else old['text']
            instruction = profile['description']+' Fixed speaker preset '+profile['speaker']+'. Performance: '+source['delivery'][event]
            yield actor,event,index,text,instruction,event in ['attack','heavy','hurt'],old.get('subtitle')

def take_pitch(path):
    import librosa
    import numpy as np
    import soundfile as sf
    audio,rate = sf.read(path)
    f0,voiced,_ = librosa.pyin(audio,fmin=55,fmax=650,sr=rate,frame_length=2048,hop_length=256)
    values = f0[voiced & np.isfinite(f0)]
    return {'voiced_frames':len(values),'median_hz':float(np.median(values)) if len(values) else 0,
            'p10_hz':float(np.percentile(values,10)) if len(values) else 0,
            'p90_hz':float(np.percentile(values,90)) if len(values) else 0}

def validate(generated):
    assert len(generated) == 96 and len({c['sha256'] for c in generated.values()}) == 96
    for actor,profile in source['actors'].items():
        for event in EVENTS:
            pool = [c for c in generated.values() if c['actor'] == actor and c['event'] == event]
            assert len(pool) == (3 if event in ['attack','heavy','hurt','victory'] else 1), (actor,event)
            for clip in pool:
                assert clip['instruction'] == profile['description']+' Fixed speaker preset '+profile['speaker']+'. Performance: '+source['delivery'][event]
                assert clip['backend'] == 'Qwen3-TTS-12Hz-1.7B-CustomVoice' and clip['speaker'] == profile['speaker']
                assert voice.sha(OUT/clip['file']) == clip['sha256']
                assert voice.sha(ROOT/clip['raw_source']) == clip['raw_sha256']
                measured = voice.metrics(OUT/clip['file'])
                assert measured['clipped_fraction'] == 0 and measured['rms_dbfs'] >= -30
                if event in ['attack','heavy','hurt']: assert .30 <= measured['seconds'] <= .50

def publish(generated):
    validate(generated)
    manifest = json.loads(json.dumps(previous))
    for clip in manifest['clips'].values():
        path = (ROOT/'game/audio/v30'/clip['file']).resolve()
        assert path.is_file() and path.is_relative_to(ROOT/'game/audio')
        clip['file'] = os.path.relpath(path,OUT).replace('\\','/')
    for actor,profile in source['actors'].items():
        pools = {e:[k for k,c in generated.items() if c['actor']==actor and c['event']==e] for e in EVENTS}
        pools['guard'] = pools['heavy'].copy()
        manifest['actors'][actor] = pools
        manifest['named_calls'][actor] = pools['special'].copy()
    manifest['clips'].update(generated)
    manifest.update(version='0.31',hero_voice_profiles=source['actors'],performance_delivery=source['delivery'],
                    hero_pitch_scale=1.0,backend='CustomVoice with six fixed speakers and event performance instructions for all 96 hero cues',
                    listening_review='User audition required; emotional quality is not inferred from PCM or pitch statistics')
    temporary = OUT/'manifest.json.tmp'
    voice.write_json(temporary,manifest)
    temporary.replace(OUT/'manifest.json')
    return manifest

def preview(generated):
    rows = []
    for actor in ['oichi','tadakatsu','nobunaga','hideyoshi','ieyasu','mitsuhide']:
        profile = source['actors'][actor]
        sections,chunks = [],[]
        for event in EVENTS:
            takes = []
            for key,clip in generated.items():
                if clip['actor'] != actor or clip['event'] != event: continue
                index = int(key.rsplit('_',1)[1])
                old = previous['clips'][previous['actors'][actor][event][index]]
                old_path = os.path.relpath((ROOT/'game/audio/v30'/old['file']).resolve(),CACHE).replace('\\','/')
                new_path = os.path.relpath(OUT/clip['file'],CACHE).replace('\\','/')
                takes.append(f'<div class="take"><strong>{html.escape(clip["text"])}</strong><p>舊版 <audio controls preload="none" src="{html.escape(old_path)}"></audio></p><p>新版 <audio controls preload="none" src="{html.escape(new_path)}"></audio></p></div>')
                with wave.open(str(OUT/clip['file'])) as wav: chunks.append(wav.readframes(wav.getnframes()))
                chunks.append(b'\0\0'*int(voice.RATE*.5))
            if takes: sections.append(f'<tr><th>{LABELS[event]}</th><td>{"".join(takes)}</td></tr>')
        if not chunks: continue
        with wave.open(str(CACHE/(actor+'-preview.wav')),'wb') as wav:
            wav.setparams((1,2,voice.RATE,0,'NONE','not compressed')); wav.writeframes(b''.join(chunks))
        rows.append(f'<section id="{actor}"><h2>{profile["name"]}</h2><p>{profile["character"]}</p><audio controls preload="none" src="{actor}-preview.wav"></audio><table>{"".join(sections)}</table></section>')
    page = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>武將語音：動作情緒與新舊試聽</title><style>body{font:18px system-ui;background:#172329;color:#eee;padding:24px;max-width:1450px;margin:auto}table{width:100%}th,td{padding:12px;border-bottom:1px solid #456;vertical-align:top}audio{width:300px;vertical-align:middle}.take{display:inline-block;margin:8px 20px 8px 0}section{margin:35px 0}nav a{color:#efce88;margin-right:22px}</style><h1>武將語音：動作情緒與新舊試聽</h1><p>攻擊要用力、受傷要短促痛呼、必殺與討取要激昂。每段均以角色聲線和該情境的表演指令重新生成；保留舊版供比較。音量與檔案檢查不能代替耳朵判斷。</p><nav>'+''.join(f'<a href="#{a}">{p["name"]}</a>' for a,p in source['actors'].items())+'</nav>'+''.join(rows)
    (CACHE/'preview.html').write_text(page,encoding='utf-8')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--actors',help='Generate selected actors without activating incomplete revision')
    args = parser.parse_args()
    selected = args.actors.split(',') if args.actors else ['tadakatsu','oichi','nobunaga','hideyoshi','ieyasu','mitsuhide']
    assert all(a in source['actors'] for a in selected)
    CACHE.mkdir(parents=True,exist_ok=True)
    ffmpeg = voice.ffmpeg_executable()
    generated,failures = {},[]
    for actor in selected:
        for job in jobs(actor):
            try:
                key,clip = voice.make_clip(ffmpeg,job)
            except ValueError as error:
                failures.append(str(error)); print('PENDING:',error,flush=True); continue
            clip.update(identity_description=source['actors'][actor]['description'],
                        performance_event=clip['event'],delivery=source['delivery'][clip['event']],
                        category='short_burst' if job[5] else ('named_move_dialogue' if clip['event']=='special' else 'character_dialogue'),
                        speaker=source['actors'][actor]['speaker'],backend='Qwen3-TTS-12Hz-1.7B-CustomVoice')
            generated[key] = clip
            accepted_path = CACHE/(key+'-accepted.json')
            accepted = json.loads(accepted_path.read_text(encoding='utf-8'))
            accepted['clip'] = clip
            voice.write_json(accepted_path,accepted)
            voice.write_json(CACHE/'generated.json',generated)
        preview(generated)
        print('PROCESSED HERO:',actor,sum(c['actor']==actor for c in generated.values()),'of 16 accepted cues',flush=True)
    if failures: raise ValueError('Incomplete revision; old manifest remains active: '+'; '.join(failures))
    if not args.actors:
        publish(generated)
        print('PERFORMED HERO VOICES PASS: 96 individually instructed cues; user audition remains required',flush=True)

if __name__ == '__main__': main()
