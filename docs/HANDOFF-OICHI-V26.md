# 阿市 v26 局部裙片交接

## 已完成與保留範圍

已逐格檢查阿市 26 組、156 格；只以 imagegen 產生的衣片局部套回原角色，沒有整張替換角色。

- **81 格已修改**，涵蓋 17 組動作
- **75 格原本符合，保留原樣**，包括 heavy1 可接受的少量白襯邊
- jump、low_sweep 各 6 格採紅色不透明外裙片，保留原已露出的腿
- 修改／原樣保留兩類互斥，總計 156 格；不能稱為「156 格都已修改」

裙長、高側衩、側腿及原動作保留。調整的是裙片重疊與不透明內襯，避免完整白色安全褲輪廓；必要小白邊允許保留，私密部位保持遮蔽。

## 最終設計與限制

jump 與 low_sweep 的早期修法生成受限，後來依使用者新批准的完整不透明紅色外裙方案重新設計成功。最終只從新設計抽取原白布區與既有紅裙接縫所需的布料，沒有將大片候選下襬蓋到原腿。這 12 格未使用任何生成皮膚；low_sweep 第 3 格中央已以紅裙遮蔽。少量白色接縫可以保留。使用者圈選圖僅用於檢視，不隨 repository 或補丁包公開。

局部對位屬美術合成，並非宣稱生成器能逐像素保形。來源生成後，利用對位與固定選區抽取局部，再保護原始像素。已知微小接縫：throw 第 1、3、4、5 格、recovering 第 4 格仍有原褲邊細線；down 第 1、3 格另有較淡邊痕。這些未構成完整白短褲輪廓，按最終檢視決定保留可用版，避免為修線而改動原腿像素；後續美術可另行精修。

## 精確保護與版本證據

- 全圖 alpha、透明區 RGB、裙片修改選區外像素、人物外輪廓保留
- 臉、髮型、白上衣、動作、身形、真正握持手與鞋區保留
- 原有腿部膚色與暖色陰影像素採保護遮罩逐像素保留，並以全身前後對照檢視；外裙原 alpha 邊界不延長
- 所有註冊裁框、foot/hand 座標、武器握點、別名、遮手資料不變
- 背弓 hand 是腰間掛點；躺姿 down 第 5–6 格 foot 是中央接地點。這些座標固定，所在裙片像素可隨衣裝改變，並非把它們誤認成實際手掌或鞋
- 其他角色與 48 把武器來源受 891 個資產 SHA-256 保護
- v24/v25 歷史清單保留；v26 使用明確逐檔 before → after 雜湊轉移

主要清單：`game/assets/v26/oichi-skirt.json`。最終逐格分類在主清單的 `frame_audit`；`frame-review.json` 保留初次檢視判定；精確像素差遮罩在 `masks/`，原／新局部像素在 `patches/`，最終 462 格角色來源清單在 `final-character-protection.json`。

每張修改圖可用 after 圖和 before patch 還原完整原 RGBA，再與凍結的原 RGBA 雜湊比對。再利用同一 diff mask 和 after patch 重建最終圖，無須 Git 歷史或重新呼叫圖像生成。

## 可重現指令

從 repository 根目錄：

```sh
python scripts/oichi_skirt_v26.py --check
python scripts/apply-oichi-skirt-v26.py --apply
python scripts/register-oichi-v22.py --check
python scripts/test-nobunaga-dark-red-v25.py
python scripts/test-weapon-art-v24.py
python scripts/verify-handoff.py
```

Pillow、NumPy 為補丁檢查／套用所需；註冊及舊版美術檢查另需 OpenCV、SciPy。`--apply` 只接受清單記錄的精確 before 或 after 版本，重跑具冪等性；不接受未知本地素材。新 clone 已包含最終 PNG，通常只需 `--check`。

Linux 可用已安裝 Godot headless 跑 `test_hero_layers_v22.gd`、`test_weapon_render_v22.gd`、`test_projectile_v22.gd`、`test_battle.gd`、`test_art_demo.gd`。本次 Linux 的這 5 項檢查直接呼叫 Godot；test-native.mjs / test-art-native.mjs 舊包裝腳本含 Windows 路徑，因此未宣稱它們在 Linux 通過。另有 test-v19.mjs 已支援 GODOT_BIN 環境變數。

## 交付與預覽

- 52 秒、1280×720 全 26 組前後對照影片，包含左右朝向
- 每格採固定展示時間，屬素材合成，**不是遊戲實機錄影，也不是實際招式時序**
- 工具／局部素材小補丁包可套入配套 repository；不含完整遊戲或引擎
- `game/assets/v26/review/air-heavy-before-after.jpg` 是主要問題姿勢的對照

圖像生成提示保存在 `generation-prompts.json`。公開補丁是已審查的最終局部像素，不需要公開完整生成候選、失敗輸出或使用者標記圖來重現。

## 本輪最終驗證

- v26 精確補丁、156 格註冊、v25 保护鏈、48 武器美術檢查：PASS
- Godot 4.6.3：hero layers 3102、weapon render 397、projectile 174、battle 59 checks，皆 0 failures
- art demo：10 poses / 2 heroes / 3 weather states，加 pause、seek、facing、slow speed、fixed feet：PASS
- 最終 handoff verifier 的 v26 transition 使用 18 個精確 overlay（17 PNG + registration）
