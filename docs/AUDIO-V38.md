# 武器音效與武將語音修正（2026-10-16）

目前專案已接入 75 個武器 WAV，提供 17 條音效路由，每條有 5 個變化版本；格擋與踢擊揮空共用相應素材。刀劍、長槍、錫杖／長棍、拳腳、普通與蓄力射箭分開選聲。命中依實際傷害事件播放，揮空只有風聲；一輪多箭只播放一次弓弦釋放。顯如依當前裝備切換錫杖鈍擊、薙刀／長槍或舊存檔的刀劍聲。

共用特效繼續顯示命中火花，由武器音效播放單次實體撞擊聲；蓄力釋放會結束原有循環聲。維持 SFX／Voice／Music 分離、六個打擊播放聲道、獨立食物拾取聲及不連續重複的隨機袋。

## 信長與第二關

信長原始音檔中有部分輕手、受傷、必殺及勝利表演落在較高音域；原本播放倍率已是 1.0。這次以同一 Ryan 預設聲線重新表演 14 段，保留原有兩段較穩定的受傷短叫，仍以 1.0 倍率播放。沒有以降速或音高變換偽造低聲。短發力／受傷聲維持 0.30–0.50 秒；每個新錄音保留原始候選、實際種子、模型版本與 SHA256。音高篩選只用於找出異常，不代表人工聲線驗收。

第二關原先有出場字幕，但三位具名武將沒有對應 `stage_boss_intros`，因此傳出空的 `line_key`。現已補上飯尾定宗、佐久間信盛、佐久間盛重三段日語出場白，沿用關卡繁中字幕，顯示時間依錄音長度設定，出場不鎖住玩家操作。

六名玩家武將仍各有完整 16 段語音，普通輕手前兩段不叫喊，第三段才發力。所有現用角色與出場路由共檢查 146 段錄音，沒有缺檔、資料雜湊錯誤或 PCM 削波。其餘角色沒有僅因音高數值而重錄。

## 素材來源

使用以下 CC0 原始擬音，經裁取單次動作、EQ、疊層、淡入淡出及音量處理：

- [StarNinjas：刀劍斬擊及金屬格擋](https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes)
- [Ben Jaszczak／Brian Nelson：武器錄音，含真實長弓與武士刀](https://opengameart.org/content/medieval-sound-effects-weapon-textures)
- [Independent.nu：拳腳與撞擊](https://opengameart.org/node/2558)

`game/audio/v38/weapons/CREDITS.txt` 與 `manifest.json` 記錄來源、下載位址、檔案雜湊及每段裁切／混音方式。

## 驗證與試聽

- `scripts/build-weapon-audio-v38.py`：重建 75 個 WAV，檢查聲音長度、能量及峰值；需先保留來源封存檔於 `artifacts/weapon-audio-v38/source`。
- `scripts/generate-voices-v38.py`：沿用本機 Qwen3-TTS CustomVoice 固定模型、舊版聲音後處理流程與候選快取；全部通過後才原子替換語音登錄。
- `scripts/verify-audio-v38.py`：檢查所有現用語音、武器音效及 94 個新 WAV 的打包收集範圍，產生 `artifacts/weapon-audio-v38/asset-verification.json` 與 `preview.html`。
- `node scripts/test-v19.mjs --only=weapon_audio_v38`：1,306 項檢查，包括六人的實際裝備出招、命中／揮空、箭矢延遲命中、多箭去重、1P／2P 語音路由、第三段輕手叫喊、三名第二關武將經 Main 的實際出場播放、共用特效不重播音效、蓄力循環結束、播放上限及音量設定。

其餘相關回歸結果收錄於 `artifacts/weapon-audio-v38/verification-summary.json`。頭戴耳機／喇叭的實際混音、日語發音、情緒、短叫力度與聽感仍需人工試聽；不能由音高與 PCM 檢查推定。試聽頁包含六人各段語音、信長前後比較、第二關出場白與武器示範。

此次沒有重新製作 EXE／PCK／ZIP。原有動態圖片載入仍會顯示 Godot 的匯出警告；本次確認的是專案執行與打包清單收集，並非正式匯出相容性。
