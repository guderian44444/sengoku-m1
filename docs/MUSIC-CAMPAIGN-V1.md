# 前三關配樂接入與驗證

2026-10-16，分支 `feature/stage03-imagawa-camp`。前三關共17個場景接入12個 OGG、11首 PeriTune 作品；同一首 Result_Celtic 拆成一次勝利短句與後續循環。此音樂變更獨立於敵軍來源 timing 修補；新敵軍 PNG 仍未接 runtime，第三關仍只由隔離入口試玩。

## 來源、署名與原始包

Music: **PeriTune / Sei Mutsuki**，**Creative Commons Attribution 4.0 International**。逐曲來源、授權與供應包改動說明保留於 [CREDITS.txt](../game/audio/peritune-campaign-v1/CREDITS.txt)及[原始 manifest](../game/audio/peritune-campaign-v1/manifest.json)，音樂授權獨立於程式碼授權。官方條款查驗日2026-10-16：[PeriTune 使用規約](https://peritune.com/about/)、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。本批曲目均為2026年2月以前作品，依官方條款繼續適用CC BY 4.0。

完整來源包 `Sengoku_Stages01_03_Music_Loops_v1_1.zip`，Library `libfile_ea1f7fdf9c148191a413032658c27edb`、file `file_00000000b03481f79c38f127d039567c`、version 1，29,754,458 bytes；SHA256 `a6dfcb0ec0e0aceeff7cd5e6fd07251ee5d1f5d962a16ca89f40af00038c174b`。原ZIP留在本機 `artifacts/stage03-music-intake-20261016/`；本次Git交付實際使用的12個OGG、原始來源文件及接入文件，沒有上傳下載憑證或私人助手。

12個OGG逐一符合原包SHA256；其中第三關先行包的6檔位元組完全相同。本次接入未重剪或重新編碼。供應者先前已作降益、2ms邊緣淡化及Vorbis重編碼，第一二關另由44.1kHz轉48kHz；無變速／變調。所有循環保留作者官方完整段落；MP3試聽預覽不作runtime來源。Result_Celtic的凱爾特慶祝音色沿用已選方案。

[來源身分](../game/audio/peritune-campaign-v1/source-library.json)、[驗證紀錄](../game/audio/peritune-campaign-v1/validation.json)與供應者[HANDOFF](../game/audio/peritune-campaign-v1/HANDOFF.md)、[第三關備註](../game/audio/peritune-campaign-v1/STAGE03_NOTES.md)均保留。原始manifest的 `file=assets/*.ogg` 不改寫；Godot載入器明確取檔名並解析到 `res://audio/peritune-campaign-v1/`。供應文件中的WebAudio／AudioContext是原始平台建議；本專案實際使用Godot原生AudioStreamOggVorbis。

## 真實場景對照

場景index為0起，來自三份 `game/data/stage-0*.json`，不是推測的外部scene ID。下表是無頭目覆蓋時的基礎曲目。

| 關 | index | 專案場景名稱 | cue | 原曲 |
|---|---|---|---|---|
| 1 | 0 | 竹林伏擊 | `s01_bamboo_approach` | Shizima3 |
| 1 | 1 | 高根山暴雨山道 | `s01_outpost_battle` | Strategy4 |
| 1 | 2 | 山腳市集 | `s01_outpost_battle` | Strategy4 |
| 1 | 3 | 前哨寨門攻防 | `s01_outpost_battle` | Strategy4 |
| 1 | 4 | 夕照兵糧營 | `s01_outpost_battle` | Strategy4 |
| 1 | 5 | 池石指揮庭園 | `s01_outpost_battle` | Strategy4 |
| 1 | 6 | 前哨陣內室決戰 | `s01_outpost_battle` | Strategy4 |
| 2 | 0 | 朝霧大高街道 | `s02_supply_road_battle` | Strategy2 |
| 2 | 1 | 扁舟川岸渡口 | `s02_supply_road_battle` | Strategy2 |
| 2 | 2 | 荷駄集落與米倉 | `s02_supply_road_battle` | Strategy2 |
| 2 | 3 | 夕照鳴海坂道 | `s02_supply_road_battle` | Strategy2 |
| 2 | 4 | 丸根砦外柵攻防 | `s02_fort_battle` | Fight3 |
| 2 | 5 | 砦內兵糧庭決戰 | `s02_fort_battle` | Fight3 |
| 3 | 0 | 前營警鐘（占位素材） | `s03_rain_approach` | Shizima4 |
| 3 | 1 | 層層木障（占位素材） | `s03_camp_battle` | Amenoshita3 |
| 3 | 2 | 帳前錯落陣形（占位素材） | `s03_camp_battle` | Amenoshita3 |
| 3 | 3 | 帳內雙將（A/B 占位） | `s03_dual_miniboss` | Kengeki |

- 第一關竹林初遇接近敵人（距存活玩家小於360px，且敵人已入場）或破壞物件後，Shizima3轉Strategy4；離開敵人／殺敵不會切回安靜曲。
- 第二關前四場景連續Strategy2，後兩場景連續Fight3。前者移動／接敵只調音量，不重開音源。
- 第三關雨營同樣首次接敵或破壞物件轉Amenoshita3；警鐘、木障、陣形保持同一播放游標，進場交戰較輕、後兩景恢復音量。帳內雙將使用Kengeki；遭遇phase `awaiting_yoshimoto`／`yoshimoto`立即切EpicBattle_J，含義元登場。
- 存活頭目覆蓋：第一關小王／松井宗信用Ametsuchi；第二關小王／佐久間盛重用Amenoshita2，地方小王較輕；第三關雙將Kengeki、義元EpicBattle_J。戰鬥內容／AI／命中與章節解鎖未因此改動。

## 播放、音量與清理

- [CampaignMusic](../game/core/campaign_music.gd)統一選曲、音量與過渡；[CombatAudio](../game/render/combat_audio.gd)沿用兩個Music bus播放器，最多一主曲加一個淡出尾音。同cue只更新目標音量，不重建stream或重啟；Wire白名單含12個新cue。
- 原生OGG明設 `loop`、`loop_offset=0`、`beat_count=0`，完整串流結尾回到起點；勝利短句不循環。勝利短句約6.7765秒，自然 `finished` 一次後接約24.7741秒結果循環，持續won快照不重播短句。won優先於殘存敵兵／頭目。
- 勝利開始立即停止主曲及淡出尾音。缺一般OGG回退既有legacy WAV；缺勝利音檔停止戰鬥及尾音。非campaign入口保留既有WAV路由。
- 輸出基準0.65，安靜曲乘0.8、第三關初接敵乘0.85、第二關兵糧道移動乘0.7／接敵乘0.9、小王乘0.85。使用既有Music音量與mute；SFX／語音bus獨立。一般跨曲0.6秒，安靜曲進場1.2秒，王曲0.25秒、雙將0.3秒、勝利短句0.18秒、結果循環0.25秒，沿用等功率交叉淡化。
- 暫停同時保留兩個播放器游標與淡化進度。campaign重開先停止舊曲再選新曲；敗北、離開／返回沿用stop並清理尾音，過期finished不能重啟勝利曲。訓練既有重設不強制重啟BGM。

## 實際驗證與限制

- `campaign_music`：136 checks／0 failures，包含12檔SHA／原生解碼／時長與loop旗標、17實際場景與Wire、首次接敵、同曲跨景／連續快照不重開、三關王曲、殘兵下勝利優先、短句只播一次接循環、敗北／重開／暫停／離開、一般缺檔fallback、勝利檔案／登錄缺失停聲。
- 11個循環檔各作兩次接近結尾seek後的自然循環邊界測試，檢查跨界仍播放、回到開頭且保留seek後的播放實例。這是加速邊界檢查，沒有宣稱每首完整播放兩輪或主觀聽感通過。
- 共8組相關測試在最新各自結果下通過：campaign_music、stage03_yoshimoto、stage03_yoshimoto_view、stage2_route_v29、music_v21、audio_v20、wire、music_integration_v14。義元119 checks、Wire304 checks、Main音樂整合22 checks；沒有重跑整個repository全部測試。
- 原生WASAPI Main測試exit 0，八張畫面；勝利短句不seek、自然播放完成後已接明亮循環。保留本機 `artifacts/campaign-music-v1/native-review.log`、`native-engine.log`、`native-exit-code.txt`及`native-review/`。既有直接載圖export警告仍存在，沒有宣稱發行包已通過。
- 測試過程曾因舊確認對話框fixture及過短邊界等待失敗；調整fixture後重跑通過，且保留訓練BGM既有行為。原始報告留在本機 `artifacts/campaign-music-v1/`，結構化摘要隨資產交付。

主觀聽感、與攻擊預警／語音的實機混音、每首完整連播兩輪、實體雙搖桿、跨機多人與發行包資產驗證仍待完成。前三關音樂接入不代表第三關正式人物／場景／物件／音效／語音或真人平衡已完成；不merge、不發布遊戲。

可針對重驗（PowerShell）：

```powershell
$env:GODOT_BIN='D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
node scripts/test-v19.mjs --only=campaign_music,music_integration_v14
```
