from pathlib import Path
import json,shutil,zipfile,hashlib
P=Path(__file__).resolve().parents[1];D=P/'delivery/review_index';D.mkdir(exist_ok=True)
idx=json.load(open(P/'ACTION_INDEX.json'));html=['<!DOCTYPE html><meta charset="utf-8"><title>家康16招審圖</title><style>body{background:#2f353d;color:#eee;font:16px sans-serif;max-width:1100px;margin:auto}img{max-width:100%}section{padding:15px;border-bottom:1px solid #768}</style><h1>家康新版16招審圖</h1><p>全部152px站立等效尺規。兩次頭槌均使用選定第二下，600ms、獨立輸入與命中。以下正常速度與代表圖；完整來源另存，尚未原生遊戲驗收。</p>'];md=['# 家康新版16招審圖','正常速度與代表圖；完整來源不在本審圖包。']
for a in idx:
 n=a['action'];sub=D/n;sub.mkdir(exist_ok=True)
 for f in ['normal.gif','representative.png']:shutil.copy(P/'preview_152px'/n/f,sub/f)
 html.append(f'<section><h2>{n}</h2><p>{a["description_zh"]} {a["count"]}播放格 / {a["duration_ms"]}ms</p><img src="{n}/normal.gif"><details><summary>代表圖</summary><img src="{n}/representative.png"></details></section>');md.extend([f'## {n}',a['description_zh'],f'{a["count"]}播放格 / {a["duration_ms"]}ms',f'![代表圖]({n}/representative.png)',f'[正常動畫]({n}/normal.gif)',''])
(D/'開啟我_家康16招.html').write_text('\n'.join(html));(D/'招式說明.md').write_text('\n'.join(md));shutil.copy(P/'交接文件.md',D/'完整包交接說明.md')
results=[]
for small,name,folder in [(False,'Ieyasu_NewCombat_16Actions_Candidate_20261015_06.zip',P),(True,'Ieyasu_16Actions_Review_Index_20261015_06.zip',D)]:
 out=P/'delivery'/name;files=[p for p in folder.rglob('*') if p.is_file() and (small or ('delivery' not in p.relative_to(P).parts and '__pycache__' not in p.parts and not (any(t.startswith('before_') for t in p.parts) and p.suffix in ['.gif','.jpg']) and not (p.suffix=='.png' and 'contact' in p.name) and not ('preview_152px' in p.parts and p.name.startswith('frame_'))))]
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,6) as z:
  for p in sorted(files):z.write(p,('家康16招審圖/' if small else 'Ieyasu_NewCombat_16Actions/')+str(p.relative_to(folder)))
 with zipfile.ZipFile(out) as z:
  assert z.testzip() is None
  for p in files:assert z.read(('家康16招審圖/' if small else 'Ieyasu_NewCombat_16Actions/')+str(p.relative_to(folder)))==p.read_bytes()
 if small:assert out.stat().st_size<9000000
 results.append(dict(path=str(out),bytes=out.stat().st_size,files=len(files),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),crc_ok=True,byte_compare_ok=True))
(P/'delivery/package-verification.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
