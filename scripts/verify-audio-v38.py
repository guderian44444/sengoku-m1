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
    return '<audio controls preload="none" src="'+html.escape(relative,quote=True)+'"></audio>'


def main():
    old_root = ROOT/'game/audio/v31'
    old = read(old_root/'manifest.json')
    repair = read(ROOT/'game/audio/v38/voices/manifest.json')
    active = json.loads(json.dumps(old))
    for field in ['clips','actors','named_calls','stage_boss_intros']: active[field].update(repair[field])
    paths = {key: ROOT/'game'/c['file'][6:] if c['file'].startswith('res://') else old_root/c['file'] for key,c in active['clips'].items()}
    keys = {k for pools in active['actors'].values() for pool in pools.values() for k in pool}
    keys.update(i['line_key'] for field in ['boss_intros','stage_boss_intros'] for i in active[field].values())
    report = {'active_voice_clips':{}, 'weapon_clips':{}, 'human_audition':'pending'}
    for key in sorted(keys):
        clip = active['clips'][key]
        assert paths[key].is_file(), key
        if 'sha256' in clip: assert sha(paths[key])==clip['sha256'], key
        report['active_voice_clips'][key] = measure(paths[key])
    for key, clip in repair['clips'].items():
        assert sha(ROOT/clip['raw_source'])==clip['raw_sha256'], key
        if clip['event'] in ['attack','heavy','hurt']: assert .30<=clip['seconds']<=.50, key
        assert clip['playback_pitch']==1.0 and 'asetrate' not in clip['post_filter'], key
    root = ROOT/'game/audio/v38/weapons'
    weapons = read(root/'manifest.json')
    for cue in weapons['cues'].values():
        assert len(cue['variants'])==5 and len({r['sha256'] for r in cue['variants']})==5
        for row in cue['variants']:
            path = root/row['file']
            assert sha(path)==row['sha256']
            if row['file'] not in report['weapon_clips']: report['weapon_clips'][row['file']] = measure(path)
    assert len(report['weapon_clips'])==75 and len(repair['clips'])==19
    spec = importlib.util.spec_from_file_location('package',ROOT/'scripts/package-current.py')
    package = importlib.util.module_from_spec(spec); spec.loader.exec_module(package)
    packaged = set(package.runtime_files())
    required = [root/row['file'] for cue in weapons['cues'].values() for row in cue['variants']]
    required += [paths[k] for k in repair['clips']]
    assert all(p.relative_to(ROOT).as_posix() in packaged for p in required)
    report['new_audio_package_coverage'] = len(set(required))
    sections = ['<h1>武器與武將音效試聽</h1><p>此頁供人工比較聲線、發音、力度與混音。檔案、音高及遊戲事件檢查不能代替聽感驗收。</p>',
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
                if hero=='nobunaga':
                    old_key = old['actors'][hero][event][i]
                    row += '<span>原版 </span>'+player(paths[old_key])+'<span>新版 </span>'
                sections.append(row+player(paths[key]))
    page = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>武器與武將音效試聽</title><style>body{font:18px system-ui;background:#172329;color:#eee;max-width:1200px;margin:auto;padding:24px}h2{margin-top:36px}audio{vertical-align:middle;margin:4px 22px 12px 0}p{margin-bottom:4px}</style>'+''.join(sections)
    (OUT/'preview.html').write_text(page,'utf-8')
    (OUT/'asset-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n','utf-8')
    print(f'AUDIO V38 ASSETS PASS: {len(keys)} active voice clips, 75 foley WAVs, 94 new files included by package collector; human audition pending')


if __name__=='__main__': main()
