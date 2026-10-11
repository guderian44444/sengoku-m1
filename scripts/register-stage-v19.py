"""Register imagegen RGBA pixels without repainting or resizing the generated sources."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "game/assets/v19/scenery"
NAMES = ["grass", "shrubs", "earth_low", "earth_high", "wood_rail", "bamboo_rail", "interior_rail", "screen", "cabinet"]
HEIGHTS = [62, 68, 45, 84, 72, 76, 74, 155, 150]
# Actual clear gutters in the generated source, not an assumed equal-sized grid.
COLUMNS = [0, 439, 831, 1254]
ROWS = [0, 421, 801, 1254]
BORDER_THEMES = {
    "bamboo": ["grass", "shrubs", "bamboo_rail"],
    "ridge": ["earth_low", "grass", "earth_high"],
    "village": ["wood_rail", "grass", "earth_low"],
    "gate": ["wood_rail", "earth_high", "grass"],
    "camp": ["bamboo_rail", "grass", "earth_low"],
    "courtyard": ["shrubs", "grass", "earth_low"],
    "chamber": ["interior_rail"],
}


def register():
    source = ART / "objects-source.png"
    with Image.open(source) as image:
        assert image.mode == "RGBA", "The built-in output must have genuine alpha"
        assert image.size == (COLUMNS[-1], ROWS[-1]), "Review extraction bounds after replacing a source"
        alpha = np.asarray(image)[:, :, 3]
    assert (alpha == 0).mean() > .50, "Transparent gaps around the generated objects must remain"
    frames = {}
    for index, name in enumerate(NAMES):
        left, right = COLUMNS[index % 3:index % 3 + 2]
        top, bottom = ROWS[index // 3:index // 3 + 2]
        ys, xs = np.where(alpha[top:bottom, left:right] > 128)
        assert len(xs) > 4000, f"Missing sprite {name}"
        x0, x1 = left + int(xs.min()) - 3, left + int(xs.max()) + 4
        y0, y1 = top + int(ys.min()) - 3, top + int(ys.max()) + 4
        assert left < x0 < x1 < right and top < y0 < y1 < bottom, f"Unsafe atlas crop: {name}"
        height = y1-y0-6
        assert height >= HEIGHTS[index], f"Do not upscale {name}"
        local_alpha = alpha[y0:y1, x0:x1]
        # Rails need real holes; both empty pixels and painted poles occur inside the crop.
        if "rail" in name:
            interior = local_alpha[height//4:height*3//4, (x1-x0)//6:(x1-x0)*5//6]
            assert (interior < 8).mean() > .25, f"Rail gaps must show the background: {name}"
        frames[name] = {
            "source": "objects-source.png", "region": [x0, y0, x1-x0, y1-y0],
            "anchor": [(x1-x0)/2, y1-y0-3], "body_height": height,
            "display_height": HEIGHTS[index], "footprint_depth": 34 if name == "screen" else (58 if name == "cabinet" else 0),
        }
    return frames


frames = register()
data = {
    "version": "0.19", "generator": "built-in image_gen.imagegen",
    "extraction": "Generated RGBA pixels are retained. Crops use inspected atlas gutters and acquire transparent filter padding at runtime.",
    "props": {name: frames[name] for name in ["screen", "cabinet"]},
    "borders": {name: frames[name] for name in NAMES[:7]},
    "border_themes": BORDER_THEMES,
    "backgrounds": {"courtyard": {"source": "courtyard.png", "horizon": .585}},
    "sources": {},
}
for source in sorted(ART.glob("*.png")):
    with Image.open(source) as image:
        data["sources"][source.name] = {"sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "size": list(image.size), "mode": image.mode}
(ART / "registration.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("PASS: v19 scenery registered: 7 transparent border groups, 2 furniture obstacles, 1 independent courtyard panorama; original pixels retained.")
