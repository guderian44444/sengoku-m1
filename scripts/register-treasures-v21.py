"""Crop the three generated charms without repainting or changing alpha."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game/assets/v21/treasures"
SOURCE = ASSETS / "treasures-source.png"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


image = Image.open(SOURCE)
assert image.mode == "RGBA" and image.getchannel("A").getextrema() == (0, 255)
data = {
    "format": "sengoku-treasures-v21",
    "generator": "built-in image_gen",
    "source": SOURCE.name,
    "source_sha256": sha(SOURCE),
    "source_size": list(image.size),
    "prompt": "prompt.txt",
    "prompt_sha256": sha(ASSETS / "prompt.txt"),
    "processing": "Crop only. Alpha and pixels inside each crop are unchanged. Bounds use alpha >= 8 plus 8px padding to exclude near-transparent empty-background noise.",
    "items": {},
}
for index, (key, label, absorption) in enumerate([
    ("kongo", "金剛護符", 40), ("iron", "玄鐵護符", 75), ("mirror", "明鏡護符", 110)
]):
    left, right = index * image.width // 3, (index + 1) * image.width // 3
    cell = image.crop((left, 0, right, image.height))
    box = cell.getchannel("A").point(lambda alpha: 255 if alpha >= 8 else 0).getbbox()
    assert box is not None
    x0, y0 = max(0, box[0] - 8), max(0, box[1] - 8)
    x1, y1 = min(cell.width, box[2] + 8), min(cell.height, box[3] + 8)
    region = (left + x0, y0, left + x1, y1)
    crop = image.crop(region)
    output = ASSETS / f"{key}.png"
    crop.save(output)
    data["items"][key] = {
        "name": label, "file": output.name, "absorption": absorption,
        "source_region_xywh": [region[0], region[1], crop.width, crop.height],
        "size": list(crop.size), "display_height": 56, "sha256": sha(output),
    }
    assert Image.open(output).tobytes() == image.crop(region).tobytes()
(ASSETS / "registration.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("PASS: three crop-only RGBA charms, original alpha preserved, source and output hashes recorded")
