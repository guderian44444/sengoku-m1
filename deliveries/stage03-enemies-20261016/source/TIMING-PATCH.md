# 蒲原斬擊 timing 缺檔修補

將此 ZIP 解壓到原 stage03-enemy-review-package 的根目錄，覆蓋同路徑 metadata 與 SHA256.json；不要解到遊戲 runtime。

新增 metadata/ujinori/slash/timing.json，是原始 timing 檔逐 byte 複製。六份蒲原原始清單的 slash.metadata 改為相對該 manifest 的 ../slash/timing.json。動作、PNG、預覽影片、主 manifest 及其時間皆未改。

斬擊 8 格：120、100、100、40、50、90、130、170 ms，合計 800 ms，與主 manifest 完全相同。主 manifest 的 package_path 以素材包根目錄為準；原始 metadata 的 file 為對應角色／動作的 frame 檔名。source/source_files/reference 是來源追溯，不是須裝進遊戲的檔案依賴。

reference-validation.json 核對 37 組／178 格主清單、所有原始 metadata 的 file、六份 timing 引用，全部存在。SHA256.json 是覆蓋後整包校驗表；此次未重新產生或改動任何圖片。若原包已移到 PR 內目錄，請只套到那個素材包目錄，保留其他提交。
