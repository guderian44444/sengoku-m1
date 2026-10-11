"""Read-only atlas pixel measurements. This script never changes image pixels."""
from pathlib import Path
import hashlib, json
from PIL import Image

root = Path(__file__).parent
report = {}
for path in sorted(root.glob('*/*.png')):
    image = Image.open(path).convert('RGBA')
    alpha = image.getchannel('A')
    assert image.size == (1536, 1024), path
    assert sum(value == 0 for value in alpha.getdata()) > 100000, path
    frames = []
    for index in range(12):
        x0, y0 = index % 4 * 384, (index // 4) * 1024 // 3
        y1 = (index // 4 + 1) * 1024 // 3
        cell = image.crop((x0, y0, x0+384, y1))
        pixels = cell.load()
        visible = [(x,y) for y in range(cell.height) for x in range(cell.width) if pixels[x,y][3] >= 128]
        contacts = []
        for left, right in ((0, 192), (192,384)):
            rows = {}
            for y in range(220,cell.height):
                xs = []
                for x in range(left, right):
                    r,g,b,a = pixels[x,y]
                    if a > 200 and r > 55 and g > 35 and b < g * .8 and g < r * .98:
                        xs.append(x)
                if len(xs) >= 4:
                    rows[y] = xs
            if rows:
                bottom = max(rows)
                contacts.append([round(sum(rows[bottom])/len(rows[bottom]),1),bottom])
            else:
                contacts.append(None)
        frames.append({'index':index,'bbox':[min(x for x,y in visible),min(y for x,y in visible),max(x for x,y in visible),max(y for x,y in visible)],'edge_alpha128':sum(x in (0,383) or y in (0,cell.height-1) for x,y in visible),'sole_gold':contacts})
    report[str(path.relative_to(root))] = {'size':list(image.size),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'alpha_zero':sum(value==0 for value in alpha.getdata()),'alpha_opaque':sum(value==255 for value in alpha.getdata()),'outer_edge_max':max([alpha.getpixel((x,0)) for x in range(1536)]+[alpha.getpixel((x,1023)) for x in range(1536)]+[alpha.getpixel((0,y)) for y in range(1024)]+[alpha.getpixel((1535,y)) for y in range(1024)]),'frames':frames}
(root/'alpha-foot-measurements.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
