"""Check the native clipping polygons against every original figure; never edit source pixels."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/tadakatsu-atlas-v17"
module = importlib.util.spec_from_file_location("registration", ROOT / "scripts/register-v16.py")
registration = importlib.util.module_from_spec(module)
module.loader.exec_module(registration)


def verify_generated_sources():
    baseline_path = OUT / "source-sha256-v17.json"
    if not baseline_path.exists():
        baseline = {}
        for prompt_path in sorted((ROOT / "game/assets/v17/prompts").glob("*.json")):
            prompt = json.loads(prompt_path.read_text(encoding="utf-8-sig"))
            source = Path(prompt.get("source_path", prompt.get("path", "")))
            assert source.is_file(), f"Cannot establish generator provenance: {prompt_path.name}"
            name = prompt["id"].removeprefix("tadakatsu-")
            folder = "v16" if name.startswith(("heavy1-v17-", "walk-v17-")) else "v17"
            relative = f"game/assets/{folder}/tadakatsu-{name}.png"
            asset = ROOT / relative
            digest = hashlib.sha256(asset.read_bytes()).hexdigest()
            assert digest == hashlib.sha256(source.read_bytes()).hexdigest(), f"Generated art pixels changed: {relative}"
            baseline[relative] = {"sha256": digest, "prompt": str(prompt_path.relative_to(ROOT)).replace("\\", "/"),
                                  "original_generator_source": str(source)}
        assert len(baseline) == 36, "Expected 32 v17 source sheets and 4 base replacement sheets"
        baseline_path.write_text(json.dumps(baseline, indent=2) + "\n", encoding="utf-8")
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    assert len(baseline) == 36
    for relative, item in baseline.items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == item["sha256"], f"Source art changed: {relative}"
    return {"source_sheets": len(baseline), "byte_identical_to_generator": True, "baseline": str(baseline_path.relative_to(ROOT)).replace("\\", "/")}


def verify_new_clips():
    native_path = OUT / "clips/native-verification.json"
    native = json.loads(native_path.read_text(encoding="utf-8"))
    root = ROOT / "game/assets/v17"
    assert hashlib.sha256((root / "registration.json").read_bytes()).hexdigest() == native["registration_sha256"], "v17 native evidence is stale"
    assert len(native["frames"]) == 192, "Render all sixteen twelve-frame clips"
    cache, result = {}, []
    for frame in native["frames"]:
        if frame["file"] not in cache:
            path = root / frame["file"]
            image = Image.open(path).convert("RGBA")
            alpha = np.asarray(image.getchannel("A"))
            labels, _ = ndimage.label(alpha > 90, np.ones((3, 3)))
            areas = np.bincount(labels.ravel())
            body_ids = [index for index, area in enumerate(areas) if index and area > 15000]
            assert len(body_ids) == 6 and (alpha == 0).mean() > .15, frame["file"]
            assert not np.any(np.concatenate((alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1])) > 24), "v17 original hits a canvas edge"
            cache[frame["file"]] = image, labels, body_ids, hashlib.sha256(path.read_bytes()).hexdigest()
        image, labels, body_ids, digest = cache[frame["file"]]
        x, y, width, height = map(int, frame["region"])
        own = max(body_ids, key=lambda label: np.count_nonzero(labels[y:y + height, x:x + width] == label))
        polygon = Image.new("1", image.size)
        ImageDraw.Draw(polygon).polygon([(px + x, py + y) for px, py in frame["polygon"]], fill=1)
        mask = np.asarray(polygon)
        foreign = int(np.count_nonzero(mask & np.isin(labels, [label for label in body_ids if label != own])))
        owned = int(np.count_nonzero(labels == own))
        retained = int(np.count_nonzero(mask & (labels == own)))
        assert foreign == 0 and retained / owned >= .985, f"{frame['actor']}:{frame['index']} contour contamination/detail loss"
        result.append({"clip": frame["actor"], "frame": frame["index"], "file": frame["file"], "source_sha256": digest,
                       "foreign_after": foreign, "owned_pixels": owned, "retained_pixels": retained})
    return {"frames": result, "clean_contours": len(result), "foreign_pixels_after": sum(item["foreign_after"] for item in result),
            "retained_fraction": sum(item["retained_pixels"] for item in result) / sum(item["owned_pixels"] for item in result),
            "native_boards": native["boards"]}


def main():
    native = json.loads((OUT / "native-verification.json").read_text(encoding="utf-8"))
    before = json.loads((OUT / "registration-before.json").read_text(encoding="utf-8"))
    current_path = registration.ASSET_DIR / "registration.json"
    assert hashlib.sha256(current_path.read_bytes()).hexdigest() == native["registration_sha256"], "Native evidence is stale"
    baseline_path = OUT / "source-sha256-before.json"
    if not baseline_path.exists():
        baseline_path.write_text(json.dumps(native["original_sources"], indent=2) + "\n", encoding="utf-8")
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    assert native["original_sources"] == baseline, "Original artwork must not be painted over or resampled"
    cache, before_cache, result = {}, {}, []
    for frame in native["frames"]:
        if frame["superseded"]:
            continue
        path = registration.ASSET_DIR / frame["file"]
        clip = frame["actor"].removeprefix("tadakatsu-")
        if frame["file"] not in cache:
            image = Image.open(path).convert("RGBA")
            alpha = np.asarray(image.getchannel("A"))
            if frame["file"] == before["actors"][frame["actor"]]["file"]:
                labels, parts = registration.body_components(image, *registration.SHEETS[clip][:2])
            else:
                labels, _ = ndimage.label(alpha > 90, np.ones((3, 3)))
                areas = np.bincount(labels.ravel())
                parts = []
                for label, bounds in enumerate(ndimage.find_objects(labels), 1):
                    if areas[label] < 15000:
                        continue
                    yy, xx = bounds
                    parts.append((label, [xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start]))
            cache[frame["file"]] = image, labels, parts
        image, labels, parts = cache[frame["file"]]
        x, y, width, height = map(int, frame["region"])
        is_repair = frame["file"] != before["actors"][frame["actor"]]["file"]
        if is_repair:
            own, own_box = max(parts, key=lambda item: np.count_nonzero(labels[y:y + height, x:x + width] == item[0]))
            xx, yy, ww, hh = own_box
            assert xx > 0 and yy > 0 and xx + ww < image.width and yy + hh < image.height, "Replacement still touches source canvas"
        else:
            own, own_box = parts[frame["index"]]
        polygon = Image.new("1", image.size)
        ImageDraw.Draw(polygon).polygon([(px + x, py + y) for px, py in frame["polygon"]], fill=1)
        mask = np.asarray(polygon)
        other_ids = [label for label, _ in parts if label != own]
        foreign = int(np.count_nonzero(mask & np.isin(labels, other_ids)))
        owned = int(np.count_nonzero(labels == own))
        retained = int(np.count_nonzero(mask & (labels == own)))
        assert foreign == 0, f"{clip}:{frame['index']} contains {foreign} neighbouring pixels"
        assert retained / owned >= .985, f"{clip}:{frame['index']} loses figure detail"
        if clip not in before_cache:
            old_image = Image.open(registration.ASSET_DIR / before["actors"][frame["actor"]]["file"]).convert("RGBA")
            before_cache[clip] = registration.body_components(old_image, *registration.SHEETS[clip][:2])
        old_labels, old_parts = before_cache[clip]
        old_own = old_parts[frame["index"]][0]
        old_other_ids = [label for label, _ in old_parts if label != old_own]
        bx, by, bw, bh = before["actors"][frame["actor"]]["regions"][str(frame["index"])]
        old_foreign = int(np.count_nonzero(np.isin(old_labels[by:by + bh, bx:bx + bw], old_other_ids)))
        result.append({"clip": clip, "frame": frame["index"], "file": frame["file"], "source_bbox": own_box,
                       "foreign_before": old_foreign, "foreign_after": foreign, "owned_pixels": owned,
                       "retained_pixels": retained, "retained_fraction": retained / owned, "replacement": is_repair})
    repairs_path = registration.ASSET_DIR / "tadakatsu-repairs-v17.json"
    repairs = json.loads(repairs_path.read_text(encoding="utf-8-sig")) if repairs_path.exists() else {}
    pending = [f"{clip}:{index}" for clip, indices in registration.REPAIR_FRAMES.items()
               for index in indices if str(index) not in repairs.get(clip, {})]
    if "--require-final" in sys.argv:
        assert not pending, f"Missing original-canvas repairs: {pending}"
        v17 = json.loads((ROOT / "game/assets/v17/registration.json").read_text(encoding="utf-8-sig"))
        assert any(item.get("hero") == "tadakatsu" and item.get("sheet") == "v17_special" and len(item["feet"]) == 12 for item in v17["actors"].values()), "The rejected special source must have a complete v17 replacement"
    report = {"native_checks": native["assertions"], "audited_original_frames": native["total_frames"],
              "clean_contours": len(result), "foreign_pixels_after": sum(item["foreign_after"] for item in result),
              "contaminated_original_regions": sum(bool(item["foreign_before"]) for item in result),
              "retained_fraction": sum(item["retained_pixels"] for item in result) / sum(item["owned_pixels"] for item in result),
              "pending_replacements": pending, "superseded_special_frames": 12, "original_sha256_unchanged": True,
              "native_boards": native["boards"], "frames": result,
              "limits": "Pixel accounting uses alpha > 90 and the same native polygon as gameplay. The existing contour approximation can omit subpixel edge pixels; animation motion and anatomy require visual review."}
    if "--require-final" in sys.argv:
        report["v17"] = verify_new_clips()
        report["generated_source_integrity"] = verify_generated_sources()
    (OUT / "verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"TADAKATSU ATLAS V17: {len(result)} clean contours, 0 neighbouring pixels; {report['contaminated_original_regions']} originally contaminated regions; retained {report['retained_fraction']:.4%}; pending={pending}")
    if "v17" in report:
        print(f"V17 CLIPS: {report['v17']['clean_contours']} clean contours, 0 neighbouring pixels; retained {report['v17']['retained_fraction']:.4%}; 36 source sheets byte-identical to generator")


if __name__ == "__main__":
    main()
