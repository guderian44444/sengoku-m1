> 歷史 v25 快照說明。最新阿市 v26 與一次交接入口請讀根目錄 [HANDOFF.md](../HANDOFF.md)；本文當時列出的阿市待辦現已完成，不作為最新狀態。

# 吞食戰國：48 武器＋三人色盤＋信長暗紅甲 v25 交接清單

本文件是本次 Git 交接入口。基底為 `2ac0688a8100b27b3a4fa958554aee8dcd3a1188`，包含先前 3 件武器／18 件圖鑑、v23 三人色盤、v24 新增 30 件武器，以及其後完成的信長暗紅甲 v25。專用分支：`handoff/weapons-48-palette-v25-20261012`。提交時間以 Git 記錄為準，未合併 `main`。

## 1. 已完成範圍

- [x] 48 件獨立武器 runtime PNG、來源素材、裁切／握點／尺寸 registration 與能力目錄。
- [x] 先前增加的美濃兼定、袋槍、竹木合弓保留；v24 刀、槍、弓各增加 10 件。
- [x] 48 條圖鑑、史料來源入口、照片授權狀態、裝備入口與相容角色查詢。
- [x] v23 角色色盤一致性資料；三人共 77 組、462 個作者畫格，姿勢、透明度、握點與註冊幾何保留。
- [x] 信長最終為 v25：25 動作／150 格，其中 17 張亮甲來源調暗，8 張原暗甲來源逐 byte 保留。披風、膚色、金邊及 48 把武器受保護。
- [x] 新武器原始生成圖、完整生成提示、來源 SHA256、alpha-only 清理規則、可重跑建置／檢查腳本。
- [x] 日文史料缺字 fallback 字型與 OFL 授權；選定 Godot headless 回歸與已知失敗證據。
- [ ] 使用者後續提出的「阿市裙長不變、側衩可露側腿、不露私密部位／內搭褲」服裝修改尚不在這個完成快照內，後續另交付。
- [ ] GUI、Windows／使用者電腦、人手控制器手感、跨機網路遊玩尚未驗證。

## 2. 友軍整合順序

1. 先把整合端的未提交變更另存／提交，再取得此分支；以 PR 或 cherry-pick 整合，勿用舊 ZIP 覆蓋整個新版專案。此分支可作完整專案 checkout，無須先找三個舊增量包。
2. 先檢查自己是否還在共同基底 `2ac0688`；若已有後續修改，逐檔處理 `main.gd`、`battle.gd`、武器 catalog／registration、圖鑑 UI 及角色 registration 衝突。不要回退其他人的功能。
3. 直接使用 Git 中已完成的 runtime 素材。角色正確最終 base 是「48 武器＋v23＋信長 v25」；v23 是重現前一階段的資料，不能拿 v23 輸出覆蓋信長 v25。不要在最終版重跑 `hero_palette_v23.py --apply`；它會拒絕不屬於舊階段的 hash。
4. 用下方 SHA／圖像檢查確認 48 件與 462 格，再讓 Godot 匯入 `game/project.godot`。`.godot`、此次產生的 `.import`、本機引擎、存檔及巨大影片不納入此交接；Godot 可重建快取。
5. 主選單「一人出陣」或「二人共鬥」→「選擇武將」→各玩家武器列旁「圖鑑」。檢查角色切換、列表捲动、實物來源／缺照提示、能力、預覽、裝備、返回／重開；兩名玩家分別驗證。
6. 測試撿取、掉落、裝備、存檔重載、雙朝向、弓弦／手部遮擋、長槍各招握點和箭矢命中。最後才進行 GUI／Windows 實機驗收與合併决定。

## 3. 關鍵檔案與資料責任

| 位置 | 內容／整合原則 |
|---|---|
| `game/core/weapon_catalog.gd` | 實際能力、掉落與角色相容性；能力唯一 runtime 依據 |
| `game/assets/v22/weapons/registration.json` | 48 件裁切、握點、長度、來源與 SHA；不要換成舊 18 件版 |
| `game/assets/v22/weapons/*.png` | 遊戲讀取的最終武器圖 |
| `game/assets/v22/weapons/sources/` | 原 18 件來源與新 30 件只清理 alpha 的來源 |
| `game/assets/v24/weapons/raw/` | 新 30 件未改動的原始生成 RGBA |
| `game/assets/v24/weapons/{art-spec30.json,generation/,alpha-processing.json}` | 提示、形制限制、逐檔來源及處理證據 |
| `game/assets/v22/weapons/encyclopedia.json` | 史料、尺寸、圖說、照片權利、來源，不代替能力 catalog |
| `game/core/weapon_encyclopedia.gd` | 圖鑑 loader；`stats(id)` 即時讀 catalog；照片嵌入與安全 URL 檢查 |
| `game/ui/weapon_encyclopedia_panel.gd`、`game/main.gd` | 圖鑑面板、選角入口、裝備與返回流程 |
| `game/core/battle.gd` | 新武器與既有投射物規則的整合 |
| `game/assets/v22/color-consistency.json` | v23 色盤參數與歷史基底 |
| `game/assets/v22/{nobunaga,oichi,tadakatsu}/` | 當前三人最終 PNG／registration |
| `game/assets/v25/nobunaga-dark-red.json` | v25 before／after hash、348 份不可動来源保護、17／8張清單 |
| `game/assets/v25/{cape-exclusion/,chest-adjustment/}` 與兩份 polygons JSON | 17 張披風保護及 6 張胸甲局部遮罩；可精確重建 |
| `artifacts/nobunaga-dark-red-v25/final-character-protection.json` | 三人最終 77 組／462 格之 after SHA，後續阿市修改前的基準 |
| `game/assets/v24/fonts/`、`game/render/game_typography.gd` | 明確隨附的缺字 fallback 與 OFL，不依賴 OS 字型 |
| `scripts/*weapons*v24.py`、`scripts/register-weapons-v22.py` | 來源處理、catalog 建置、登錄與預覽工具 |
| `scripts/nobunaga_dark_red_v25.py`、`scripts/test-nobunaga-dark-red-v25.py` | 暗紅甲可重現處理及逐像素不變量 |
| `artifacts/handoff-v25/` | 此次發布前，在最終合併快照上重新執行的檢查結果 |

能力只涵蓋既有傷害、距離、擊退與元素欄位；新增 30 件元素均為無。武器各自攻速、耐久、專用蓄力窗口、穿透系統沒有在本輪實裝。`implemented-stats.json` 是本輪快照，後續改平衡仍以 catalog 為準。

## 4. 可重跑驗證

已驗證工具鏈：Python 3.12.14、Pillow 12.3.0、NumPy 2.3.5、SciPy 1.17.0、opencv-python-headless 5.0.0.93；Godot 4.6.3 stable Linux headless；Node 24.19.0。圖像重建需相同版本避免 PNG byte hash 因編碼器不同而改變。影片預覽另外需要 FFmpeg，非 runtime 依賴。

建議以獨立 Python 虛擬環境安裝 `scripts/requirements-handoff-v25.txt`。不要把引擎或 Python 套件提交進 Git。若只啟動已完成專案，不需重建美術。

```sh
python scripts/verify-handoff-v25.py
python scripts/register-weapons-v22.py --check
python scripts/test-weapon-art-v24.py
python scripts/nobunaga_dark_red_v25.py --check
python scripts/test-nobunaga-dark-red-v25.py
python scripts/test-nobunaga-v22.py
GODOT_BIN=/path/to/godot TEST_ARTIFACT_DIR="$PWD/artifacts/recheck-v25" node scripts/test-v19.mjs --only=weapon_expansion_v24,weapons_save_v22,loadout_menu_v22,weapon_render_v22,hero_layers_v22,weapon_encyclopedia_v23,projectile_v22,animation_timing_v11,progression_v21,knockdown_v18,battle,wire,training,tadakatsu_combat_v17,typography_v20
```

`v25 --check` 沒有 before 備份時，会從 Git 讀取 `2ac0688` 的原 PNG，再重現 v23 後檢查 v25；需完整 Git 歷史或已 fetch 該 commit。只下載 GitHub ZIP 可啟動 runtime，但不能單靠 ZIP 重現這個歷史來源檢查。可先執行不依賴 Git 歷史的 `verify-handoff-v25.py`。

首次 Godot 匯入若沒有可寫入的個人目錄，將 `XDG_DATA_HOME`、`XDG_CONFIG_HOME`、`XDG_CACHE_HOME` 指向自己的測試暫存目錄，再 `godot --headless --editor --path game --import`。Node runner 為各次測試使用獨立暫存存檔，不碰正式遊戲存檔。

重建新 30 件工具順序為 `build-weapon-catalog-v24.py` → `prepare-weapon-art-v24.py` → `register-weapons-v22.py`；這會寫來源／catalog／registration，僅在備份後的專用重建分支使用，並再跑以上驗證。v25 工具先檢查所有受保護 hash，未知基底會停止。不要為了讓舊 v23 歷史階段檢查變綠而退回現有 v25。

## 5. 驗證證據與未完成事項

- v24 原交付：14 個不同的相關 Godot headless 群組通過，詳 `artifacts/weapon-expansion-v24/test-summary.json`。
- v25 原交付：8 個選定回歸群組通過；信長 734 項註冊檢查、像素不變量、無備份重建、registration 再生一致性通過。詳 `artifacts/nobunaga-dark-red-v25/` 及 `artifacts/native-v25/`。
- 本次 Git 發布另外在最終快照重跑上述群組聯集（15 群組），15 組全部通過、0 失敗，另有 49 組未選入；詳 `artifacts/handoff-v25/results-v19-rerun.json` 和 `regression.log`。選定群組通過不代表整個 repo 全測試通過。
- 已知舊 `projectile_v12`：142 checks 中 62 failures，基線可重現，非本次新增武器／校色已修好。證據：`artifacts/native-v24/legacy-projectile/projectile_v12.log` 與同目錄結果 JSON；可用 `--only=projectile_v12` 單獨重跑。
- 預覽是作者素材合成，不是實機遊玩／GUI 錄影，也不證明物理碰撞及真實手感。原圖、PNG 遮罩與 JSON 是交接依據；大影片／重複 ZIP 不入 Git。
- GUI、Windows／使用者電腦、控制器與跨機網路尚未驗收。
- 原測試報告中的「未 push」是該報告生成時的歷史狀態；發布狀態以 GitHub 本次 commit／PR 為準。CI 狀態另以 GitHub exact commit checks 為準，不能以本地選定測試代替遠端 CI。

## 6. 實物照片、史料與授權界線

48 條皆有來源；僅 2 個舊條目共 3 張本地授權實物照片可嵌入，46 條尚無本地內嵌照片；新增 30 件全部缺少本地實物照片。圖鑑中某些條目的遠端參考圖記錄不等於已獲可嵌入本地照片。遊戲圖是原創生成素材，不能冒充博物館實物照片。

本地 3 張均為 Met CC0：打刀條目使用裝具對照及刀莖工藝局部，十文字槍條目使用 1727 年江戶槍頭與鞘；不宣稱它們就是戰國原件。完整 credit、原件／圖片 URL、授權連結及對照限制在 `encyclopedia.json` 與 `weapons/references/README.md`。

其他館方未明示重製授權的照片只保留來源外鏈，不納入 runtime 或 Git。弓的本輪 10 件為明示復原；槍桿／刀裝亦有遊戲重建部分，不宣稱是原裝認證複刻。人物可裝備關係是遊戲設計，非持有史實。

## 7. 可直接檢視的素材證據

- [新增 30 件武器總覽](../artifacts/weapon-expansion-v24/weapon-30-overview.png)
- v24 武器攻擊逐格：`artifacts/weapon-expansion-v24/sword/`、`spear/`、`bow/`，各 10 張，共 720 視圖。這是 **v25 前** 的武器合成審查，不能據此判讀信長最終甲色。
- [信長 v25 校色重點](../artifacts/nobunaga-dark-red-v25/nobunaga-dark-red-focus.png)／[25 動作前後對照](../artifacts/nobunaga-dark-red-v25/nobunaga-dark-red-before-after.png)
- 信長 **v25 最終** 150 格檢視：`artifacts/nobunaga-dark-red-v25/nobunaga-dark-all-frames-1.png` 至 `-5.png`。
- 上述全部為素材審查圖，不是實機截圖。大 MP4 與重複 ZIP 未放入 Git。

## 8. 48 件 ID 對照

保留既有 ID，包含原有拼法 `sword_samonnji`。整合時不任意改名，以免破壞存檔。

| # | ID | 圖鑑名稱 | 批次 |
|---:|---|---|---|
| 1 | `sword_uchigatana` | 打刀 | 原有 15 |
| 2 | `sword_nagamitsu` | 大般若長光 | 原有 15 |
| 3 | `sword_samonnji` | 宗三左文字 | 原有 15 |
| 4 | `sword_heshikiri` | 壓切長谷部 | 原有 15 |
| 5 | `sword_dojigiri` | 童子切安綱 | 原有 15 |
| 6 | `spear_suyari` | 直槍 | 原有 15 |
| 7 | `spear_kamayari` | 片鐮槍 | 原有 15 |
| 8 | `spear_jumonji` | 十文字槍 | 原有 15 |
| 9 | `spear_nihongo` | 日本號 | 原有 15 |
| 10 | `spear_tonbokiri` | 蜻蛉切 | 原有 15 |
| 11 | `bow_azusa` | 梓丸木弓 | 原有 15 |
| 12 | `bow_bamboo` | 竹藤弓 | 原有 15 |
| 13 | `bow_black_lacquer` | 黑漆弓 | 原有 15 |
| 14 | `bow_red_lacquer` | 朱漆弓 | 原有 15 |
| 15 | `bow_shigeto` | 重藤弓 | 原有 15 |
| 16 | `sword_kanesada_mino` | 美濃兼定 | 前輪新增 3 |
| 17 | `spear_fukuro_yari` | 袋槍 | 前輪新增 3 |
| 18 | `bow_awase_yumi` | 竹木合弓 | 前輪新增 3 |
| 19 | `sword_mikazuki_munechika` | 三日月宗近 | v24 新增 30 |
| 20 | `sword_okanehira` | 大包平 | v24 新增 30 |
| 21 | `sword_shishio` | 獅子王 | v24 新增 30 |
| 22 | `sword_kanze_masamune` | 觀世正宗 | v24 新增 30 |
| 23 | `sword_yamanbagiri_kunihiro` | 山姥切國廣 | v24 新增 30 |
| 24 | `sword_himetsuru_ichimonji` | 姬鶴一文字 | v24 新增 30 |
| 25 | `sword_magoroku_kanemoto` | 孫六兼元 | v24 新增 30 |
| 26 | `sword_odenta_mitsuyo` | 大典太光世 | v24 新增 30 |
| 27 | `sword_kosetsu_samonji` | 江雪左文字 | v24 新增 30 |
| 28 | `sword_okanemitsu` | 大兼光 | v24 新增 30 |
| 29 | `spear_otegine` | 御手杵（復原） | v24 新增 30 |
| 30 | `spear_omi_sukesada_1504` | 大身槍・長船祐定 | v24 新增 30 |
| 31 | `spear_sasaho_kanesada` | 笹穗槍・兼貞型（復原） | v24 新增 30 |
| 32 | `spear_kikuchi_kunikiyo` | 菊池千本槍・國清 | v24 新增 30 |
| 33 | `spear_hirasankaku_hidesada` | 平三角槍・英定 | v24 新增 30 |
| 34 | `spear_gyukaku_jumonji` | 牛角十文字槍 | v24 新增 30 |
| 35 | `spear_techigai_jumonji` | 手違十文字槍 | v24 新增 30 |
| 36 | `spear_sagara_yari` | 傳相良槍 | v24 新增 30 |
| 37 | `spear_takebera_yari` | 竹篦槍 | v24 新增 30 |
| 38 | `spear_inji_yari` | 印地槍型（復原） | v24 新增 30 |
| 39 | `bow_todake_reconstruction` | 外竹伏竹弓（復原） | v24 新增 30 |
| 40 | `bow_sanmaiuchi_reconstruction` | 三枚打弓（復原） | v24 新增 30 |
| 41 | `bow_shihochiku_reconstruction` | 四方竹弓（復原） | v24 新增 30 |
| 42 | `bow_odawara_higo_reconstruction` | 小田原弓胎弓（復原） | v24 新增 30 |
| 43 | `bow_fukiyose_tou_reconstruction` | 吹寄籐弓（復原） | v24 新增 30 |
| 44 | `bow_tokoroito_reconstruction` | 所糸卷弓（復原） | v24 新增 30 |
| 45 | `bow_shigeito_reconstruction` | 重糸卷弓（復原） | v24 新增 30 |
| 46 | `bow_nioiito_reconstruction` | 匂糸卷弓（復原） | v24 新增 30 |
| 47 | `bow_nibiki_shigeito_reconstruction` | 二引重糸卷弓（復原） | v24 新增 30 |
| 48 | `bow_nibiki_kaba_reconstruction` | 二引樺卷弓（復原） | v24 新增 30 |
