"""Import the approved delivery unchanged; derive only the six 20 ms loop seams."""
from pathlib import Path
import hashlib
import json
import shutil
import wave
import array

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts/sfx-weapons-impact-20261016/deliveries/sfx-weapons-impact-20261016/package'
DEST = ROOT / 'game/audio/weapons-v3'


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    rows = json.loads((SOURCE / 'docs/event-map.json').read_text('utf-8'))
    banks = {}
    for row in rows:
        src = SOURCE / row['wav']
        dst = DEST / src.name
        shutil.copy2(src, dst)
        take = {'file': dst.name, 'sha256': hashlib.sha256(dst.read_bytes()).hexdigest()}
        bank = banks.setdefault(row['event_id'], {'loop': row['loop'], 'variants': []})
        bank['variants'].append(take)
        if row['loop']:
            with wave.open(str(src), 'rb') as w:
                assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == 48000
                pcm = array.array('h', w.readframes(w.getnframes()))
            count = 960
            seam = [round(pcm[-count+i]*(1-i/(count-1))+pcm[i]*i/(count-1)) for i in range(count)]
            loop = array.array('h', pcm[count:-count]) + array.array('h', seam)
            loop_path = DEST / (dst.stem + '-loop.wav')
            with wave.open(str(loop_path), 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(48000); w.writeframes(loop.tobytes())
            bank['runtime_loop'] = loop_path.name
            bank['runtime_loop_sha256'] = hashlib.sha256(loop_path.read_bytes()).hexdigest()
    for name in ('SOURCES.md', 'LICENSES.md'):
        src = SOURCE / 'docs' / name
        if src.exists(): shutil.copy2(src, DEST / name)
    shutil.copy2(SOURCE / 'manifest.json', DEST / 'source-manifest.json')
    shutil.copy2(SOURCE / 'docs/event-map.json', DEST / 'source-event-map.json')
    manifest = {'source_zip_sha256': '3fdc045f382f8dd8d5c815b41dc870e86f2b949ecbc67c934d9493ccca390f07', 'loop_overlap_ms': 20, 'cues': banks}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', 'utf-8')
    print(f'Imported {len(rows)} exact WAVs, {len(banks)} banks, six derived loop seams')


if __name__ == '__main__': main()
