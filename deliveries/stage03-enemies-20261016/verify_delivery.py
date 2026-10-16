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
        names = package.namelist()
        assert len(names) == len(set(names)) == 223
        assert package.testzip() is None
        for entry in package.infolist():
            path = PurePosixPath(entry.filename)
            assert not path.is_absolute() and ".." not in path.parts
            assert "\\" not in entry.filename and ":" not in entry.filename
            assert not stat.S_ISLNK(entry.external_attr >> 16)
            assert (source / entry.filename).read_bytes() == package.read(entry)
        assert {p.relative_to(source).as_posix() for p in source.rglob("*") if p.is_file()} == set(names)
        hashes = json.loads(package.read("SHA256.json"))
        assert len(hashes) == 222 and set(hashes) == set(names) - {"SHA256.json"}
        for name, expected in hashes.items():
            assert digest(package.read(name)) == expected, name

        manifest = json.loads(package.read("manifest.json"))
        inventory = json.loads(package.read("inventory.json"))
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
                raw = json.loads(package.read(data["metadata_path"]))
                if isinstance(raw, list):
                    metadata = next(row for row in raw if row["action"] == aid)
                elif "actions" in raw:
                    metadata = raw["actions"][aid]
                else:
                    metadata = raw
                if metadata.get("metadata") and not any(name.endswith("/" + metadata["metadata"]) for name in names):
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
                    payload = package.read(name)
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
        assert missing == [{"action": "ujinori/slash", "reference": "slash/timing.json"}]
        assert missing == contract["missing_source_references"]
        movie = next(item for item in provenance["sources"] if item["file_name"] == "enemy-combined-preview.mp4")
        assert digest(package.read(movie["file_name"])) == movie["sha256"]

    return {
        "status": "PASS_WITH_DOCUMENTED_SOURCE_GAPS",
        "zip_bytes": archive.stat().st_size,
        "zip_sha256": ARCHIVE_SHA256,
        "unchanged_extracted_files": 223,
        "verified_source_sha256_entries": 222,
        "characters": counts,
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
