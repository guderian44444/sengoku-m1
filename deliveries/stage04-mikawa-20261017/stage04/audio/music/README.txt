第四關「三河歸途」正式音訊交接 v4

可交付正式檔案共4個：
- Oboro2：20.25秒 WAV intro（0–20秒保持使用者試聽；最後0.25秒供轉場）。
- EpicBattle_Deity：救援／追擊完整官方循環 OGG。
- Strategy3：王戰完整官方循環 OGG。
- Hanagoyomi2：勝利一次性完整 OGG。
這些不是30秒試聽替代品。

必須另取得的完整熱血loop：
《百折不撓》採自訂授權，沒有明確的私人素材包或公開Git例外。本包未包含其音訊；詳細判斷見 docs/LICENSE_AUDIT.txt。完整loop已做本地技術驗證，精確資訊在 audio_specs.json（included=false）。這項缺件明確列為交付依賴，不能稱全數已打包。
由使用者直接下載：https://kazuki-kaneko-music.com/wp-content/uploads/2023/09/kk_battle10.zip
對應官方頁：https://kazuki-kaneko-music.com/battle10/
下載後在本機執行：python3 tools/import_battle10.py /path/to/kk_battle10.zip
匯入腳本不連網、不操作Git或遊戲runtime。它檢查官方ZIP與指定純loop雜湊，只將完整純loop複製到本包assets。不要改用全曲帶intro的kk_battle10_loop.ogg；其內建loop metadata與純loop不同。

切換（僅規格，尚未實作到遊戲）：
1. 每次重新開始第四關時，Oboro2 intro播放一次，gain=1.0。
2. t=20.000秒啟動百折不撓純loop，先套-12.37dB；兩軌做0.25秒線性交叉淡化。intro於20.250秒結束。之後只循環熱血段；進蘆葦河岸保持播放位置，不重播intro。
3. 橋頭救援觸發時，以0.25秒線性交叉淡化切EpicBattle_Deity；河岸追擊沿用該曲且保留播放位置。
4. 王戰觸發時切Strategy3，0.25秒線性交叉淡化，觸發一次，不能每幀重啟。
5. 王敗且勝利狀態確立時切Hanagoyomi2，0.5秒線性交叉淡化，單次播放；離開結算頁時可0.5秒淡出。
6. 暫停保留播放位置；恢復續播。重開關卡重設intro。任何新場景切歌可中斷尚未完成intro。檔案缺失應明確報錯，不能靜默用舊v2 Oboro2長循環替代。

循環邊界／增益：以music_map.json、audio_specs.json為準。frame單位是「來源檔每聲道音訊框」，end為exclusive；並非雙聲道所有sample總數。引擎若重採樣請用精確秒數或按新sample rate換算，不直接套44100Hz frame到48000Hz buffer。
前三個循環均為官方獨立loop的全段，不含試聽末端淡出；不要額外在每輪循環加淡入淡出或重放intro。

原始完整loop未再轉碼或烘焙增益。請在runtime使用指定static gain一次。以完整檔實測LUFS設定約-18 LUFS；此為一致音量起點，並不是最終遊戲混音驗收。不要把單段試聽的動態loudnorm處理誤當完整loop處理，亦不要重複減兩次音量。保留SFX清晰度仍需實際遊戲驗收。

本包QA：全部正式檔完整ffmpeg解碼、來源hash、PCM框數、LUFS/true peak，20秒intro與既有試聽逐樣本比對。未聲稱已驗收引擎內切換與loop聽感；未修改runtime/Git，未公開發布音樂。源碼與設定可交接，涉及他人音樂的再散布仍需遵守CREDITS及授權稽核。
