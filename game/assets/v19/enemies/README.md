# 今川正式敵人素材 v0.19

此批遵循 `assets/enemies-v0.8/imagawa.png` 的足輕、旗兵、指揮、弓兵與小王造型；鐵炮參照既有 v10 今川兵。松井宗信是獨立的大王遊戲造型：黑金鍬形兜、厚肩甲、紅披肩、紅穗薙刀。旗上沿用 v18 定案的今川赤鳥旗印輪廓與遊戲配色。

全部原圖由內建 image_gen 製作，保留原始 RGBA，沒有以低解析圖放大或程式搖晃代替動作。`generation-journal.json`、`attack-generation-journal.json`、`troop-attack-generation-journal.json`、`root-walk-*.json` 保存提示、參照與來源。早期 `*-walk.png` 留作身份參照；執行時使用 `*-walk-cycle.png`。

## 執行時接口

- 7 身份：soldier、flag、commander、archer、gunner、boss、matsui。
- `enemy_clip:imagawa:<身份>:<動作>`；松井仍是 `fighter.kind=boss`，由 `stage_boss=true` 選擇 matsui。
- 共 54 clips／247 個引用幀；40 組原圖提供 240 個不同的執行時關鍵姿勢，待機額外重用 7 個雙腳接觸姿勢。足輕 walk 由 12 張原稿挑選 6 張，原索引寫在 registration。
- 待機 1、走路 6、受擊 3、掙脫 3、倒地死亡 6。普通近戰兵各 3 招，弓兵和鐵炮各 1 招，小王／大王各 4 招，每招 6 張。
- 走路 60 ticks 一輪，每姿勢 10 ticks；放開移動立即待機。後退沿原步態倒序播放。
- 人物尺規為頭盔／頭頂至鞋底，不計武器、旗桿。每個圖集固定人體尺規；蹲下或死亡不按當前包圍盒放大。常規兵 146 px、指揮 158、小王 163、大王 201.5（155 × 1.3）。

## 登錄與驗收

`python scripts/register-enemies-v19.py` 登錄原圖完整 alpha 連通輪廓、鞋底接點、弓箭／槍口位置及 SHA256。來源分格不一定等寬等高，因此禁止直接均分裁切。Godot 載入時使用獨立圖片與 2 px 透明外框，再用完整人物輪廓排除鄰格；來源 PNG 不改寫。

`python scripts/register-enemies-v19.py --check` 驗證 54 clips 完整、透明度、來源解析、來源 SHA、6 格步態腳距變化和登錄可重現。

`game/tests/test_enemy_art_v19.gd` 檢查 7 身份所有實際狀態／招式均使用 v19、獨立來源圖、固定人體尺規、武器射出點、最後一格平躺。步態時序由 `test_enemy_walk_v19.gd` 驗證。

原生視覺證據：`artifacts/native-v19/enemy-states/` 有 7 張全狀態和 7 張全招式連續圖；`artifacts/native-v19/enemy-walk/` 和 `enemy-walk-v19.mp4` 用遊戲實際縮放展示左右步態、六張開合姿勢與信長同地面身高比較。這些是可重現的原生素材／播放驗收，不宣稱已完成人工試玩驗收。
