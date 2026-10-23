# 第四關新版敵軍增援交接（2026-10-18）

**僅設計交接，尚未實裝或實測。** 本版取代舊第四關「2–3 人初值／無增援／僅初始敵清場」的密度與完成條件。原素材、招式、地形設定與舊 [13 節點配置](../stage04/layout/stage4_nodes_proposal.json) 保留，供比較及回退；其餘既有規則依本包交接說明沿用。

## 接手入口

- [README_CODEX.md](README_CODEX.md)：排程、名額預約、吉良雙佇列、王先敗退、重試／存讀與完成條件。
- [stage04_density_v2.json](stage04_density_v2.json)：13 節點的原始配置；[逐節人數表](stage04_density_v2.md)與 [易讀 TXT](第四關敵軍增援交接.txt) 可直接閱讀。
- [enemy_id_mapping.json](enemy_id_mapping.json)：9 個設計 ID 與素材 key；runtime factory／登錄 ID 全部待核實，不得靜默退回通用兵種。
- [TEST_MATRIX.md](TEST_MATRIX.md)／[test_matrix.json](test_matrix.json)：15 項案例，全部 **NOT_RUN**。
- [第三關參照](stage03_reference_report.md)、[來源 blob SHA](source_file_hashes.json)、[本輪發布驗證](PUBLISH_VALIDATION.json)。

每節初始兵另計，再增援 2–3 波；每波左右各 3–4 名、合計 6–8 名，共 33 波。固定排程全關 313 名，吉良六弓死亡替補另計。同場 cap 為普通 10、富永／長照 11、吉良 15。雙人不額外再乘出兵數量。預警與左右成對入場間隔以交接內 45 ticks／0.75 秒規則為準。

王先敗退仍須完成有限波次；長照另須逃離完成，再與清兵條件共同判斷通關。吉良六弓替補與三批有限近戰是不同佇列。這些是待實作規格，不代表目前引擎已支援。

## 來源及檢查

來源 ZIP：Library `libfile_95b531fa12a881919ee83818a3966c9f`，31,911 bytes，SHA-256 `922ec86b1213dc1cf4d3b51b7392161ac74ad594c399a4d2b1e6fd3a10b9eac2`。易讀 TXT 來源為 `libfile_6dd3bbd44798819191d7d5331167c3c1`，與 ZIP 內 TXT 完全相同，僅保留一份。

11 個來源文字／JSON／checksum 檔均原樣展開，ZIP 未加入 Git。原配置 JSON SHA-256 保持：

`484da071069ca80a54d00892b63fe925b893b8ff8ffd44f1f83b65f5abf48a6f`

已核對 ZIP CRC／路徑安全、5 份來源 JSON、10 筆原 checksum、13 節點／33 波／313 人、左右編成與 cap 算術，以及 15 項 NOT_RUN 狀態。7 個第三關參照 blob 均與遠端 main `30fdac0349fb39bd769061318a497446a9ff0114` 的檔案相符。未發現本輪規則涵蓋的私鑰、憑證或簽名下載網址；未加入圖像、音訊或其他素材。

來源 `validation.json` 記錄的是製作交接時的靜態檢查；本次 Git 文件發布的檢查另見 `PUBLISH_VALIDATION.json`。本次未修改 runtime、未合併 main，亦未執行引擎、通關、效能或平衡測試。
