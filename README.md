# 吞食戰國：主程式與角色素材

此儲存庫保存可繼續修改的 Godot 專案、連續圖片、音效、素材登錄工具與人物驗收流程。目前專案版本為 **0.20.0**；第一關「桶狹間竹林」採七個長場景、十四個據點、31 波攻防，同景內清場顯示 GO、走到底才換背景。敵人從畫面外左右進場，雙人每波雜兵數量增加 50% 並向上取整；大小王步速為目標角色步行的 80%，大王存活時每 30 秒呼叫一波增援。

開始畫面以圖形標題、書法字形與街機排版呈現；按下開始後進入正式主選單，選「一人出陣」或「二人共鬥」，再選武將、難度並出陣。「遊戲設定」分開調整音樂、音效與語音音量並自動保存，音樂在每個區段循環，暫停與結果畫面也持續播放。底部暫留「工程入口」，收納練習、陣營試戰、素材展示及 IP 直連，正式發行前再移除。

上方顯示頭像、生命與氣條，不顯示波數；正常啟動預設全螢幕，F11 切換，操作說明位於設定／F1。小王血量為玩家最大生命的 2 倍，大王 3 倍；多人以隊伍最高 `max_hp` 為基準，包含倒地隊友，不再疊乘敵方難度或雙人倍率。普通難度玩家 120 HP，對應小王 240、大王 360 HP。

倒地與起身中的玩家、敵人均免受擊；玩家起身以小範圍推開附近敵人，傷害只有 2 點，並保護 45 tick，大小王起身仍會無傷震飛站立的近身玩家。玩家死亡保持倒地，全滅時相機留在倒地隊伍位置。畫面右緣不顯示尚未開放的區域，GO 等待期間也不提前露出；同圖已清空的左側可回頭拾取補給。前後景交界有透明草木、土堆、疏欄，室內屏風與櫃子會阻擋移動；食物拾取有三種音效及人物輪廓閃光。

## 開啟與執行

使用 **Godot 4.7.2 Standard** 開啟 `game/project.godot`，按 F5 執行專案。引擎執行檔需自行安裝，不放進 Git。

也可以在 PowerShell 指定已安裝的引擎：

```powershell
$env:GODOT_BIN = 'C:\你的工具目錄\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT_BIN --path ./game --editor
& $env:GODOT_BIN --path ./game
```

根目錄的啟動 `.cmd` 沿用本機慣例，預期引擎位於 `tools/godot-4.7.2/`；若使用其他位置，直接使用上述指令即可。遊戲內 F1 顯示操作說明；完整操作與模式見 [操作說明](README-試玩.md)。

## 修改位置

| 路徑 | 用途 |
| --- | --- |
| `game/main.gd`、`game/main.tscn` | 主入口、選單與輸入流程 |
| `game/core/` | 戰鬥狀態、招式、移動、命中與合作遊玩 |
| `game/data/stage-01.json` | 第一關七場景／十四據點的區名、敵波、將領、物件、補給、天候與配樂 |
| `game/render/` | 畫面繪製、逐格播放、素材裁切與特效 |
| `game/assets/` | 實際使用的連續圖片、registration、提示詞與來源記錄 |
| `game/render/combat_audio.gd`、`game/audio/` | 音效邏輯、已生成的語音與背景音樂 |
| `assets/` | 定案草圖、早期原圖與量測來源，供後續角色調整 |
| `game/tests/`、`scripts/` | 邏輯測試、素材登錄、畫面擷取與驗證工具 |
| `docs/` | 角色規格、招式設計與可填寫的驗收流程 |

素材按版本分目錄；較舊版本仍可能被主程式或登錄腳本引用，不能只因版本較舊就刪除。保留 `.uid` 和 `.import` 設定，Godot 的 `.godot/` 快取會在本機重建。

新增或調整角色先依 [人物建構與驗收流程（含 v0.19 節奏規則）](docs/人物建構與驗收流程-v0.17.html) 逐項處理。新製動作可用六個真正關鍵姿勢，今川敵兵步行為「開 → 窄 → 交錯 → 換腿開 → 窄 → 交錯」，每張 10 tick、完整一秒；停止移動直接回站姿。既有主角 12 張素材保留，不因減少張數壓縮播放時間。該頁可直接用瀏覽器開啟，驗收紀錄留在瀏覽器本機，並支援匯出／匯入 JSON；流程頁本身不代表全部項目已獲人工驗收。

第一關與未來 24 關的將領候選見 [關卡設計頁（已同步 v0.20 規則）](docs/第一關與24關設計-v0.19.html)，每個場景、據點與未來關卡均可保存評論。主選單「一人出陣」與「二人共鬥」進入正式第一關；工程入口的陣營選擇用於練習／陣營試戰。第一關沿用今川路線，其他 23 關目前是規劃清單。v0.18 設計頁與資料快照保留作歷史對照。

## 驗證

安裝 Node.js，並設定上述 `GODOT_BIN` 後，在儲存庫根目錄執行：

```powershell
node scripts/test-character-workflow-v17.mjs
node scripts/test-stage-design-v19.mjs
node scripts/test-v19.mjs
node scripts/test-v19.mjs --only=menu_v20,combat_v20,audio_v20,typography_v20,music_integration_v14 --render-v20
```

現有 runner 名稱沿用 `test-v19.mjs`。核心檢查涵蓋七場景／十四據點流程、逐波人數、定時增援、畫外入場與避障、80% 步速、王血比例、倒地保護、玩家與大小王起身、死亡相機及三主角攻擊通關。通關 fixture 每 tick 補回玩家生命，保留正常 `max_hp` 與王血比例，只驗證可通行與戰鬥接線，不代表玩家難度或實際遊玩時間。

v0.20 新增選單、三路音量、實際音樂循環邊界、渲染器字重及戰鬥規則測試；`--render-v20` 擷取正式選單和三位主角／雙人全滅畫面，並檢查倒地最後一格、鏡頭位置、特效消退及繪圖不修改世界狀態。截圖在 `artifacts/native-v20/`，日誌與逐次報告仍在 `artifacts/native-v19/`。runner 將測試程序的使用者資料導向該目錄，不改玩家真正的音量設定。既有場景與角色截圖用 `--render`，既有角色切圖檢查用 `node scripts/test-v17.mjs`。自動化輸入與渲染通過，不等同實體搖桿及真人聽感已驗收。

若需重做圖片量測或驗證輪廓，Python 環境須具備 `Pillow`、`numpy`、`scipy`。例如先跑 v0.17 Godot 測試，再產生本多逐格證據並驗證：

```powershell
& $env:GODOT_BIN --path ./game --audio-driver Dummy --log-file "$PWD/artifacts/tadakatsu-clips-engine.log" --script res://tests/capture_tadakatsu_clips_v17.gd
python scripts/verify-tadakatsu-atlas-v17.py --require-final
```

`artifacts/` 僅有六份固定 JSON 例外納入版控：三份本多切圖／來源雜湊基準、v10 原圖元件量測，以及 v14、v15 素材來源記錄。它們是測試與既有工具的輸入，並非試玩包或生成報告。

## 素材與交付範圍

主程式可直接使用儲存庫內既有 PNG／WAV。重新生成語音需另外準備相應模型與 Python／GPU 環境；圖片生成的歷史 JSON 可能記錄原工作機的絕對路徑，該路徑僅供追溯，不是執行遊戲的前提。不要把金鑰、模型快取或本機環境檔提交上來。

v0.20 標題與城郭背景使用原創圖形，提示詞、參考構圖與原圖雜湊在 `game/assets/v20/title/source-notes.json`。選單與遊戲文字共用 `game/render/game_typography.gd`；內附 Noto Serif TC 字型、來源及 OFL 授權，以粗體與金白描邊近似街機質感，未抽取原作字型。

第一關場景圖的來源與裁切量測保留在 `game/assets/v18/` 與 `game/assets/v19/scenery/` 的 `prompts.json`、`registration.json`；可用 `scripts/register-stage-v18.py`、`scripts/register-stage-v19.py` 重新驗證。四首循環配樂的生成方式見 `scripts/generate-stage-bgm-v18.py`，既有檔案可加 `--verify` 檢查。

今川軍足輕、旗手、指揮官、弓兵、鐵砲手、小王與獨立松井大王的正式圖源在 `game/assets/v19/enemies/`。登錄涵蓋 54 組站立、步行、攻擊、受擊、掙扎與死亡 clip，圖片來源及提示詞保留於該目錄的 journal JSON；`python scripts/register-enemies-v19.py --check` 核對來源雜湊、完整裁切、腳點與六步姿勢差異。身高按解剖尺度登錄，不以每張圖的外框高度拉伸人物；每格使用獨立透明邊界，避免相鄰圖滲入。`test_enemy_art_v19.gd` 逐狀態禁止退回舊版低解析圖源。

試玩 ZIP、錄影、Godot 執行檔、匯出包、快取與舊規劃網站皆排除版控。`scripts/package-native.ps1` 保留為日後需要時的交付工具，須先放妥本機 Godot 執行檔；本次原始碼整理不產生或上傳試玩包。

自動化測試驗證程式與素材接線；實體搖桿、震動、真人聽感及動作觀感需另外依流程驗收。
