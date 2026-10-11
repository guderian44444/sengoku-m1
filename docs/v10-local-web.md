# M1 v0.10 本機展示整合

本輪保留原網站與 owner／guest 留言流程；新增 `#combat-v10`、`#controls-v10`、`#factions-v10`、`#voice-v10` 展示段落。評論仍寫入既有 `art`，建議內容以「v0.10／角色或陣營／動作」開頭。既有 35 個評論 ID、24 關逐關意見、v0.9 影片與素材皆保留。

## 展示內容

- 60 秒 1280×720 原生鍵盤影片 `M1-v10-六武將試戰.mp4`，含音軌，25,720,945 bytes。內容為六主角與毛利軍／木樁，並非十二陣營全展示；其他陣營另看動作檢視台。
- 六主角的防禦、受擊、擊飛、倒地、暈眩、起身逐格檢視；新四角色另有普通攻擊與技能板。等速換格僅供畫格審閱，正式節奏由原生戰鬥計算。
- 十二陣營沿用已確認 v0.8 兵裝基底，另列小王兵器與三招。陣營代表沿音訊 manifest，霞標明原創；這不是完成 24 關劇情。
- 十一個新增陣營的普通兵使用 26 張有效動作板，合計 55 個兵種分組、704 張實繪畫格；部分兵種採獨立板補齊招式，不重複畫格湊數。毛利軍保留既有動作台。
- 操作表共用 `game/controls-v10.json`，網站副本 `planning-site/lib/controls-v10.json` 必須相同；含六角色、PS5、雙點衝刺、防禦、木樁滿怒例外。
- 126 段原生語音中選 36 段上網站：六角色各登場／出招／受擊／必殺，十二小王各登場。全部為合成測試聲，不是真人演員配音或聲音複製；技術解碼不等於聽感驗收。
- 原生下載目標 `/native/吞食戰國-M1-v0.10-Windows.zip`；檔案未就緒時顯示準備中，不提供壞的下載連結。

## 檔案與檢查入口

- 頁面：`planning-site/app/combat-v10-showcase.tsx`。
- 動作：`planning-site/public/art-v10`，取自原生 atlas 與 renderer 的 runtime registration；後者保留裁切、支點與 polygon 邊界。
- 試聽清單：`planning-site/lib/audio-samples-v10.json`；36 段 WAV 約 3.6 MB。
- 自動頁面檢查：`planning-site/tests/v10-check.mjs`。含六英雄／19 列一致性、48 組畫格變化（含新四角待機）、十二陣營、36 段 WAV 解碼、播放推進、切換停止、既有評論入口與手機／200% 排版。
- 普通兵檢查台從最終 runtime registration 全部 actor 的 `groups` 讀取各陣營動作板，依足輕、旗手、指揮官、弓兵、鐵砲手排序。動作可以分置獨立素材板，不受 a／b 板限制；沒有對位資料時清楚標示仍在整理。毛利沿用既有六兵種台。
- `planning-site/tests/v10-troops-check.mjs` 要求十一陣營各五個普通兵分組，近戰每種 16 格、遠程每種 8 格；驗證來源 PNG、支點與裁切資料完整，並在瀏覽器比較全部 176 組動作各四個不同畫格。此檢查須在所有素材 READY 後執行，不以占位圖通過。
- 本機命令：`npm.cmd run dev`、`node node_modules/typescript/bin/tsc --noEmit`、`node tests/self-check.mjs`、`node tests/v10-check.mjs`、`npm.cmd run build`。Playwright 可透過 `PLAYWRIGHT_PACKAGE` 指向可用安裝。

此輪僅做本機整合與檢查，不發布 Sites、不提交 Git。真實 PS5、跨電腦網路、真人聽感與最終美術銜接仍需相應實玩驗收。

## 本輪已完成的檢查

2026-10-10 本機檢查：TypeScript、既有 self-check、`npm.cmd run build` 通過。`v10-check.mjs` 在 Edge headless 通過既有主角畫格變化、六人操作表與原生 JSON 相同、十二陣營、36 音檔實際解碼、播放時間推進、切換停止，以及 390px 手機／768px 200% 字體無頁面溢出。首次找到素材板沿用負 margin 在 200% 下溢出，已限制在 v10 區段修正。截圖位於 `planning-site/.sites-runtime/qa-v10`，已人工檢視人物逐格台與語音區的桌面、手機畫面。

語音測試以靜音播放確認解碼與時間推進；未宣稱實際聽感或真人配音驗收。

既有 `combat-check.mjs` 亦通過：60 秒 v0.9 影片、六兵種各四組動作逐格差異、播放速度、16 列舊操作表、既有評論入口及手機／200% 排版。為支援同頁兩個版本，只將該測試的截圖 selector 限定至 `#combat-v09`，未更動舊版展示行為。

最終 runtime registration 與 65 個 active actor PNG 同步後，已重跑並通過 `v10-check.mjs`：48 組主角畫格（含四角待機與往返播放），以及 `v10-troops-check.mjs`：26 張有效普通兵板、55 兵種、176 組動作各四個不同畫格。逐格資料同時檢查來源、支點與裁切；桌面與手機截圖已人工檢視。另修正網頁普通兵固定支點，讓最長旗桿完整落在畫布內，沒有逐格縮放造成大小跳動。

最終影片替換後，另驗證網站副本與原始影片逐位元相同，瀏覽器能解碼 60.000 秒、1280×720 並實際推進播放；SHA256 為 `8341F7463EA13F3C5AF75F9FD55B5FBA1424F6ABC41F6BD883CE1F2313B10A5D`。65 張 active PNG、runtime registration 與網站下載版 README 也都與原生來源逐位元相同。最後一次 `npm.cmd run build` 通過；Windows ZIP 下載按鈕實際可見。

原生整合驗收由根任務執行 `scripts/test-native.mjs` 全套通過，含 499 項音效與 38 項輸入檢查、既有回歸，以及同機雙人與結局同步。增加 0.7 秒客端延遲並丟棄初次登場事件的情境仍通過：主機會等客端台詞播完才恢復戰鬥。此結果不代表跨電腦／WAN 驗收；本輪沒有接上真實 DualSense，語音的實際聽感仍待人工審閱。

## 原生套件與下載

`吞食戰國-M1-v0.10-Windows.zip` 共 323,557,652 bytes，SHA256 為 `3B2B72A212A8F494060D8BADAA93E067B054BD51595A834084A26574D10DD964`。ZIP 與 `.sha256` 已複製到 `planning-site/public/native`；經本機 HTTP 完整串流下載，回應為 HTTP 200／`application/zip`，實際大小與 SHA256 均和原檔相同。

根任務另驗證 ZIP 內 343 個 entry 與來源逐檔 SHA 相同，並在全新目錄解壓後，以包內 Godot 執行 `test_input_v10`（38 checks）和 `test_render_v10 --require-v10 --require-factions`，全部通過，不依賴工作目錄快取。紀錄：`artifacts/package-v10-verification.json`。
