"""Register original HD PNG drawings without resampling or changing their pixels."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

VERSION = sys.argv[1] if len(sys.argv) > 1 else "v12"
assert VERSION in ("v12", "v13"), "Usage: register-v12.py [v12|v13]"
ROOT = Path(__file__).resolve().parents[1] / "game/assets" / VERSION


def register(name, meta):
    if "parts" in meta:
        parts = [register(name, {**part, "part": True}) for part in meta["parts"]]
        selections = [source.get("indices", list(range(len(part["feet"])))) for source, part in zip(meta["parts"], parts)]
        for part, indices in zip(parts, selections):
            assert indices and len(indices) == len(set(indices)) and all(0 <= index < len(part["feet"]) for index in indices), f"{name}: invalid selected drawings"
        total = sum(len(indices) for indices in selections)
        assert total == meta["frame_count"] == 12, f"{name}: split clip must contain twelve drawings"
        spec = {**parts[0], "columns": 4, "rows": 3, "feet": [], "regions": {},
                "unplanted": list(range(total)), "frame_files": {}, "body_heights": [], "hands": {}, "hands_global": True,
                "blades": {}, "blades_global": True}
        for part, indices in zip(parts, selections):
            start = len(spec["feet"])
            for position, local in enumerate(indices):
                key = str(start + position)
                spec["feet"].append(part["feet"][local])
                spec["regions"][key] = part["regions"][str(local)]
                spec["frame_files"][key] = part["file"]
                spec["body_heights"].append(part.get("body_heights", [part["body_height"]] * len(part["feet"]))[local])
                if str(local) in part.get("hands", {}): spec["hands"][key] = part["hands"][str(local)]
                if str(local) in part.get("blades", {}): spec["blades"][key] = part["blades"][str(local)]
        if "hands" in meta: spec["hands"].update(meta["hands"])
        if "blades" in meta: spec["blades"].update(meta["blades"])
        if "body_heights" in meta:
            assert len(meta["body_heights"]) == total and min(meta["body_heights"]) >= 220, f"{name}: invalid anatomical scales"
            spec["body_heights"] = meta["body_heights"]
        if "groups" in spec: spec["groups"] = {key: list(range(total)) for key in spec["groups"]}
        return spec
    path = ROOT / meta["file"]
    image = Image.open(path)
    assert image.mode == "RGBA", f"{name}: genuine alpha required"
    alpha = np.asarray(image.getchannel("A"))
    assert (alpha == 0).mean() > .15, f"{name}: background is not transparent"
    assert meta["body_height"] >= 220, f"{name}: drawing is too small"
    columns, rows = meta["columns"], meta["rows"]
    count = columns * rows
    assert count == meta["frame_count"] and count in ((1, 6) if meta.get("part") else (12,)), f"{name}: incorrect drawing count"
    labels, _ = ndimage.label(alpha > 90, np.ones((3, 3)))
    areas = np.bincount(labels.ravel())
    minimum = max(500, (alpha > 90).sum() / count * .24)
    boxes = []
    for i, bounds in enumerate(ndimage.find_objects(labels), 1):
        if areas[i] < minimum:
            continue
        yy, xx = bounds
        boxes.append([xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start])
    assert len(boxes) == count, f"{name}: {len(boxes)} bodies; overlaps or missing drawings"
    # Bottoms identify source rows even when a sword extends above its neighbours.
    bottoms = np.array([box[1] + box[3] for box in boxes])
    centers = np.linspace(bottoms.min(), bottoms.max(), rows)
    for _ in range(30):
        groups = np.abs(bottoms[:, None] - centers).argmin(axis=1)
        updated = np.array([np.median(bottoms[groups == row]) if np.any(groups == row) else centers[row] for row in range(rows)])
        if np.allclose(updated, centers): break
        centers = updated
    row_counts = [int((groups == row).sum()) for row in range(rows)]
    assert row_counts == [columns] * rows, f"{name}: declared layout disagrees with actual rows {row_counts}"
    ordered = []
    for row in range(rows):
        ordered.extend(sorted([box for box, group in zip(boxes, groups) if group == row], key=lambda box: box[0]))
    spec = {"file": meta["file"], "columns": columns, "rows": rows,
            "feet_global": True, "feet": [], "regions": {}, "unplanted": list(range(count)),
            "body_height": meta["body_height"], "component_clip": True}
    if "body_heights" in meta:
        assert len(meta["body_heights"]) == count and min(meta["body_heights"]) >= 220, f"{name}: invalid anatomical scales"
        spec["body_heights"] = meta["body_heights"]
    if name.startswith("boss-"):
        faction = name.split("-")[1]
        spec.update(target="enemy_attack", groups={"boss" if faction == "mori" else "boss-" + faction: list(range(count))})
    else:
        hero, clip = name.split("-", 1)
        spec.update(target="hero", hero=hero, sheet=VERSION + "_" + clip)
    for i, (x, y, w, h) in enumerate(ordered):
        assert x > 0 and y > 0 and x + w < image.width and y + h < image.height, f"{name} frame {i}: clipped outer edge"
        body_height = meta.get("body_heights", [meta["body_height"]] * count)[i]
        body = alpha[max(y, y + h - int(body_height * .65)):y + h - int(body_height * .2), x:x + w] > 90
        _, body_x = np.nonzero(body)
        anchor_x = x + (float(np.median(body_x)) if len(body_x) else w * .5)
        spec["feet"].append([round(anchor_x, 2), y + h])
        left, top = max(0, x - 2), max(0, y - 2)
        right, bottom = min(image.width, x + w + 2), min(image.height, y + h + 2)
        spec["regions"][str(i)] = [left, top, right - left, bottom - top]
    if "feet" in meta:
        assert len(meta["feet"]) == count
        spec["feet"] = meta["feet"]
    if "hands" in meta:
        spec.update(hands=meta["hands"], hands_global=True)
    if "blades" in meta:
        spec.update(blades=meta["blades"], blades_global=True)
    return spec


def main():
    clips = {}
    for path in sorted(ROOT.glob("*-clips.json")):
        for name, meta in json.loads(path.read_text(encoding="utf-8-sig")).items():
            assert name not in clips, f"duplicate clip: {name}"
            clips[name] = register(name, meta)
            print(name, clips[name]["body_height"], "px / 12 drawings")
    assert clips, "No accepted clips"
    (ROOT / "registration.json").write_text(json.dumps({"version": "0." + VERSION[1:], "actors": clips}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
