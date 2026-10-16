Git 版路徑說明：下文 runtime/ 對應本目錄；qa 對應 docs/qa/hideyoshi-v27/；接入文件為 docs/hideyoshi-v27-handoff.md。sheets 可重建而未重複提交，review 刀使用既有 game/assets/v22/weapons。

秀吉 v27 打刀＋固定葫蘆扇完整角色素材

內容：39組動作 × 6格＝234個原生姿勢，另1張透明頭像。
22組攻擊源自核准22個接觸姿勢；不是22個獨立按鍵。另17組移動、受擊、倒地、回復、防禦等。

素材完成／待遊戲整合。
所有預覽為離線素材合成，不是遊戲錄影。三刀檢查使用普通打刀、美濃兼定、大包平的既有原尺寸／世界長度。

runtime/body：透明RGBA單格，保留原生大小。
runtime/sheets：對應3×2透明圖集；只供替代載入/素材檢視，與單格内容相同。
runtime/layers/hands：手指和必要的近前臂前景遮擋。
runtime/ui：同造型頭像。
runtime/registration.proposed.json：腳root、雙握點、刀角、來源追溯和遮擋信度。
runtime/equipment-placement.json：逐刀逐格主握點偏移，需配合helper接入。
runtime/animation_plan.json：39組與特殊技18格串接。
runtime/approved_contact_map.json：核准22姿勢輸入對照。
runtime/profiles：局部材質調色recipe，原生alpha和幾何不變。
sources：僅最後實際採用的原始來源PNG；棄稿不納入。
production：最終逐格量測、提示詞、參考與重建工具。
qa：39組全格contact sheets、全動作三刀短片、來源／調色／整合檢查。
docs/CODEX-INTEGRATION.md：舊遊戲尚需接入的欄位與路由。

角色和空鞘／固定扇在body，主刀完全獨立；納刀時只顯示目前裝備刀的柄，不能把固定刀柄畫回body。
二手握點被前臂遮住的格子保留推定／低信度標記，並附參考，不能視作可見像素直接量測。

重建：Python3.12+，Pillow與numpy。執行 production/rebuild_assets.py --output 新的空目錄。
加 --previews 可重出三刀離線合成。Git精簡版若未附武器，另加 --weapons-dir 指向遊戲game/assets/v22/weapons。
重建會產單格、前景、sheets、調色profile，從原生source重做，不累加二次調色，不改遊戲工作樹。

Git精簡出版可省sheets（可由重建產生）、review武器副本（引用既有v22），下載全包則保留兩者便於獨立檢視。

預覽GIF固定每格150ms、影片每格140ms，是便於檢查的慢速播放；animation_plan的tick只是接入時序提案。equipment-placement的sheath_plane只供1024預覽診斷，遊戲需從本地鞘口與body_height重新算世界位置。

來源路徑：standalone的runtime registration以source_root=../sources/解析source.file（raw/...）；以authoring_root=../production/解析metadata_source（metadata/...）。grade profile內reference/...亦對應production/reference/...。Git精簡版的root已改成同層sources/、production/。
