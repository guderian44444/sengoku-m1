from __future__ import annotations

import json
import hashlib
from pathlib import Path

from PIL import Image


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


def main() -> None:
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
            for index in range(columns * rows):
                column, row = index % columns, index // columns
                x0, x1 = column * width // columns, (column + 1) * width // columns
                y0, y1 = row * height // rows, (row + 1) * height // rows
                alpha = image.getchannel("A").crop((x0, y0, x1, y1))
                visible = alpha.point(lambda value: 255 if value > 24 else 0).getbbox()
                assert visible is not None and visible[2] - visible[0] > 80 and visible[3] - visible[1] > 80, f"{filename}: empty cell {index}"
                regions[str(index)] = [x0 + visible[0], y0 + visible[1], visible[2] - visible[0], visible[3] - visible[1]]
                feet.append([(x0 + x1) // 2, y1 - 6])
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
            inventory.append({"sheet": f"v16_{clip}", "file": filename, "columns": columns, "rows": rows, "frames": frame_count, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
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
        "acceptance": "Atlas registration, hashes, and source routes recorded. Live gameplay, visual timing, and human audio acceptance were not performed.",
    }
    (ROOT / "docs" / "character-assets-v16.json").write_text(json.dumps(asset_record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Registered {len(actors)} Tadakatsu sheets ({sum(item['frames'] for item in inventory)} frames).")


if __name__ == "__main__":
    main()
