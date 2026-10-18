from pathlib import Path
import json, math
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'artifacts/basic36-nobunaga16-git-20261016/deliveries/basic36-nobunaga16-hires-20261016/nobunaga'
OUT=ROOT/'prototypes/nobunaga-repair-v36/patch-sheets'
OUT.mkdir(parents=True,exist_ok=True)
for clip,indices in [('grab_start',list(range(8))),('charge_release',[0,1,2,3,4,5,6,7,8,9,21,22]),('throw_reverse',[5,15])]:
    frames=json.loads((SOURCE/clip/'delivery-frames.json').read_text())
    meta=json.loads((SOURCE/clip/'layers-visible-manifest.json').read_text()) if clip!='throw_reverse' else [{'grip_art_px':f['grip_art_native_px']['right']} for f in frames]
    columns=min(4,len(indices))
    sheet=Image.new('RGB',(400*columns,440*math.ceil(len(indices)/columns)),'#565656');draw=ImageDraw.Draw(sheet);rows=[]
    for tile,i in enumerate(indices):
        grip=meta[i]['grip_art_px'];box=[round(grip[0])-200,round(grip[1])-200,round(grip[0])+200,round(grip[1])+200]
        # Actor-only source keeps charge FX out of patch generation.
        actor_path=SOURCE/clip/'layers-native/actor'/f'{i:03}.png'
        if not actor_path.exists():actor_path=SOURCE/frames[i]['master']['path']
        im=Image.open(actor_path).convert('RGBA').crop(box)
        x,y=(tile%columns)*400,(tile//columns)*440
        sheet.paste(im,(x,y),im);draw.text((x+12,y+410),f'{clip} FRAME {i:03}',fill='white')
        rows.append({'frame':i,'tile':tile,'native_box':box,'canvas_box':[x,y,x+400,y+400],'source':str(actor_path.relative_to(SOURCE))})
    sheet.save(OUT/f'{clip}-reference.png')
    (OUT/f'{clip}-map.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Prepared three original-pixel patch sheets')
