# DOT 素材與 v0.26 整合驗收

交付來源：[PR #1](https://github.com/guderian44444/sengoku-m1/pull/1)，commit `5f69da850aa44c97ea8f89b6aff85f7942433897`，共同基底 `2ac0688a8100b27b3a4fa958554aee8dcd3a1188`。本次保留 DOT 已完成美術，加入使用者要求的戰鬥中裝備頁與大關存檔，遊戲版本為 0.26.0。

## 素材完整性

- 武器 PNG、catalog、registration、圖鑑 ID 完全對齊：刀／槍／弓各 16 件，共 48 件；原 18 件與新增 30 件來源都存在，原始 RGB、明示 alpha 清理、裁切與握點檢查通過。
- 三人 77 組／462 格完整；信長 v25 的 17 張修正及 8 張原樣來源、阿市 v26 的 81 格修改及 75 格保留都符合已核准 SHA 鏈。
- 阿市的選區外像素、皮膚、全圖 alpha、註冊幾何和手／腳／武器錨點檢查通過。信長來源註冊 734 項、本多素材 916 項檢查通過。
- 原交付在 Windows checkout 曾因 CRLF 使保護文字檔 SHA 不符。核對 Git blob 與作者記錄一致後，以 `.gitattributes` 固定文字 LF；未修改已核准 PNG。

## 裝備與收藏

選角「裝備」及暫停的「1P／2P 裝備與收藏」進入同一頁面，顯示人物永久屬性、當前武器欄、收藏清單、圖片與能力。換裝立即更新正在戰鬥的人物並保存，不重置生命、命數、積分或場景；已發射彈體沿用原有武器快照規則。玩家只可裝備自己的已收藏相容武器，雙人同武將仍分開保存。

頁面由資料列提供 `id/name/category/description/image/can_equip/has_details/slot` 與已裝備 ID 清單，分類由資料產生；頁面不引用武器 catalog。未來其他物品可使用相同 UI，目前主程式與存檔只接已實裝的武器，沒有新增未定義的裝備效果。

DOT 的掉落候選保留未收藏的低階／同階款式，使取得最高階後仍可繼續收集；收齊該人物可用種類後停止武器掉落。

## 存檔

舊 `characters-v1.json` 保持可讀，仍保存 1P／2P 各武將的總積分、永久生命加成、已裝備武器與收藏。新增共用 `chapter`、`completed_chapter`：只記大關與最高通關關號，舊檔缺少欄位時從第一關開始。

出陣可選已實作、已開放的大關，從該關起點／第一據點／第一波開始、滿血三條命。場景、位置、據點、波次、目前 HP、命數、怒氣、護符、敵人與掉落物不寫入存檔。目前只有第一大關可玩；記錄中的下一大關尚未開放時會說明並提供已開放大關重玩。存檔備份、損毀保護、未知版本拒絕與測試資料隔離保留。

## 本次實測

Windows Godot 4.7.2；Python 3.12.14、Pillow 12.3.0、NumPy 2.3.5、SciPy 1.17.0、OpenCV headless 5.0.0.93。

- 最終 17 個相關 headless 群組全部通過，0 失敗，48 組未選入。清單與結果在 [dot-integration-tests-20261012.json](dot-integration-tests-20261012.json)。
- 收藏／大關 34 項、角色圖層 3102 項、48 武器擴充 73397 項檢查通過。
- 另一次裝備、選角、暫停及原生擷取共 4 組通過；目視選角入口、戰鬥換裝及 2P 頁面，無裁切／重疊。
- 標準 Python 素材 SHA 驗證、48 武器來源／裁切檢查、阿市精確補丁、三人來源與 Windows editor 匯入通過。
- 本機完整日誌與圖片位於 `artifacts/dot-integration-20261012/`，測試產物不納入 Git。可用 `node scripts/test-v19.mjs --only=collection_progress_v26 --render-collection-v26` 重現裝備頁檢查。

## 保留的限制與失敗

- 46 條圖鑑缺少本地實物照片，只有 2 條共 3 張 Met CC0 圖；照片缺口明示，生成遊戲圖不冒充實物照片。阿市少量衣裝接縫保留，位置見 DOT 交接。
- `test-nobunaga-dark-red-v25.py` 的歷史 PNG byte 重建在這次 Windows 環境失敗。另以核准 Git 原圖／參數在記憶體重建 17 張，16 張 RGBA 完全一致；`special` 有 1 像素、最大 2 色階差異，停用 OpenCV 優化後仍相同。沒有放寬原重建的精確斷言或改動素材；正式 PNG 全部符合核准 SHA。此項需回作者 Linux 工具鏈複核，不列為 Windows 通過項。
- 原始 snapshot checker 保護了當時遊戲程式碼；整合功能會改變程式碼，因此新增明示 `--assets-only` 模式保護所有美術，程式碼由本次 Godot 回歸驗證。預設的完整快照檢查保留。
- 沒有宣稱整個 repo 全綠。DOT 提供的舊 `projectile_v12` 62 failures 為既有證據，本次未修復或重新驗收該基線。
- 未驗證 Windows/PCK 匯出、實體搖桿手感、真人音訊與跨機網路；headless 原圖載入仍有既有匯出警告。
