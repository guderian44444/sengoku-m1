# 首頁 Amenoshita 音樂接入

分支 `feature/title-amenoshita`，基底為遠端main `30fdac0349fb39bd769061318a497446a9ff0114`。查核時PR #8尚未合併，但遠端main已整合章節選曲／勝利管理器。本機main另有友軍未推送的`f553400c`語音修補與未提交戰鬥工作；本次不夾帶、不覆寫，也不沿舊第三關分支替換整份音訊程式。此提交只處理首頁音樂；UI字型與卷軸樣式另行交付。

## 音源與精確時序

使用者核准來源：Library `libfile_03484563bf008191afb1b9b8fdee3a40`，原包`Sengoku_Title_Amenoshita_Approved_v1.zip`，2,871,835 bytes，SHA256 `0dd6999e8df9733ba3a0bfa3017c56e10741a78e75c2d03ccb32c86584193ff2`。原ZIP保留於本機`artifacts/title-music-intake-20261016/`，兩個OGG及包內交接／署名／數值報告原樣隨專案交付。

- 首次進入首頁從0播`title_intro.ogg`，長14.805895692秒。
- 播放游標到14.705895692秒開始`title_loop.ogg`，沿既有兩播放器作100ms線性intro 1→0、loop 0→1；停止舊intro，持續同一loop播放實例。
- loop長128.135600907秒，原生OGG循環從0開始，`beat_count=0`、`loop_offset=0`；後續每圈不播intro、不再套長淡化。供應者頭尾各3ms保護及總時長保持不變。
- OGG已包含0.65降益與intro 0.6秒淡入，播放器增益用1.0；不重複乘0.65。Music bus仍受既有音樂音量／靜音控制。
- 過渡時間讀自[原始handoff](../game/audio/title-amenoshita-v1/title_music_handoff.json)；缺metadata時用原生intro長度減100ms。觸發受遊戲frame與音訊mixer更新粒度影響，不宣稱sample-accurate排程或主觀節拍驗收。

## 生命週期與備援

`CombatAudio.play_title_music()`記住本次程式執行是否已用過intro；一般首頁／主選單／設定／名簿之間移動保持同一播放器與游標。返回選單或連線失敗後播放loop，不重播intro。結束程式後下次啟動才重新播intro。

開始單人／雙人／演武時，由音樂管理器將首頁聲音交叉淡出並切既有章節／演武曲；返回選單同樣使用既有兩播放器轉場。戰鬥重開、勝利短句／循環、敗北及直接cleanup仍保留原本處理；素材展示仍停音樂。intro的finished亦作錯過時間閾值時的接續備援；過期尾音finished不會搶回主曲。

缺intro而有loop時直接loop；缺loop則從intro接回既有legacy WAV；兩檔都缺也回退legacy。缺檔不刪改來源檔，測試以載入失敗注入驗證備援。暫停保留播放位置，清理後不會被舊finished重新啟動。

## 來源署名與授權

Amenoshita — **PeriTune / むつき醒（Sei Mutsuki）**，2015-07-03，CC BY 4.0。[原曲](https://peritune.com/blog/2015/07/03/amenoshita/)、[官方條款](https://peritune.com/about/)、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。[CREDITS](../game/audio/title-amenoshita-v1/CREDITS.txt)保留作者、來源、改編與接縫處理；[六筆SHA](../game/audio/title-amenoshita-v1/SHA256SUMS.txt)及[來源身分](../game/audio/title-amenoshita-v1/source-library.json)可追溯。音樂授權獨立於程式碼授權。

## 實際驗證

[結構化結果](../game/audio/title-amenoshita-v1/runtime-validation.json)：五組相關測試最新結果全過：title_music、campaign_music、music_integration_v14、music_v35、ui_flow_v34。新首頁測試39 checks／0 failures，Main音樂整合22 checks／0 failures；涵蓋六筆來源SHA、原生時長、100ms線性中點、兩次循環邊界、同曲選單、暫停、進戰鬥與返回、連線失敗、缺檔備援。

原生WASAPI同測試加`--natural`共40 checks／0 failures、exit 0；實際Main intro不seek，自然進loop，等待後loop游標0.5137秒。原始日誌在本機`artifacts/title-music-v1/`。首次回歸有四個舊斷言仍期待legacy首頁／-19dB與返回legacy，已改為本次核准的intro／烘焙增益／返回loop後重跑通過，未為了測試取消新行為。

尚未做主觀聽感、戰鼓音色／燃度、每圈完整連播、實體手把及正式發行包驗收；不merge、不發布遊戲。

```powershell
$env:GODOT_BIN='D:\AI\吞食戰國\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
node scripts/test-v19.mjs --only=title_music,campaign_music,music_integration_v14,music_v35,ui_flow_v34
```
