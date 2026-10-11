# 本多忠勝 v22 身體／武器分層素材

26 套／156 張真姿勢，原生 built-in imagegen 生成，保留原始透明 RGBA，不用程序重畫補幀。各動作六格，黑甲、鹿角兜、白念珠、紅黑肩披風。武器由遊戲另行繪製；人物圖保留握拳與逐格握點。畫法參考正式 v19 今川兵。

`registration.json` 保存每張原圖 SHA256、裁切矩形、腳底錨點、主握點、角度、前後武器層及手掌遮擋矩形。`clip_polygon` 只在遊戲渲染時排除鄰格輪廓；原 PNG 的 alpha／RGB 完全不改。原生 1536×1024，每張 3×2 六格，`body_height=390` 不含鹿角，不隨屈膝動作縮放。

| 動作組 | 原始 clip |
|---|---|
| 移動 | idle、walk、run、jump |
| 普通攻擊 | light1–3、heavy1–2 |
| 蓄力／衝擊 | charge_forward、dash、slam_charge、charged_slam、upper、low_sweep |
| 空中 | air_light、air_heavy |
| 防守與反應 | hurt、guard、death、recover、launched |
| 抓投 | holding、throw |
| 大絕與慶祝 | special、victory |

通用 action 的 21 個 aliases 全部指向本次新圖。受控凍結／暈眩共用痛苦動作；上挑快慢版共用真正上挑六姿勢，時序由遊戲控制；下重蓄力與釋放有各自六格。倒地最後為完整躺平，起身由側撐、跪膝到站起。勝利為高舉槍、撫念珠收勢。

`charged_slam` 的第 4、5 格設 `weapon_grounded:true`，手掌沿槍身滑握以使槍底貼地，槍長與原握點不變。抓投時槍繪在背後，不能消失變空手裝備。`portrait` 直接取本次 idle 的頭部。

生成提示與來源在 `prompts/generation-journal.json`。`light2-boot-repair.json` 記錄右下靴尖留白修正；修正前原圖留在 `sources/`，不作執行時素材。

走路水平錨點使用落地雙腳範圍中點，避免像素中位數因一隻靴子面積較大而跳到單腳。跑步六格由骨盆位置人工登錄，讓握槍相對玩家根位置的水平差小於 4 遊戲像素，空中擺腳不牽動整個人物忽前忽後。

重建登錄：`python scripts/register-tadakatsu-v22.py`。來源驗證：`python scripts/test-tadakatsu-v22.py`，916 檢查包含每圖六個人物、所有來源 hash、身體不碰畫布外框、握點位於不透明人物、裁切輪廓無鄰人、走跑腳間距有超過 80 像素差異、跑步握槍水平穩定。全 action native sampler／裝備渲染另外由 v22 runtime tests 驗證。
