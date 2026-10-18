from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,zipfile
P=Path(__file__).resolve().parents[1];D=P/'walk'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=Path('/workspace/scratch/98b7ec868bfb/hideyoshi_newspec_20261015')
(P/'idle/source_metadata.json').write_bytes((old/'reference/shared_ready/metadata.json').read_bytes())
body=Image.open(P/'idle/body_canvas_00.png').convert('RGBA');hand=Image.new('RGBA',body.size);hand.alpha_composite(body.crop((166,157,191,177)),(166,157));hand.save(P/'idle/hand_occlusion_00.png')
metadata={'character':'hideyoshi','action':'idle','status':'approved_existing_asset_registered','frame_count':1,'loop':True,'duration_ms':1000,'head_scale':.95,'standing_ruler_px':150,'origin_canvas':[185,253],'source':'hideyoshi_newspec_20261015/reference/shared_ready','source_is_existing_approved':True,'visual_modified':False,'frame':{'index':0,'duration_ms':1000,'body':'body_canvas_00.png','weapon':'weapon_00.png','hand_occlusion':'hand_occlusion_00.png','composite':'composite_00.png','feet_canvas':{'left':[150,250],'right':[218,250]},'grip_canvas':[179.625,167.125],'weapon_angle_deg':120,'layer_order':['body','weapon','hand_occlusion']},'sha256':{n:sha(P/'idle'/n) for n in ['body_canvas_00.png','weapon_00.png','composite_00.png']},'note':'Canonical composite byte-for-byte copy. Source rendering metadata archived as source_metadata.json; no idle redraw or tween.'}
(P/'idle/metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
meta=json.loads((D/'metadata.json').read_text());meta['quality_notes']=[s.replace('Eight generated whole-body poses','Eight original-resolution generated whole-body poses') for s in meta['quality_notes']];meta['world_motion']['support_intervals']=[{'frames':[0,1,2,3],'foot':'far'},{'frames':[4,5,6,7],'foot':'near'}];(D/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
manifest={'character':'hideyoshi','head_scale':.95,'standing_ruler_px':150,'scope':'idle registration, approved portrait crop and walk candidate only','status':'walk_pending_user_approval','idle':'idle/metadata.json','portrait':'portrait/metadata.json','walk':'walk/metadata.json','review_gif':'walk/hideyoshi_walk_review.gif','inplace_gif':'walk/hideyoshi_walk_inplace.gif','world_gif':'walk/hideyoshi_walk_world.gif','same_scale_comparison':'walk/qa/idle_walk_same_scale.png','contact':'walk/qa/idle_walk_same_scale_contact.png','source_used':list(meta['source_info']),'source_not_used':['walk_a_initial_undersize.png','pair_2.png'],'existing_16_actions_unchanged':True,'game_runtime_integrated':False}
(P/'review_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(P/'README.md').write_text('''# 秀吉基本動作候選：walk\n\n只登錄核准共同 idle、裁核准肖像，製作 walk 候選。其餘八個基本動作等待使用者確認後才處理。沒有變更既有16招、審閱站或 Git。\n\n- walk：8個原始完整姿勢，960ms 循環；前半遠側腳承重，後半近側腳承重。普通行走無 FX。\n- 原始人物有效高度869–953px。每次官方 imagegen 都直接參照核准身份原圖及完整母圖，沒有用新小格反覆生成。新增高解析細節限衣褶、甲片線條及行走姿勢，不新增服裝裝飾。\n- 頭部依頸部接點局部95%；固定站高尺規150px，以同向頭胸量體校準原圖，不逐格以人物外框等高。保留屈膝/抬腳自然高度差。\n- 人物、刀、手部遮擋為透明 RGBA 獨立圖層，圖層順序與握點、武器角度、腳點、root、逐格時長記於 walk/metadata.json。\n- 原地貼圖與 world 位移曲線分開。世界預覽每圈重設位置只是審閱，不應把重設當成遊戲退步。\n- idle/composite_00.png 與核准共同 idle 逐 byte 相同；肖像只裁圖，沒有另畫。\n\n## 審閱\n\nhideyoshi_walk_review.gif 直接並列核准戰鬥 idle 與同尺度 walk。qa/idle_walk_same_scale_contact.png 為逐格對照。另附純原地 GIF 與世界位移 GIF。\n\n本輪已逐格檢查臉/衣裝/色調、交替腿路徑、透明邊緣、握點與刀層；GIF 解碼驗證8格、960ms與loop。尚未接入正式遊戲，這是待使用者確認的候選。\n\n## 來源與重建\n\n保留原始生成PNG、head95前來源與最終一次縮小前人物/手遮擋層。scripts/build_walk.py可重建候選；scripts/register.py登錄idle與包裝。原始來源直接參照reference/approved_identity_original.png與reference/approved_full_mother.png。\n''')
# Verify all currently approved combat assets remain present, record read-only hashes.
rm=json.loads((old/'review_manifest.json').read_text());checks={}
for a in rm['actions']:
 for key in ['gif','representative','metadata']:
  f=Path('/workspace/scratch/98b7ec868bfb')/a[key];checks[a['id']+'/'+key]=sha(f)
(P/'existing_combat_readonly_sha256.json').write_text(json.dumps(checks,indent=2))
# Package only candidate and sources used. Unselected generated studies remain on disk, excluded.
exclude={'walk_a_initial_undersize.png','pair_2.png','pair_1.png_unused','cross_3_visible.jpg'}
z=P/'hideyoshi_idle_walk_candidate_head95.zip'
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as out:
 for f in sorted(P.rglob('*')):
  if f.is_file() and f!=z and f.name not in exclude and not f.name.endswith('.zip') and not f.name.startswith('library_'):
   out.write(f,str(f.relative_to(P.parent)))
print(z,z.stat().st_size)
