> 本文保留 v24 增量包的歷史說明。Git 完整交接與最終信長 v25 請先讀 [48 武器＋v25 交接清單](HANDOFF-48-WEAPONS-V25.md)。目前 Git checkout 無須再套旧包。

# 新增30把武器，總數48把

基礎版本：Git `2ac0688` ＋已交付的美濃兼定／袋槍／合弓與圖鑑 ＋三人色盤校正。這批是該完成版本上的增量，不是完整Godot專案。未提交、未push，沒有操作使用者電腦或真實遊戲存檔。

## 內容

- 刀：三日月宗近、大包平、獅子王、觀世正宗、山姥切國廣、姬鶴一文字、孫六兼元、大典太光世、江雪左文字、大兼光。
- 槍：御手杵復原、長船祐定大身槍、兼貞型笹穗槍復原、國清菊池千本槍、英定平三角槍、牛角十文字槍、手違十文字槍、傳相良槍、竹篦槍、印地槍型復原。
- 弓：外竹伏竹、三枚打、四方竹、小田原弓胎、吹寄籐、所糸卷、重糸卷、匂糸卷、二引重糸卷、二引樺卷。全部是明示復原，不宣稱十把名弓或十種互斥弓制。

每把獨立生成原創PNG，有自己的刀姿、槍頭／側刃或弓的曲線／接合／卷束。刀裝與完整槍桿並非館藏原裝的認證複刻。弓以約172世界單位搭配阿市148身高基準，沒有再把實物公分值直接當作遊戲顯示長度。

## 安裝與保護

1. 保留目前專案備份。先套用前輪18武器與色盤校正。
2. 本輪runtime增量ZIP的內容依原有`game/`、`scripts/`、`docs/`相對路徑覆蓋到專案根目錄。多個runtime包全部需要。
3. 原始生成圖與完整預覽若另成ZIP，僅用於重建或審閱，不影響遊戲讀取已完成的裁切PNG。
4. `game/assets/v24/weapons/base-file-sha256.json`記錄套用前應存在的共用檔案hash；`characters-protected-before.json`、`protected-before.json`保護既有角色及18把武器。最終包另外附逐檔SHA與套用檢查工具。
5. 不包含`.godot`、`.import`、測試存檔、使用者存檔、第三方未授權照片或本機引擎。Godot可重建自身快取。

## 可重跑建置與驗證

Python需Pillow、NumPy、SciPy；影片另外需FFmpeg。

```sh
python scripts/build-weapon-catalog-v24.py
python scripts/prepare-weapon-art-v24.py
python scripts/register-weapons-v22.py --check
python scripts/test-weapon-art-v24.py
GODOT_BIN=/path/to/godot TEST_ARTIFACT_DIR="$PWD/artifacts/native-v24/recheck" node scripts/test-v19.mjs --only=weapon_expansion_v24,weapons_save_v22,loadout_menu_v22,weapon_render_v22,hero_layers_v22,weapon_encyclopedia_v23,projectile_v22,battle,wire,progression_v21
python scripts/preview-weapons-v24.py
```

Windows可用既有PowerShell/Node流程設定`GODOT_BIN`與`TEST_ARTIFACT_DIR`。重建美術需原始生成圖ZIP；只使用runtime包不必重新生成。`build-weapon-catalog-v24.py`只重建本批記錄，保留18條基線記錄。請勿對日後自行修改的同名檔案盲目重跑覆蓋。

## 史料、照片與能力的界線

`research-30.json`是來源、尺寸和復原限制；`implemented-stats.json`才是本版實際能力。能力使用傷害、距離、擊退，元素均為無；沒有新增武器專屬攻速、蓄力窗口、耐久或穿透系統。角色相容性是遊戲安排，不據此宣稱人物持有原件。

新30件照片沒有取得可嵌入遊戲的重製授權，且部分只有群照或文字。圖鑑保留来源入口與缺口，不放假照片。御手杵照片屬現代復元件；笹穗兼貞未能核實同件照片；弓的內芯、單件曲率和卷束位置並未全部核定。製作時實看來源並更正研究中的錯圖索引，相關更正保存在生成規格內。

原始imagegen輸出保留不動，新的runtime來源僅清理alpha，RGB不改；原18把不清理、不改色。完整提示、原圖SHA、處理結果SHA、裁切區、握點和尖端均可追查。

## 測試範圍

全批預覽是角色原生畫格的素材合成，按現有握點、層級、手部遮擋及弓弦規則重建。30件各普通／重擊6格、雙朝向，共720視圖。素材合成不是實機遊玩、原生視窗驗收或物理碰撞證明。

Godot headless測試另驗證命中邊界、掉落、裝備、存檔、同步與圖鑑。引擎版本、執行組別與各項結果見交付QA摘要；未執行的實機控制器、視窗體感及網路連線不列為通過。原`projectile_v12`基線已存在62個失敗，不能把選定新測試通過說成整個專案全綠。

### 日文原名缺字修正

原繁中字型缺少「匂」等20個史料字。此版保留原Noto Serif TC字型不動，新增16KB的OFL授權日文字形補字集，runtime與預覽皆使用明確隨附的fallback，不依賴使用者作業系統。原始著作權、OFL、抽字清單與來源SHA保存在`game/assets/v24/fonts/`。
