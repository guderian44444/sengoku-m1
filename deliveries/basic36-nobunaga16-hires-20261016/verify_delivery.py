"""Verify both expanded source packages without changing locked source reports."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    subprocess.run([sys.executable, '-X', 'utf8', str(ROOT / 'four-heroes/tools/verify_final_bundle.py')], check=True)
    report = ROOT / 'nobunaga/validation-final.json'
    original = report.read_bytes()
    try:
        subprocess.run([sys.executable, '-X', 'utf8', str(ROOT / 'nobunaga/tools/verify_delivery.py')], check=True)
        reproduced = json.loads(report.read_text(encoding='utf-8'))
        assert reproduced['status'] == 'passed' and reproduced['frames'] == 232
    finally:
        report.write_bytes(original)
    assert report.read_bytes() == original
    for folder in ['four-heroes', 'nobunaga']:
        base = ROOT / folder
        for line in (base / 'SHA256SUMS').read_text(encoding='utf-8').splitlines():
            if not line.strip():
                continue
            digest, name = line.split(None, 1)
            path = Path(name.lstrip('* '))
            assert not path.is_absolute() and '..' not in path.parts
            assert hashlib.sha256((base / path).read_bytes()).hexdigest() == digest, name
    print(json.dumps({'status': 'PASS', 'actions': 52, 'frames': 444, 'locked_reports_preserved': True, 'runtime_tested': False}))


if __name__ == '__main__':
    main()
