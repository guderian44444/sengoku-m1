# 信長 16 招核准素材交付包

## 入口

- `delivery-manifest.json`：最終版本鎖定，16 招、232 播放格、10520 ms；反摔為 planted_v2 16 格 / 800 ms。
- 各招 `delivery-frames.json`：逐格時間、原生 master、圖層路徑與 SHA、腳/root/握點/刀角度、預覽轉換、事件與驗證範圍。
- 各招 `preview-approved.gif`、`frames-approved-review/`：原核准預覽，逐位元保存，不是原生高解析替代品。
- 各招 `frames-composite/`：原生尺寸透明合成 master。不要用 GIF 或預覽 PNG 放大取代。每格畫布可能不同，依 metadata 放置。
- 各招 `layers-visible/`，反摔為 `layers/`：人物、現用刀可見像素、握刀手前遮擋。蓄力釋放另有原生前後 FX。
- `validation-final.json`、`SHA256SUMS`：實際逐格驗證及檔案校驗。
- `representatives/`、`qa/`：代表圖與分層/腳點檢查圖。
- `weapon-swap-gaps.json`：逐格換刀缺口；`INTEGRATION-CONTRACT.md`：接入規則。

## 已完成的範圍

核准動作、身分、16 招選版、時長與原有高解析素材均保持。現有 RGBA 直接保留；RGB 背景依原核准渲染的背景規則移除，白領/白甲與深色衣料抽樣實看。原生素材疊回原背景的結果與核准渲染配方逐格驗證。可見圖層用來源像素分配，重組不改核准外觀。

圖層是同座標可見像素的分拆，必須 identity transform 重組。反摔 16 格完整 RGBA 像素相等；其餘圖層驗證所有可見 RGBA 像素與 alpha 相等。完全透明處 RGB 位元可因圖像庫不同而捨棄，沒有可見差。

原先 RGB 放在深底再縮放，與先去背後 RGBA 縮放的取樣不完全相同。抓起、蓄力等原本分別變換刀層與人物的配方，也不等於把合成圖再整張縮放。差異量已記在 `source-mapping.json`；核准 GIF / review PNG 與原渲染配方的對照是精確的。不要宣稱任意重新縮放輸出與原預覽逐位元一致。

## 明確未完成的範圍

- 未畫出被刀/手/軀幹遮住的隱藏底圖，不能直接獨立移刀或保證任意換刀無洞。232 格含 165 張不重複 actor master，是後續檢查上限，不是必須重畫數量。
- 部分 canonical blade 招式的刀層僅含獨立鋼刃，原來源刀柄/護手仍與人物融合。各格 manifest 有具體範圍。
- 反摔 005 刀被軀幹遮住，015 刀尖超出畫布。沒有補出原本看不到的部位。
- 抓起 003、正摔 015 的原核准素材在刀旁臉部有擦除透明缺口；保留核准 master。新武器若露出該區需另做局部 hidden-fill，不覆寫 master。
- 可見像素所有權在暗色接觸邊界仍有近似分類。重組相等證明外觀保留，不等於完整可動刀 rig。
- root/腳/握點/刀軸是美術座標，部分為影像推估；尚未驗證 runtime socket、碰撞、敵人抓取附著、世界位移或狀態轉移。

沒有修改遊戲 runtime、網站或 Git。Git 交付者應依接入契約存放資產，保持原 gameplay 契約；ZIP 只作傳輸，請解壓後提交檔案，不提交 ZIP。
