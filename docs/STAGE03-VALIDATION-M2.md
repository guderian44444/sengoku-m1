# 第三關三段原型：M2 驗證與交接

日期：2026-10-16。分支 `feature/stage03-imagawa-camp`，接續 M1 `55f4b6bed9774050d63115da170c3e0c09a9c24e`。本輪不 push、不 merge、不發布遊戲。原 main 工作樹與其他工作者修改不動。

## 可試玩內容

沿用 M1 的隔離啟動器，從警鐘連續進入多層木障及錯落陣形：

```powershell
$env:GODOT_BIN = 'D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
.\scripts\play-stage03-alarm.ps1
# 同機雙人需兩支搖桿
.\scripts\play-stage03-alarm.ps1 -Coop
```

警鐘全柱破壞並清餘兵後，依 GO 全員向右；木障必須三層全毀後向右。陣形有刻意錯開的盾槍兵、槍兵與弓兵，擊破前排後可趁缺口前進；突破前線後守軍會轉身追擊、近戰迎擊。全員穿過帳門標線後結束三段原型，帳內 Boss 尚未製作。

預設三層木障 HP 180／210／240、缺口至少 90 tick、死亡補兵 240 tick／准入間隔 45 tick、單人 6／雙人 9 兵及帳門座標，全部是可調原型參數。角色與裝備不寫回原玩家進度；正常章節選單仍不開放第三關。

## 針對與回歸

```powershell
$env:TEST_ARTIFACT_DIR = Join-Path (Get-Location) 'artifacts/stage03-m2/checks'
node scripts/test-v19.mjs --only=stage03_alarm,stage03_alarm_view,stage03_objectives,stage2_route_v29,stage2_combat_v29,stage_movement_v19,wire
```

2026-10-16T04:00:59.576Z 開始的七組全部通過，exit 0：

| 套件 | 結果 | 秒數 |
|---|---|---:|
| `stage03_alarm` | PASS | 1.862 |
| `stage03_alarm_view` | PASS | 36.501 |
| `stage03_objectives` | PASS | 2.203 |
| `stage2_route_v29` | PASS | 35.478 |
| `stage2_combat_v29` | PASS | 0.674 |
| `stage_movement_v19` | PASS | 2.697 |
| `wire` | PASS | 1.185 |

警鐘 72、M2 障礙／陣形 103、第二關路線 1,066、第二關戰鬥 65、移動 210、Wire 304 項檢查均為零失敗；另有 UI／鐘聲生命週期測試通過。完整紀錄 `artifacts/stage03-m2/checks/results-v19-20261016T040059576Z.json`。

涵蓋：

- 三層木障各五條 lane × 地面／空中／衝撞的不可繞行碰撞；實際輕擊破壞第一層，破裂後碰撞開通，全毀才轉下一段。
- 前排缺口的最小延遲，候補唯一歸屬，預約時不瞬移、不回血、不轉換兵種；士兵經多 tick 實際前移，新兵只入後排。
- 補位途中死亡、兩缺口競爭同一候補、大量同時死亡、屍體清除後恢復完整人口，未綁定前排補兵單不能卡死後排准入。
- 突破前線後持續狀態保存、轉身追擊與近戰出招；雙人只有一人穿過不能結束，全員到帳門即停援，可保留存活敵兵。
- 勝敗／據點重開取消、錯誤型別、重複候補／補兵／障礙 ID、錯誤後排位置、舊 epoch 與不完整障礙碰撞深度拒絕。
- 900 tick 的雙人主機決定性模擬、每三 tick 的 300 次序列化快照；省略事件後，客端副本仍與主機的移動／補兵預約一致。這是快照往返驗證，尚未做跨機實網路驗收。

最終補驗：

- 更新原型完成文字後，UI／鐘聲與 M2 測試再度通過，紀錄 `artifacts/stage03-m2/final-checks/results-v19-20261016T040414858Z.json`。
- 另補「木障缺 mandatory 欄位」的畸形快照案例，避免校驗讀取不存在欄位；M2 最終 **104 checks／0 failures**，紀錄在 `artifacts/stage03-m2/validation-boundary`。
- 原生畫面核對後加入第三關專用「盾槍／槍／弓」字標，避免既有盾牌錨點缺失造成兵種混淆；不更動前兩關角色顯示。M1 已存在的四組廣泛舊套件失敗保持另列，詳見 [M1 基底比對](STAGE03-VALIDATION-M1.md)，本輪沒有改舊測試斷言隱藏失敗。

## 原生畫面

`game/tests/capture_stage03_objectives.gd` 使用實際 Main／BattleView、人工設定初始位置及死亡，接著跑原本 Battle 的真實移動 tick；畫面不是 HTML 模擬，也不代表真人通關或難度驗收。

原生程序正常退出，九張 1280×720 畫面及 `review.json` 位於 `artifacts/stage03-m2/native-review`：

| 畫面 | 驗證用途 |
|---|---|
| `01-barriers-intact.png`／`02-first-layer-open.png` | 全帶木障、HP、第一層破裂後向第二層推進。 |
| `03-formation-holding.png` | 刻意錯開的前後排與盾槍／槍／弓占位字標。 |
| `04-front-gap.png`／`05-gap-held.png` | 死亡缺口與至少 90 tick 的保留時間。 |
| `06-reserved-rear-soldier.png`／`07-rear-soldier-walking.png`／`08-gap-filled.png` | 同一 ID 士兵先預約、實際逐步前移、最後補上缺口。 |
| `09-breached-melee.png` | 前線突破後守軍轉身、追擊與近戰迎擊。 |

所有擷取時點快照通過 Wire。補位士兵 ID 33 從 `(1320,425)` 出發，預約時未改座標；實際移動與突破近戰後到 `(1111.706,458.517)`，HP 65 及槍兵身分保持不變。中途 120 tick 的位移有上限斷言，不能用直接放到前線代替走路。

畫面、報告及引擎日誌放在忽略的 artifacts，不納入 Git；只保留本機，不重傳已交付的 M1 截圖。正式盾牌錨點／素材仍待核對，字標不代表正式美術完成。

## 提交範圍與限制

本輪僅提交下列 16 個檔案；不納入 `.import`／`.uid`、快取、artifacts 或其他素材：

```text
docs/STAGE03-ASSETS.md
docs/STAGE03-IMAGAWA-CAMP.md
docs/STAGE03-VALIDATION-M2.md
game/core/battle.gd
game/core/stage03_encounter.gd
game/core/stage03_objectives.gd
game/core/stage_data.gd
game/core/wire.gd
game/data/stage-03.json
game/main.gd
game/render/battle_view.gd
game/tests/capture_stage03_objectives.gd
game/tests/play_stage03_alarm.gd
game/tests/test_stage03_alarm.gd
game/tests/test_stage03_objectives.gd
scripts/test-v19.mjs
```

正式人物不重新生成，鐘／木障仍用幾何占位與既有營地／敵兵素材。

尚未驗收：實體搖桿、真人難度、跨機連線、正式木障／敵兵識別素材與音效聽感。尚未實作：帳內雙小王、雙血條、義元的戰術移動及箭／刀氣兩招。
