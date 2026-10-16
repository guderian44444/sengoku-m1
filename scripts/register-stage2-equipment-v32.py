"""Register Oda banner cloth overlays against existing poses; preserve source pixels."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "artifacts/integration-v30/python-deps"))
from scipy.ndimage import binary_closing, label
from scipy.spatial import ConvexHull

SOURCE = ROOT / "game/assets/v19/enemies"
OUTPUT = ROOT / "game/assets/v32/enemies"
registration = json.loads((SOURCE / "registration.json").read_text(encoding="utf-8"))
result = {"version": "v32", "equipment_file": "equipment.png", "shield_region": [223, 192, 353, 718],
          "banner_region": [800, 140, 500, 720], "flag_cloth": {}, "sources": {}}
result["shield_grips"] = {
    "oda:soldier:walk": [[245,155],[941,156],[1308,157],[600,514],[224,872],[574,875]],
    "oda:soldier:idle": [[245,155]],
    "oda:soldier:hurt": [[210,347],[672,414],[1070,400]],
    "oda:soldier:struggle": [[234,877],[648,934],[1055,891]],
    "oda:soldier:spear_thrust": [[205,370],[612,381],[1080,364],[340,888],[724,880],[1105,885]],
    "oda:soldier:spear_sweep": [[349,240],[940,258],[379,625],[974,633],[390,1040],[946,1008]],
    "oda:soldier:spear_butt": [[329,235],[909,197],[391,593],[1027,602],[460,995],[975,988]],
}
for key, grips in result["shield_grips"].items():
    spec = next(v for v in registration["actors"].values() if v["key"] == key.replace("oda:", "imagawa:"))
    assert len(grips) == spec["columns"] * spec["rows"]
    image = Image.open(SOURCE / spec["file"]).convert("RGBA")
    assert all(image.getpixel(tuple(grip))[3] >= 80 for grip in grips), key
for key, spec in registration["actors"].items():
    if not spec["key"].startswith("imagawa:flag:"):
        continue
    path = SOURCE / spec["file"]
    result["sources"][spec["file"]] = hashlib.sha256(path.read_bytes()).hexdigest()
    image = np.array(Image.open(path).convert("RGBA"))
    poses = []
    for index in range(spec["columns"] * spec["rows"]):
        x, y, w, h = spec["regions"][str(index)]
        crop = image[y:y+h, x:x+w].astype(float)
        mask = (crop[:, :, 2] > crop[:, :, 0] * 1.5) & (crop[:, :, 2] > crop[:, :, 1] * 1.15) & (crop[:, :, 3] > 80)
        components, count = label(binary_closing(mask, iterations=3))
        sizes = np.bincount(components.ravel()); sizes[0] = 0
        assert count and sizes.max() > 100, (key, index, "missing cloth")
        rows, cols = np.nonzero(components == sizes.argmax())
        points = np.column_stack((cols, rows)).astype(float)
        hull = points[ConvexHull(points).vertices]
        center = points.mean(axis=0)
        # Extend two source pixels to cover the old blue anti-alias edge.
        direction = hull - center
        hull += direction / np.linalg.norm(direction, axis=1)[:, None] * 2
        covariance = np.cov(points.T)
        _, axes = np.linalg.eigh(covariance)
        vertical = axes[:, -1]
        if vertical[1] < 0: vertical *= -1
        horizontal = np.array([vertical[1], -vertical[0]])
        projected = np.column_stack(((hull-center) @ horizontal, (hull-center) @ vertical))
        uv = (projected-projected.min(axis=0)) / np.ptp(projected, axis=0)
        poses.append({"polygon": (hull + [x, y]).round(2).tolist(), "uv": uv.round(5).tolist()})
    result["flag_cloth"][spec["key"].replace("imagawa:", "oda:")] = poses
result["equipment_sha256"] = hashlib.sha256((OUTPUT / result["equipment_file"]).read_bytes()).hexdigest()
(OUTPUT / "registration.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print("Registered", sum(map(len, result["flag_cloth"].values())), "Oda flag poses; source sheets unchanged")
