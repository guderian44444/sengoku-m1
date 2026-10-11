from __future__ import annotations

import json
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "game" / "assets" / "v16"
SHEETS = {
    "idle": (3, 2, 330),
    "light1": (4, 3, 250),
    "light2": (4, 3, 250),
    "light3": (4, 3, 250),
    "heavy1": (4, 3, 250),
    "heavy2": (4, 3, 250),
    "charge": (4, 3, 250),
    "grab": (4, 3, 250),
    "walk": (4, 3, 250),
    "run": (4, 3, 250),
    "jump": (4, 3, 250),
    "reactions": (4, 3, 250),
    "special": (4, 3, 250),
    "victory": (4, 3, 250),
}

# Pelvis/support landmarks measured on the original drawings, not cell centres or VFX bounds.
ANCHOR_X = {
    "idle": [282, 787, 1292, 280, 788, 1293],
    "light1": [186, 532, 861, 1312, 175, 553, 934, 1331, 176, 612, 1001, 1365],
    "light2": [174, 549, 906, 1328, 184, 543, 903, 1287, 179, 594, 972, 1337],
    "light3": [212, 589, 986, 1397, 246, 595, 969, 1364, 204, 591, 994, 1357],
    "heavy1": [262, 621, 960, 1343, 234, 594, 961, 1330, 221, 592, 990, 1338],
    "heavy2": [207, 587, 980, 1360, 160, 536, 925, 1313, 186, 606, 994, 1369],
    "charge": [182, 559, 934, 1293, 177, 553, 931, 1291, 184, 561, 932, 1295],
    "grab": [192, 562, 944, 1308, 183, 556, 941, 1299, 185, 563, 957, 1320],
    "walk": [211, 607, 994, 1355, 236, 621, 1004, 1374, 221, 605, 993, 1364],
    "run": [214, 588, 978, 1351, 221, 598, 989, 1375, 209, 592, 984, 1371],
    "jump": [172, 551, 917, 1308, 190, 561, 943, 1322, 199, 579, 931, 1320],
    "reactions": [208, 601, 982, 1373, 176, 571, 928, 1292, 202, 595, 958, 1329],
    "victory": [227, 583, 963, 1352, 219, 590, 966, 1344, 221, 596, 978, 1356],
}
FOOT_Y = {
    "heavy1": [362, 363, 367, 370, 683, 681, 684, 683, 1001, 1002, 1005, 1010],
    "run": [323] * 4 + [664] * 4 + [988] * 4,
    "charge": [333] * 4 + [662] * 4 + [992] * 4,
    "reactions": [361, 365, 370, 349, 659, 661, 636, 638, 980, 990, 991, 994],
}
CLIPPED_SOURCE_FRAMES = {"heavy1": [2], "walk": [3, 7, 11]}
REPAIR_FRAMES = {"heavy1": list(range(12)), "walk": list(range(12))}

REPAIR_SUPPORT_X = {
    "heavy1": [273, 787, 1312, 270, 766, 1290, 288, 787, 1300, 286, 797, 1288],
    "walk": [273, 791, 1291, 295, 793, 1290, 284, 798, 1302, 278, 807, 1300],
}
REPAIR_ORDER = {"heavy1": [0, 1, 2, 3, 4, 6, 5, 7, 8, 9, 10, 11], "walk": list(range(12))}


def body_components(image: Image.Image, columns: int, rows: int):
    alpha = np.asarray(image.getchannel("A"))
    assert (alpha == 0).mean() > .15, "A genuine transparent source is required"
    labels, _ = ndimage.label(alpha > 90, np.ones((3, 3)))
    areas = np.bincount(labels.ravel())
    parts = []
    for label, bounds in enumerate(ndimage.find_objects(labels), 1):
        if areas[label] < 15000:
            continue
        yy, xx = bounds
        parts.append((label, [xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start]))
    assert len(parts) == columns * rows, f"Expected {columns * rows} separate figures, got {len(parts)}"
    # Feet identify the source rows even when a raised spear extends into the preceding row.
    parts.sort(key=lambda item: item[1][1] + item[1][3])
    ordered = []
    for row in range(rows):
        ordered.extend(sorted(parts[row * columns:(row + 1) * columns], key=lambda item: item[1][0]))
    return labels, ordered


def register_repairs() -> None:
    repairs = {}
    for clip in REPAIR_FRAMES:
        drawings = []
        for part in ["a", "b"]:
            filename = f"tadakatsu-{clip}-v17-{part}.png"
            path = ASSET_DIR / filename
            if not path.is_file():
                return
            image = Image.open(path).convert("RGBA")
            _, parts = body_components(image, 3, 2)
            for _, (x, y, width, height) in parts:
                assert x > 0 and y > 0 and x + width < image.width and y + height < image.height, "Repair still clipped by source canvas"
                left, top = max(0, x - 3), max(0, y - 3)
                right, bottom = min(image.width, x + width + 3), min(image.height, y + height + 3)
                drawings.append({"file": filename, "region": [left, top, right - left, bottom - top],
                                 "foot": [REPAIR_SUPPORT_X[clip][len(drawings)], y + height],
                                 "body_height": 280 if clip == "heavy1" else 350})
        assert len(drawings) == 12 and sorted(REPAIR_ORDER[clip]) == list(range(12))
        repairs[clip] = {str(index): drawings[source] for index, source in enumerate(REPAIR_ORDER[clip])}
    (ASSET_DIR / "tadakatsu-repairs-v17.json").write_text(json.dumps(repairs, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    register_repairs()
    actors = {}
    inventory = []
    for clip, (columns, rows, body_height) in SHEETS.items():
        filename = f"tadakatsu-{clip}.png"
        path = ASSET_DIR / filename
        with Image.open(path) as image:
            image = image.convert("RGBA")
            width, height = image.size
            frame_count = columns * rows
            feet, regions = [], {}
            if clip == "special":
                # This source has inseparable drawings; v17 replaces it rather than cutting off the spear.
                existing = json.loads((ASSET_DIR / "registration.json").read_text(encoding="utf-8"))["actors"]["tadakatsu-special"]
                feet, regions = existing["feet"], existing["regions"]
            else:
                _, parts = body_components(image, columns, rows)
                assert len(ANCHOR_X[clip]) == frame_count
                for index, (_, (x, y, w, h)) in enumerate(parts):
                    left, top = max(0, x - 3), max(0, y - 3)
                    right, bottom = min(width, x + w + 3), min(height, y + h + 3)
                    regions[str(index)] = [left, top, right - left, bottom - top]
                    feet.append([ANCHOR_X[clip][index], FOOT_Y[clip][index] if clip in FOOT_Y else y + h])
            actors[f"tadakatsu-{clip}"] = {
                "hero": "tadakatsu",
                "target": "hero",
                "sheet": f"v16_{clip}",
                "file": filename,
                "columns": columns,
                "rows": rows,
                "feet_global": True,
                "feet": feet,
                "regions": regions,
                "unplanted": list(range(columns * rows)),
                "body_height": body_height,
            }
            if clip != "special":
                actors[f"tadakatsu-{clip}"].update(component_clip=True, component_alpha_threshold=90 / 255)
            inventory.append({"sheet": f"v16_{clip}", "file": filename, "columns": columns, "rows": rows, "frames": frame_count, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    repairs_path = ASSET_DIR / "tadakatsu-repairs-v17.json"
    repairs = json.loads(repairs_path.read_text(encoding="utf-8-sig")) if repairs_path.exists() else {}
    pending = []
    for clip, indices in REPAIR_FRAMES.items():
        actor = actors[f"tadakatsu-{clip}"]
        for index in indices:
            repair = repairs.get(clip, {}).get(str(index))
            if not repair:
                pending.append(f"{clip}:{index}")
                continue
            assert (ASSET_DIR / repair["file"]).is_file(), f"Missing replacement {clip}:{index}"
            actor.setdefault("frame_files", {})[str(index)] = repair["file"]
            actor["regions"][str(index)] = repair["region"]
            actor["feet"][index] = repair["foot"]
            actor.setdefault("body_heights", [actor["body_height"]] * len(actor["feet"]))[index] = repair["body_height"]
    assert set(actors) == {f"tadakatsu-{clip}" for clip in SHEETS} and sum(item["frames"] for item in inventory) == 162
    (ASSET_DIR / "registration.json").write_text(json.dumps({"actors": actors}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    routes = {
        "idle": "v16_idle (6)", "walk": "v16_walk (12)", "run": "v16_run (12)", "jump": "v16_jump (12)",
        "light1": "v16_light1 (12)", "light2": "v16_light2 (12)", "light3": "v16_light3 (12)",
        "heavy1": "v16_heavy1 (12)", "heavy2": "v16_heavy2 (12)", "charge/charged": "v16_charge (6+6)",
        "holding/throw": "v16_grab (12)", "reactions": "v16_reactions (12)", "special": "v16_special (12)", "victory": "v16_victory (12)",
    }
    asset_record = {
        "version": "v16",
        "hero": "tadakatsu",
        "design": "Full redesign: black lacquered armor with red lacing, gold details, deer-antler kabuto, pale prayer beads, and Tonbokiri with one leaf-shaped blade and a blunt rear cap. One weapon, two hands, no extra limbs.",
        "routes": routes,
        "voice_pitch_scale": 0.88,
        "historical_references": [
            "https://online.bunka.go.jp/heritages/detail/210439",
            "https://www.pref.shizuoka.jp/kankosports/bunkageijutsu/bunkazai/1002825/1041003/1041888/1004969/1020948.html",
        ],
        "assets": inventory,
        "acceptance": "Whole-figure registration and measured support landmarks replace equal grid cuts; existing component contours exclude neighbouring figures. Original PNG pixels are unchanged. The merged special sheet is superseded by v17. Live gameplay and human audio acceptance are separate.",
        "pending_replacements": pending,
    }
    (ROOT / "docs" / "character-assets-v16.json").write_text(json.dumps(asset_record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Registered {len(actors)} Tadakatsu sheets ({sum(item['frames'] for item in inventory)} frames).")
    if pending:
        print("Pending original-canvas repairs: " + ", ".join(pending))


if __name__ == "__main__":
    main()
