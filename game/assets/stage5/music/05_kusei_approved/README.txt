空誓配樂交接 v1

使用者核准：前段 Grim League，再接 Satiate - only percussion。
建議編排：Grim League 原速76 BPM，25.2631519秒；接 Satiate 原速90 BPM，42.6666667秒循環。兩首音高與速度不變，不重疊不同速度的鼓點。前段尾250ms淡出；循環尾20ms接回起點前的素材，接界3ms防爆音短淡化。

節拍長度是依官方BPM的編輯建議，並非已核實樂譜；自然鼓點有時間浮動。主觀音樂接縫尚待試聽確認。已做數值解碼、削波與邊界不連續檢測。

WAV為44.1kHz/stereo/16-bit；OGG Vorbis quality 6。各intro只播一次，再無縫接loop反覆播放。先預載／解碼兩檔並以sample排程，不要靠兩次HTML audio play事件銜接。loop_manifest.json為精確sample/秒數；OGG另帶LOOPSTART/LOOPEND/LOOPLENGTH。端點採exclusive。

試聽在25.263秒轉曲，67.930秒出現一次loop回接，75.930秒結束。結尾1秒淡出僅用於試聽。沒有血量觸發或其他遊戲runtime變更。前四段核准配樂不受影響。
