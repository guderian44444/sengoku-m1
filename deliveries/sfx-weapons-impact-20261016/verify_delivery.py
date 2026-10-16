"""Read-only validation of the received v3 package and its integration map.

python -X utf8 verify_delivery.py [--decode] [--report /absolute/path.json]
--decode requires numpy and soundfile (libsndfile); it never executes pack scripts.
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import wave
import zipfile

ROOT = Path(__file__).resolve().parent
ZIP_NAME = "Sengoku_All_Weapons_SFX_v3.zip"
ZIP_SHA = "3fdc045f382f8dd8d5c815b41dc870e86f2b949ecbc67c934d9493ccca390f07"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decode", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    package = ROOT / "package"
    archive = ROOT / ZIP_NAME
    assert archive.stat().st_size == 19515398
    assert sha(archive) == ZIP_SHA
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        names = z.namelist()
        assert len(names) == len(set(names)) == 215
        for name in names:
            rel = PurePosixPath(name)
            assert not rel.is_absolute() and ".." not in rel.parts
            assert ":" not in name and "\\" not in name
            assert (package / name).read_bytes() == z.read(name), name
        assert set(names) == {
            p.relative_to(package).as_posix()
            for p in package.rglob("*") if p.is_file()
        }
    sums = (package / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines()
    for line in sums:
        expected, name = line.split("  ", 1)
        assert sha(package / name) == expected, name
    assert len(sums) == 214
    for source in (package / "originals").glob("*.zip"):
        with zipfile.ZipFile(source) as z:
            assert z.testzip() is None, source.name
    manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
    source_map = json.loads((package / "docs/event-map.json").read_text(encoding="utf-8"))
    mapping = json.loads((ROOT / "runtime-map.json").read_text(encoding="utf-8"))
    ids = [row["id"] for row in manifest]
    assert len(set(ids)) == len(ids) == 98
    assert {row["variant_id"] for row in source_map} == set(ids)
    assert len(source_map) == 98
    assert {row["suggested_event_id"] for row in mapping["events"]} == {
        row["event_id"] for row in source_map
    }
    assert len(mapping["events"]) == 44 and mapping["runtime_connected"] is False
    for row in mapping["events"]:
        expected = [x for x in source_map if x["event_id"] == row["suggested_event_id"]]
        assert row["variants"] == expected
        assert row["current_selector"] and row["integration_notes"]
    files = []
    for row in source_map:
        for fmt in ("wav", "ogg"):
            path = package / row[fmt]
            assert path.is_file()
            assert path.stem == row["variant_id"]
            entry = {"file": row[fmt], "sha256": sha(path)}
            if fmt == "wav":
                with wave.open(str(path)) as w:
                    assert (w.getframerate(), w.getnchannels(), w.getsampwidth()) == (48000, 1, 2)
                    entry.update(sample_rate=48000, channels=1, bits=16, frames=w.getnframes())
            files.append(entry)
    assert len(files) == 196
    audio_paths = {p.relative_to(package).as_posix() for p in (package / "processed").glob("*/*")}
    assert audio_paths == {row["file"] for row in files}
    preview_index = json.loads((package / "docs/preview-index.json").read_text(encoding="utf-8"))
    assert len(preview_index) == 44
    assert {row["id"] for row in preview_index}.issubset(set(ids))
    categories = {row["variant_id"]: row["event_id"] for row in source_map}
    assert {categories[row["id"]] for row in preview_index} == set(categories.values())
    assert all(a["at_seconds"] <= b["at_seconds"] for a, b in zip(preview_index, preview_index[1:]))
    decoder = None
    preview = None
    if args.decode:
        import numpy as np
        import soundfile as sf
        decoder = {"soundfile": sf.__version__, "libsndfile": sf.__libsndfile_version__}
        for row in files:
            data, rate = sf.read(package / row["file"], dtype="float32", always_2d=True)
            assert data.shape[0] > 0 and rate == 48000 and data.shape[1] == 1
            assert np.isfinite(data).all(), row["file"]
            peak = float(np.max(np.abs(data)))
            clipped = int(np.count_nonzero(np.abs(data) >= 1.0))
            assert peak > 0 and clipped == 0, row["file"]
            row.update(decoded_frames=len(data), seconds=len(data)/rate,
                       peak_dbfs=20*math.log10(peak), clipped_samples=clipped, finite=True)
        data, rate = sf.read(package / "Sengoku_All_Weapons_Preview_v3.mp3", dtype="float32", always_2d=True)
        assert len(data) > 0 and np.isfinite(data).all() and np.max(np.abs(data)) < 1
        preview = {"seconds": len(data)/rate, "sample_rate": rate,
                   "peak_dbfs": 20*math.log10(float(np.max(np.abs(data)))),
                   "finite": True, "clipped_samples": 0}
        assert preview_index[-1]["at_seconds"] < preview["seconds"]
    report = {
        "status": "passed", "zip": {"file": ZIP_NAME, "bytes": archive.stat().st_size, "sha256": ZIP_SHA},
        "zip_entries_byte_identical": 215, "source_hashes_verified": 214,
        "original_source_zips_crc_verified": 3, "suggested_categories": 44,
        "independent_audio_variants": 98, "audio_files": 196, "preview_categories": 44,
        "loop_variants": [x["id"] for x in manifest if x["loop"]],
        "decoded": args.decode, "decoder": decoder, "preview": preview,
        "subjective_listening": False, "runtime_connected": False,
        "producer_v2_preservation_claim": "64 files; retained in package/docs/QA.json; no separate v2 baseline supplied for independent comparison",
        "files": files,
    }
    if args.report:
        target = args.report.resolve()
        assert not target.is_relative_to(package.resolve()), "Do not overwrite received package evidence"
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "files"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
