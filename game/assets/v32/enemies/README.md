# 第二關正式配件 v32

`equipment.png` 由內建 imagegen 生成，1536 × 1024 RGBA，與既有 v19 敵兵相同的寫實繪製、暖木色與鐵件色調。左側是木盾；右側是無文字的織田木瓜紋旗布。生成原檔為 `C:/Users/guder/.codex/generated_images/01a133e2-47a4-7da1-b899-e7ef34401a23/exec-2a7de479-c678-41d4-b222-9e0d89eb1558.png`。參考圖是 `artifacts/stage2-repair-v32/enemy-source-before.png`，僅用於畫風參考。

`registration.json` 登錄木盾取樣區、旗布取樣區、31 個盾兵前臂掛點、37 個旗兵格的旗布輪廓與 UV、原始七張旗兵 PNG 的 SHA256。`scripts/register-stage2-equipment-v32.py` 只產生這份登錄，不改動 v19 原圖；SciPy 使用既有 `artifacts/integration-v30/python-deps`。

ArtAssets 為第二關建立 Oda 專用動作鍵，保留原身體、旗桿、手與透明輪廓，在原旗布的區域套上木瓜紋旗布。第一關今川梳紋旗保持原本的動作鍵。盾兵使用有木紋、鐵帶與鉚釘的木盾，火矢兵沿用原弓、箭袋並在搭箭時顯示火焰；毀糧兵保留武將衣甲、刀、扇，移除假糧袋與跨身色帶。第二關敵人頭上不顯示兵種文字或將領名字，王名由 HUD 和開場對話顯示。

## 生成提示詞（內建工具）

Create a production transparent PNG game equipment atlas, TWO isolated objects side by side, wide landscape aspect. Reference image is STYLE ONLY: same crisp historical Japanese beat-em-up 2D hand-painted naturalistic sprite shading, warm muted browns, beige linen and dark iron, lit from upper left, no modern items. LEFT HALF: ONE small Sengoku infantry handheld rectangular wooden tate shield viewed frontal with slight 3/4 depth (right thin side visible), four weathered brown vertical planks, two narrow dark iron reinforcement crossbars with rivets, thick wood edge, leather strap implied behind, no hand and no character. Width 200 px, height 400 px centered in left half. It must look like a real battle shield, not a graphic icon. RIGHT HALF: ONE rectangular cream beige linen Japanese war banner CLOTH ONLY (no pole, no crossbar, no tassels, no person), front view, width320 height440, subtly bowed lower edge and gentle folds, physically lit cloth and stitching. Its only mark is an accurate black Oda mokko kamon: a five lobed quince flower ring with inset Tang flower; no writing or letters anywhere, especially no comb symbol of Imagawa. Keep the crest centrally placed large for readability at small sprite scale. Both objects fully visible, sharp clean edges, ample transparent padding between and around each, real alpha transparency, no background gradients, no ground shadow, no labels or numbers. This equipment will be mounted on the reference enemies at 30x60 game pixels.
