# 必殺音效資產與整合候選

## 已完成與界線

- 18 段既有日文必殺喊聲的保守 remaster；不是新錄音、新聲演或新台詞。
- 六英雄各有原創 DSP charge / release / final 三層，共 18 段新 SFX。
- 六英雄各有一段 4.5 秒聲音預覽，使用已存在的 210-tick/3.5 秒戰鬥，保留尾響。
- 所有檔案提供 48kHz mono PCM16 WAV 與 Ogg Vorbis q6。既有原音為 22.05kHz，升採樣不等於增加原始細節。
- 本批未經聽覺驗收；解碼、峰值、時長檢查不能证明熱血程度、發音或性別/音色辨識正確。
- 沒有修改遊戲 checkout、main、音效映射或既有音檔。未新增安裝、下載模型、傳送憑證、付費或使用第三方服務。

## 原音和名稱

原音來源：game/audio/v11/lines.json、manifest.json 與 *_special_0.wav。
原生成脚本 scripts/generate-voices-v11.py 記載 Qwen3-TTS-12Hz-1.7B-VoiceDesign，revision 5ecdb67327fd37bb2e042aab12ff7391903235d3；自然語言設計聲音，未使用特定聲優或克隆參考。
這是倉庫的來源紀錄，不代表本次重新驗證原始生成過程。
官方模型頁（2026-10-13查核）標示 Apache-2.0：https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign
該模型授權不是所有生成輸出的全面法律保證；本批只處理用戶既有遊戲素材，不散佈模型權重。
新 SFX 由附帶 build_audio.py 的振盪器、濾波噪聲、包絡與瞬態合成，無外部 sample、錄音、音樂或素材庫。

六英雄既有日文：
- 信長：天魔の刃！
- 阿市：氷の羽！
- 秀吉：大返し！；新美術三擊草案名「千成奇策」尚未配音。不能把此音檔標示為喊了新名稱。
- 家康：三河の意地！；新24姿勢 U 必殺提案「三河不動」尚未配音。「炎輪」屬站立蓄力視覺，非替代該新 U 技名。
- 光秀：月光一閃！
- 忠勝：蜻蛉切！

其餘12名boss的台詞、原創聲線描述、原檔與SHA256在manifest中。v27目前boss special映射到泛用重手喊聲；可選擇恢復各自 v11 專名，但本批沒有改動該映射。

## 時序

這批預覽僅對齊既有 legacy runtime，來源 game/core/battle.gd 的 SPECIAL_TICKS=210 與 SPECIAL_HIT_TICKS。非新三段動畫authoring時間表。
聲音在tick0喊一次，charge從tick0到首次命中；release於每個非最後命中tick，final於最後命中。60 tick/s：
- nobunaga / oichi：[26,68,110,152,192]
- hideyoshi：[18,44,70,96,122,148,174,198]
- ieyasu：[36,102,168]
- mitsuhide：[24,66,108,150,192]
- tadakatsu：[36,84,132,180]

家康SFX結合低頻地面打擊與火焰噴發，只是視聽層，沒有把既有earth傷害改成fire。

## Godot 接口

special_audio.gd 是獨立候選Node，預設資產路徑 res://vfx/audio/。configure(root)載入manifest。begin_cast(unique_cast_id, actor, allow_legacy_voice)只在動作開始呼叫一次；逐模擬tick呼叫advance_cast(cast_id,action_tick)，禁止用wall clock timer代替。allow_legacy_voice=false可避免新名動作誤用舊台詞。
必須以每次施放唯一ID（fighter ID + cast serial）避免重複開始。helper本身處理同tick重入、跨tick、停止/取消，沒有自動改現有事件流程。
請在新的special處理中停用舊generic special SFX與舊special speech，否則雙重播音。其他事件不需停。
暫停時呼叫set_audio_paused(true)，回復時false；慢動作下cue跟模擬tick，語音保持原速避免聲線變調。新三段動作需自己的cue表；不可直接套210tick。
結束、換場、取消請cancel_cast或cancel_all。Voice/SFX bus若不存在會降至Master，不改用戶存檔音量。
voice_duck_requested訊號具有多語音引用計數；用專用 transient gain/mix stage 音量而非覆寫用戶設定來duck Music -6dB / SFX -3至-6dB，約20ms attack、200ms release。預覽已對SFX做-6dB duck。
建議master保留至少3dB headroom，加true-peak limiter -1dBTP，兩人同放時優先保護Voice並將每人SFX再降3dB。需在完整遊戲實機驗聽多敵命中場景。

## 檢查

manifest.json：每檔時長、sample peak、4x估算true peak、RMS、SHA256。validation.json：OGG解碼峰值、4x估算true peak、clipped samples及ffmpeg EBU R128結果。短SFX integrated LUFS受gating與時長影響，不作主觀响度合格保證。
standalone Godot 4.6.3 --check-only通過，初次引擎因預設user data目錄不可寫崩潰，指定可寫XDG後成功。
本資料夾的project.godot只供獨立QA，非遊戲專案替代品。

## 可攜重建

以Python環境既有NumPy/SciPy以及ffmpeg執行：

    python build_audio.py --repo /absolute/path/to/source-game-repository
    python validate.py

不含模型權重或套件安装。--repo必填，只讀取既有game/audio/v11；輸出寫在本script所在資料夾，會覆寫本包衍生檔，不改原倉庫。
同ID重複begin會被忽略，完成/取消的ID亦不能再用；cancel_all在換場時清除已用ID。新建player繼承暫停狀態。play_authored_voice(cast_id,slot)只嘗試new_asset，缺slot直接false/靜音，絕不fallback舊台詞。
