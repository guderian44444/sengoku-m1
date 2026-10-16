# 四人基本動作＋信長高解析最終交付

共 **52 組已驗收動作／444 格**，保留 4,312 個來源檔。

- [四人 36 組：代表圖、動作說明與交接](FOUR_HEROES_BASIC36.md)
- [信長 16 招：代表圖、動作說明及換武器缺口](NOBUNAGA_16.md)
- [批次索引](DELIVERY.json) · [驗證結果](VALIDATION.json)
- [四人原始入口](four-heroes/manifest.json) · [信長原始入口](nobunaga/delivery-manifest.json)
- [四人來源與傳輸雜湊](FOUR_HEROES_PROVENANCE.json) · [信長來源與傳輸雜湊](NOBUNAGA_PROVENANCE.json)

只提交展開來源與文件；ZIP、分片、傳輸資料及不完整下載留在本機暫存。未修改或測試 runtime。信長目前武器的可見分層重組通過，隱藏底圖、完整換武器、碰撞／事件／物理／引擎效能均未完成。

重跑驗證（Python 3＋Pillow＋NumPy）：

```powershell
python -X utf8 verify_delivery.py
```

入口會保留原始鎖版驗證報告的位元組；不要把歷史生成腳本當成可移植重建流程。
