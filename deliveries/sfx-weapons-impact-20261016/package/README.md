# 吞食戰國：武器音效試作 v3 完整試接版

98 個事件音效，WAV PCM16 / OGG Vorbis 雙格式，48 kHz、單聲道。包含 v2 原有 32 檔、18 個新增類別各 3 變體、4 個單次 Foley、8 個元素層。這是供挑選與混音的候選素材，尚未主觀聆聽驗收，也尚未加入遊戲。

processed 是加工版；originals ZIP 是未修改下載原檔；manifest.json 記載每個來源、加工、時長、峰值、RMS。preview-index.json 是試聽秒數。build_v1.py 為前版配方、build_v2.py 為此次修改配方。

加工增加低頻短暫衝擊、材質音層、破風瞬態及輕度飽和，沒有把所有聲音單純調大。命中素材峰值約 -3 dBFS；v2 刀揮約 -8 dBFS，蓄力保持約 -12 dBFS，實際遊戲同時發聲仍須預留混音空間。低頻不能替代中高頻瞬態，小喇叭尤其應以實機驗收。

## 事件對接
- sword_swing / staff_swing：綁揮動速度最快的畫格，空揮也播放；不要每張動畫影格觸發。
- sword_hit_flesh / sword_hit_armor：碰撞確認當刻播放，按受擊材質二選一。護甲為交擊設計聲，並非歷史甲冑錄音。
- bow_release：箭離弦事件。arrow_hit_body / arrow_hit_wood：投射物真正命中時才播，與發射分開，保留飛行時間。
- staff_hit / body_collision：碰撞、摔落實際確認再播放。不要將同一傷害多個碰撞盒重複觸發。
- charge_start：開始集氣一次；charge_hold_loop：持續集氣接入，取消/出招後淡出 40–80 ms。
- charge_release：放開蓄力時一次；spin_swing_loop：旋轉期間接入，建議程式以 20 ms overlap crossfade 循環。loop 為候選邊界處理版，需實機聽循環接縫。
- spin_finish：最後落點/收勢重擊候選；裡面含命中層。若空揮，請只用旋轉破風淡出，不播含命中收尾。

## 混音起始建議（須依目前遊戲實際音量調整）
- 命中聲作為主體；v2 刀揮檔案已比命中低約 5 dB，不要再機械式重複降 5–8 dB；棍類按聽感另調，蓄力持續低 10–14 dB。
- 普通同類變體隨機選擇，避免連續同一檔；pitch 約 ±3%，命中少量差異即可。
- 同時擊中多敵：保留最強 2–3 聲，其他降音量；同一事件/目標去重。SFX 同類 voice cap 4，絕招 loop 每角色最多一個。
- 必殺時可讓音樂短暫 duck 3–5 dB、attack 30 ms/release 200 ms；總線保留至少 6 dB 餘量，避免群怪疊加爆音。
- 本包不更改 runtime、Git 或任何現有音量設定。接上後仍需耳機、小喇叭、群怪及低音量實測。

## v2 使用者試聽修正
- 刀揮三變體：峰值比 v1 低 5 dB，尾段縮至原長度 76% 並漸弱。
- 刀砍肉身三變體：強化原始拳擊 Foley 的短促起音，加短肉身厚度與 35 ms 噪聲瞬態，峰值仍為 -3 dBFS。
- 棍空揮與棍命中：依使用者明確要求，各三變體整組交換映射；音檔與對應 v1 來源 bit-identical，並非新錄音。
- 蓄力起始/保持/釋放及旋轉持續：移除電子掃頻和諧波嗡聲，改低通木/軟物 Foley 共鳴、低沉氣流與自然 swish。鼓震是設計目標，不是真實太鼓錄音。
- 箭、鎧甲、衝撞與 spin_finish 保留 v1 音檔不變。原 v1 資料夾/ZIP 留存可還原。
- 新短試聽只放修改類別，最後兩項是「空揮→0.32 秒後命中」成對示範；成對試聽整體降 3 dB 保留疊音餘量，獨立檔音量不受影響。
- 尚未主觀聆聽 v2 或驗證遊戲內混音；請以試聽意見為準。這版沒有改遊戲/Git。

## v3 完整武器對接
本包共 98 個獨立事件檔，WAV/OGG 各 98。既有 v2 全數保留音訊位元一致，不因補其他武器而重新改動已調好的音效。
新增：槍刺、薙刀/長柄橫掃與各自肉身命中；棍打鎧甲；飛刀投擲與肉身/鎧甲命中；拳、頭槌、膝擊、摔投破風、落地；盾擋；角色與敵兵火槍、子彈肉身/鎧甲命中；拔刀/收刀/抓握/裝填；火冰風電各命中與持續層。

### 可重用映射
- 刀、打刀、大刀：sword_swing / sword_hit_flesh / sword_hit_armor。大刀可降 pitch 3–5%，不必另存副本。
- 槍：spear_thrust / spear_hit_flesh；金屬命中用 sword_hit_armor。
- 薙刀：polearm_sweep / polearm_hit_flesh；突刺用 spear_thrust。
- 棍、法杖：staff_swing / staff_hit / staff_hit_armor。維持使用者 v2 指定的空揮/肉身命中交換。
- 弓：bow_release / arrow_hit_body / arrow_hit_wood；打甲可共用 knife_hit_armor。
- 飛刀：knife_throw / knife_hit_flesh / knife_hit_armor；落木可共用 arrow_hit_wood。
- 火槍：musket_player_shot 與 musket_enemy_shot 分開；命中以 musket_hit_body / musket_hit_armor。裝填單次綁開始事件，1.5 秒音檔僅為機械 Foley 試作，不是史實裝填錄音。
- 抓技：grab_contact；頭槌/膝擊碰撞用各自 hit；甩出去用 throw_swing，敵人實際落地才 body_land。身體撞擊用 body_collision。
- 蓄力各階段沿用 v2；佛珠揮擊可用 polearm_sweep，佛珠命中用 staff_hit。卍字外射可用 charge_release，命中用 body_collision，避免每顆特效都播放。
- 無屬性劍氣可用 polearm_sweep 降音量；元素聲獨立疊加，禁止每幀重播。冰聲為高音金屬設計、電聲為短爆裂噪聲、火槍為噪聲爆鳴設計，都不是實物錄音。

### 具體事件表
讀 docs/event-map.json 或 CSV：event_id 是建議接入 ID，不宣稱與目前 runtime 命名相同。variant_id 是檔案名；gain_linear 是 0–1 建議起始倍率，音檔本身已有音量差異，勿再自動全部正規化。檔案清單與時長/峰值/RMS 見 manifest.json。
每次揮擊選一個變體；命中由 attackId+targetId+eventId 去重。同時多敵最多保留三個主要命中，其餘降量或略過；遠處敵兵槍聲再依距離衰減。盾擋成功只播 shield_block，不同時播肉身命中。穿透三人可最多三個命中，射擊聲只播一次。
loop 每角色同類最多一個，起/停淡入淡出40–80ms、循環銜接20ms。charge_release 後停止 charge_hold_loop。element loop 只在實際元素持續效果存在時播放。快速攻擊短音不要截斷前次的必要尾音，可用4個voice上限。

### 試接驗收
先用目前遊戲事件映射接入，確認空揮/命中分離、敵我火槍辨識、穿透/多敵不爆音、取消蓄力會停聲。資料已做解碼與削波檢查，但本助手未主觀試聽v3，未接runtime驗證；由使用者進遊戲聽後微調。
