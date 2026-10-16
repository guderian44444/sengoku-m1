# 各頁 MasaFont 與02紅錦卷軸交接

使用者已核准實際正風毛筆預覽，這次將原版MasaFont Regular與02紅錦無字底接入各頁，文字由Godot動態繪製。分支 `feature/ui-masafont-scroll02`，基於遠端main `30fdac03`；首頁音樂獨立於[Draft PR #9](https://github.com/guderian44444/sengoku-m1/pull/9)。兩批都未merge或發布。本機友軍main為`f553400c`，另有未提交戰鬥／舊資產整理工作；提交前確認其UI／音樂來源沒有後續差異，本次不拷貝或覆寫該工作樹。

## 原生截圖與可傳輸檔案

[單檔原生驗收包](ui-scroll02-proof/UI-MasaFont-Scroll02-Native-Proof.zip)包含15張實際頁面：首頁、主選單、玩家名簿、武將名簿、角色與行囊、倉庫、圖鑑、戰功、聲畫、演武／連線、確認、字盤、戰場HUD、暫停、操作說明；另有四種輸出尺寸與五種真實控制項狀態。包大小 16923988 bytes，SHA256 `a7d79cbec55edb1f4e944ea3a42ba5e149c872fdc2764a902e259906475b9eab`，可直接從GitHub取得供雲端再存Library。原生驗收包已保存Library `libfile_17c5b08ae054819199ae7f7e1a111aac`；亦提供GitHub檔案供雲端取得。 代表頁另已保存9張可直接檢視的Library圖片，[識別碼、檔名與版本](ui-scroll02-proof/library-files.json)一併交付。

| 畫面 | 原生PNG |
|---|---|
| 首頁 | [title](ui-scroll02-proof/title.png) |
| 主選單 | [main](ui-scroll02-proof/main.png) |
| 選角與裝備 | [select](ui-scroll02-proof/select.png) |
| 倉庫與分類 | [collection](ui-scroll02-proof/collection.png) |
| 設定 | [options](ui-scroll02-proof/options.png) |
| 姓名字盤 | [keyboard](ui-scroll02-proof/keyboard.png) |
| Normal／Hover／Focus／Pressed／Disabled | [真實Button狀態](ui-scroll02-proof/native-button-states.png) |
| 小尺寸960×540 | [native 960](ui-scroll02-proof/main-960x540.png) |
| 大尺寸1920×1080 | [native 1920](ui-scroll02-proof/main-1920x1080.png) |

圖片是引擎viewport直接輸出的原始PNG，未用圖片生成或後製替代遊戲畫面。狀態頁是同一Theme下的真實Button，hover透過viewport滑鼠事件、focus為實際焦點、pressed為Button按下狀態；不是將不同字樣烘焙在底圖上。

## 字型、來源與授權

- 字型為[官方masafont](https://github.com/max32002/masafont) `tw/MasaFont-Regular.ttf`，官方archive commit `8fa528cc22be3294af172634fc6ef70288d5f776`，Version 2.1。SHA256 `f5a449d3a9ce2170e404050cc2b44bfa16ae48ef8fb06aa5968383ed74e5ed4d`；核准Library包與官方原檔位元組一致。
- 保留[內嵌OFL 1.1原文](../game/assets/current/fonts/MasaFont-OFL.txt)、[官方README](../game/assets/current/fonts/MasaFont-UPSTREAM-README.md)及[來源資料](../game/assets/current/fonts/MasaFont-SOURCE.txt)。沒有執行repository腳本、安裝系統字型、修改字型或使用Medium／Bold。
- 核准素材包Library `libfile_b9ddbbbe928081918726f4bb0a5a7d91`，`MasaFont_scroll02_preview_pack.zip`，SHA256 `8fd523e68c5da8b73a5a4864be2a653849fd4314adae47c8c481f594165d0758`。15個payload SHA全部符合；原包SHA256.json帶有舊的自我雜湊，不能驗成自身雜湊，已明列此來源索引限制。實際字型及底圖皆逐檔驗證。
- 只接入無字`scroll02_blank.png`，SHA256 `adb7dc6c39225a2005b7bf5952dda1f3a91f5cebc3131969401ce86b04609daf`。沒有載入預覽label圖或button預烘焙文字圖；[原包交接](../game/assets/current/ui/scroll02/HANDOFF.txt)、[原始索引](../game/assets/current/ui/scroll02/SHA256.json)、[身分與例外](../game/assets/current/ui/scroll02/source-library.json)保留可查。

## 接入與版面

`game_typography.gd`改用真MasaFont Regular，主字型與兩個離線缺字fallback的`variation_embolden`均為0；Controls outline_size=0，Canvas文字不再疊偏移黑描邊。罕用字仍由既有Noto Serif TC與reference fallback補齊，不依賴系統字型。

共用`WashiButton` StyleBox改為02紅錦卷軸；保留原PNG，只於繪製時略過透明外圍，以高度維持兩端軸頭比例，中央紙面水平延展，窄按鈕也保留中央文字區。字與底圖分離；下拉選單、勾選、頁籤、字盤與各頁按鈕沿用共用Theme。選中清單使用淺金紙與深墨字；焦點有金色角標及亮色記號，hover增亮、pressed壓暗、disabled降低色彩與透明度。

保留所有既有按鈕文字、信號、確認流程、鍵盤與手把操作；沒有修改Battle、存檔、AI、角色動作或音樂程式。首頁／主選單主按鈕字級26、最小高度54，其餘依既有頁面17–22等字級；增加安全文字邊距，首頁提示改淺色，去掉主選單按鈕群外的深褐大底。UI圖片採線性過濾，1280×720設計空間與canvas_items／keep縮放沿用。

320×68、850×180原預覽只是示意尺寸，未當成遊戲固定尺寸。測試使用960×540、1280×720、1366×768、1920×1080，主按鈕均在設計空間與footer之上，長字保留可讀中央紙面。

## 實際驗證

[完整結果](ui-scroll02-proof/validation.json)：六組相關測試最新結果全數通過：ui_scroll02、ui_input_v34、ui_theme_v34、ui_panels_v34、ui_flow_v34、menu_pad_v27。字庫檢查涵蓋實際程式／資料文字與常用UI原生字形；保留長20字名號、十億數值、120件倉庫、長說明捲動及圖鑑選取等原有測試。

原生15頁流程228 checks／exit 0；原生四種尺寸與五種控制項狀態92 checks／0 failures、exit 0。已視覺檢視首頁、主選單、選角、倉庫、字盤、說明、狀態頁及960輸出。這些是合成輸入與原生畫面，沒有宣稱實體雙搖桿／震動、使用者最終視覺或正式發行包已驗收。

```powershell
$env:GODOT_BIN='D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
node scripts/test-v19.mjs --only=ui_scroll02,ui_input_v34,ui_theme_v34,ui_panels_v34,ui_flow_v34,menu_pad_v27
```


## 新音效需求的只讀接入備註

本次未修改音效runtime。依友軍目前v38資料：刀風`sword_whoosh` -17dB、重刀風`sword_heavy_whoosh` -15dB；砍中`hit` -17dB／`heavy_hit` -13dB；射箭`bow_release` -15dB、重箭`bow_heavy_release` -14dB、箭中`arrow_hit` -17dB；棍風`blunt_whoosh` -17dB、棍中`blunt_hit` -17dB／`blunt_heavy_hit` -13dB。這些採樣各5個take、輪袋避免連續重複；`CombatAudio`為6個輪用SFX播放器，繁忙時會取代舊聲音，沒有另加時間冷卻。`run_bump`目前映射`blunt_hit`，沒有專屬衝撞音；`weapon_swing`依weapon與action分流，`swing`本身不出風聲。

蓄力／旋轉另由VFX2 recipe的`*_charged_wave`／`*_growing_spin`管理，以`blade/fire/ice/wind/lightning`的`*_charge_loop`、`*_release`、`*_hit`等分段事件對接。蓄力loop基準-24dB並隨進度-8→0dB，單次基準-18dB並隨進度-2→0dB；另有強度、距離、分層與語音ducking（-6dB），不能只換檔卻重複觸發。控制器最多12播放器、單實例5個，超額優先取代舊單次音，釋放／取消會停蓄力loop；emitter最多48效果、遲到音訊窗口6tick。`shared_sfx=true`會跳過CombatAudio，避免雙播。後續包到齊再獨立驗聲、接線與調混音。
