# 戰國鼓弦配樂接入

2026-10-15。本機試玩採十首新編場景曲，使用 SCC Taiko Drums 的實錄太鼓及 VSCO 2 CE 的大鼓、小提琴、大提琴、豎琴與長笛。原先以振盪器合成的音樂不再由正式播放表選用。未更動戰鬥音效、角色語音或玩家音量設定。

使用者指定《吞食天地 II 赤壁之戰》、《三國志》、《信長之野望》與《無雙》為參考。此次採歷史戰陣的節奏、日式五聲音階與分場景配器方向，旋律為新作，沒有完成指定原曲的逐音重編或聽辨驗收。

| 場景 | 曲名 | BPM | 配器重點 |
|---|---|---:|---|
| 主選單／演武 | 天下布武 | 104 | 弦樂主題、低鼓 |
| 竹林 | 竹霧潛行 | 82 | 長笛、疏落弦樂與太鼓 |
| 市集／街道／米倉 | 城下行旅 | 114 | 豎琴、輕鼓與短弦 |
| 雨道／坂道 | 雨道進軍 | 132 | 太鼓、大鼓與低弦推進 |
| 寨門／陣內 | 破寨之陣 | 144 | 弦樂齊奏、重鼓與鼓棍 |
| 夕照兵糧營 | 夕照兵糧 | 96 | 豎琴、緩和低弦 |
| 池石庭園 | 池石微風 | 78 | 長笛、留白、弱鼓 |
| 川岸渡口 | 川岸伏兵 | 108 | 長笛短句、太鼓與低弦 |
| 小將交鋒 | 陣將交鋒 | 150 | 密集鼓組、短弓弦樂 |
| 大將決戰 | 大將決戰 | 164 | 大鼓、太鼓連奏與弦樂齊奏 |

每首約 47–74 秒，24 或 32 小節完整循環；反射尾音跨越循環接點。沿用兩播放器交叉淡入淡出，大王登場 0.55 秒切換；敵將死亡後返回所在背景的曲目。`camp`、`courtyard`、`riverbank` 依背景細分，保留既有關卡／連線資料格式。

## 來源與重建

- 太鼓：[SCC Taiko Drums / Floe](https://github.com/floe-audio/Taiko-Drums)，Subaqueous 錄音，S. Christian Collins 製作取樣配置，CC BY-SA 4.0。
- 弦樂、大鼓、豎琴與長笛：[VSCO 2 CE](https://versilian-studios.com/vsco-community/)，Versilian Studios / Sam Gossner，CC0。
- 原音 40 檔、48,634,752 bytes；`assets/music-v35-sources/manifest.json` 固定來源 commit、Git blob SHA、SHA256。建置使用的實錄取樣不混入遊戲包；只包成品曲目、曲譜及授權文件。
- 十首成品音樂採 CC BY-SA 4.0，署名及變更說明位於 `game/audio/v35/CREDITS.txt`。這個聲音授權不變更其他遊戲內容的授權。

Python 建置需要 numpy、scipy、soundfile；本機額外套件放在 `tools/music-v35-python`。使用 Python 執行：

```text
scripts/fetch-music-v35.py
scripts/generate-music-v35.py
scripts/generate-music-v35.py --check
```

`music.json` 保留完整音符事件、音源、音量及 SHA256。`artifacts/music-v35/preview.html` 提供十曲各 24 秒試聽。

## 驗證與限制

十曲來源雜湊、解碼、立體聲、峰值、RMS、無長段靜音及循環接點檢查通過。Godot `music_v35` 119 項檢查涵蓋十曲實際跨尾循環、第一／第二關 13 段背景、敵將優先權、死亡回曲、切換不中斷及選單復歸；`stage_music_v18` 46 項通過。舊測項的王戰淡入與音量假設已按現有 v27 行為修正。UI 流程與同機雙人啟動回歸通過。

打包清單檢查為 827 個依賴，包含全部十首曲目及授權文件，未建立新 EXE／PCK。技術通過不代表真人試聽通過；音色、旋律、與語音混音及實體揚聲器效果尚待使用者確認。
