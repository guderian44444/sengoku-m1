# 前三關音樂包 v1.1

完整包取代第三關先行包；第三關六個 OGG 的 bytes 與 SHA256 完全保留。

## 對應方向（非硬編場景 ID）
- 第一關桶狹間竹林・高根山前哨：竹林 Shizima3；一般交戰 Strategy4；松井宗信 Ametsuchi。
- 第二關大高兵糧道・丸根砦突破：兵糧道推進／護送 Strategy2；砦內強戰鬥用 Fight3（170 BPM）；佐久間盛重 Amenoshita2。
- 第三關今川營地：雨營 Shizima4；鳴鐘／陣列 Amenoshita3；帳前雙小頭目 Kengeki；義元 EpicBattle_J。
- 三關共用明亮勝利：Result_Celtic 短句一次，接 loopB。凱爾特音色是刻意的慶祝對比，並非日本傳統曲。

第一關應有7scene、第二關6scene，實際 ID、戰鬥標記、小王/王事件、返回狀態都由接入者檢查真實專案資料，不能靠猜。重複採用同一曲的鄰近場景應連續播放；用增益與過渡區分，別每scene重開。每關主題和王戰不同，三關加共用勝利共11首作品，12個OGG（含勝利短句/循環拆分）。

## 接入
使用 WebAudio 解碼音訊 AudioBuffer，loopStart=0、loopEnd=frames/48000。不得依賴 HTML audio ended 重播以求無縫，也不要循環 MP3 預覽。所有 loop 是作者官方循環段，並未盲剪和聲；做了降益、2ms邊緣防爆音與輸出OGG。第一二關44.1k來源另轉48k；速度音高不變。第三關接入細節見 STAGE03_NOTES.md。

切場交叉淡化0.3–0.8秒；切王0.2–0.35秒，讓攻擊預警/出場聲清楚。音樂初始master 0.65，SFX獨立；提供音樂slider和mute。只允許1首主BGM加1首過渡outgoing；同cue不重建音源。死亡、返回、重新開始與暫停必須清理/暫停；Resume保留合理游標。勝利stinger只播一次，之後循環短結果曲。第一次音訊由開始遊戲手勢啟用AudioContext。

## 驗證邊界
已做每檔完整解碼、sample count/loop時間、峰值、接縫跳變、SHA256及zip CRC檢查，未做真正音訊聆聽。選曲情緒依作者描述判斷；實際遊戲的聽感、首幀音訊解鎖、跨場、暫停、死亡、重開、Boss轉勝利以及連播至少兩輪仍須接入後測試。Music不應蓋住敵人預警。

CREDITS.txt與manifest內的作者、原曲連結、CC BY 4.0連結與改動說明都要保留。音樂授權獨立於程式碼授權，不登記第三方音樂獨占Content ID。免費下載來自作者官網，不含付費WAV。
