# 阿市 17 招最終素材包 · 2026-10-14

請從 [招式代表圖與說明](docs/combat-art-reference/oichi-final.md) 開始，接入前閱讀 [交接文件](HANDOFF.md)。

採用版本由ACTION_MANIFEST.json明列。包含每招正常速度GIF、代表圖、透明分層PNG、事件／接點JSON、來源及重建腳本。沒有更改遊戲runtime；本包以最新回饋完成素材整理，接線與引擎驗證交由Codex。

執行 `python verify_package.py` 核對全包SHA256、17招入口及播放時長。GIF是展示，不是人物正式貼圖。最終反摔為registered13格；最終箭雨半徑1230、70箭；不要回退其他中間版本。
