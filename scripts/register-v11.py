"""Measure untouched sprite PNGs; generate regions and anchors, never edit pixels."""
import json
import statistics
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/v11"
HEROES = ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
ROLES = ["soldier", "flag", "commander", "archer", "gunner", "boss"]
FACTIONS = ["mori", "imagawa", "oda", "saito", "miyoshi", "azai", "asakura", "takeda", "ikko", "akechi", "hashiba", "iga"]
BODY_HEIGHTS = {"oichi-combat": 133, "oichi-reactions": 147, "oichi-skills": 142, "oichi-needles":182, "nobunaga-skills":101, "hideyoshi-skills":128, "ieyasu-skills":93}


def measure(path, rows=6):
    alpha = np.asarray(Image.open(path).getchannel("A")) > 90
    labels, _ = ndimage.label(alpha, np.ones((3, 3)))
    areas = np.bincount(labels.ravel())
    minimum = max(500, alpha.sum() / (rows * 8) * .28)
    boxes = []
    for i, region in enumerate(ndimage.find_objects(labels), 1):
        if areas[i] < minimum:
            continue
        yy, xx = region
        boxes.append([xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start])
    # Source rows have a common ground line, including horizontal fallen figures.
    bottoms = np.array([y + h for x, y, w, h in boxes])
    centers = np.linspace(bottoms.min(), bottoms.max(), rows)
    for _ in range(30):
        groups = np.abs(bottoms[:, None] - centers).argmin(axis=1)
        updated = np.array([np.median(bottoms[groups == i]) if np.any(groups == i) else centers[i] for i in range(rows)])
        if np.allclose(updated, centers):
            break
        centers = updated
    ordered = [sorted([b for b, group in zip(boxes, groups) if group == i], key=lambda b: b[0]) for i in range(rows)]
    counts = [len(row) for row in ordered]
    assert all(4 <= n <= 8 for n in counts), f"{path.name}: malformed row counts {counts}"
    for row in ordered:
        for x, y, w, h in row:
            assert x > 0 and y > 0 and x + w < alpha.shape[1] and y + h < alpha.shape[0], f"{path.name}: clipped edge {(x,y,w,h)}"
    return alpha, ordered, counts


def registration(path, selections=None):
    sources = {}
    if selections:
        rows, counts, row_sources = [], [], []
        for selection in selections:
            name = selection["file"]
            if name not in sources:
                sources[name] = measure(OUT / name, selection.get("rows",6))
            alpha, measured, _ = sources[name]
            row = [box for row in measured[selection["row"]:selection["row"] + selection.get("span_rows",1)] for box in row]
            rows.append(row)
            counts.append(len(row))
            row_sources.append(name)
    else:
        alpha, rows, counts = measure(path, 3 if path.stem == "oichi-needles" else 6)
        sources[path.name] = (alpha,rows,counts)
        row_sources = [path.name] * len(rows)
    is_enemy = path.stem.startswith(("reactions-", "movement-", "attacks-"))
    is_reaction = path.stem.startswith("reactions-")
    # Each row remains eight slots in the atlas; playback uses only measured distinct poses.
    # Padding is never presented as a new animation frame.
    spec = {"columns": 8, "rows": len(rows), "feet_global": True, "feet": [], "regions": {},
            "component_clip": True, "support_offset": 0, "unplanted": list(range(len(rows) * 8)),
            "frame_counts": counts, "body_height": 1, "body_heights": [], "file":row_sources[0], "frame_files":{}}
    if is_enemy:
        faction = path.stem.split("-", 1)[1]
        target = {"reactions":"enemy_reaction", "movement":"enemy_movement", "attacks":"enemy_attack"}[path.stem.split("-",1)[0]]
        spec.update(target=target, groups={role if faction == "mori" else f"{role}-{faction}": list(range(i * 8, i * 8 + 8)) for i, role in enumerate(ROLES)})
    else:
        hero, sheet = path.stem.split("-", 1)
        spec.update(target="hero", hero=hero, sheet="v11_" + sheet)
    manual = BODY_HEIGHTS.get(path.stem)
    stand_height = float(manual) if isinstance(manual, (int, float)) else statistics.median(b[3] for b in rows[0])
    for row_index, row in enumerate(rows):
        name = row_sources[row_index]
        alpha, source_rows, _ = sources[name]
        # Reaction rows start bent already: use each role's first pose scale, never prone bounds.
        body_height = (manual[row_index] if isinstance(manual,list) else row[0][3]) if is_enemy else stand_height
        if selections:
            body_height = selections[row_index].get("body_height", statistics.median(b[3] for b in source_rows[0]))
        for column in range(8):
            x, y, w, h = row[min(column, len(row) - 1)]
            cell = row_index * 8 + column
            if name != row_sources[0]: spec["frame_files"][str(cell)] = name
            left, top = max(0, x - 2), max(0, y - 2)
            right, bottom = min(alpha.shape[1], x + w + 2), min(alpha.shape[0], y + h + 2)
            spec["regions"][str(cell)] = [left, top, right - left, bottom - top]
            crop = alpha[y:y + h, x:x + w]
            if is_reaction and column >= 4 or not is_enemy and spec["sheet"] == "v11_reactions" and row_index in [2, 3]:
                anchor_x = x + w * .5
            else:
                body = crop[max(0, h - int(body_height * .7)):max(1, h - int(body_height * .2))]
                _, body_x = np.nonzero(body)
                anchor_x = x + (float(np.median(body_x)) if len(body_x) else w * .5)
            spec["feet"].append([round(anchor_x, 2), y + h])
            spec["body_heights"].append(round(body_height, 2))
    spec["body_height"] = round(stand_height, 2)
    hands_path = OUT / (path.stem + "-hands.json")
    if hands_path.exists():
        spec["hands_global"] = True
        spec["hands"] = json.loads(hands_path.read_text(encoding="utf-8-sig"))
    return spec


def main():
    actors = {}
    for name in ["reaction-measurements.json", "movement-measurements.json", "skills-measurements.json", "male-reaction-measurements.json", "attack-measurements.json", "attack-measurements-extra.json"]:
        path = OUT / name
        if path.exists(): BODY_HEIGHTS.update(json.loads(path.read_text(encoding="utf-8-sig")))
    composition_path = OUT / "combat-compositions.json"
    compositions = json.loads(composition_path.read_text(encoding="utf-8")) if composition_path.exists() else {}
    for path in sorted(OUT.glob("*.png")):
        if path.stem in [prefix + faction for prefix in ["reactions-", "movement-", "attacks-"] for faction in FACTIONS] or any(path.stem == f"{hero}-{sheet}" for hero in HEROES for sheet in ["combat", "skills", "reactions", "movement", "needles"]):
            spec = registration(path)
            actors[path.stem] = spec
            print(path.name, spec["frame_counts"])
    for hero, selections in compositions.items():
        if len(selections) != 6: continue
        spec = registration(OUT / f"{hero}-combat.png",selections)
        actors[f"{hero}-combat"] = spec
        print(hero + "-combat (source composition)",spec["frame_counts"])
    assert actors, "No completed atlases found"
    (OUT / "registration.json").write_text(json.dumps({"version": "0.11", "actors": actors}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
