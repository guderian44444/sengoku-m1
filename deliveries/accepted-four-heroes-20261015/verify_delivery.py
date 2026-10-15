"""Verify this accepted art delivery without changing game files."""
import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path
from urllib.parse import unquote

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DOC = ROOT / "docs/HANDOFF-ACCEPTED-FOUR-HEROES-20261015.md"
EXPECTED = {
    "tadakatsu": (651, "9e62f480e0bc9f783a8d4590d94037373968116a394dcd34fd4024e4874630cb"),
    "hideyoshi": (1972, "7b1f9d3b24b2c6214b6f426a283b8f69a9b5a779d6d8cad89614e5f6ad3ee21f"),
    "ieyasu": (2340, "b18ed188a47aec6c3413af4f684325a94486619c8c45507a622b8d7ee78f15ef"),
    "kennyo": (4044, "3b737f9d0da9708e904a82ba525076ae535344afdca0167e7a3fa608a2740710"),
}
ACTIONS = {
    "light_1", "light_2", "light_3", "heavy", "charge_ready", "charge_hold",
    "charge_release", "air_light", "air_heavy", "grab_start", "grab_hold",
    "grab_hit_1", "grab_hit_2", "throw_forward", "throw_reverse", "dash_heavy",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify():
    provenance = read(HERE / "DELIVERY.json")
    assert provenance["base_commit"] == "966cf8c3d48a4579554bc046a5961870faaaafa8"
    assert provenance["status"] == "accepted"
    assert provenance["oichi"]["duplicated_files"] == 0
    hashes = read(HERE / "SOURCE_SHA256SUMS.json")
    assert len(hashes) == 9007
    actual_paths = set()
    sizes = []
    for hero, (count, archive_sha) in EXPECTED.items():
        folder = HERE / hero / "source"
        files = [file for file in folder.rglob("*") if file.is_file()]
        assert len(files) == count, (hero, len(files), count)
        record = next(p for p in provenance["packages"] if p["hero"] == hero)
        assert record["sha256"] == archive_sha
        assert record["status"] == "accepted" and record["action_count"] == 16
        for file in files:
            name = file.relative_to(HERE).as_posix()
            assert not any(part in {".git", ".godot", "__pycache__", "node_modules", "__MACOSX"} for part in file.parts)
            assert "nobunaga" not in name.lower() and "信長" not in name
            assert file.suffix.lower() not in {".pyc", ".tmp", ".env"}
            assert file.stat().st_size < 7_000_000, name
            assert digest(file) == hashes[name], name
            actual_paths.add(name)
            sizes.append(file.stat().st_size)
    assert actual_paths == set(hashes)
    accepted = read(HERE / "ACCEPTED_ACTIONS.json")
    assert accepted["status"] == "accepted" and accepted["runtime_changed"] is False
    actions = accepted["actions"]
    assert len(actions) == 64
    assert Counter(a["hero"] for a in actions) == {hero: 16 for hero in EXPECTED}
    decoded_gif_frames = 0
    for hero in EXPECTED:
        assert {a["id"] for a in actions if a["hero"] == hero} == ACTIONS
    for action in actions:
        assert action["status"] == "accepted"
        for key in ["representative", "normal_gif", "metadata", "source_directory",
                    "source_manifest", "original_move_document", "original_handoff"]:
            target = (HERE / action[key]).resolve()
            assert target.is_relative_to(HERE) and target.exists(), (action["hero"], action["id"], key)
        read(HERE / action["metadata"])
        assert action["description"].strip()
        assert action["frame_count"] > 0 and action["body_duration_ms"] > 0
        with Image.open(HERE / action["representative"]) as image:
            image.verify()
        with Image.open(HERE / action["normal_gif"]) as gif:
            durations = []
            for frame in range(gif.n_frames):
                gif.seek(frame)
                durations.append(gif.info.get("duration", 0))
            assert durations == action["decoded_gif_durations_ms"]
            assert sum(durations) == action["preview_duration_ms"]
            decoded_gif_frames += gif.n_frames
    select = lambda hero, action: next(a for a in actions if a["hero"] == hero and a["id"] == action)
    hide = select("hideyoshi", "charge_release")
    assert "fastburst_v8" in hide["normal_gif"]
    assert hide["gif_library_version"] == 7
    assert (hide["frame_count"], hide["body_duration_ms"], hide["preview_duration_ms"]) == (17, 1240, 1440)
    assert next(p for p in provenance["packages"] if p["hero"] == "hideyoshi")["library_zip_version"] == 6
    ieyasu = select("ieyasu", "charge_release")
    assert "issen" in ieyasu["revision"]
    assert "history/" not in ieyasu["metadata"]
    assert (ieyasu["frame_count"], ieyasu["body_duration_ms"]) == (12, 800)
    kennyo = select("kennyo", "air_heavy")
    assert "continuous_15f_v5" in kennyo["source_directory"]
    assert (kennyo["frame_count"], kennyo["preview_duration_ms"]) == (15, 950)
    documents = [DOC, HERE / "README.md"]
    documents += [HERE / hero / "CURRENT_STATUS.md" for hero in EXPECTED]
    link_count = 0
    for document in documents:
        text = document.read_text(encoding="utf-8")
        for url in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            if url.startswith(("http://", "https://", "#")):
                continue
            target = (document.parent / unquote(url.split("#")[0])).resolve()
            assert target.is_relative_to(ROOT)
            if target != HERE / "VALIDATION.json":
                assert target.exists(), (document, url)
            link_count += 1
    assert len(re.findall(r"!\[", DOC.read_text(encoding="utf-8"))) == 64
    return {
        "status": "PASS", "source_files": len(hashes), "source_sha256_verified": len(hashes),
        "source_bytes": sum(sizes), "maximum_file_bytes": max(sizes),
        "accepted_actions": 64, "characters": {hero: 16 for hero in EXPECTED},
        "normal_gifs_decoded": 64, "decoded_gif_frames": decoded_gif_frames,
        "representative_images_verified": 64, "active_relative_links_verified": link_count,
        "latest_revision_locks": {"hideyoshi": "FX/action v8; GIF Library v7; ZIP Library v6", "ieyasu": "issen release 12 frames/800ms", "kennyo": "air_heavy 15 frames/950ms"},
        "historical_source_bytes_preserved": True, "oichi_files_duplicated": 0,
        "runtime_changed": False, "runtime_tested": False,
        "scope_note": "Only new navigation documents are link-checked. Original source documents and absolute historical production paths are preserved unchanged.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args()
    report = verify()
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.write_report:
        (HERE / "VALIDATION.json").write_text(output, encoding="utf-8", newline="\n")
    print(output)
