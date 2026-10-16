"""Verify active voice/foley assets and create a human audition page without modifying originals."""
import hashlib
import html
import importlib.util
import json
import math
import os
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'artifacts/weapon-audio-v38'
HEROES = ['nobunaga','oichi','hideyoshi','ieyasu','mitsuhide','tadakatsu']
NAMES = ['信長','阿市','秀吉','家康','顯如','忠勝']


def read(path): return json.loads(path.read_text('utf-8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def measure(path):
    with wave.open(str(path)) as wav:
        assert wav.getsampwidth()==2 and wav.getnchannels()==1, path
        frames, rate = wav.getnframes(), wav.getframerate()
        data = wav.readframes(frames)
    samples = [v[0]/32768 for v in struct.iter_unpack('<h',data)]
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v*v for v in samples)/len(samples))
    assert 0.01<peak<.999 and rms>.002, (path, peak, rms)
    return dict(seconds=frames/rate, rate=rate, peak=peak, rms_dbfs=20*math.log10(rms))


def player(path):
    relative = os.path.relpath(path,OUT).replace('\\','/')
    return '<audio controls preload="none" src="'+html.escape(relative+'?v='+sha(path)[:12],quote=True)+'"></audio>'


def main():
    old_root = ROOT/'game/audio/v31'
    old = read(old_root/'manifest.json')
    repair = read(ROOT/'game/audio/v38/voices/manifest.json')
    previous_root = OUT/'before-raspy-r2/game/audio/v38/voices'
    previous = read(previous_root/'manifest.json') if (previous_root/'manifest.json').exists() else old
    active = json.loads(json.dumps(old))
    for field in ['clips','actors','named_calls','stage_boss_intros','hero_voice_profiles']: active[field].update(repair[field])
    paths = {key: ROOT/'game'/c['file'][6:] if c['file'].startswith('res://') else old_root/c['file'] for key,c in active['clips'].items()}
    keys = {k for pools in active['actors'].values() for pool in pools.values() for k in pool}
    keys.update(i['line_key'] for field in ['boss_intros','stage_boss_intros'] for i in active[field].values())
    report = {'active_voice_clips':{}, 'weapon_clips':{}, 'human_audition':'full bank pending',
              'approved_direction':'User selected B: mature male voices, -3 semitones with original duration'}
    for key in sorted(keys):
        clip = active['clips'][key]
        assert paths[key].is_file(), key
        if 'sha256' in clip: assert sha(paths[key])==clip['sha256'], key
        report['active_voice_clips'][key] = measure(paths[key])
    for key, clip in repair['clips'].items():
        assert sha(ROOT/clip['raw_source'])==clip['raw_sha256'], key
        if clip['event'] in ['attack','heavy','hurt']: assert .30<=clip['seconds']<=.50, key
        assert clip['playback_pitch']==1.0 and 'asetrate' not in clip['post_filter'], key
        if clip['actor'] in ['nobunaga','ieyasu','mitsuhide']:
            assert clip['offline_pitch_semitones']==-3 and 'rubberband=tempo=1:' in clip['post_filter'], key
            assert clip['speaker']==active['hero_voice_profiles'][clip['actor']]['speaker'], key
    root = ROOT/'game/audio/v38/weapons'
    weapons = read(root/'manifest.json')
    for cue in weapons['cues'].values():
        assert len(cue['variants'])==5 and len({r['sha256'] for r in cue['variants']})==5
        for row in cue['variants']:
            path = root/row['file']
            assert sha(path)==row['sha256']
            if row['file'] not in report['weapon_clips']: report['weapon_clips'][row['file']] = measure(path)
    assert len(report['weapon_clips'])==75 and len(repair['clips'])==56
    assert len({c['sha256'] for c in repair['clips'].values() if c['actor'] in HEROES})==53
    for hero in HEROES:
        changed = [c for c in repair['clips'].values() if c['actor']==hero]
        assert len(changed)==(16 if hero in ['nobunaga','ieyasu','mitsuhide'] else 5 if hero=='oichi' else 0), hero
    assert '顕如' in repair['clips'][repair['actors']['mitsuhide']['intro'][0]]['text']
    assert all('光秀' not in c['text'] and '月光一閃' not in c['text'] for c in repair['clips'].values() if c['actor']=='mitsuhide')
    spec = importlib.util.spec_from_file_location('package',ROOT/'scripts/package-current.py')
    package = importlib.util.module_from_spec(spec); spec.loader.exec_module(package)
    packaged = set(package.runtime_files())
    required = [root/row['file'] for cue in weapons['cues'].values() for row in cue['variants']]
    required += [paths[k] for k in repair['clips']]
    assert all(p.relative_to(ROOT).as_posix() in packaged for p in required)
    report['new_audio_package_coverage'] = len(set(required))
    sections = ['<h1>武器與武將音效試聽・B 方向</h1><p>第二輪：信長更粗啞；家康成熟有力；顯如沉穩、攻擊低吼；阿市指定五句加強發力。男性採 B 的低沉程度，阿市維持原音高。此頁供人工比較，檔案與音高檢查不能代替聽感驗收。</p><section id="voice-r2"><h2>本次重錄・先聽登場與指定攻擊</h2>']
    for hero in ['nobunaga','oichi','ieyasu','mitsuhide']:
        sections.append('<h3>'+NAMES[HEROES.index(hero)]+'</h3>')
        for event in ['intro','attack','heavy']:
            for key in active['actors'][hero][event]:
                if key in repair['clips']:
                    sections.append('<p>'+html.escape(event+' '+active['clips'][key]['text'])+'</p>'+player(paths[key]))
    sections += ['</section>',
                '<h2>武器：刀劍／鈍擊／長槍／弓箭</h2>'+player(OUT/'weapons-preview.wav'),
                '<h2>第二關武將出場白</h2>']
    for name, intro in repair['stage_boss_intros'].items():
        clip = repair['clips'][intro['line_key']]
        sections.append('<p>'+html.escape(name+'：'+clip['text'])+'</p>'+player(paths[intro['line_key']]))
    for hero,name in zip(HEROES,NAMES):
        sections.append('<h2>'+name+'</h2>')
        for event,pool in active['actors'][hero].items():
            if event=='guard': continue
            for i,key in enumerate(pool):
                clip = active['clips'][key]
                row = '<p>'+html.escape(event+' '+clip['text'])+'</p>'
                if key in repair['clips']:
                    before = previous if hero in previous['actors'] else old
                    old_key = before['actors'][hero][event][i]
                    old_clip = before['clips'][old_key]
                    old_path = previous_root/Path(old_clip['file']).name if before is previous and before is not old else old_root/old_clip['file']
                    row += '<span>修改前 </span>'+player(old_path)+'<span>本次重錄 </span>'
                sections.append(row+player(paths[key]))
    page = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>武器與武將音效試聽・B 方向</title><style>body{font:18px system-ui;background:#172329;color:#eee;max-width:1200px;margin:auto;padding:24px}h2{margin-top:36px}audio{vertical-align:middle;margin:4px 22px 12px 0}p{margin-bottom:4px}</style>'+''.join(sections)+'<script>document.addEventListener("play",e=>document.querySelectorAll("audio").forEach(a=>{if(a!==e.target)a.pause()}),true)</script>'
    (OUT/'preview.html').write_text(page,'utf-8')
    (OUT/'asset-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n','utf-8')
    print(f'AUDIO V38 ASSETS PASS: {len(keys)} active voice clips, 75 foley WAVs, {len(set(required))} new files included by package collector; human audition pending')


if __name__=='__main__': main()
