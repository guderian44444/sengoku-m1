"""Original boss entrances, sustained death wails and hero victory cries using the local voice pipeline."""
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('voice_pipeline', ROOT / 'scripts/generate-voices-v15.py')
voice = importlib.util.module_from_spec(spec)
spec.loader.exec_module(voice)
voice.OUT = ROOT / 'game/audio/v27'
voice.CACHE = ROOT / 'artifacts/voice-v27'
voice.OUT.mkdir(parents=True, exist_ok=True)
voice.CACHE.mkdir(parents=True, exist_ok=True)
manifest = json.loads((ROOT / 'game/audio/v15/manifest.json').read_text(encoding='utf-8'))
for clip in manifest['clips'].values():
    clip['file'] = '../v15/' + clip['file']
descriptions = json.loads((ROOT / 'game/audio/v11/lines.json').read_text(encoding='utf-8'))['actors']
delivery = 'Speak Japanese as an explosive, proudly projected arcade battlefield proclamation. Full chest support, fierce ringing energy, clear consonants, a brief dramatic pause after the first clause. No quiet narration, no singing. Finish the final vowel powerfully. Keep the complete sentence under six seconds.'
ffmpeg = voice.ffmpeg_executable()
for actor in ('nobunaga', 'oichi', 'hideyoshi', 'ieyasu', 'mitsuhide', 'tadakatsu'):
    job = (actor, 'boss_defeat', 0, '敵将、討ち取ったり！', descriptions[actor]['voice_description'] + ' ' + delivery, False, '敵將討取！')
    key, clip = voice.make_clip(ffmpeg, job)
    manifest['clips'][key] = clip
    manifest['actors'][actor]['boss_defeat'] = [key]
manifest['stage_boss_intros'] = {}
for actor, name, text, subtitle, tone in (
    ('sena', '瀨名氏俊', '山道の両側から囲め！一人も逃がすな！', '山道兩側，合圍！一個都別放過！', 'Fierce mature Japanese male commander, forceful baritone.'),
    ('udono', '鵜殿長照', '砦を守れ！今川の兵よ、我に続け！', '守住寨門！今川軍，隨我迎敵！', 'Rugged mature Japanese male captain, bright commanding mid-low voice.'),
    ('ii', '井伊直盛', '井伊直盛、見参！この庭を越えたくば、我を倒せ！', '井伊直盛在此！踏過這座庭園，先勝過我！', 'Proud mature Japanese male samurai, strong clear resonant baritone.'),
    ('matsui', '松井宗信', '松井宗信、ここにあり！援軍よ、敵を押し返せ！', '松井宗信在此！援軍接應，隨我殺退敵軍！', 'Powerful mature Japanese male general, thunderous bass-baritone with fierce supported projection.'),
):
    key, clip = voice.make_clip(ffmpeg, ('stage_' + actor, 'intro', 0, text, tone + ' ' + delivery, False, subtitle))
    manifest['clips'][key] = clip
    ticks = math.ceil(clip['seconds'] * 60)
    assert 1 <= ticks <= 1800
    manifest['stage_boss_intros'][name] = {'name': name, 'line_key': key, 'ticks': ticks, 'text': text}
manifest['actors']['boss_fallen'] = {'defeat': []}
manifest['actors']['boss_minor_fallen'] = {'defeat': []}
for index, text in enumerate(('うわっ、うわっ、うわあああああーっ！', 'ぐわっ、うわっ、うわあああああーっ！')):
    tone = 'Japanese male samurai general, deep rough resonant voice. An exaggerated old arcade boss death wail, shouted with theatrical despair: two short uwa cries followed by one very long falling uwaaaaa. Sustain the last open vowel for at least three seconds with wavering breath and a descending pitch. Total duration four to six seconds. Powerful voiced projection, no narration, no music, no other words.'
    key, clip = voice.make_clip(ffmpeg, ('boss_fallen', 'defeat', index, text, tone, False, ''))
    assert 2.5 <= clip['seconds'] < 7, 'Boss death wail must retain its sustained ending'
    clip['category'] = 'boss_death_wail'
    manifest['clips'][key] = clip
    manifest['actors']['boss_fallen']['defeat'].append(key)
    short_key = f'boss_minor_fallen_defeat_{index}'
    short_path = voice.OUT / f'{short_key}.wav'
    filters = 'atrim=end=1.45,asetpts=PTS-STARTPTS,afade=t=out:st=1.30:d=0.15'
    voice.convert(ffmpeg, voice.OUT / clip['file'], short_path, filters)
    metrics = voice.metrics(short_path)
    assert 1.0 <= metrics['seconds'] <= 1.5 and metrics['clipped_fraction'] == 0
    manifest['clips'][short_key] = dict(clip, file=short_path.name, seconds=metrics['seconds'],
        actor='boss_minor_fallen', category='miniboss_death_wail', sha256=voice.sha(short_path),
        text='Opening excerpt of: ' + text, source_clip=key, edit_filter=filters, metrics=metrics)
    manifest['actors']['boss_minor_fallen']['defeat'].append(short_key)
manifest.update(version='0.27', listening_review='pending human audition', recipe='scripts/generate-voices-v27.py')
voice.write_json(voice.OUT / 'deaths.json', {
    actor: [{'line_key': key, 'ticks': math.ceil(manifest['clips'][key]['seconds'] * 60)}
            for key in manifest['actors'][actor]['defeat']]
    for actor in ('boss_fallen', 'boss_minor_fallen')
})
voice.write_json(voice.OUT / 'manifest.json', manifest)
print('Generated 6 hero cries, 4 boss entrances, 2 long final-boss wails and 2 miniboss wails capped at 1.5 seconds.', flush=True)
