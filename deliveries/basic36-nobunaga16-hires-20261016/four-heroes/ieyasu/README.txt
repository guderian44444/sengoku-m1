家康 06 最終 Git 展開交接包

整合入口：integration_manifest.json；完整角色索引：character_manifest.json。9 組、50 格，全部依 Sentinel_003f9aaa53ac819191a42c7ac9485ce8 核准。
run 必須採 run_v5；victory 採 victory_v2。provenance 內的舊 run_v4、candidate 字樣或舊 QA 狀態只屬歷史，不是目前狀態。

畫布 480×320，root [220,280]，固定 152px 站高尺規。walk 使用既有三層導出，僅比原生畫布向下平移 40px；idle 原核准 520×280 圖只整數平移 [85,35]。沒有按逐格 bbox 拉等高或再次縮圖。
三透明層順序 body → weapon → hand_occlusion。sheath 已在原遊戲解析度先合到 body 背後，不需第四個 sheath。
每格 metadata 有毫秒時長、起始時間、root、near/far 腳點與原索引（left/right 僅在原紀錄有標註時提供，否則 null 待確認）、握點、武器角度、前後層、loop、landing/settle、preview 與 world 分離。source_parts 的路徑以本角色包根目錄為準。
preview GIF 是既有交付原檔；歷史標題文字及用於預覽的位移不能作為 runtime 狀態或世界位移來源。

所有 sources 原檔及核准母圖均保留。未選入的舊稿只作歷史。正式圖像和 50 格三層重組逐像素一致。run_v5 6 格的鎖腿 mask 區域與 run_v4 完全一致。down→recovering→idle 接縫及 hurt/jump/victory 回 idle 已作像素檢查。
QA.json 是離線檔案、像素、metadata 和 SHA 驗證，沒有遊戲 runtime 測試。

驗證：python validate_bundle.py；依賴 Pillow、NumPy。SHA256SUMS 包含每個交付檔案（自身除外）。
此工作只建立新展開包，未改動舊素材、舊 zip、站或 Git。
