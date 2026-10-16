"""Verify the unmodified Stage 03 art delivery; does not modify runtime files."""
from pathlib import Path, PurePosixPath
from io import BytesIO
import hashlib
import json
import stat
import zipfile
from PIL import Image

BASE = Path(__file__).resolve().parent
ARCHIVE = "stage03-enemy-review-package.zip"
ARCHIVE_SHA256 = "5ec1811cc96b41de19e290545711e98489ed7e2d2adcea7659fb456bbc6894a1"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify():
    archive = BASE / ARCHIVE
    assert archive.stat().st_size == 33121939
    assert digest(archive.read_bytes()) == ARCHIVE_SHA256
    source = BASE / "source"
    contract = json.loads((BASE / "integration-contract.json").read_text(encoding="utf-8"))
    provenance = json.loads((BASE / "source-library.json").read_text(encoding="utf-8"))
    assert contract["runtime_integrated"] is False
    assert provenance["preview_approved"] is True and provenance["runtime_integrated"] is False
    for item in provenance["sources"]:
        path = BASE.parents[1] / item["repository_path"]
        assert path.is_file() and path.stat().st_size == item["size_bytes"]
        assert digest(path.read_bytes()) == item["sha256"]

    with zipfile.ZipFile(archive) as package:
        original_names = package.namelist()
        assert len(original_names) == len(set(original_names)) == 223
        assert package.testzip() is None
        original_hashes = json.loads(package.read("SHA256.json"))
        assert len(original_hashes) == 222
        payloads = {name: package.read(name) for name in original_names}
        for name, expected in original_hashes.items():
            assert digest(payloads[name]) == expected
        patch_path = BASE / "stage03-enemy-timing-fix.zip"
        assert digest(patch_path.read_bytes()) == "dc392a86df968130cd1e5f9163f7d7201eed4f76d2af3c51ce18dbd898b76050"
        with zipfile.ZipFile(patch_path) as patch:
            assert patch.testzip() is None
            assert len(patch.namelist()) == 10
            for entry in patch.infolist():
                assert not stat.S_ISLNK(entry.external_attr >> 16)
                payloads[entry.filename] = patch.read(entry)
        names = sorted(payloads)
        assert len(names) == 226
        for name in names:
            path = PurePosixPath(name)
            assert not path.is_absolute() and ".." not in path.parts
            assert "\\" not in name and ":" not in name
            assert (source / name).read_bytes() == payloads[name]
        assert {p.relative_to(source).as_posix() for p in source.rglob("*") if p.is_file()} == set(names)
        hashes = json.loads(payloads["SHA256.json"])
        assert len(hashes) == 225 and set(hashes) == set(names) - {"SHA256.json"}
        for name, expected in hashes.items():
            assert digest(payloads[name]) == expected, name

        manifest = json.loads(payloads["manifest.json"])
        inventory = json.loads(payloads["inventory.json"])
        assert len(manifest) == 6 and len(inventory) == 37
        inventory_by_id = {(row["character"], row["action"]): row for row in inventory}
        assert len(inventory_by_id) == 37
        assert set(manifest) == set(contract["characters"])
        frame_paths, frame_hashes, counts, missing = [], [], {}, []
        for cid, actor in manifest.items():
            normalized = contract["characters"][cid]
            assert actor["root"] == normalized["default_root"]
            assert actor["scale"] == normalized["preview_scale"]
            assert set(actor["actions"]) == set(normalized["actions"])
            actor_frames = 0
            for aid, action in actor["actions"].items():
                data = normalized["actions"][aid]
                raw = json.loads(payloads[data["metadata_path"]])
                if isinstance(raw, list):
                    metadata = next(row for row in raw if row["action"] == aid)
                elif "actions" in raw:
                    metadata = raw["actions"][aid]
                else:
                    metadata = raw
                if metadata.get("metadata") and not (source / data["metadata_path"]).parent.joinpath(metadata["metadata"]).is_file():
                    missing.append({"action": cid + "/" + aid, "reference": metadata["metadata"]})
                assert action["loop"] == data["loop"]
                hold = bool(metadata.get("hold_final") or metadata.get("hold_last") or metadata.get("end_hold") or metadata.get("end") == "hold_last_frame")
                assert hold == data["hold_last"]
                durations = [frame["duration_ms"] for frame in action["frames"]]
                assert all(type(ms) is int and ms > 0 for ms in durations)
                assert durations == data["durations_ms"]
                row = inventory_by_id[cid, aid]
                assert row["frames"] == len(durations) and row["duration_ms"] == sum(durations)
                assert row["loop"] == action["loop"]
                if "duration_ms" in metadata:
                    assert metadata["duration_ms"] == sum(durations)
                if "frame_ms" in metadata:
                    assert metadata["frame_ms"] == durations
                assert [frame["root"] for frame in action["frames"]] == data["roots"]
                assert [frame["package_path"] for frame in action["frames"]] == data["paths"]
                for index, frame in enumerate(action["frames"]):
                    name = frame["package_path"]
                    assert name.startswith(f"frames/{cid}/{aid}/")
                    payload = payloads[name]
                    image = Image.open(BytesIO(payload))
                    image.load()
                    assert image.mode == "RGBA" and list(image.size) == data["canvas_sizes"][index]
                    bounds = image.getchannel("A").getbbox()
                    assert bounds and bounds[0] > 0 and bounds[1] > 0
                    assert bounds[2] < image.width and bounds[3] < image.height, name
                    frame_paths.append(name)
                    frame_hashes.append(digest(payload))
                actor_frames += len(durations)
            counts[cid] = {"actions": len(actor["actions"]), "playback_frames": actor_frames}
        assert len(frame_paths) == len(set(frame_paths)) == 178
        assert set(frame_paths) == {name for name in names if name.startswith("frames/")}
        assert not missing
        assert missing == contract["missing_source_references"]
        references = {"frames": 0, "timing": 0}
        for metadata_path in sorted((source / "metadata").rglob("*.json")):
            cid = metadata_path.relative_to(source / "metadata").parts[0]
            def visit(node, action):
                if isinstance(node, list):
                    for item in node: visit(item, action)
                elif isinstance(node, dict):
                    if node.get("action") in manifest[cid]["actions"]: action = node["action"]
                    if isinstance(node.get("file"), str):
                        assert (source / "frames" / cid / action / node["file"]).is_file()
                        references["frames"] += 1
                    if isinstance(node.get("metadata"), str):
                        target = (metadata_path.parent / node["metadata"]).resolve()
                        assert target.is_relative_to(source.resolve()) and target.is_file()
                        references["timing"] += 1
                    for key, value in node.items():
                        if key == "actions":
                            for action_id, descriptor in value.items(): visit(descriptor, action_id)
                        else: visit(value, action)
            visit(json.loads(metadata_path.read_text(encoding="utf-8")), metadata_path.parent.name)
        assert references == {"frames": 586, "timing": 6}
        movie = next(item for item in provenance["sources"] if item["file_name"] == "enemy-combined-preview.mp4")
        assert digest(payloads[movie["file_name"]]) == movie["sha256"]

    return {
        "status": "PASS",
        "zip_bytes": archive.stat().st_size,
        "zip_sha256": ARCHIVE_SHA256,
        "verified_extracted_files": 226,
        "original_archive_files": 223,
        "verified_source_sha256_entries": 225,
        "original_archive_sha256_entries": 222,
        "characters": counts,
        "source_metadata_references": references,
        "actions": 37,
        "playback_frames": 178,
        "unique_png_sha256": len(set(frame_hashes)),
        "all_frames_rgba_with_clear_canvas_border": True,
        "approved_video_matches_package": True,
        "runtime_integrated": False,
        "missing_source_references": missing,
        "not_in_package": ["arrow flight PNG", "sword-energy projectile PNG", "stage backgrounds and destructible props", "audio"],
    }


if __name__ == "__main__":
    print(json.dumps(verify(), ensure_ascii=False, indent=2))
