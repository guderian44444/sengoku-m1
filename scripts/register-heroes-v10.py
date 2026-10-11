"""Measure original PNG alpha only; no image pixels are changed."""
import json, shutil, statistics
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = json.loads((ROOT / 'assets/animation-v0.10/hero-prompts.json').read_text(encoding='utf-8'))
actors = {}

def cuts(counts, sections):
    size = len(counts)
    result = [0]
    for index in range(1, sections):
        expected = index * size / sections
        radius = int(size / sections * .18)
        candidates = range(max(result[-1]+15, int(expected)-radius), min(size-15,int(expected)+radius))
        result.append(min(candidates, key=lambda at: sum(counts[max(0,at-2):at+3]) + abs(at-expected)*.08))
    return result + [size]

for item in source['outputs']:
    name = item['id']
    hero, sheet = name.split('-')
    path = Path(item['file'])
    image = Image.open(path).convert('RGBA')
    alpha = image.getchannel('A')
    assert alpha.getextrema()[0] == 0, name+' requires transparent alpha'
    mask = alpha.point(lambda a: 255 if a > 90 else 0)
    width, height = image.size
    ys = cuts([sum(mask.crop((0,y,width,y+1)).histogram()[1:]) for y in range(height)], 6)
    regions, feet, heights = {}, [], []
    for row in range(6):
        top,bottom=ys[row:row+2]
        xs=cuts([sum(mask.crop((x,top,x+1,bottom)).histogram()[1:]) for x in range(width)],6)
        for col in range(6):
            left,right=xs[col:col+2]
            box=mask.crop((left,top,right,bottom)).getbbox()
            assert box and box[3]-box[1] > 30, (name,row,col,box)
            x0,y0,x1,y1=box
            # Use the rear sole as support; near-horizontal/prone cells use their contact centre.
            line=mask.crop((left,top+y1-5,right,top+y1))
            foot_x=[x for x in range(right-left) if line.crop((x,0,x+1,5)).getbbox()]
            assert foot_x
            fx=statistics.median(foot_x)
            if sheet!='reactions' or row not in [2,3]: fx=statistics.median(foot_x[:max(1,len(foot_x)//2)])
            feet.append([round(left+fx,1),top+y1-1])
            regions[str(row*6+col)]=[left,top,right-left,bottom-top]
            heights.append(y1-y0)
    body_height=statistics.median(heights[:6])
    unplanted=list(range(6)) if sheet=='combat' else (list(range(24,30)) if sheet=='skills' else list(range(12,24)))
    actors[name]={'target':'hero','hero':hero,'sheet':sheet,'columns':6,'rows':6,'feet_global':True,'feet':feet,'body_height':body_height,'regions':regions,'component_clip':True,'unplanted':unplanted}
    for relative in ['game/assets/v10','assets/animation-v0.10']:
        target=ROOT/relative/(name+'.png');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
    print(name, '36 frames',image.size,'body',body_height,'row cuts',ys)
result={'version':'0.10','measurement':'Original alpha, adaptive gutters, grounded contact points. Source PNG bytes retained.','actors':actors}
for relative in ['game/assets/v10/hero-registration.json','assets/animation-v0.10/hero-registration.json']:
    (ROOT/relative).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
assert len(actors)==12
