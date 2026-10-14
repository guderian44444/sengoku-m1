# 秀吉站立尺寸與雙手走跑修訂

2026-10-13。站立基準為 `../../body/idle/01.png`，既有身體尺規 416 像素、臉部尺規 55 像素；站立素材與遊戲顯示倍率保留。所有 39 組、234 格改用這個基準。

`standing-scale.json` 為每段動作的站立等效尺規。同段六格使用相同的原始像素→世界座標比例，避免蹲下、傾身、抬手、舉扇、裁圖高度與臉部遮擋造成縮放跳動。原圖中獨立高解析度格按實際像素密度換算；必殺末格實測為 2.2×，不硬套 2×。`scripts/register-hideyoshi-v30.py` 驗證來源 SHA，再生成正式 registration；每格都保留尺度來源，不能混回舊的裁圖高度。

走路、跑步改成雙手握同一把刀，各六格。右手在上、左手在下，握點固定；刀尖朝上並略向前、刃面朝外，沒有換手。兩隻手各有前景遮擋區，武器沿兩手軸繪製，繼續使用裝備目錄中的刀。人物圖不烘焙刀、刀柄或劍氣。新素材：

- `walk-two-hands.png`：1536×1024 RGBA，三欄兩列，六格走路。
- `run-two-hands.png`：1536×1024 RGBA，三欄兩列，六格跑步。
- `registration.json`：來源裁圖、雙手握點、腳底根點、遮擋區與 SHA。

使用 built-in imagegen 生成；角色身份／色調參照既有站立，雙手姿勢參照先前產生的雙手草稿。檢查 alpha 後確認可見的棕色 RGB 背景區為 alpha 0，不會進入遊戲畫面。原友軍 PNG、提案與先前 v30 修訂保留。

原生檢查使用 `game/tests/test_heroes_v30.gd`：全 39 段尺度覆蓋、每段固定倍率、原站立不變、兩手在同一刀柄可見寬度內、刀柄留在下手之下、刃面朝外、三把刀與左右朝向。`--capture-all` 保存完整 78 張素材表、28 張實際招式表及 20 張並排站立參考總覽。

```powershell
$env:PYTHONUTF8 = '1'
python scripts/register-hideyoshi-v30.py --check
$env:TEST_ARTIFACT_DIR = "$PWD/artifacts/hideyoshi-scale-v32/recheck"
node scripts/test-v19.mjs --only=heroes_v30,weapon_render_v22,animation_timing_v11 --render-heroes-v30
```

原生圖像屬可重現素材／招式檢查，實體手把與真人遊玩手感另外驗收。本次不修改人物資料、戰鬥判定或存檔。

## 正式素材的生成提示

### Walk

```text
Use case: identity-preserve. Production 2D game BODY sprites of the exact reference Hideyoshi. Keep his face/topknot/goatee, navy/red coat, black/gold armor, gray trousers, blue knee cords, straw sandals and single stowed gold gourd fan. Both arms bent inward, both fists aligned on ONE VERTICAL empty katana hilt axis in front of waist/lower chest, anatomical RIGHT fist above LEFT fist. Never swap hands, never let either hand swing free. Hands are EMPTY because engine draws the interchangeable katana; NO baked blade, hilt or guard. Same camera, facing RIGHT, muted palette, crisp isolated illustration, uniform anatomical head/armor/limb size across all six. TRUE transparent alpha outside body; no halo, glow, shadows, floor, backdrop, effects or text. Make ONLY SIX WALK poses from the first six reference poses: contact, down, pass, opposite contact, down, pass. Output a LANDSCAPE SIX-FRAME sheet with THREE columns and TWO rows, 1536x1024 aspect. All SIX complete sprites entirely inside their own equal 512x512 cells, 50px empty margins on each edge. Separate both rows with a wide TRANSPARENT gap. Do NOT include running poses or twelve frames. Feet must be fully visible, no clipping.
```

### Run

```text
Use case: identity-preserve. Production 2D game BODY sprites of the exact reference Hideyoshi. Keep his face/topknot/goatee, navy/red coat, black/gold armor, gray trousers, blue knee cords, straw sandals and single stowed gold gourd fan. Both arms bent inward, both fists aligned on ONE VERTICAL empty katana hilt axis in front of waist/lower chest, anatomical RIGHT fist above LEFT fist. Never swap hands, never let either hand swing free. Hands are EMPTY because engine draws the interchangeable katana; NO baked blade, hilt or guard. Same camera, facing RIGHT, muted palette, crisp isolated illustration, uniform anatomical head/armor/limb size across all six. TRUE transparent alpha outside body; no halo, glow, shadows, floor, backdrop, effects or text. Make ONLY SIX RUN poses from the last six reference poses: running contact, compression, passing flight, opposite contact, compression, passing flight. Lean forward, both hands fixed on same guard grip. Output a LANDSCAPE SIX-FRAME sheet with THREE columns and TWO rows, 1536x1024 aspect. All SIX complete sprites entirely inside their own equal 512x512 cells, 50px empty margins on each edge. Separate both rows with a wide TRANSPARENT gap. Do NOT include walking poses or twelve frames. Feet must be fully visible, no clipping.
```


本次最後驗證：人物測試 9,752 項、原生完整擷取 9,984 項均為 0 失敗；武器渲染、動畫時序與護符群組通過。126 張原生圖片及彙總在 `artifacts/hideyoshi-scale-v32/final-density/` 與 `verification-summary.json`，包含三刀、六格、雙朝向及每列站立參照。原交付 234 個身體 PNG 的 SHA 全數保留。
