from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
P=Path(__file__).resolve().parent
T=P.parents[1]/'tadakatsu_delivery_20261015_forward/main/light_1/body_canvas_01.png'
t=Image.open(T).convert('RGBA')
m=Image.open(P.parent/'charge_ready/body_01.png').convert('RGBA')
scale=163/457
W,H=840,400;floor=318
out=Image.new('RGB',(W,H),(40,44,48));font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',18)
# Tadakatsu composited source is kept at exact production pixel size, shifted only.
out.paste(t,(-2,floor-296),t)
s=m.resize((round(m.width*scale),round(m.height*scale)),Image.Resampling.LANCZOS)
out.paste(s,(round(600-277*scale),round(floor-474*scale)),s)
d=ImageDraw.Draw(out);d.line((40,floor,800,floor),fill=(130,140,148),width=1)
# Match cranial crown, exclude horns and crest ornament.
head=floor-163;d.line((200,head,670,head),fill=(207,170,90),width=1)
d.text((120,24),'本多忠勝（既有素材原尺寸）',font=font,fill=(235,235,235));d.text((510,24),'顯如03（比照本多身高）',font=font,fill=(235,235,235))
d.text((65,355),'同一地面；頭頂至腳底約163px，不計鹿角。屈膝姿勢不逐格拉高。',font=font,fill=(210,212,214))
out.save(P/'tadakatsu-kennyo-scale.jpg',quality=93)
contract={'target_anatomical_standing_height_px':163,'tadakatsu_reference':str(T),'tadakatsu_source_crown_y':120,'tadakatsu_source_sole_y':497,'tadakatsu_source_scale':160/370,'horns_excluded':True,'kennyo_ready_source_crown_y':17,'kennyo_ready_source_sole_y':474,'kennyo_ready_scale':scale,'rule':'Measure cranial crown to soles for neutral reference only. Preserve per-source head, torso, bone proportions across every action. Never rescale crouch/air frames by alpha bbox height. Root translation is separate.'}
(P/'scale-contract.json').write_text(json.dumps(contract,indent=2))
