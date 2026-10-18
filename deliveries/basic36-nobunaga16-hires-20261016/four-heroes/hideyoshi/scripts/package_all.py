from pathlib import Path
import json,zipfile,hashlib
P=Path(__file__).resolve().parents[1];A=['walk','run','hurt','stunned','jump','launched','down','recovering','victory']
audit=json.loads((P/'technical_audit.json').read_text());assert audit['technical_pass'];manifest={'character':'hideyoshi','scope':'Nine basic-action candidates; user artwork approval pending','status':'nine_candidates_ready_for_review','head_scale':.95,'standing_ruler_px':150,'frame_count_total':56,'idle':'idle/metadata.json','portrait':'portrait/metadata.json','technical_audit':'technical_audit.json','existing_16_actions_unchanged':True,'game_runtime_integrated':False,'actions':{}}
library={}
for act in A:
 D=P/act;m=json.loads((D/'metadata.json').read_text());manifest['actions'][act]={'metadata':act+'/metadata.json','gif':act+f'/hideyoshi_{act}_review.gif','version':m['version'],'status':'candidate_pending_user_review','frame_count':m['frame_count'],'duration_ms':m['duration_ms'],'loop':m['loop']}
 lm=P/'library_manifest.json' if act=='walk' else D/('library_manifest_v2.json' if act=='run' else 'library_manifest.json')
 if lm.exists():library[act]=[{k:r.get(k) for k in ['library_file_id','file_name','current_version_number','mime_type']} for r in json.loads(lm.read_text()) if r.get('status')=='succeeded' and r.get('mime_type')!='application/zip']
(P/'review_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(P/'library_catalog.json').write_text(json.dumps(library,ensure_ascii=False,indent=2))
readme='''# 秀吉九組基本動作候選（頭95%、站高尺規150px）

本包共九組、56格，均為待使用者審閱的候選；核准戰鬥 idle 和既有16招保持不變，尚未接入遊戲。

## 動作與版本
'''
for a,v in manifest['actions'].items():readme+=f"- {a}: {v['frame_count']} 格 / {v['duration_ms']}ms / loop={v['loop']} / {v['version']}\n"
readme+='''
## 近期修訂
- jump：10格900ms，地面230ms蓄勢，前傾屈膝→伸髖蹬地；上升和頂點軀幹接近直立，下降才準備落地。
- launched：6格500ms，加速離地、後仰及四肢慣性甩開；world後飛210px、最高105px；末格接down。
- down：落地接觸、壓縮、反作用、靜止共4格620ms；可死亡停在第3格（零起算）。
- run v2：6格480ms，一圈左右各一步。2/5加入髖下passing，保留前傾3/4側視。上半身由原生高解析contact合成，下半身採原生passing；官方imagegen只修腰甲下小接縫，僅局部遮罩採用生成結果。頭胸與contact的遊戲縮尺相同，遮罩外原始像素不變。

## 檔案與使用
- 每組 metadata.json 提供逐格時長、root、腳點、握點、武器角度、圖層前後順序、loop與位移。frames/內 body、weapon、hand_occlusion 是獨立透明RGBA；composite可作渲染參考。
- 圖層順序：body → weapon → hand_occlusion。hand_occlusion僅放實際遮住武器的手部像素，部分idle遮層很小是正常的。
- root/world位移與預覽位移分開；PNG是角色局部座標，勿重複套用位移。GIF為審閱方便可能重播；遊戲是否循環以metadata.loop為準。
- run世界位移每圈134px；walk每圈位移見metadata。非循環動作的GIF重播回到首格，不代表遊戲中倒退或自動復活。
- launched末格與down首格完全同圖層；down末格與recovering首格完全同圖層。銜接時保留角色當前world位置。
- idle/composite_00.png是核准合成圖逐byte副本。idle原始登錄PNG皆保留；metadata引用 *_exact_00.png 作精確三層輸出，只重新切分手部36像素，最終視覺不變。
- 肖像只由核准圖裁切，沒有另畫。普通基本動作全部沒有FX。

## 高解析來源與尺規
原始身份與完整戰鬥母圖在reference/。所有全身姿勢用官方imagegen直接參照原圖；原始PNG完整保留。生成時只增加高解析衣褶與既有甲片線條，不加裝飾。人物有效高度或橫躺長軸至少600px。沒有由小遊戲圖反覆生成、全身鏡像換腳或光流補格。
各姿勢按頭胸及肢體量體校準，不以人物外框等高；保留蹲下、跳躍和倒地的姿勢高度差。頭部局部95%，人物保留高解析到最終一次遊戲尺寸縮小。run高解析合成只放大原生上半身至共同組裝畫布，最後才縮至遊戲尺寸。

## 技術驗證
technical_audit.json記錄56格三層重組全相同、透明邊界無裁切、GIF格數/總時長一致、idle與倒地銜接，以及既有16招48個檔案雜湊未變。這是檔案與像素驗證，不等於遊戲實測或使用者已批准動畫。

## 兩個版本的包
- full_highres：保留採用的原始PNG、縮小前素材、參考母圖、三層逐格圖、metadata、審閱圖與腳本。未採用的研究稿不混入正式來源清單。
- runtime_review：僅含三層逐格圖、metadata、核准idle/肖像、武器來源與審閱GIF/PNG，便於整合。高解析來源欄位仍保留，但原母圖只在完整包內。
本次完整包與輕量包包含idle精確圖層修補，取代早前單組草稿ZIP作為最新技術交付。
'''
(P/'README.md').write_text(readme)
common=[P/n for n in ['README.md','review_manifest.json','technical_audit.json','library_catalog.json','existing_combat_readonly_sha256.json']]+[f for folder in ['idle','portrait'] for f in (P/folder).glob('*') if f.is_file()]+[P/'reference/sword_uchigatana.png']
full=set(common);light=set(common)
for act in A:
 D=P/act;m=json.loads((D/'metadata.json').read_text());used=set(m['source_info'])
 if act=='run':used.update(['compact_passing_near.png','compact_passing_far.png','assembled_passing_near.png','assembled_passing_far.png','seam_passing_near_generated.png','seam_passing_far_generated.png'])
 for f in D.rglob('*'):
  if not f.is_file() or f.name.startswith('library_manifest') or '__pycache__' in f.parts:continue
  rel=f.relative_to(D)
  if rel.parts[0]=='source' and f.suffix.lower()=='.png' and f.name not in used:continue
  full.add(f)
  if rel.parts[0]=='frames' or f.name in ['metadata.json','build_config.json'] or (len(rel.parts)==1 and f.suffix=='.gif') or (rel.parts[0]=='qa' and (f.name.startswith('idle_') or f.name in ['validation.json','technical_validation.json','run_six_frames_numbered.png','contact_anatomy_trace.png','highres_assembly_provenance.json','seam_patch_provenance.json'])):light.add(f)
full.update(f for f in (P/'reference').glob('*') if f.is_file());full.update(f for f in (P/'scripts').glob('*.py'))
checks={}
for label,files in [('full_highres',full),('runtime_review',light)]:
 z=P/f'hideyoshi_nine_base_head95_{label}.zip'
 with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as out:
  for f in sorted(files):out.write(f,str(f.relative_to(P.parent)))
 with zipfile.ZipFile(z) as q:assert q.testzip() is None
 checks[label]={'path':str(z),'bytes':z.stat().st_size,'sha256':hashlib.sha256(z.read_bytes()).hexdigest(),'file_count':len(files)}
(P/'package_manifest.json').write_text(json.dumps(checks,indent=2));print(json.dumps(checks,indent=2))
