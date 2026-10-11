# 吞食戰國：主程式與角色素材

此儲存庫保存可繼續修改的 Godot 專案、連續圖片、音效、素材登錄工具與人物驗收流程。目前專案版本為 **0.17.0**，包含信長、阿市的既有功能，以及本多忠勝的完整動作登錄、切圖修正、槍底震地與平順突進。

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
| `game/render/` | 畫面繪製、逐格播放、素材裁切與特效 |
| `game/assets/` | 實際使用的連續圖片、registration、提示詞與來源記錄 |
| `game/render/combat_audio.gd`、`game/audio/` | 音效邏輯、已生成的語音與背景音樂 |
| `assets/` | 定案草圖、早期原圖與量測來源，供後續角色調整 |
| `game/tests/`、`scripts/` | 邏輯測試、素材登錄、畫面擷取與驗證工具 |
| `docs/` | 角色規格、招式設計與可填寫的驗收流程 |

素材按版本分目錄；較舊版本仍可能被主程式或登錄腳本引用，不能只因版本較舊就刪除。保留 `.uid` 和 `.import` 設定，Godot 的 `.godot/` 快取會在本機重建。

新增或調整角色先依 [人物建構與驗收流程 v0.17](docs/人物建構與驗收流程-v0.17.html) 逐項處理。該頁可直接用瀏覽器開啟，驗收紀錄留在瀏覽器本機，並支援匯出／匯入 JSON；流程頁本身不代表全部項目已獲人工驗收。

## 驗證

安裝 Node.js，並設定上述 `GODOT_BIN` 後，在儲存庫根目錄執行：

```powershell
node scripts/test-character-workflow-v17.mjs
node scripts/test-v17.mjs
```

第二項會執行 12 組 Godot 檢查，包含戰鬥、連段、人物切圖、本多招式與雙人啟動。需要原生畫面擷取時使用 `node scripts/test-v17.mjs --render`；擷取及報告寫入本機 `artifacts/`，不提交 Git。

若需重做圖片量測或驗證輪廓，Python 環境須具備 `Pillow`、`numpy`、`scipy`。例如先跑上面的 Godot 測試，再產生新版逐格證據並驗證：

```powershell
& $env:GODOT_BIN --path ./game --audio-driver Dummy --log-file "$PWD/artifacts/tadakatsu-clips-engine.log" --script res://tests/capture_tadakatsu_clips_v17.gd
python scripts/verify-tadakatsu-atlas-v17.py --require-final
```

`artifacts/` 僅有六份固定 JSON 例外納入版控：三份本多切圖／來源雜湊基準、v10 原圖元件量測，以及 v14、v15 素材來源記錄。它們是測試與既有工具的輸入，並非試玩包或生成報告。

## 素材與交付範圍

主程式可直接使用儲存庫內既有 PNG／WAV。重新生成語音需另外準備相應模型與 Python／GPU 環境；圖片生成的歷史 JSON 可能記錄原工作機的絕對路徑，該路徑僅供追溯，不是執行遊戲的前提。不要把金鑰、模型快取或本機環境檔提交上來。

試玩 ZIP、錄影、Godot 執行檔、匯出包、快取與舊規劃網站皆排除版控。`scripts/package-native.ps1` 保留為日後需要時的交付工具，須先放妥本機 Godot 執行檔；本次原始碼整理不產生或上傳試玩包。

自動化測試驗證程式與素材接線；實體搖桿、震動、真人聽感及動作觀感需另外依流程驗收。
