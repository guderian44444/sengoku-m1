# 第三關警鐘原型：M1 驗證與試玩

日期：2026-10-16。分支 `feature/stage03-imagawa-camp`，基底 `d28717797584dc2ea794c57b9b01b2980f6a7c82`。僅本機里程碑提交；未 push、未 merge、未發布遊戲。

## 試玩

在此 worktree 根目錄以 PowerShell 執行：

```powershell
$env:GODOT_BIN = 'D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
.\scripts\play-stage03-alarm.ps1
# 雙人：同機兩支搖桿；鍵盤亦可控制 1P
.\scripts\play-stage03-alarm.ps1 -Coop
```

沿用遊戲原有操作，先移至地面支柱附近攻擊；全部柱子破壞後停止增援，再清除餘兵完成。原型預設兩柱、單人 6／雙人 9 兵、死亡後 240 tick 預約、45 tick 准入間隔均可調，非使用者最終確認數值。

啟動器把 APPDATA／XDG 指向本 worktree 的 `artifacts/stage03-playerdata`，並於結束還原環境變數；專用入口不載入或寫回玩家人物進度。正常選單的第一、二關進度發現方式保持不變。

## 重現針對測試

```powershell
$env:TEST_ARTIFACT_DIR = Join-Path (Get-Location) 'artifacts/stage03-m1/checks'
node scripts/test-v19.mjs --only=stage03_alarm,stage03_alarm_view,stage2_route_v29,stage2_combat_v29,wire,stage_movement_v19
```

最終版本於 `2026-10-16T03:40:57.067Z` 開始的 6 組測試全部通過，程序 exit 0：

| 套件 | 結果 | 秒數 |
|---|---|---:|
| `stage03_alarm` | PASS，72 checks／0 failures | 2.217 |
| `stage03_alarm_view` | PASS，入口、目標 HUD、鐘聲循環／暫停／停止、快照 | 43.710 |
| `stage2_route_v29` | PASS | 46.733 |
| `stage2_combat_v29` | PASS | 0.896 |
| `stage_movement_v19` | PASS | 3.498 |
| `wire` | PASS | 1.613 |

精確秒數以 `artifacts/stage03-m1/checks/results-v19-20261016T034057067Z.json` 為準；`results-v19-rerun.json` 是同輪最新結果。Godot 資源導入已先完成。僅忽略引擎已知的 Windows root certificate store 診斷，其餘腳本／引擎錯誤均會讓測試失敗。

## 原生畫面

以現有 Main、BattleView 與雙人 HUD 輸出 1280×720 原生畫面，非 HTML 模擬；人工擺位及設定受損狀態，只作視覺核對，不宣稱真人完整通關。

```powershell
.\scripts\play-stage03-alarm.ps1 -Coop -ReviewDir (Join-Path (Get-Location) 'artifacts/stage03-m1/native-review')
```

本機證據：`artifacts/stage03-m1/native-review/01-ringing.png`、`02-heavy-damage.png`、`03-one-post-broken.png`、`04-alarm-stopped.png` 及 `review.json`。四個快照均通過 Wire；原生程序正常退出。畫面與引擎日誌放在忽略的 artifacts，未納入本次程式提交。

已目視確認高處鐘、地面柱及 HP 條、頂部 0/2→2/2 目標進度、單柱破壞仍響、全柱破壞後落鐘與停響提示。鐘、柱與鐘聲均為占位；正式美術、實際聽感與難度尚待驗收。

## 廣泛舊套件比對

`stage_v19` 在修改前後均為 1,898 checks／18 failures：舊兵量、舊 30 秒整批增援預期及 width 邊界等。基底原始紀錄 `artifacts/stage03-baseline/checks/stage_v19.log`，修改後 `artifacts/stage03-m1/legacy-checks/stage_v19.log`。

另外三組以 HEAD 原始 runtime／測試 runner 與同一引擎重跑，失敗文字及數目與修改後完全相同：

| 套件 | 乾淨基底 | 本次修改後 | 既有失敗 |
|---|---|---|---|
| `battle` | 59 checks／1 fail | 59 checks／1 fail | 舊武器拾取直接裝備預期。 |
| `stage_integration_v19` | 36 checks／2 fails | 36 checks／2 fails | 開場陣營／狀態及非阻塞簡介預期。 |
| `stage_music_v18` | 46 checks／2 fails | 46 checks／2 fails | 淡出暫停狀態及 Boss 音量回到一般音量的舊預期。 |

比對紀錄位於 `artifacts/stage03-m1/baseline-comparison/checks`；`restore-verification.json` 確認暫存的本次 runtime 逐位元還原。`stage_v19` 的 18 項失敗亦逐項比對相同。上述四組仍標記失敗，沒有更動測試斷言來隱藏既有問題。

## 驗證限制與後續

本里程碑驗證有界佇列、死亡去重、進場人口、同 tick 停援、屍體占位、重開／勝敗取消、決定性主機模擬、畸形快照拒絕及 UI／鐘聲生命週期。尚未做實體搖桿、跨機網路、真人通關／難度或正式音效聽感驗收，也未輸出可發布遊戲包。

下一里程碑：多層必拆障礙與三大段推進，接著陣形真實補位、雙小王及雙血條、義元 AI 與箭／刀氣分離攻擊。素材缺口見 [P0／P1 清單](STAGE03-ASSETS.md)。

## 本次明確提交範圍

僅提交下列 17 個檔案；不包含 Godot `.import`／`.uid`、快取、artifacts、既有人物素材或主工作樹其他修改：

```text
docs/STAGE03-ASSETS.md
docs/STAGE03-IMAGAWA-CAMP.md
docs/STAGE03-VALIDATION-M1.md
game/core/battle.gd
game/core/stage_data.gd
game/core/stage03_encounter.gd
game/core/wire.gd
game/data/stage-03.json
game/main.gd
game/render/battle_view.gd
game/render/combat_audio.gd
game/tests/play_stage03_alarm.gd
game/tests/test_stage03_alarm.gd
game/tests/test_stage03_alarm_view.gd
game/tests/test_wire.gd
scripts/play-stage03-alarm.ps1
scripts/test-v19.mjs
```
