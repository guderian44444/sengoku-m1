阿市反摔13格：腳點registration修訂包。此版取代先前細腿13格未對位預覽。動作原畫與腿型保留，無光流或局部肢體拉伸。
實測原承重鞋底Y在195–209間跳動；按逐格承重腳而非人物外框對位，修訂後全部Y=202，固定支點X誤差<=0.5px。第2/4格額外3%等比頭/軀幹尺度校準後重新鎖腳，其他既有尺規保留。所有transform見registered_metadata.json；校正前兩腳量測見jitter_measurements.json。
這代表量測腳點已校正，不保證完全沒有視覺抖動。正常960ms、13格、580ms鬆手；慢速3倍。GIF單次播放，末幀左向收勢。正式接入需交接左向idle/後續動作，不能直接跳回右向抓取首幀；未修改runtime或戰鬥。
兩包解壓同一目錄。python reverse_coherent/build_stable.py 可重建最新正常/慢速GIF；需要Pillow及numpy。build_final.py保留原來源裁切與合成追溯（另需scipy），產出的舊中間預覽不是最新交付，若執行它，最後仍須執行build_stable.py。
含原始來源PNG、13人物裁圖、獨立身體/弓/替身畫布、接點及根點metadata、前後量測、聯絡表、SHA256清單。已在乾淨解壓目錄逐位元驗證最新GIF重建一致。