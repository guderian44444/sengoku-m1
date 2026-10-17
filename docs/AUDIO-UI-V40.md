# 首頁、音效與介面素材接入

2026-10-17，本機現行版本接入三批交付，保留 f553400c 的成熟角色語音及 v39 的跳重／秀吉範圍修正。

## 首頁與介面

- Amenoshita 由 PeriTune／むつき醒創作，CC BY 4.0；署名及核准交付時序保留在 `game/audio/title-amenoshita-v1/`。首次啟動播放 14.8059 秒前奏，在 14.7059 秒開始以 100 ms 線性淡接 128.1356 秒循環曲。返回選單只播循環，同頁切換不重開；音檔已有 0.65 增益，不重複衰減。沿用 Music 音量設定與章節管理器。
- MasaFont Regular 原檔與 OFL 授權在 `game/assets/current/fonts/`，不額外加粗或描黑邊。原版 `scroll02_blank.png` 作為共用卷軸按鈕，文字仍動態繪製，保留焦點、停用、滑鼠與手把操作。
- 移植來源為本機交付 `6aa32e9a` 與 `fb0304fb` 的限定程式差異，不覆寫目前角色、戰鬥或語音程式。

## 武器音效

`game/audio/weapons-v3/` 保存全部 98 個原版 48 kHz mono PCM16 WAV、來源清單與 SHA。來源 ZIP SHA256 為 `3fdc045f382f8dd8d5c815b41dc870e86f2b949ecbc67c934d9493ccca390f07`；CC0 來源見同目錄 `SOURCES.md`。遊戲只使用 WAV，沒有與同內容 OGG 同播，也沒有修改原音檔製作音量或將棍杖空揮／命中交換回去。

| 動作／接觸 | 接入方式 |
| --- | --- |
| 刀劍、槍刺、薙刀、棍杖、弓箭、飛針 | 真正釋放時播空揮／放弦，確認碰撞後才播命中。薙刀以裝備 ID 區分；劍氣使用長柄掃風，不當飛刀。 |
| 肉身、護甲、格擋、木製道具 | 傷害事件攜帶實際材質；箭入木僅限箭／飛針命中木箱或木道具。護符吸收與人體盾牌分開，吸收後的殘餘傷害不重播命中。 |
| 頭槌、膝擊、抓住、投出、身體撞擊與落地 | 信長／家康／顯如用頭槌；阿市／秀吉／忠勝用膝擊。投出只播破風，身體落地才播撞擊，濕地保留水聲。 |
| 敵我火槍 | 各三個實際變體；新音庫獨占槍聲，保留共享槍口閃光。 |
| 蓄力、旋轉、家康一閃 | 通用蓄力起手及循環，實際放開才播釋放；家康一閃播拔刀。同一動作的刀與劍氣共享一次聲音。旋轉末擊只在命中時播放。 |
| 元素 | 確認元素命中才疊低音量短聲。燃燒／冰凍狀態與實際元素必殺期間有循環，結束、死亡、換場會清理。 |

循環檔由 `scripts/import-audio-v40.py` 對原音做 20 ms overlap，另外輸出六個 `-loop.wav`，原檔保持不動；控制器在開始／取消時做 60 ms 淡變，暫停也凍結淡變。換場立即清空。沿用六聲物理音池及十二聲特效池、SFX bus、既有語音與音樂音量，不採用素材預覽的高增益。各 bank 按真實長度洗牌，三變體不再硬套五份。

`punch_hit`、`sword_sheathe`、`musket_reload` 已保留入庫，現有動作沒有可靠的拳擊、收刀或裝填接點，故不拿它們代替其他動作。火槍及裝填素材是設計聲，並非史實錄音。多敵混音沿用有上限的聲音池，未另加按音量挑選最強三個敵人的演算法。

## 驗證

- 原 ZIP 215 檔逐位元一致、214 項 SHA、98 WAV＋98 OGG 及預覽 MP3 獨立解碼，無數位削波。結果：`artifacts/audio-integration-v40/source-verification.json`。
- 18 組原生測試通過；`audio_v40` 共 753 checks，涵蓋全部 bank、原檔／衍生循環 SHA、實際抓技材質、聯機事件、音效所有權、淡變、暫停、死亡與換場。既有角色語音、章節音樂、UI、戰鬥、第三關與網路回歸也通過，彙整在 `artifacts/audio-integration-v40/verification-summary.json`。
- WASAPI 原生播放讓前奏自然到達接點，40 checks／0 failures；四種尺寸與五種控制項狀態的原生截圖通過，已檢視主選單及按鈕狀態。
- 打包器包含新音樂、音效與字型／卷軸；只檢查發行依賴清單，沒有重做或發布 EXE／ZIP。

```powershell
$env:TEST_ARTIFACT_DIR='D:\AI\吞食戰國\artifacts\audio-integration-v40\verification'
node scripts/test-v19.mjs --only=audio_v40,weapon_audio_v38,heavy_wave_v39,title_music,music_integration_v14,ui_scroll02 --render-audio-v40
```

原生音訊播放、合成輸入及截圖不等於使用者聽感、實體手把或真人連線驗收；本次未 commit／push。
