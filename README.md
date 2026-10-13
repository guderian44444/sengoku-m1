> DOT 原始交付與美術追溯：[HANDOFF.md：48 武器＋信長 v25＋阿市 v26](HANDOFF.md)。現版操作以 [README-試玩.md](README-試玩.md) 為準。

# 吞食戰國：主程式與角色素材

此儲存庫保存可繼續修改的 Godot 專案、連續圖片、音效、素材登錄工具與人物驗收流程。目前專案版本為 **0.30.0**，已開放兩個大關。第一關「桶狹間竹林」採七個長場景、十四個據點、31 波攻防；第二關「大高兵糧道」有六個新場景、十二個據點、26 波攻防。同景內清場顯示 GO、走到底才換背景。敵人從畫面外左右進場，雙人每波雜兵數量增加 50% 並向上取整；大小王步速為目標角色步行的 80%，大王存活時每 30 秒呼叫一波增援。

v0.30 接入友軍核准的阿市 26 組動作與秀吉 39 組動作。秀吉改用打刀、固定葫蘆扇，必殺一次串接三段；舊槍保留在行囊，可查看或出售。護符共 30 款，一次裝備一件，高階款提供數項小幅 BUFF；功能、數值與史料題材見 [護符設計](docs/TALISMANS-V30.md)，接入與驗證界線見 [v0.30 試玩記錄](docs/PLAYTEST-V30.md)。

六名武將各自固定原創合成參考聲線，完整台詞與短喊共 96 段。發力、重手、受傷及勝利各有三段；忠勝以自身低沉錄音播放，取消 runtime 降音高。聲線設計、播放規則、試聽位置及檢查界線見 [六人獨立聲線](docs/VOICES-V30.md)。

v0.29 第二關從朝霧街道經渡口、米倉、夕照坂道，攻入丸根砦。新增盾槍兵、火箭兵、搶糧兵，以及兩段可選的糧車護送；完成各得 300／450 金，失敗仍可通關。背景、生活布景與路人按區域配置；人物及武器以當前姿勢投影簡易動態陰影，腳底保留接觸影。通過第一關後，在選角頁的大關選單選第二關；既有第二關進度可直接續玩。完整內容與驗證界線見 [第二關 v0.29](docs/PLAYTEST-V29.md)。

v0.28 重整選角與裝備：左側站姿及實際能力，右側護身符與武器，換裝立即更新。新增具獨立 JSON 存檔的本機玩家、每武將 120 件行囊、重複武器、逐件耐久、物品出售與 30 種成就。六人各有自己的白板練習武器；蜻蛉切改為可收集名槍。武器掉落為小兵 5%／小王 15%／大王 30%，特殊表現另有 10% 掉寶。完整規則及驗證見 [v0.28 玩家與武器平衡](docs/PLAYTEST-V28.md)。

v0.27 的語音、戰後拾取、退出確認及阿市箭式修正延續，歷史記錄見 [v0.27 試玩修正](docs/PLAYTEST-V27.md)。

v0.22 已將信長、阿市、本多忠勝重畫為與正式今川敵軍一致的畫風：信長 25 組、阿市與本多各 26 組，共 **77 動作組、462 格真正新姿態**，每組六格。人物身體與刀／弓／槍分層，握點、武器角度、手部遮擋和腳底錨點逐格登錄；頭像也使用新版人物。信長待機、走跑採頭側雙手立刀，三輕手依下斬、上撩、橫切銜接；阿市保留苗條腿型、白色內搭、長馬尾與簡單頭飾、背弓、轉身高踢和露肩慶祝；本多保留鹿角兜、念珠、代表長槍與槍底震地。其餘三位可選角色沿用既有圖源，未宣稱已完成細節重畫。

刀、槍、弓各 16 款收藏武器，加六件各人物專用的白板，共 54 件。武器具有傷害、攻速、範圍、擊退、特殊效果與耐久；相同武器可收多件，各自消耗耐久。名稱與形制的史料、原圖與圖鑑維持原有來源；階位與能力屬遊戲設計。

正式主選單與選角提供「玩家設定」。每位本機玩家一個 `user://players/player-*.json`，分武將保存積分、永久生命加成、行囊、裝備、耐久、金錢與成就；大關進度屬於該玩家。舊 `characters-v1.json` 的 1P／2P 進度可轉入兩名玩家，原檔保留。有效備份、損毀原件保留及未知版本保護延續。再次出陣從大關起點、滿血三條命開始，不保存戰鬥中位置、生命或剩餘命數。

選角左側顯示完整站姿與能力，右側即時換裝。物品管理／出售和暫停裝備頁顯示每件物品圖片、能力、簡介、耐久及售價；出售有確認，購買入口暫時停用。百分比／定值護身符可替換，頭上圖示表示 BUFF，已取消周身光暈。

v0.20 基準已先提交為 `915690d`。v0.21 信長普通重手第一／二段的前方判定增加到 200／230 世界單位，劍氣顯示共用同一範圍。工程選單修正下拉取得焦點時切頁造成的原生崩潰，覆蓋毛利軍與其他陣營、武將及難度下拉。

每位玩家起始三條命（包含目前這條），死亡後倒地約兩秒，落地後滿血起身並保護三秒；命數用完才出局，雙人只要仍有人能戰鬥或等待復活就繼續。各自計分，每累積 10,000 分加一命，跨區保留；擊殺足輕 100、旗手／弓兵 150、鐵砲兵 200、指揮官 300、小王 1,500、大王 5,000，破壞物件 50，歸最後造成致命傷的玩家。訓練場不扣命、不計分。

金剛／玄鐵／明鏡護身符抵消 40／75／110 點傷害；疾風／武神／月影御守提供初始 15%／25%／35% 減傷。御守按抵消傷害消耗耐久，減傷率跟隨耐久比例下降，剩 20% 時損壞；御守另提供速度、攻擊或範圍加成。每件都存入行囊並可換裝。詳見 [v0.28 規則](docs/PLAYTEST-V28.md)。

竹林／庭園使用舒緩簫聲風格，市集使用鈴鼓與木敲節奏；小王與大王分別切換兩首緊張太鼓配樂，擊敗後切回區域音樂。新曲為原創合成音色，非原作擷取或實錄樂器；四首都循環並沿用音樂獨立音量及漸變銜接。

開始畫面以圖形標題、書法字形與街機排版呈現；按下開始後進入正式主選單，選「一人出陣」或「二人共鬥」，再選武將、難度並出陣。「遊戲設定」分開調整音樂、音效與語音音量並自動保存，音樂在每個區段循環，暫停與結果畫面也持續播放。底部暫留「工程入口」，收納練習、陣營試戰、素材展示及 IP 直連，正式發行前再移除。

上方顯示頭像、生命與氣條，不顯示波數；正常啟動預設全螢幕，F11 切換，操作說明位於設定／F1。小王血量為玩家最大生命的 2 倍，大王 3 倍；多人以隊伍最高 `max_hp` 為基準，包含倒地隊友，不再疊乘敵方難度或雙人倍率。普通難度玩家 120 HP，對應小王 240、大王 360 HP。

倒地與起身中的玩家、敵人均免受擊；玩家起身以小範圍推開附近敵人，傷害只有 2 點，並保護 45 tick，大小王起身仍會無傷震飛站立的近身玩家。玩家最後一命死亡保持倒地，全滅時相機留在倒地隊伍位置。畫面右緣不顯示尚未開放的區域，GO 等待期間也不提前露出；同圖已清空的左側可回頭拾取補給。前後景交界有透明草木、土堆、疏欄，室內屏風與櫃子會阻擋移動；食物拾取有三種音效及人物輪廓閃光。

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
| `game/core/weapon_catalog.gd`、`equipment.gd`、`player_store.gd`、`save_profile.gd` | 武器相容、歷史來源、效果與角色屬性／裝備保存 |
| `game/data/stage-01.json`、`stage-02.json` | 兩關的區名、敵波、將領、物件、補給、天候、配樂及護送配置 |
| `game/render/` | 畫面繪製、逐格播放、素材裁切與特效 |
| `game/render/weapon_renderer.gd`、`game/assets/v22/` | 三主角六格身體、48 款武器、握持／遮擋分層與新圖頭像 |
| `game/assets/` | 實際使用的連續圖片、registration、提示詞與來源記錄 |
| `game/render/combat_audio.gd`、`game/audio/` | 音效邏輯、已生成的語音與背景音樂 |
| `assets/` | 定案草圖、早期原圖與量測來源，供後續角色調整 |
| `game/tests/`、`scripts/` | 邏輯測試、素材登錄、畫面擷取與驗證工具 |
| `docs/` | 角色規格、招式設計與可填寫的驗收流程 |

素材按版本分目錄；較舊版本仍可能被主程式或登錄腳本引用，不能只因版本較舊就刪除。保留 `.uid` 和 `.import` 設定，Godot 的 `.godot/` 快取會在本機重建。

新增或調整角色先依 [人物建構與驗收流程（已加入 v0.22 分層與六格規則）](docs/人物建構與驗收流程-v0.17.html) 逐項處理。三位新主角與今川敵軍步行為「開 → 窄 → 交錯 → 換腿開 → 窄 → 交錯」，六張各 10 tick、完整一秒；三位新主角跑步為 45 tick 一輪，停止移動立即回站姿。較舊主角 12 張素材保留供歷史／回歸，不作三位新版動作的缺圖替代。該頁可直接用瀏覽器開啟，驗收紀錄留在瀏覽器本機，並支援匯出／匯入 JSON；流程頁本身不代表全部項目已獲人工驗收。

第一關與 24 關的將領候選見 [原關卡設計頁](docs/第一關與24關設計-v0.19.html)，每個場景、據點與未來關卡均可保存評論。主選單「一人出陣」與「二人共鬥」可選擇已解鎖大關；工程入口的陣營選擇用於練習／陣營試戰。第一關沿用今川路線，第二關採原規劃的大高兵糧道演義題材；其他 22 關仍為規劃。舊設計頁與資料快照保留作歷史對照，第二關實際內容以 stage-02.json 為準。

此前的 [v0.21 武器分層製作方案](docs/武器分層與六格角色製作方案-v0.21.html) 保留為歷史評估與評論記錄，其中 v12–v17 盤點不代表目前執行素材。v0.22 已實作三人身體重畫、同類武器外觀替換、Boss 掉落、HUD 武器欄與角色存檔；實際圖源及登錄在 `game/assets/v22/`，以新版原生渲染與當次測試報告驗收。

## 驗證

安裝 Node.js，並設定上述 `GODOT_BIN` 後，在儲存庫根目錄執行：

```powershell
node scripts/test-v19.mjs --only=stage2_route_v29,stage2_combat_v29,shadows_v29 --render-v29
node scripts/test-v19.mjs --only=inventory_v28,menu_inventory_v28,balance_v28,wire,knockdown_v18,menu_pad_v27,exit_save_v27 --render-v28
node scripts/test-character-workflow-v17.mjs
node scripts/test-stage-design-v19.mjs
node scripts/test-weapon-plan-v21.mjs
node scripts/test-v19.mjs
node scripts/test-v19.mjs --only=progression_v21,music_v21,engineering_menu_v21,render_items_v21,wire --render-v21
node scripts/test-v19.mjs --only=menu_v20,combat_v20,audio_v20,typography_v20,music_integration_v14 --render-v20
node scripts/test-v19.mjs --only=weapons_save_v22,loadout_menu_v22,weapon_render_v22 --render-v22
node scripts/test-v19.mjs --only=hero_layers_v22 --render-heroes-v22
node scripts/test-v19.mjs --only=collection_progress_v26,weapon_expansion_v24,weapon_encyclopedia_v23,weapons_save_v22,loadout_menu_v22 --render-collection-v26
python scripts/verify-handoff.py --assets-only
```

現有 runner 名稱沿用 `test-v19.mjs`。核心檢查涵蓋七場景／十四據點流程、逐波人數、定時增援、畫外入場與避障、80% 步速、王血比例、倒地保護、玩家與大小王起身、死亡相機及三主角攻擊通關。通關 fixture 每 tick 補回玩家生命，保留正常 `max_hp` 與王血比例，只驗證可通行與戰鬥接線，不代表玩家難度或實際遊玩時間。

v0.20 新增選單、三路音量、實際音樂循環邊界、渲染器字重及戰鬥規則測試；`--render-v20` 擷取正式選單和三位主角／雙人全滅畫面，並檢查倒地最後一格、鏡頭位置、特效消退及繪圖不修改世界狀態。截圖在 `artifacts/native-v20/`，日誌與逐次報告仍在 `artifacts/native-v19/`。runner 將測試程序的使用者資料導向該目錄，不改玩家真正的音量設定。既有場景與角色截圖用 `--render`，既有角色切圖檢查用 `node scripts/test-v17.mjs`。自動化輸入與渲染通過，不等同實體搖桿及真人聽感已驗收。

v0.21 新增生命／積分／護符與重手邊界測試、區域與大小王音樂切換、工程下拉失焦回歸及 HUD／護符渲染檢查。新曲可執行 `python scripts/generate-stage-bgm-v21.py --verify` 核對 PCM 雜湊、接縫、音量與削波；護符原圖、提示、透明切圖與 SHA 登錄在 `game/assets/v21/treasures/`，武器盤點由 `scripts/inventory-weapon-layers-v21.py` 重建。以上均不取代真人聽感及持刀動作驗收。

v0.22 的 `weapons_save_v22`、`loadout_menu_v22`、`weapon_render_v22` 覆蓋同類拾取、升階掉落、裝備效果、彈體屬性快照、1P／2P 角色保存、損毀回復、選角／暫停接線與實際武器繪圖。`hero_layers_v22` 對三人逐一檢查 40 種執行動作均使用新版六格來源；`--render-heroes-v22` 以正式 renderer 繪出六個時間點，證據與 `coverage.json` 存在 `artifacts/native-v22/hero-actions/`。蓄力保持、格擋、凍結會刻意停留，40 種 action 不等於 40 組獨立新圖。完整模式不允許回退舊圖；開發用 `--available` 局部結果不能代替全套。測試隔離玩家真實存檔，報告僅代表當次檔案與驗證層級，不預先宣稱後續素材修訂或真人操作已通過。

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

DOT 的 `verify-handoff.py` 預設仍檢查原交付全部程式快照；整合後新增裝備與大關邏輯，使用 `--assets-only` 核對完整美術 SHA，再跑上述遊戲測試。素材資料夾 README 保留製作階段的歷史描述，現行存檔／換裝規則以本文件與操作說明為準。`.gitattributes` 固定文字 LF，避免 Windows checkout 改變受 SHA 保護的 JSON 位元組。
