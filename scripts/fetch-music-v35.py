"""Fetch the small, pinned acoustic sample set used by generate-music-v35.py."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/music-v35-sources'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows = json.loads((OUT/'manifest.json').read_text('utf-8'))['samples']

    def fetch(row):
        path = OUT / row['file']
        assert path.resolve().is_relative_to(OUT.resolve())
        assert row['url'].startswith('https://raw.githubusercontent.com/')
        path.parent.mkdir(parents=True, exist_ok=True)
        data = path.read_bytes() if path.exists() else urllib.request.urlopen(row['url'], timeout=60).read()
        assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == row['git_blob'], row['file']
        assert hashlib.sha256(data).hexdigest() == row['sha256'], row['file']
        if not path.exists(): path.write_bytes(data)
        return dict(row, sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        records = list(pool.map(fetch, rows))
    assert len([r for r in records if r['instrument']]) >= 35
    (OUT/'manifest.json').write_text(json.dumps({'samples': records}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Verified {len(records)} source files, {sum(r["bytes"] for r in records)} bytes')


if __name__ == '__main__': main()
