# 第三關帳內雙小王：M3 驗證與交接

日期：2026-10-16。分支 `feature/stage03-imagawa-camp`，基底 M2 `5a460fb8b02abb49bfc8e0ba7ba31422fc6d8263`。使用者已明確允許本分支 runtime、戰鬥與同步開發；本輪只本機提交，不 push、merge 或發布。

## 可試玩範圍

沿用 `scripts/play-stage03-alarm.ps1` 的隔離資料啟動器：警鐘 → 木障 → 陣形 → 帳門 → 雙小王。雙人可加 `-Coop`，使用兩支搖桿。

兩王固定叫「小王 A（占位）」與「小王 B（占位）」，不是歷史人物定稿；兩條血條各有固定 ID，死亡後仍保留歸零記錄。單王死亡續補雜兵，兩王皆死才停援並顯示「義元階段待接」。玩家及現存帳內雜兵保留，此時可繼續打餘兵，但義元尚不生成、整關尚未結算。

## 機制與可調預設

- 雜兵單人 4／雙人 6、死亡補位 240 tick、准入間隔 45 tick；存活（含進場）＋待補 ≤ 目標，不計小王、不復活小王。
- A／B 分開設定 HP、位置、招式及體型；目前沿用薙刀／雙刀行為占位，沒有新增正式人物或歷史姓名。
- 初始間距約 363 px；接近至 260 px 時嘗試軟性分離。後撤最多 36 tick／90 px，24 tick 收招、240 tick 冷卻；牆邊側移，不能持續重啟退避。外部受擊位移仍由既有物理處理。
- 目標保留 180 tick，雙人各有偏好目標；死亡立即失效改選，避免玩家交錯時每幀換目標。預備攻擊沿用既有鎖向與收招。
- 兩王死亡同 tick 先取消舊補兵，再進入 `awaiting_yoshimoto`。死亡墓碑、目標、後撤／收招與預約都在主機持續快照，不依賴單次事件。

以上數字均為可調原型預設，非使用者最終確認值。

## 驗證

本輪共 10 組套件通過（M1／M2／M3、第二關、移動、Wire 及既有 HUD）：

| 套件 | 結果 | 最後通過秒數 |
|---|---|---:|
| `stage03_alarm` | PASS | 2.325 |
| `stage03_alarm_view` | PASS | 42.978 |
| `stage03_objectives` | PASS | 2.731 |
| `stage03_tent` | PASS | 1.884 |
| `stage03_tent_view` | PASS | 44.719 |
| `stage2_route_v29` | PASS | 44.305 |
| `stage2_combat_v29` | PASS | 0.937 |
| `stage_movement_v19` | PASS | 3.789 |
| `wire` | PASS | 1.486 |
| `hud_v19` | PASS | 4.043 |

M3 最終 **50 checks／0 failures**，M1 警鐘 72、M2 障礙／陣形 105（多一個第四場景設定校驗）、第二關路線 1,066、第二關戰鬥 65、移動 210、Wire 304 項均零失敗；另有兩組第三關 UI 與既有 HUD 驗證通過。

- 9 組回歸：`artifacts/stage03-m3/regression/results-v19-20261016T042323230Z.json`。
- 舊單 Boss HUD：`artifacts/stage03-m3/hud-regression/results-v19-20261016T042632920Z.json`。
- 最終補驗共用人口 API 不計小王、拒絕帳內外來警鐘柱，以及 Wire：`artifacts/stage03-m3/final-checks/results-v19-20261016T042836445Z.json`。

重現指令：

```powershell
$env:GODOT_BIN = 'D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$env:TEST_ARTIFACT_DIR = Join-Path (Get-Location) 'artifacts/stage03-m3/regression'
node scripts/test-v19.mjs --only=stage03_alarm,stage03_alarm_view,stage03_objectives,stage03_tent,stage03_tent_view,stage2_route_v29,stage2_combat_v29,stage_movement_v19,wire,hud_v19
```

只忽略引擎既有 Windows root certificate store 診斷，其餘腳本與引擎錯誤會讓測試失敗。

涵蓋：兩種擊殺順序、同時死亡、單王死仍續援、重複死亡去重、雙王死同 tick 取消到期單、保留活著雜兵、小王不回血／不重生、屍體移除後墓碑仍有效、勝敗／重開取消；雙人目標保持、死亡改選、有限後撤／冷卻／收招與牆邊結束；畸形 ID／墓碑／階段／資料型別拒絕；200 次主機序列化快照（省略事件）與雙模擬決定性。

原生程序 exit 0；`artifacts/stage03-m3/native-review` 有四張 1280×720 圖與 `review.json`：

| 檔案 | 已核對 |
|---|---|
| `01-tent-entrance.png` | 布簾帳門、GO 導向與實際進場過渡。 |
| `02-two-leaders.png` | A／B 字標、不同大小占位及兩份獨立血條，擷取時 ID 45／46。 |
| `03-leader-a-defeated.png` | A 歸零、B 仍活著，遭遇繼續補兵。 |
| `04-awaiting-yoshimoto.png` | 兩條歸零、現存雜兵保留及「義元階段待接」。 |

所有擷取時點快照均通過 Wire；屍體清除後 UI 仍保留兩份歸零紀錄。畫面使用既有 Main／BattleView／CombatHUD，初始位置與死亡為人工設定，未宣稱真人通關；只保留本機，不上傳新圖。

## 明確提交範圍

僅下列 16 檔，不含匯入產物、快取、artifacts、其他素材或主工作樹修改：

```text
docs/STAGE03-ASSETS.md
docs/STAGE03-IMAGAWA-CAMP.md
docs/STAGE03-VALIDATION-M3.md
game/core/battle.gd
game/core/stage03_encounter.gd
game/core/stage03_tent.gd
game/core/stage_data.gd
game/core/wire.gd
game/data/stage-03.json
game/main.gd
game/render/battle_view.gd
game/render/combat_hud.gd
game/tests/test_stage03_objectives.gd
game/tests/test_stage03_tent.gd
game/tests/test_stage03_tent_view.gd
scripts/test-v19.mjs
```

## 後續與限制

尚未實作義元與箭／刀氣兩招，也未做正式人物、配音、真人難度、實體搖桿或跨機網路驗收。原生擷取採人工設定位置／死亡與真實狀態推進，不能當真人完整通關。M1 已存在的廣泛舊套件失敗仍另列，不把它們算成通過。
