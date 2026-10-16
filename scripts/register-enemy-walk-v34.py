"""Expose all twelve existing soldier walk drawings without editing source pixels."""
import argparse
import hashlib
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "artifacts/integration-v30/python-deps"))
v19 = runpy.run_path(str(ROOT / "scripts/register-enemies-v19.py"))
SOURCE = ROOT / "game/assets/v19/enemies/soldier-walk-cycle.png"
OUTPUT = ROOT / "game/assets/v34/enemies/registration.json"
# Source-space spear-hand positions also support Oda's separately drawn shield.
GRIPS = [[245,155],[579,155],[941,156],[1308,157],[246,510],[600,514],
         [943,510],[1301,513],[224,872],[574,875],[940,873],[1316,879]]


def build():
    image, _, _, parts = v19["components"](SOURCE, 4, 12)
    old = json.loads((SOURCE.parent / "registration.json").read_text(encoding="utf-8"))["actors"]["soldier-walk"]
    spec = {**old, "file":"../../v19/enemies/soldier-walk-cycle.png", "columns":12,
            "source_indices":list(range(12)), "body_heights":[310] * 12,
            "regions":{}, "feet":[], "shield_grips":GRIPS}
    spec.pop("foot_spans")
    for index, part in enumerate(parts):
        x0, y0, x1, y1 = part["box"]
        left, top = max(0,x0-3), max(0,y0-3)
        spec["regions"][str(index)] = [left, top, min(image.width,x1+3)-left, min(image.height,y1+3)-top]
        spec["feet"].append(part["feet"])
        assert image.getpixel(tuple(GRIPS[index]))[3] >= 80, (index, "Shield grip outside drawing")
    assert len({tuple(r) for r in spec["regions"].values()}) == 12
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == old["sha256"]
    for index, source_index in enumerate(old["source_indices"]):
        assert spec["feet"][source_index] == old["feet"][index]
        assert spec["regions"][str(source_index)] == old["regions"][str(index)]
    return {"version":"v34", "notes":"Twelve original v19 drawings, five ticks each; unchanged 60-tick full gait. No newly generated or duplicated frames.", "actors":{"soldier-walk":spec}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = build()
    if args.check:
        assert json.loads(OUTPUT.read_text(encoding="utf-8")) == result, "Run registration script"
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("ENEMY WALK V34 PASS: 12 original drawings, stable source scale and measured shield grips")
