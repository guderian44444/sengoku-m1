> PROVENANCE ONLY. These are authoring-stage suggestions. Final runtime paths, timings, and behavior are in ../../catalog.json and docs/HANDOFF-SHARED-VFX-V1.md. No discarded ring v1 is included.

# 共用冰雪 VFX：美術與接入交接

## 交付狀態

四張獨立單張透明美術，不是四格逐格動畫。以 builtin imagegen 生成，未使用 Python 去背、畫特效或改色。首輪 sprite-strip 未通過幀布局及消散一致性，不列為交付。整合者看過 ice_arc 樣板後同意用單張美術＋程序動畫。

- `ice_arc.png`：右側 C 形上挑冰晶刀弧
- `ice_ring.png`：完整水平橢圓冰晶環，中心留空
- `ice_wave.png`：向右前進並升起的冰霜晶浪
- `ice_shatter.png`：徑向碎晶命中爆散

每張 1024×1024 RGBA，外圈至少64像素 alpha=0 gutter。原始生成圖完整保存在同名 `_source.png`。發行 PNG 只做統一等比 Lanczos 縮放，fit 入896×896，置中於1024透明畫布；不裁切，不去背，不改繪。`alpha_validation.json` 記錄像素統計。部分source低alpha霜粉靠近原圖邊界，外加gutter保護採樣；核心未見硬截斷。建議 Godot filter=linear, repeat=disabled，壓縮先採 lossless，正規 alpha mix，勿當 premultiplied 輸入。

## 共同 manifest

`ice_manifest.json` 每項含 texture, cell, columns, rows, row, frames, pivot, split_depth, seam, duration_ticks, loop, world_size。

- frames/columns/rows 都為1，播放幀序列只有[0]
- pivot 為 normalized [.5,.5]，中心是效果旋轉/擴張軸
- wave 若掛腳底，建議父節點額外用貼圖高約.37的offset對齊下緣，不偷偷變更共用pivot
- world_size 為建議畫面像素寬高，不是實際Godot世界米制；整合者需轉換現有遊戲單位
- texture 是建議目標 `res://assets/vfx/ice/` 路徑，需實際複製接入；本worker沒有修改repo
- tick建議60Hz。所有loop=false，沒有可無縫循環的作者格

## 程序時序建議

以下是接入建議，並非已生成的作者格；整合者負責實作及測試。

1. ice_arc：20 ticks，0–3淡入，3–12由下尾往上尖做極角遮罩reveal、scale .80→1.05，12–20淡出；可另加少量向上飄霜粉粒子。不要把整張僵硬地慢速旋轉當逐格揮刀。
2. ice_ring：30 ticks，0–5展開，5–18 tangential UV/網格微擾維持掃動，18–30 scale 1→1.12並淡出。從 UV.y=.5 分兩pass，後半 y<.5 在人物後層，前半 y>=.5 在人物前層；兩pass使用同一transform/time，半開區間分割避免接縫重複加亮。保留標準alpha；微量額外highlight可另pass，勿全圖additive。
3. ice_wave：28 ticks，0–6從低到高reveal，scale .75→1.0；6–18向前推移，18–28尾端先消散並fade。貼圖朝右；朝左用整體flip_h。若做持續冰浪必須增加独立粒子或真正6–8個連貫作者格，不可重播單張假稱循環動畫。
4. ice_shatter：16 ticks，0–2迅速淡入，2–7 scale .45→1.0，7–16 scale 1→1.25淡出；可疊加向外彈射碎晶粒子延長尾巴。適合短促命中，不循環。

雪花/霜粉長時間循環尚未交付為逐格素材，需要GPU粒子持續發射與隨機壽命/角度補足。單張縮放/UV扭動的質感與真正作者逐格不同，應如實標示。

## 美術與透明度

冷白薄核、冰藍透明晶片、刻面與霜粉，明確區別火焰。樣板在透明背景檢查有真alpha，不含棋盤或實底。mix優先以保留冰晶暗部刻面；大範圍additive會抹掉材質並導致過曝。

## 生成方式與 prompts

全部使用內建 imagegen，transparent_background=true。共同提示：single isolated production game VFX, true transparent RGBA, painterly samurai action RPG, faceted glacial ice and frost powder, restrained selective white highlights; no people, weapon, ground, text, borders or checkerboard. 各張主體提示見 `generation_prompts.txt`。
