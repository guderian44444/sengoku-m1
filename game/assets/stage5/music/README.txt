第五關正式配樂包 v1

01 第一段 Ohayashi2A；02 第二段 Michikusa2；03 寺內 EpicBattle_J＋法器；04 夏目／快速戰 Kengeki＋法器；05 空誓 Grim League→Satiate，保持已核准原檔。

前四首取自作者官方完整loop OGG，不是40秒試聽延伸。WAV是44.1kHz stereo 16bit轉檔，OGG q6。music_map.json含精確sample及秒數，loop end採exclusive，OGG亦帶LOOPSTART/LOOPEND/LOOPLENGTH。每檔從sample0播至end再回0；空誓按獨立manifest先intro一次再loop。

循環接點已內建3ms微淡化；法器尾音跨回循環起點，勿額外長交叉淡化，以免重鼓或縮短週期。場景換曲建議舊曲250ms淡出再新曲150ms淡入，避免不同BPM鼓點重疊。若要crossfade，只用100ms等增益作場景過渡，非循環；屬整合建議，沒有修改runtime或新增血線觸發。

建議BGM master初值0.75；空誓0.65，對白時再降低4–6dB。音效應獨立bus。本包寺院鐘木魚為已核准BGM編曲組成，不是戰鬥擊打SFX；總覽未加擊打/人物音效。原選曲核准，延伸loop混音為正式交接版本；尚未人工聽音複核，不能以數值QA保證所有主觀音樂接縫。

空誓檔案從已交付ZIP逐byte恢復，hash已核對。其舊README中編排建議字樣保持原檔，實際版本已獲用戶2026-10-17核准。

音色是遊戲化處理，不是本證寺史實儀式還原；沒有經文。淨土真宗不用木魚。勝利沿用既有公共勝利映射，Result_Celtic僅舊交付參照，沒有另選或新增檔案。

檢查：所有WAV/OGG可解碼、沒有>=1削波；audio_qa.json記錄端點差；SHA256SUMS列所有交付資產。來源原始hash另附source_hashes.json，供後續核對，本次未能比對已遺失的舊下載hash。
