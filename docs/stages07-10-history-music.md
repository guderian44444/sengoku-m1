# 第 7–10 關：人物史料與和風配樂

核對日期：2026-10-22。關號與大王沿用《第一關與24關設計-v0.19》；第 6 關由另一作業處理。

## 人物配置與史實界線

| 關卡 | 小王／角色 ID | 大王 | 配置依據與演繹範圍 |
| --- | --- | --- | --- |
| 7．美濃山道（1567） | 氏家直元（卜全）`ujie` | 稻葉良通（一鐵） | 兩人與安藤守就同屬美濃三人眾。1567 年三人眾轉向織田是史實；本關把轉投前的山道交鋒作為 IF 演繹，不能表述為三人眾最後忠於齋藤的史實戰役。 |
| 8．岐阜城門（1567） | 長井道利 `nagai` | 齋藤龍興 | 龍興是稻葉山城主，1567 年失城。可兒市發掘報告討論長井道利作為龍興家臣、掌握明知莊與烏峰城的史料。把他移到最後城門戰是戰場濃縮；具體守門、拔刀、箭雨招式均屬創作。關名沿用「岐阜」，當時攻城目標仍為稻葉山城。 |
| 9．上洛街道（1568） | 三好長逸 `nagayasu` | 岩成友通（石成友通） | 三好長逸、三好宗渭與岩成友通為三好三人眾。1568 年上洛軍攻略芥川城、把岩成逐出勝龍寺城有地方官方資料支持；把兩處戰線合併為街道阻擊與民眾撤離是遊戲編排。 |
| 10．金崎退卻（1570） | 朝倉景恒 `kagetsune` | 朝倉義景 | 敦賀市資料記錄朝倉景恒率軍守金崎、天筒兩城。金崎陷落後織田軍退卻是背景；景恒在退卻路上再戰、義景親自封鎖出口均是 IF，並非經史料證實的單挑。 |

武器招式、顏色、配飾與招式特效用於玩法與辨識，並不聲稱是人物真實武藝或甲冑復原。稻葉家可查證的家紋為「折敷（三方）に三文字」；其他未核實的服裝細節不標成史實。

史料連結：

- [岐阜市：稻葉良通與美濃三人眾、家紋](https://www.city.gifu.lg.jp/kankoubunka/kankou/1013050/1005149/1017450/1017465/1020528.html)。記錄由齋藤轉向織田的年份。
- [岐阜市：岐阜城歷代城主](https://www.city.gifu.lg.jp/kankoubunka/kankou/1013051/1005097/1034742/1034737.html)。核對龍興與 1567 年落城。
- [可兒市《金山城跡發掘調查報告書》，奈良文化財研究所全國遺跡報告總覽](https://sitereports.nabunken.go.jp/files/attach/36/36653/40743_1_%E9%87%91%E5%B1%B1%E5%9F%8E%E8%B7%A1%E7%99%BA%E6%8E%98%E8%AA%BF%E6%9F%BB%E5%A0%B1%E5%91%8A%E6%9B%B8.pdf)。長井道利與龍興的關係見正文第 12 頁附近；報告亦說明年代比定及身份推論有不同解釋。
- [可兒市《史跡美濃金山城跡保存活用計畫書》](https://www.city.kani.lg.jp/secure/14783/kaneyamahozonkatsuyou.pdf)。1565 年棟札與明知莊代官的證據。
- [大東市：飯盛城與三好氏資料](https://www.city.daito.lg.jp/uploaded/attachment/26278.pdf)。三好三人眾及 1568 年芥川城攻略。
- [長岡京市：京都防衛要地勝龍寺城](https://www.city.nagaokakyo.lg.jp/0000011496.html)。年表明列 1568 年信長逐走石成友通。
- [敦賀市：金崎城及周邊城跡導覽](https://www.city.tsuruga.lg.jp/page/4440.html)。金崎退卻背景。
- [敦賀市：中池見濕地保全活用計畫資料](https://www.city.tsuruga.lg.jp/kurashi/kankyou_kougai/nakaikemi/nakaikemishichihozen.files/0011_20211209.pdf)。第 3.3 節「人文的歷史／天筒山之戰」提及景恒守金崎、天筒。

## 遊戲內配樂

| 關卡／時機 | 曲目 | Runtime key | 選曲理由 |
| --- | --- | --- | --- |
| 7．山道接敵前 | Oboro2 | `s07_mountain_approach` | 笛、琴、笙與撥弦，襯托霧中山道；首次接敵後不再退回安靜開場。 |
| 7．交戰、氏家與一鐵 | Ametsuchi | `s01_matsui_boss` | 琴、拍子木與管弦的沉著力度，配合破柵與重刀。重用既有檔案。 |
| 8．城門至本丸 | Amenoshita | `s08_castle_battle` | 壯闊和風管弦，對應逐層攻城與城主號令。使用完整官方循環段，與標題畫面的剪接版本分開。 |
| 9．街道攻防 | Amenoshita3 | `s03_camp_battle` | 三味線、尺八、和太鼓與管弦的推進感，適合撤離與交叉火線。重用既有檔案。 |
| 10．殿後退卻 | Amenoshita2 | `s02_sakuma_boss` | 142 BPM 的琴、三味線、太鼓與拍子木，維持追兵逼近的壓力。重用既有檔案。 |
| 四關勝利 | Oboro2 | `s07_mountain_approach` | 0.35 秒淡入緩和的和風循環；新四關不播放舊凱爾特勝利短句。 |

每關戰鬥旋律不同。一般戰鬥採 0.52 runtime gain，大王存活時提高至 0.65，保持同一播放游標；Oboro2 為 0.45。音樂音量滑桿仍由既有 Music bus 控制。敗北會停止主音軌與淡出尾音。

選曲依作曲者對樂器與風格的說明，排除 EDM、晶片音樂及和風搖滾曲。既有 Kengeki／EpicBattle_J 未分配至新四關。這是現代和風配樂，不聲稱為 16 世紀原樣演奏。

曲目及授權來源：

- [Oboro2（2019）](https://peritune.com/blog/2019/04/10/oboro2/)
- [Amenoshita（2015）](https://peritune.com/blog/2015/07/03/amenoshita/)
- [Ametsuchi（2018）](https://peritune.com/blog/2018/10/01/ametsuchi/)
- [Amenoshita3（2020）](https://peritune.com/blog/2020/08/13/amenoshita3/)
- [Amenoshita2（2016）](https://peritune.com/blog/2016/10/13/amenoshita2/)
- [PeriTune 官方使用規約](https://peritune.com/about/)明載：2026 年 2 月以前發布的曲目繼續適用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。以上均為此範圍；作者為 PeriTune／Sei Mutsuki，來源、授權、改動說明保存於 `game/audio/peritune-campaign-v1/CREDITS.txt` 與 manifest。

## 安裝與驗證

新增兩支 OGG：Oboro2 79.059 秒、Amenoshita 128.136 秒。官方來源下載 SHA、原始音軌 SHA、成品 SHA、取樣數、增益與接縫資料寫入 `game/audio/peritune-campaign-v1/manifest.json`。`scripts/import-expedition-music.py` 可從固定 SHA 的官方下載重建，保留完整循環長度，不變速、不改調；只調整音量、加入 2ms 接縫淡化並轉為 OGG。

既有 `scripts/package-current.py` 依 manifest 的 ID 收錄同名 OGG 並驗 SHA；新增兩支已符合規則，不需要另加音樂封裝分支。原始下載只放在忽略的 `artifacts/stages07-10-music`。

- 完整 PCM 解碼、立體聲、有限數值、每秒非全靜音、峰值及接縫檢查通過。
- `test_expedition_music.gd`：38 項通過，包含四關切曲、大王增益、同曲游標、勝利／敗北以及兩次實際 OGG 循環邊界。
- `test_campaign_music.gd`：148 項通過，包含既有 1–3 關音樂及新增 OGG。測試命令指定 Godot 4.7.2 `--headless --audio-driver WASAPI`。
- 日誌在 `artifacts/stages07-10-music/native-audio-test.log` 及 `campaign-audio-regression.log`。受限環境出現系統憑證與裝置名稱 UTF-8 訊息，未出現腳本／解碼失敗。

尚未完成人耳聽感與完整戰鬥混音驗收；解碼、循環和來源樂器描述不能取代實際聆聽。
