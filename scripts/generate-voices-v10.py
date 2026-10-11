"""Generate original Japanese prototype speech; runtime uses only the saved WAV files."""
import asyncio, json, math, subprocess
from pathlib import Path
import edge_tts

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/audio/v10'
SOURCE = json.loads((OUT / 'lines.json').read_text(encoding='utf-8'))
SEM = asyncio.Semaphore(4)

async def render(actor_id, actor, event, index, text):
    key = f'{actor_id}_{event}_{index}'
    mp3 = ROOT / 'artifacts/voice-v10' / f'{key}.mp3'
    wav = OUT / f'{key}.wav'
    mp3.parent.mkdir(parents=True, exist_ok=True)
    async with SEM:
        if not mp3.exists():
            for attempt in range(3):
                try:
                    await edge_tts.Communicate(text, actor['voice'], rate=actor['rate'], pitch=actor['pitch']).save(str(mp3))
                    break
                except Exception:
                    if attempt == 2: raise
                    await asyncio.sleep(1 + attempt)
        filters = 'silenceremove=start_periods=1:start_threshold=-48dB,areverse,silenceremove=start_periods=1:start_threshold=-48dB,areverse,highpass=f=100,lowpass=f=8200,acompressor=threshold=0.18:ratio=3:attack=5:release=60,alimiter=limit=0.88'
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(mp3),'-af',filters,'-ar','22050','-ac','1',str(wav)],check=True)
        probe = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(wav)]))
        duration = float(probe['format']['duration'])
        assert .08 < duration < 18 and wav.stat().st_size > 3500, key
        print(f'{key}: {duration:.2f}s', flush=True)
        return key, {'file': wav.name, 'seconds': duration, 'text': text, 'actor': actor_id, 'event': event}

async def main():
    jobs = [render(actor_id, actor, event, i, text) for actor_id, actor in SOURCE['actors'].items() for event, lines in actor['clips'].items() for i, text in enumerate(lines)]
    clips = dict(await asyncio.gather(*jobs))
    actors = {actor_id: {event:[f'{actor_id}_{event}_{i}' for i in range(len(lines))] for event, lines in actor['clips'].items()} for actor_id,actor in SOURCE['actors'].items()}
    intros = {}
    for actor_id, actor in SOURCE['actors'].items():
        if 'faction' not in actor: continue
        key = actors[actor_id]['intro'][0]
        intros[actor['faction']] = {'name':actor['name'],'line_key':key,'ticks':math.ceil(clips[key]['seconds']*60)+18,'text':clips[key]['text']}
    manifest = {'version':'0.10','backend':SOURCE['mode'],'actors':actors,'clips':clips,'boss_intros':intros}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    print(f'PASS: {len(clips)} original Japanese clips, {len(actors)} actor profiles, {len(intros)} timed boss introductions.')

asyncio.run(main())
