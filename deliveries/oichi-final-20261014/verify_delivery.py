"""Verify the original archive, imported bytes, animations, and document links."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from urllib.parse import unquote

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EXPECTED_SHA256 = "0207bf9c6ad7e0d634a92c490300f29f816a39b1688e573266285317120b57f8"
EXPECTED_SIZE = 99440734
EXPECTED_ACTIONS = {
    "light_1", "light_2", "light_3", "heavy", "charge_ready", "charge_hold",
    "charge_release", "charge_rain", "air_light", "air_heavy", "dash_heavy",
    "grab_start", "grab_hold", "grab_hit_1", "grab_hit_2",
    "throw_forward", "throw_reverse",
}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify():
    archive = HERE / "oichi_final_20261014.zip"
    record = json.loads((HERE / "integration.json").read_text(encoding="utf-8"))
    package = ROOT / record["package_directory"]
    assert archive.stat().st_size == EXPECTED_SIZE
    assert digest(archive) == EXPECTED_SHA256 == record["archive_sha256"]
    changes = {item["path"]: item for item in record["document_only_changes"]}
    assert all(path.startswith("docs/combat-art-reference/source-spec/")
               and path.endswith(".md") for path in changes)
    revised_hashes = json.loads((package / "SHA256SUMS.json").read_text(encoding="utf-8"))
    with zipfile.ZipFile(archive) as zipped:
        names = [item.filename for item in zipped.infolist() if not item.is_dir()]
        assert len(names) == 768 and len(set(names)) == 768
        original_hashes = json.loads(zipped.read("SHA256SUMS.json"))
        assert set(revised_hashes) == set(original_hashes)
        for name in names:
            data = zipped.read(name)
            original_sha = hashlib.sha256(data).hexdigest()
            if name != "SHA256SUMS.json":
                assert original_sha == original_hashes[name], name
            current_sha = digest(package / name)
            if name in changes:
                assert original_sha == changes[name]["original_sha256"], name
                assert current_sha == changes[name]["published_sha256"], name
            elif name != "SHA256SUMS.json":
                assert current_sha == original_sha, name
            if name in revised_hashes:
                assert current_sha == revised_hashes[name], name
    identity = record["additional_identity_reference"]
    assert digest(ROOT / identity["path"]) == identity["sha256"]
    actions = json.loads((package / "ACTION_MANIFEST.json").read_text(encoding="utf-8"))
    assert len(actions) == 17 and {a["id"] for a in actions} == EXPECTED_ACTIONS
    action_results = []
    for action in actions:
        for key in ["asset_directory", "metadata", "preview", "representative"]:
            assert (package / action[key]).exists(), (action["id"], key)
        metadata_path = package / action["metadata"]
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        frames = metadata["frames"]
        assert len(frames) == action["playback_keys"], action["id"]
        assert all(frame["duration_ms"] > 0 for frame in frames)
        assert sum(frame["duration_ms"] for frame in frames) == action["duration_ms"]
        for event in action["events"]:
            assert 0 <= event["frame"] < len(frames), (action["id"], event)
        for frame in frames:
            for key in ["body_canvas", "victim_canvas", "weapon_canvas",
                        "hand_foreground_mask", "isolated_file"]:
                if frame.get(key):
                    assert (metadata_path.parent / frame[key]).is_file(), (action["id"], key)
        with Image.open(package / action["preview"]) as image:
            milliseconds = 0
            for frame in range(image.n_frames):
                image.seek(frame)
                milliseconds += image.info.get("duration", 0)
            assert milliseconds == action["duration_ms"], action["id"]
        action_results.append({
            "id": action["id"], "frames": len(frames),
            "duration_ms": milliseconds, "event_count": len(action["events"]),
        })
    images = [file for file in package.rglob("*") if file.suffix.lower() in {".png", ".gif", ".jpg"}]
    for file in images:
        with Image.open(file) as image:
            assert min(image.size) > 0
            image.verify()
    documents = list(package.rglob("*.md"))
    documents += list((ROOT / "docs/combat-art-reference").rglob("*.md"))
    documents.append(ROOT / "docs/HANDOFF-OICHI-FINAL-20261014.md")
    links = 0
    for document in documents:
        text = document.read_text(encoding="utf-8")
        text = re.sub(r"```.*?```", "", text, flags=re.S)
        for link in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            if re.match(r"https?://", link) or link.startswith("#"):
                continue
            target = (document.parent / unquote(link.split("#")[0])).resolve()
            assert target.is_relative_to(ROOT) and target.exists(), (document, link)
            links += 1
    body_document = (ROOT / "docs/combat-art-reference/characters/oichi.md").read_text(encoding="utf-8")
    assert len(re.findall(r"!\[", body_document)) == 17
    for action in actions:
        assert "`" + action["id"] + "`" in body_document
        assert action["description"] in body_document
    reverse = json.loads((package / actions[-1]["metadata"]).read_text(encoding="utf-8"))
    assert reverse["frame_count"] == 13 and reverse["release_ms"] == 580
    assert reverse["total_ms"] == 960 and reverse["loop"] is False
    rain = next(a for a in actions if a["id"] == "charge_rain")
    rain_metadata = json.loads((package / rain["metadata"]).read_text(encoding="utf-8"))
    assert rain_metadata["particle_count"] == 70
    return {
        "status": "PASS", "original_zip_size_bytes": EXPECTED_SIZE,
        "original_zip_sha256": EXPECTED_SHA256, "archive_files": 768,
        "original_files_preserved": 768 - len(changes) - 1,
        "document_navigation_changes": len(changes),
        "package_hash_entries": len(revised_hashes),
        "image_files_checked": len(images), "relative_links_checked": links,
        "actions": action_results, "runtime_tested": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args()
    report = verify()
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.write_report:
        (HERE / "validation.json").write_text(output, encoding="utf-8")
    print(output)
