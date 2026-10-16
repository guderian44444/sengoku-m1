# 第三關義元與完整流程：M4 驗證與交接

日期：2026-10-16。分支 `feature/stage03-imagawa-camp`，獨立 worktree `D:/AI/吞食戰國/artifacts/stage03-imagawa-camp`，本輪基底為 M3 `4717e003ca3188686d3cb3a89ae472eaed29af00`。使用者已授權本分支 runtime／戰鬥／同步開發及本機 commit；本輪不 push、merge 或對外發布，也不改原主工作樹。

## 可玩範圍與限制

目前可由警鐘 → 三層木障 → 錯落陣形 → 帳內 A／B 雙小王 → 義元 → 原型勝利。入口與鍵盤／搖桿操作見[簡易試玩](STAGE03-PLAYTEST.md)；加 `-StartScene 3` 可直接試帳內。

- 雙王皆死先取消舊預約、90 tick 安全出場，保留玩家與現有雜兵。義元使用新 ID；A／B 死亡墓碑不回復。雙歸零血條切為義元單血條。
- 義元具較快接近、有限側移／短退、近遠距離遲滯、穩定目標／倒地改選、正面格擋與可受傷收招。攻擊承諾後固定瞄準，不隨玩家穿身轉向。
- 箭與刀氣是兩個動作和真實投射物；有不同預備／飛行速度／命中深度／穿透，從實際出手保證共用冷卻。沒有以鐵砲 `boss_volley` 冒充箭。
- 義元死亡即停援並 `won`，現存雜兵不阻擋結算；同 tick 玩家全倒仍以義元死亡勝利優先。玩家單獨全倒則 `lost`。重開重建遭遇，不重用墓碑或舊補兵單。
- 義元人物沿用既有 Boss，弓為姿勢代理加幾何弓及字標；刀氣／格擋使用可讀幾何占位。正式人物、拉弓／放弦／武器切換動畫、營帳美術、VFX、音效及配音未完成，未重做已核准玩家素材。

所有 HP、時間、人口、距離、傷害、命中範圍與冷卻均是可調原型預設，詳見[設計](STAGE03-IMAGAWA-CAMP.md)及[素材狀態](STAGE03-ASSETS.md)。

## 自動驗證

12 組第三關／第二關／移動／Wire／HUD 回歸通過：

| 套件 | 結果 | 秒數 |
|---|---|---:|
| `stage03_alarm` | PASS | 1.801 |
| `stage03_alarm_view` | PASS | 33.022 |
| `stage03_objectives` | PASS | 2.176 |
| `stage03_tent` | PASS | 1.306 |
| `stage03_tent_view` | PASS | 33.642 |
| `stage03_yoshimoto` | PASS | 1.440 |
| `stage03_yoshimoto_view` | PASS | 34.396 |
| `stage2_route_v29` | PASS | 33.478 |
| `stage2_combat_v29` | PASS | 0.794 |
| `stage_movement_v19` | PASS | 3.017 |
| `wire` | PASS | 1.452 |
| `hud_v19` | PASS | 3.298 |

原始報告：`artifacts/stage03-m4/regression/results-v19-20261016T044755827Z.json`。

其後把遠程共用冷卻下限由實際 release 時點重新保證，並補入義元與既有 Boss 實際移速比較、只有玩家倒下時失敗的檢查。最後針對 `stage03_tent`、`stage03_yoshimoto`、`wire` 再跑，3 組均 exit 0；義元最終 **119 checks／0 failures**。報告：`artifacts/stage03-m4/final-checks/results-v19-20261016T045223572Z.json`，逐項日誌在同目錄。

涵蓋安全過渡與玩家狀態保留、現存雜兵／新缺額預約、兩種遠程固定瞄準及差異、冷卻與遲滯、正面／背面／重擊／收招、失效目標、牆邊有限移動、勝敗／重開取消、單人與雙人四場景可達勝利、200 次省略事件的主機快照 roundtrip，以及畸形 ID／瞄準／模式／計時／外部輸入拒絕。

完整流程 fixture 會人工清除目標、定位玩家／敵人並給玩家短無敵，只驗證狀態機可達與不變量；不是以真人輸入或自然攻擊完整打通，不宣稱真人難度通過。

重現選定回歸：

```powershell
$env:GODOT_BIN = 'D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$env:TEST_ARTIFACT_DIR = Join-Path (Get-Location) 'artifacts/stage03-m4/regression'
node scripts/test-v19.mjs --only=stage03_alarm,stage03_alarm_view,stage03_objectives,stage03_tent,stage03_tent_view,stage03_yoshimoto,stage03_yoshimoto_view,stage2_route_v29,stage2_combat_v29,stage_movement_v19,wire,hud_v19
```

本輪沒有再跑所有歷史套件。M1 已核對的舊基底失敗仍另見 [M1 紀錄](STAGE03-VALIDATION-M1.md)，不能把上述 12 組說成全專案測試全過。

## 原生畫面

原生 Main／BattleView／CombatHUD 腳本通過並 exit 0；`artifacts/stage03-m4/native-review/` 有八張 1280×720 PNG 與 `review.json`，所有擷取快照通過 Wire。`native-review.log` 及 `native-exit-code.txt` 位於上一層。

| 圖檔 | 核對內容 |
|---|---|
| `01-final-boss-introduction.png` | A／B 雙歸零血條、保留玩家／雜兵及「義元即將入陣」。 |
| `02-bow-windup-placeholder.png` | 義元單血條、既有人物加弓與「弓・占位」預備提示。 |
| `03-locked-arrow.png` | 真實固定方向箭，擷取在出手後 8 tick，與弓輪廓分開。 |
| `04-sword-wave-windup.png` | 刀氣動作的預備畫面，使用既有揮擊姿勢代理。 |
| `05-locked-sword-wave.png` | 出手後 8 tick 的較寬青色弧形刀氣，輪廓明顯不同於箭。 |
| `06-frontal-guard.png` | 獨立金色格擋弧與字標；驗證腳本清除上一發刀氣，避免誤讀。 |
| `07-guard-recovery.png` | 格擋結束的「收招」提示與可受傷狀態。 |
| `08-prototype-victory.png` | 義元歸零、現有雜兵仍在而第三關勝利已顯示。 |

位置、時間、死亡與部分動作為人工安排，實際 Battle ticks 驅動箭／刀氣釋放及格擋收招。擷取不是真人通關，也不是正式持弓美術驗收。新圖只保留本機，沒有上傳 Library 或增加交付圖片；先前批准的兩張警鐘圖維持原交付。

啟動仍有基底既有的 Windows root certificate store 診斷，以及直接載入原圖的 export 警告；沒有略過腳本錯誤。這不是 TLS 或匯出版本驗證，本輪未產生新遊戲匯出包。

## 明確提交範圍

僅下列 20 檔；不含 `.godot`、`.import`、`.uid`、artifacts、阿市／家康素材或其他主工作樹內容：

```text
docs/STAGE03-ASSETS.md
docs/STAGE03-IMAGAWA-CAMP.md
docs/STAGE03-PLAYTEST.md
docs/STAGE03-VALIDATION-M4.md
game/core/battle.gd
game/core/stage03_encounter.gd
game/core/stage03_tent.gd
game/core/stage03_yoshimoto.gd
game/core/wire.gd
game/data/stage-03.json
game/main.gd
game/render/battle_view.gd
game/render/combat_hud.gd
game/tests/play_stage03_alarm.gd
game/tests/test_stage03_tent.gd
game/tests/test_stage03_tent_view.gd
game/tests/test_stage03_yoshimoto.gd
game/tests/test_stage03_yoshimoto_view.gd
scripts/play-stage03-alarm.ps1
scripts/test-v19.mjs
```

提交前檢查暫存清單及 `git diff --cached --check`；提交後確認追蹤檔與暫存區無差異。Godot 已生成的未追蹤 `.import`／`.uid` 另列數量並留在本機，不為宣稱乾淨而刪除或納入提交。

## 待驗與交接

未驗真人難度／正常攻擊全程通關、實體雙搖桿／震動、跨機網路、正式外觀／弓動作／音樂聽感與遊戲匯出。Wire 與本機決定性通過只證明本次模擬及快照層級。後續先按簡易入口試玩，再對占位素材與平衡逐項驗收；本輪不擴增新功能。
