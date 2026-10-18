# 阿市新版17招素材交接

> 2026-10-15 後續：本機 runtime 已接入，請先讀 [接入記錄](COMBAT-V33.md)。下方保留友軍原始交付範圍。

## Git交付位置

- [既有阿市招式文件](combat-art-reference/characters/oichi.md)已填入17招代表圖、說明、採用版本與事件連結；[素材README](combat-art-reference/README.md)可進入。
- [原始ZIP](../deliveries/oichi-final-20261014/oichi_final_20261014.zip)：99,440,734 bytes，SHA256 `0207bf9c6ad7e0d634a92c490300f29f816a39b1688e573266285317120b57f8`；未重新壓縮。
- 解壓內容在 [prototypes/oichi-final-20261014](../prototypes/oichi-final-20261014/README.md)。人物／武器／效果PNG、metadata、manifest與重建來源均保持原始位元組。source-spec僅修正文件連結；[整合記錄](../deliveries/oichi-final-20261014/integration.json)明列原／新hash。
- 以 `python -X utf8 prototypes/oichi-final-20261014/verify_package.py` 驗包內hash及17招GIF時長；以 `python -X utf8 deliveries/oichi-final-20261014/verify_delivery.py` 驗原ZIP、逐檔搬入、事件／圖層與所有新增文件相對連結。Windows需UTF-8模式。
- 此次未修改game目錄，尚未接runtime。取消窗、判定、左右向碰撞、實體手把與遊戲內武器替換需接入後驗收。

## 入口與完成範圍

- [docs/combat-art-reference/oichi-final.md](combat-art-reference/oichi-final.md)：17招代表圖、正常速度GIF、動作說明及逐招metadata連結。
- [ACTION_MANIFEST.json](../prototypes/oichi-final-20261014/ACTION_MANIFEST.json)：唯一機器可讀選版表。每招的資料夾、實際播放格數、逐格時長加總及採用版本已核對。
- 此包是使用者本輪確認後的素材交付，不包含遊戲runtime接線、命中判定實作或原生遊戲測試。不得因文件稱「最終」就將所有JSON中的prototype標記解讀為已登錄。

## 放進專案

本次已將解壓內容放入 `prototypes/oichi-final-20261014/`；正式接入時再按專案資產規範搬入runtime位置及對應docs。先以分支提交供Codex整合，不自動覆蓋既有角色registry或已執行的遊戲腳本。若本包併入repository較深的目錄，保持docs與assets的相對路徑。主招式文件可連結到本包的oichi-final.md；不要以舊招式表替換本輪修訂。

## 播放與接點

1. 依ACTION_MANIFEST選招，不掃描資料夾挑「看起來最新版」的檔案。來源／重建中間檔不一定是採用幀。
2. 讀取該招metadata的frames與duration_ms。先以毫秒時間軸播放，最後再映射引擎tick；不同招可有3、4、5、6、8、9、10、13播放格。某些待機返回格是重複姿勢，不是全部唯一新畫。
3. 人物比例以148px站立等效尺規為預覽標準；正式縮放整個角色與其武器接點同乘一致倍率。禁止以每格透明外框高度各自填滿格子，蹲姿與跨步不能拉高。
4. root/foot、hand/grip、draw_fingertips或second_hand保留該JSON的座標空間；按來源裁切與scale換算。近戰melee_support_grip / bow_bash_support_hand並非拉弦手。
5. 分層順序依weapon_behind及hand前景遮罩處理。箭與特效是獨立物件，不能烘焙在人物層。示意受害者是灰色占位圖，正式替換敵人並保持抓取接點、放手事件及拋物線。
6. light1/2/3各自一次按鍵，完整收回共用ready；保留前踏位移，不往回滑。第三段命中才擊飛。heavy與charge_release的projectile_direction為[1,0]。
7. 空重採v3近中遠分散、較平與較遠；已取代最早平行半畫面規格。箭雨採最新半徑1230／70支，固定seed只供可重現視覺；radius為素材來源單位，不是遊戲公尺。投影圓在地面呈橢圓，中心跟隨角色root，前後遮擋層分開。上射箭離開畫面立即開始箭雨。
8. 反摔必用registered_metadata與stable_*圖。結尾面向左，銜接左向idle；不可把向左末格直接跳回右向首格無限循環。13格960ms，580ms放手。承重腳校正只證明量測點一致，不代表所有輪廓完全無抖動。

## 重建與驗證

Python 3搭配Pillow；近戰、空中、抓摔腳本另需numpy，抓摔清邊需scipy。僅從官方套件來源安裝，無需Qwen、ComfyUI、模型權重或重新生成。

- `python verify_package.py`：驗證所有交付檔案SHA256、17招入口與GIF時長。
- 近戰在assets/oichi/melee執行build_revisions.py（前兩段）及build_light3_v3.py（第三段）。build_revisions可能產生舊第三段中間檔，採用入口仍以manifest的v3為準。
- 空中／衝刺各在對應資料夾執行 `python build_preview.py air_light`、`python build_preview.py air_heavy` 或 `python build_preview.py dash_heavy`。
- 抓摔在assets/oichi/grabs執行 `python build.py grab_start grab_hold grab_hit_2`。不可無參數批次重建，否則會要求或產生已替換的舊版本。
- 第一膝擊：`python grab_hit_1_six/rebuild.py`；前摔：`python throw_fixes/rebuild.py throw_forward`；反摔：`python reverse_coherent/build_stable.py`。
- 箭雨在assets/oichi/arrows/rain_package執行 `python render_plus50_half_arrows.py`；此入口已引用最終人物幀及1230／70箭參數。
- 箭招原始重建依賴另在sources/arrows/。按其中REBUILD.md重建，歷史凍結人物原圖僅作來源，不重新跑本地模型。生成後的原始來源metadata可能含舊箭雨半徑；交付入口始終採assets內最新metadata。
- 圖層、接點、預覽已交付，但命中盒、傷害、取消窗、遊戲音效及左右向碰撞驗證需整合方完成。不得拿GIF畫面中的箭雨幀數當人物畫格數。

## 尚需整合方檢查

- 弓身目前剛性圖層旋轉，未做真實弓臂彈性形變；人物為整張RGBA姿勢，不是逐肢骨架。
- 各招錨點主要為視覺量測，正式武器替換需抽查所有握點和遮罩；抓取起手／保持／第二膝擊仍保留已接受初版的少量髮梢邊緣。
- 全包未聲稱已通過原生遊戲播放、傷害碰撞或跨角色受擊測試。單ZIP與解壓內容均保留。本包94.834MiB，小於GitHub100MiB單檔限制；未拆包。
