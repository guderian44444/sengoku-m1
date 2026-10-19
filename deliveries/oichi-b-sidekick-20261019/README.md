# 阿市 B 轉身高側踢｜素材與接入交接

這個分支只新增素材與交接，**未接入 runtime、未修改 main、未 merge**。使用者暫接受目前 B 的腿型與服裝，核准先採用這版持弓無箭的轉身高側踢及加粗氣勁。原圖沒有重畫、拉腿或改衣服。

- 分支：`codex/oichi-b-sidekick-assets-20261019`
- 原儲存庫：`https://github.com/guderian44444/sengoku-m1.git`
- 素材分支起點：`702b2f602a553a11469fd34a8337d055093844b8`（main）
- 尺寸與接入介面參考：第五關試玩分支 `codex/stage05-integration-20261018`，`fbda57c3d28c07dcc125cde4ab9b5ec61a59c4f7`
- 原核准預覽 Library ID：`libfile_efaf7c2759fc819199a067078755196a`

## 先看這些檔案

| 用途 | 檔案 |
|---|---|
| 給友軍接入的尺寸、腳錨、逐格圖層候選 | [light_3.candidate.json](ready-assets/light_3.candidate.json) |
| 身體與氣勁貼圖 | [body-atlas.png](ready-assets/body-atlas.png)、[fx-atlas.png](ready-assets/fx-atlas.png) |
| 校準後與現行站姿並排對照 | [calibrated-standing-comparison.jpg](alignment/calibrated-standing-comparison.jpg) |
| 每格新舊腳錨及畫布偏移 | [calibrated-anchors.json](alignment/calibrated-anchors.json) |
| 185 筆阿市現行及 B 尺寸／來源登錄 | [all-actions.csv](alignment/all-actions.csv)、[all-actions.json](alignment/all-actions.json) |
| 前兩段起止與 B 的銜接對照 | [同尺度對照](alignment/combo-transition-comparison.jpg)、[銜接量測](alignment/combo-transition-validation.json) |
| 預設 60Hz 姿勢、氣勁、root motion | [default-60hz-timeline.json](ready-assets/default-60hz-timeline.json) |
| 原始核准預覽（未做本次尺寸校準） | [正常速度 GIF](original-approved-B/oichi-B-fx-only-body-and-white-costume-pending-normal-speed.gif) |
| 原圖及可逆映射 | [原始整張圖](original-approved-B/generated-turning-side-kick.png)、[八張姿勢](original-approved-B/poses)、[還原映射](alignment/restore-original-pixels.json) |

原來源 manifest 保留了當時「未啟用／修圖未完成」的文字，沒有修改原檔。使用者本次已暫接受這些腿型及服裝；接入狀態以本交接為準。

## 尺寸與腳錨已校準

正常遊戲阿市高度為 **148 world units**。現行 v33 戰鬥多數 body ruler=315，反向摔投=148；移動、跳躍及受擊各用已登錄的450～900尺規。美術展示的225高度不是遊戲高度。站立 idle 實際使用 `light_1/0`，不是 current/idle。

B 原試作尺規380、兩腳間根點已完整保留在 [light_3.approved-scale.json](ready-assets/light_3.approved-scale.json)。交接候選採全八格共同尺規 **390.347222**，整體縮放相對核准試作 **0.973492261**，PNG 像素不變。判定數值不受美術縮放影響。

校準排除高於頭頂的弓尖，以起手／收勢的頭髮頂至鞋底對齊現行站姿：現行152.23 units，B校準後153.56／150.90，偏差均小於 **0.9%**。頭部量測保留±3 source px誤差；不以每格透明外框個別拉伸身體。[量測資料](alignment/standing-calibration.json)

腳錨採前方落地鞋底群中心，加上現行 `light_1/0` 腳錨至鞋底中心的偏差。腳底相對 ground 的垂直偏差同樣匹配舊站姿（4.081746 units）。原B兩腳間根點不再直接用於交接候選，避免起手／收勢相對舊前腳根點跳位。每格身體、已畫入的弓、氣勁同步平移。已逐像素確認第一段末姿勢＝第二段首姿勢、第二段末姿勢＝舊第三段首姿勢＝idle；八張B的前方鞋底群中心相對根點及鞋底垂直偏差均已對齊此參考，正反朝向數值驗證通過。已附1、2段起止與B起止的同尺度比較；實際輸入／hit-stop仍須接入者在遊戲驗收。

```text
scale = 148 / body_height
world_x = fighter_x + face * (source_x - anchor_x) * scale
world_y = fighter_y - z + (source_y - anchor_y) * scale
```

`current` 圖載入會加2px透明 padding，腳錨也加(2,2)；v33 atlas 直接使用 crop-local anchor。表內分開記錄兩種情況。左向須一起鏡像身體、弓、氣勁。不要以增加 root_step 掩蓋畫布偏移。

`aligned-original-pixels/` 是未縮放的640×704可逆畫布，原始根點(280,600)，只是製作參考；不是校準後 runtime atlas。每張原RGBA可從還原矩形完整取回。原始少量鄰格alpha1～5保留不清除，尺寸量測用alpha>=32排除。

## 接入契約

只替換阿市 **light_3**，第一、二段、傷害、裝備加成、擊飛力度與終結恢復規則不變。

- 八張姿勢0→7，預設60Hz持續ticks `[2,2,2,2,4,4,4,5]`，總25ticks／416.667ms；tick8接觸。
- 候選保留舊作者時鐘 `duration_ms=970`、`contact=380`，由現有 `combat_time_ms` 映射。為保存舊root_step與FX淡出，分成17個登錄時間段，仍僅八張身體姿勢。
- 舊root_step時間完整保留；阿市輕手runtime會乘3，最後前進54 units，預設tick0/7/8/11/14的累計位移為0/9/30/48/54。這是保留的合理前進，不是腳錨修正；校準只平移整張姿勢，不改姿勢內四肢相對位置。不同攻速及hit-stop繼續沿用同一時鐘。
- 只在pose3、4顯示氣勁：tick6～9全量、10為2/3、11為1/3、12收腿起消失；在身體後方 `fx_back`。
- `fx-atlas` 已預先生成。身體尺規390.347222，對應FX尺規304.059942；腳錨delta已按296/380映射給FX。不要把FX原始登錄當成校準後的圖層錨點；以candidate每格layers為準。
- 弓已畫在完整姿勢內，沒有箭。候選 `authored_weapon=true`、`fixed_weapon=true`、`nocked=false`，沒有獨立weapon layer；需沿用現有authored分支，避免多畫一把動態弓或箭。
- 預設第三段前方判定 **258.336**、縱深半寬 **82.944**、背後18。基礎reach138 × 阿市1.3 × 既有終結1.44；depth57.6 × 1.44。只套用阿市第三段，前兩段115／48不動。裝備距離照原位置加入，不再額外乘1.2。
- 普通目標原擊飛horizontal12／vertical6、初始z=1，終結恢復30ticks；不新增更大擊飛。
- 保留既有finisher事件供同步／測試使用，但避免舊通用終結弧與腳部氣勁重複顯示或延續到收腿後。

目前 `ArtAssets` 載入器會在圖層路徑加 `v33/oichi/` 前綴。這份候選使用新素材資料夾內的相對檔名；友軍必須明確接上資料夾及僅覆寫light_3綁定。**放入JSON不等於已接入。**

## 保留與還原

`original-approved-B/` 完整保留原圖、核准預覽及原FX演算法；`baseline/` 保留19份既有阿市登錄、atlas及武器圖等素材。runtime程式不在本素材分支內，只在[snapshot-manifest](baseline/snapshot-manifest.json)留來源雜湊。

還原時，撤回接入者自己新增的light_3綁定及第三段判定改動即可；不要用baseline整包覆蓋後續其他人的工作。回復未校準B腳錨可參照approved-scale候選；回復原遊戲第三段可參照baseline/v33登錄。原始圖片字節與變換資料均保留。

## 已驗證及友軍待驗收

已完成逐檔SHA256、八姿勢atlas原RGBA一致、統一畫布逆轉、25tick姿勢／FX／舊root_step一致性及校準後身體／FX共同偏移驗證。兩張atlas解碼約9.27MiB；未執行Godot，因此不宣稱實機效能或遊戲接入通過。

執行唯讀檢查（Python＋Pillow）：

```sh
python tools/verify_package.py
```

接入後請驗收：真實輸入1→2→3與回idle、左右朝向、腳底／握弓不漂、無重複弓箭；258.336／±82.944及背後18的內外緣、裝備加成、原擊飛；氣勁tick6～11與hit-stop／攻速同步；重複連段貼圖載入與記憶體穩定。完成後交實際Godot正常速度預覽。

適用回歸：`test_light_finisher`（僅更新阿市第三段預期值）、`test_light_finisher_cadence`、`test_combat_v33`、`test_current_runtime_v33`、`test_variable_frames_v36`、`test_oichi_air_multihit`，以及第五關combat/network/streaming。

[SHA256SUMS.txt](SHA256SUMS.txt)涵蓋本資料夾所有檔案（校驗表自身除外）。既有v33的部分rgba_sha256是打包前crop雜湊，可能因alpha_composite改變透明RGB而不等於atlas解碼值；原歷史值保留，當前PNG完整SHA256另記錄。
