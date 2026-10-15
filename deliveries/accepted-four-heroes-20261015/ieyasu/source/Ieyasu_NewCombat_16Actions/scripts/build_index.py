from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,math
P=Path(__file__).resolve().parents[1];O=P/'preview_152px';O.mkdir(exist_ok=True);catalog=[]
zh={'light_1':'第一段：前踏斜橫斬，接觸推人後回正。','light_2':'第二段：肩後蓄勢反掃，保留前踏位移。','light_3':'第三段：沉肩轉髖大掃，命中擊飛。','heavy':'普通重手：收刀、分段拔刀後水平前突；刀鞘留腰側。','charge_ready':'一閃蓄勢：右手握柄、左手鞘口，刀鞘朝後，慢收刀並屈膝壓低。','charge_hold':'一閃保持：完全入鞘、低姿待發；示範保持400ms，遊戲由放鍵決定。','charge_release':'一閃施放：瞬間拔刀、三步前衝，關鍵踏步各100ms；末段水平前指停留；大型劍氣前向穿透、沿路敵人倒地，殘影／劍氣／量測敵人皆獨立層。','air_light':'空中輕手：起跳後主武近距離揮斬，下降落地。','air_heavy':'空中重手：跳起向前一步52px、深下斬後低馬步落地，回收不滑回原點。','grab_start':'抓起：收刀安全收納、伸手閉握、拉近。','grab_hold':'抓握保持：固定衣領／上臂接點。','grab_hit_1':'第一頭槌：採用已選第二下的同套姿勢與600ms節奏；獨立第一下輸入與命中。','grab_hit_2':'第二頭槌：與第一下共用已選姿勢，600ms；獨立第二下輸入與命中，不自動兩連擊。','throw_forward':'前摔：轉髖前拋，轉髖後鬆手，被投者獨立飛出。','throw_reverse':'反摔：轉背上肩、反向過肩釋放，最後左向站穩。','dash_heavy':'跑步重手：末步前掃、制動回站。'}
G=json.load(open(P/'grabs/registration.json'))
for name,desc in zh.items():
 d=O/name;d.mkdir(exist_ok=True);gs=name in G
 if gs:meta=G[name];frames=meta['frames'];ds=[q['duration_ms'] for q in frames];factor=1;offset=(205-150,365-220);base=P/'grabs'/name
 else:meta=json.load(open(P/'actions'/name/'metadata.json'));frames=meta['frames'];ds=[q['duration_ms'] for q in frames];factor=1;first=frames[0].get('root_world',frames[0].get('root_preview'));offset=(205-first[0],365-first[1]);base=P/'actions'/name
 cw=640 if name.startswith('charge_') else 560
 if name.startswith('charge_'):offset=(0,0)
 out=[];regs=[]
 for i,q in enumerate(frames):
  if gs:
   body=Image.open(base/f'body_{i:02}.png');w=Image.open(base/f'weapon_{i:02}.png');proxy=Image.open(base/f'proxy_{i:02}.png');comp=Image.new('RGBA',body.size);comp.alpha_composite(proxy);comp.alpha_composite(w);comp.alpha_composite(body)
   if name.startswith('throw') and i>=6:comp.alpha_composite(proxy)
  else:comp=Image.open(base/(f'preview_fx_{i:02}.png' if name.startswith('charge_') else f'composite_{i:02}.png'))
  trans=Image.new('RGBA',(cw,400));small=comp.resize((round(comp.width*factor),round(comp.height*factor)),Image.Resampling.LANCZOS);trans.alpha_composite(small,(round(offset[0]),round(offset[1])));trans.save(d/f'frame_{i:02}.png')
  bg=Image.new('RGB',(cw,400),(47,53,61));bg.paste(trans,mask=trans.getchannel('A'));draw=ImageDraw.Draw(bg);draw.line((0,366,cw,366),fill=(80,86,93));draw.text((12,10),f'IEYASU {name} | 152 px / {sum(ds)} ms',fill='white');draw.text((12,382),f'{i+1:02} / {len(frames)} | candidate - independent layers',fill=(180,190,200));out.append(bg)
  regs.append(dict(frame=i,display_scale=factor,translation=list(offset),duration_ms=ds[i],source_metadata_frame=i,root_world=[205,365] if gs else [q.get('root_world',q.get('root_preview'))[0]+offset[0],q.get('root_world',q.get('root_preview'))[1]+offset[1]]))
 for suffix,m in [('normal',1),('slow',3)]:out[0].save(d/f'{suffix}.gif',save_all=True,append_images=out[1:],duration=[x*m for x in ds],disposal=2,**({} if (name.startswith('throw') or name=='air_heavy' or name.startswith('charge_')) else {'loop':0}))
 representative=min(len(out)-1,3 if len(out)>3 else 0);out[representative].save(d/'representative.png');contact=Image.new('RGB',(cw*4,400*math.ceil(len(out)/4)),(47,53,61));[contact.paste(v,((i%4)*cw,(i//4)*400)) for i,v in enumerate(out)];contact.save(d/'contact.png')
 r=dict(action=name,description_zh=desc,count=len(out),duration_ms=sum(ds),preview=f'preview_152px/{name}/normal.gif',representative=f'preview_152px/{name}/representative.png',source_metadata='grabs/registration.json' if gs else f'actions/{name}/metadata.json',display_height_px=152,frames=regs)
 json.dump(r,open(d/'display_registration.json','w'),indent=2,ensure_ascii=False);catalog.append(r)
json.dump(catalog,open(P/'ACTION_INDEX.json','w'),indent=2,ensure_ascii=False)
md=['# 家康新版16招候選素材','2026-10-15。全索引統一152px站立等效尺規、一般560×400畫布、根點初始x=205；一閃三段640×400、起始腳點x=120；地面y=365。此包未進遊戲驗收。','']
html=['<!DOCTYPE html><meta charset="utf-8"><title>家康新版16招候選</title><style>body{background:#2f353d;color:#eee;font:16px sans-serif;max-width:1200px;margin:auto}img{max-width:100%}.row{display:flex;flex-wrap:wrap}section{border-bottom:1px solid #657;padding:16px}</style><h1>家康新版16招候選</h1><p>統一152px站立等效尺規。正常速度／3倍慢速並列；未進遊戲驗收。灰色人形是獨立量測替身。</p>']
for r in catalog:
 n=r['action'];md += [f'## {n}',r['description_zh'],f"{r['count']}播放格，{r['duration_ms']}ms。",f"![代表圖]({r['representative']})",f"[正常動畫]({r['preview']}) · [慢速](preview_152px/{n}/slow.gif)",'']
 html += [f'<section><h2>{n}</h2><p>{r["description_zh"]} {r["count"]}播放格／{r["duration_ms"]}ms</p><div class="row"><div>正常<br><img src="preview_152px/{n}/normal.gif"></div><div>3倍慢速<br><img src="preview_152px/{n}/slow.gif"></div></div></section>']
(P/'招式文件.md').write_text('\n'.join(md));(P/'招式動畫索引.html').write_text('\n'.join(html))
