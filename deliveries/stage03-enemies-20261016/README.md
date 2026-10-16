# 第三關敵軍美術交付（2026-10-16）

綜合預覽已獲使用者確認並授權本輪 Git 交付。6 種敵人、37 組動作、178 個播放格；部分重用影格，不代表 178 張新繪姿勢。**新素材尚未接遊戲，第三關正式場景／物件／音效與完整驗收尚未完成。**

- [Codex 接手先讀](../../docs/CODEX-STAGE03-HANDOFF.md)：機制現況、角色／動作對照、接點／時序、世界位移、事件與精確缺項。
- [37 組動作索引](ACTION-INDEX.md)及 [結構化接入資料](integration-contract.json)。
- [原始單一 ZIP](stage03-enemy-review-package.zip)：33,121,939 bytes；SHA256 `5ec1811cc96b41de19e290545711e98489ed7e2d2adcea7659fb456bbc6894a1`，未重新壓縮。
- [核准綜合 MP4](source/enemy-combined-preview.mp4)／[GIF](source/enemy-combined-preview.gif)：包內 MP4 與另給的 Library 影片逐位元組相同。
- [來源 manifest](source/manifest.json)、[原始作者交接](source/HANDOFF.md)、[來源 SHA256](source/SHA256.json)、[Library 來源紀錄](source-library.json)、[實際驗證結果](validation.json)。來源文件保留製作當時的「待審／尚未 Git」文字，現況以本頁及 Codex 入口為準。

原始ZIP保持未改；`source/`已套製作者的[最小時序修補包](stage03-enemy-timing-fix.zip)，目前226檔／225筆SHA256。PNG、GIF、MP4與主manifest位元組未改；六份蒲原清單與原始timing依修補包更新，沒有自行猜填時序。見[source/TIMING-PATCH.md](source/TIMING-PATCH.md)。

重驗（Python 3 與 Pillow）：

```powershell
python -X utf8 deliveries/stage03-enemies-20261016/verify_delivery.py
```

蒲原slash缺檔已由原作者修補並驗證：原始8格時序與800ms總長不變，586筆來源frame引用及六份timing引用均存在。世界位移／命中事件仍是未接runtime事項，不能因此宣稱已接線。義元劍氣只交付人物施放動作及外部 FX 事件，包內沒有劍氣投射物圖，也沒有獨立箭矢飛行圖。

敵軍人物與固定武器已合成，不需要可替換武器層或手部遮罩；未來接入時避免再次疊武器。此交付沒有更動 `game/`，也沒有重做玩家角色。
