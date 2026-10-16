# 第三關音樂包 v1

已選定六個可直接載入音檔，映射見 manifest.json。實際 scene ID 請從專案資料核對。

- 雨中進場：Shizima4（安靜尺八／琴）
- 鳴鐘交戰、層疊路障／陣列：Amenoshita3（同曲延續，後段增加音量，不重新開始）
- 帳前雙小頭目：Kengeki（165 BPM 和風硬搖滾）
- 義元：EpicBattle_J（150 BPM 和風交響／搖滾）
- 勝利：Result_Celtic Jingle 一次，接明亮 loopB。它有明顯凱爾特音色，是暫定的爽快勝利提示；不是考據式日本音樂。

## 播放要求

使用已解碼 AudioBuffer 循環（loopStart=0，loopEnd=frames/48000）；不要用 MP3 預覽循環。OGG tag 不保證引擎會自動採用，讀 manifest 的點位。內建的 2ms 防爆音邊緣不替代場景切換 fade。一般跨場 0.3–0.8 秒等功率 crossfade；不要在同一曲映射的場景間重啟。切王時留出出場音效與第一擊；勝利音效僅在真正清關事件播放一次，重啟／死亡／暫停／切關須停止舊音源。

所有曲目使用作者提供的完整循環段，避免未聽辨下硬剪樂句；只做靜態降益與 2ms 接縫淡化。採樣峰值已檢查，未做聽感或音樂和聲的人工驗收。母音量建議先 0.65，提供 Music slider / mute；SFX 獨立，BGM 不得蓋過攻擊預警。瀏覽器需由使用者開始遊戲的手勢啟動 AudioContext。移除音源物件時釋放／停止，避免音樂疊播。

OGG 均已完整解碼測試，時長、峰值、來源及 SHA256 見 manifest。來源為官方免費壓縮音檔，非付費 WAV。CREDITS.txt 應留在專案與遊戲 credits；音樂授權與程式授權分開。無聆聽工具，未聲稱已試聽；preview/stage03_music_audition.mp3 為依序每首約10秒的快速聽感檢查檔。
