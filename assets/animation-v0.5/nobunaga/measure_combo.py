"""Read-only alpha and gold-shoe measurements; never writes image pixels."""
import hashlib, json
from pathlib import Path
from PIL import Image

path = Path(__file__).with_name('combo.png')
image = Image.open(path).convert('RGBA')
pixels = image.load()
frames = []
for index in range(12):
    x0 = (index % 4) * 384
    y0 = round((index // 4) * image.height / 3)
    x1 = x0 + 384
    y1 = round((index // 4 + 1) * image.height / 3)
    visible = []
    edge = 0
    soles = [{}, {}]
    for y in range(y0, y1):
        for x in range(x0, x1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 32:
                visible.append((x - x0, y - y0))
                if x in (x0,x1-1) or y in (y0,y1-1): edge += 1
            if y-y0 > 220 and alpha > 210 and red > 85 and green > 55 and blue < green * 0.7 and green < red * 0.95:
                side = 0 if x-x0 < 192 else 1
                soles[side].setdefault(y-y0, []).append(x-x0)
    contacts = []
    for side in soles:
        rows = [y for y, xs in side.items() if len(xs) >= 4]
        bottom = max(rows)
        xs = side[bottom]
        contacts.append([round((min(xs)+max(xs))/2, 1), bottom])
    frames.append({'index':index, 'bbox_alpha_gt32':[min(p[0] for p in visible), min(p[1] for p in visible), max(p[0] for p in visible), max(p[1] for p in visible)], 'edge_pixels_alpha_gt32':edge, 'left_sole':contacts[0], 'right_sole':contacts[1]})
report = {'file':'combo.png','width':image.width,'height':image.height,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'row_starts':[0,341,683], 'alpha_zero_pixels':sum(a==0 for a in image.getchannel('A').getdata()), 'frames':frames}
path.with_name('measurements.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print(json.dumps(report, separators=(',', ':')))
