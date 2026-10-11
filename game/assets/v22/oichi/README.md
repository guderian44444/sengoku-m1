# 阿市 v0.22 分層連續圖片

使用內建 image_gen，參考 v12 阿市的既定服裝、長馬尾、苗條比例與 v19 今川軍的正式繪法。26 組動作各有 6 張真正重畫的姿態，共 156 格。人物圖不烘焙長弓；主程式依握點與裝備資料，把目前裝備的弓疊在背部或手上，拉弦階段再依另一手的位置畫弓弦。

## 造型與動作

保留苗條身形、長黑馬尾、簡單金紅髮飾、白色無袖交領上衣、紅短裙與腰帶、黑護腕、白足袋和紅涼鞋。踢擊、跑步與大絕已依使用者回饋，把長版白色貼身短褲改回與既定造型一致的短版白色內搭。

| 類別 | 登錄的動作 |
| --- | --- |
| 移動 | idle、walk、run、jump |
| 地面攻擊 | light1、light2、light3、heavy1、heavy2 |
| 衍生技 | rising、low_sweep、dash_heavy、dash_strike、charged_upper、charged_slam |
| 空中與大絕 | air_light、air_heavy、special |
| 受擊與恢復 | hurt、down、recovering、launched、stunned、guard |
| 抓摔與慶祝 | throw、victory |

輕三以轉身、抬膝、踢出、跟隨和收勢表現迴旋踢；倒地最後一格保持躺平。走路 60 ticks／循環、跑步 45 ticks／循環，每組 6 格，放開移動立即回待機。握弓、拉弦、手掌遮擋和背弓位置逐格登錄，避免換武器後穿掌或浮在空中。

## 有效來源與歷史候選

執行時只讀 `registration.json` 列出的來源。待機使用 `idle-walk-source.png` 的前六姿勢；走路使用獨立的 `walk.png`。跳躍使用 `jump-spaced.png`，慶祝使用 `victory-boxed.png`，其版面輔助線在有效裁切範圍外。其餘動作使用同名 PNG。

`jump.png`、`victory.png`、`victory-spaced.png`、`run-covered.png` 和初稿的非有效動作保留作歷史候選，不能用它們覆蓋已登錄圖。提示及改稿記錄保存在 `sources.json`、`action-prompts.json`、`heavy1-prompt.txt`、`kick-costume-source.json`、`costume-sources.json`、`layout-sources.json` 與 `victory-source.json`；以有效來源的 SHA-256 和登錄檔為執行依據。

## 修改與驗收

1. 以原始 PNG 和提示作參考重畫，保留來源 RGBA；不要用去背或重採樣覆蓋原圖。
2. 修改 `scripts/register-oichi-v22.py` 的來源、腳底基準、解剖身高、握點、角度和遮擋區；重建 `registration.json`。姿態縮腰、跳躍或躺下不能拿當格外框高度作人物縮放依據。
3. 跑 `python scripts/register-oichi-v22.py --check`，檢查來源 SHA、登錄漂移、完整 26 組、每組六張不同像素、原圖邊界及握點。runtime 裁切會加透明邊距，以輪廓遮罩排除鄰格，來源圖片本身不改。
4. 跑 `node scripts/test-v19.mjs --only=hero_layers_v22,weapon_render_v22 --render-heroes-v22`，檢查 40 個遊戲狀態的 v22 覆蓋、不同武器、左右朝向及實際引擎合成。
5. 目視六格接續、腳底穩定、弓弦與握點、踢擊幅度、躺平死亡、慶祝及雙人遊戲；自動測試不取代真人連續操作驗收。
