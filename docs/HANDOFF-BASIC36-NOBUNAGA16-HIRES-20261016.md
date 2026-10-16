# Codex 交接：四人基本動作＋信長高解析 16 招

使用者已核准這批素材上 Git。本次只新增素材與文件，基底為遠端 main `966cf8c3d48a4579554bc046a5961870faaaafa8`；未帶入本機 main 的兩個未發布提交或友軍未提交變更。

| 部分 | 數量 | 入口與完整圖文說明 |
|---|---:|---|
| 本多、秀吉、家康、顯如基本動作 | 36 組／212 格 | [中文圖文交接](../deliveries/basic36-nobunaga16-hires-20261016/FOUR_HEROES_BASIC36.md) |
| 信長高解析攻擊 | 16 招／232 格／10,520 ms | [中文圖文交接與缺口](../deliveries/basic36-nobunaga16-hires-20261016/NOBUNAGA_16.md) |

[整批入口](../deliveries/basic36-nobunaga16-hires-20261016/README.md) · [機器索引](../deliveries/basic36-nobunaga16-hires-20261016/DELIVERY.json) · [驗證結果](../deliveries/basic36-nobunaga16-hires-20261016/VALIDATION.json)。

家康基本跑步鎖定 run_v5；信長反摔鎖定 planted_v2 16 格／800 ms，六招抓摔持刀，滿蓄範圍採 range150。影格數及 duration 因動作而異，事件必須依逐格資料解讀；藝術事件與 preview 位移不能直接當成 gameplay callback 或世界位移。

保留人物、武器、手部遮擋與獨立前後 VFX 的原始圖層及來源尺規；信長圖層是同座標可見像素分拆，完整換武器仍須檢查並補齊隱藏底圖、刀柄／護手與來源臉部透明缺口。232 格中 165 個不重複 actor 是檢查上界，不是已完成的 hidden-fill 數量。反摔 005 遮擋與 015 刀尖裁切均保留原核准圖，不要覆寫 master。

**未完成且本次未宣稱完成：** 引擎圖集／alpha 匯入、換武器 socket、左右向、碰撞／hitbox／hurtbox、敵人附著與投摔事件、狀態與輸入接線、重力／位移／接地物理、實機播放與效能測試。未修改 runtime，未執行遊戲測試。

阿市沿用 [PR #5](https://github.com/guderian44444/sengoku-m1/pull/5)；四人既有 64 招攻擊沿用 [PR #6](https://github.com/guderian44444/sengoku-m1/pull/6)。本批未整包重複匯入這兩份既有交付；基本動作包自帶的待機、肖像及來源依賴仍完整保留。不包含其他 VFX／UI／音樂或歷史封存改動。

兩個完整 ZIP 與五個傳輸分片均保留本機；只提交展開檔案。最大來源單檔 6,572,441 bytes，無需 LFS 或另外上傳大 ZIP。
