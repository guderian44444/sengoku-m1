# 音效 v3：CODEX 接入交接

本批只交付素材與對接方案，尚未接 runtime，也沒有主觀遊戲驗收。基準是遠端 main `30fdac0349fb39bd769061318a497446a9ff0114`。本機 main `f553400c` 與工作中修改不包含於本分支；來源 hash 與差異標記在 [runtime-reference.json](runtime-reference.json)。接線前請先對照實際目標分支，勿把本表視為執行中的設定。

## 交付檔案與選用

- [原始單一 ZIP](Sengoku_All_Weapons_SFX_v3.zip) 保留不重壓；解壓 [package/](package/README.md) 215 檔逐位元一致，44 個建議類別、98 個獨立變體、WAV/OGG 各98。
- 新素材在 `package/processed/wav/` 與 `package/processed/ogg/`；48kHz、mono；WAV PCM16，OGG Vorbis。這是 delivery 路徑，**目前沒有 res:// runtime 路徑**。接入方另行選版本目錄，不要直接覆寫 `game/audio/v38/` 或 `game/vfx/v2/`。
- [runtime-map.json](runtime-map.json) 覆蓋44類與全部98變體；[CSV](runtime-map.csv) 一列一變體。包內 `docs/event-map.*` 原樣保留，其 event_id 是建議名稱。
- 一次接一組候選比較；WAV/OGG 是同一內容的兩種格式，不同時播放。不重跑上游 build/verify 腳本：它們依賴前版資料夾，會改寫 QA、checksum 或重新打包。可用本交付的唯讀 [verify_delivery.py](verify_delivery.py)。

## 現有播放契約與需調整處

1. `CombatAudio.sound_for_event()` 將事件選為 cue；`play_event()` 先處理語音，再依 `shared_sfx` 決定是否略過物理音。一般音效6個 round-robin player，bus=SFX；食物另有一個 player。`swing` 只是語音起始，實際破風應綁 `weapon_swing`/`bow_release`/`gunshot`，不可每影格播放。
2. v38共有17個sampled cue，每cue固定assert 5個take。新包27組各3變體、17組單檔，不能原封不動套用5變體assert，也不要複製同一檔五份充數。修改接入器按實際 bank 長度選擇，保留洗牌袋與邊界避免連續同take。`guard`現共用`shield_hit`檔，`kick_whoosh`共用`blunt_whoosh`檔。
3. `SharedCombatVfx.accept_event()` 對v38 sampled cue仍畫VFX但設silent，由CombatAudio獨佔物理聲。火槍走hero/enemy_matchlock，bullet/needle命中接受時則走blunt_impact/slash_hit。不要只換同名fallback synth而以為已聽到新聲。火槍目前event.id%4選變體，新包各3個，必須一併改成bank長度。
4. 目前原生 hit/heavy_hit payload 附weapon，沒有受擊材質或可靠的歷史攻擊子類；prop_hit附material但沒有來襲武器。flesh/armor、拳/頭槌/膝、槍刺/薙刀橫掃需顯式補語義。不要把所有shield_hit視為金屬甲，或重用每幀actor.action猜過去事件。`damage`僅扣血/顯示，不另播命中。
5. catalog僅sword/bow/spear三family（57件）；音效還有blunt/kick/chain/needle/bullet/blade等token。長棍/錫杖為blunt，薙刀仍spear；內部mitsuhide是目前顯如。刀氣blade與飛針needle分開。鏈鎌/踢擊/guard_break/陶木石藤等破壞沒有專用新版候選，請保留既有聲或在表內明確選可重用聲，不能假稱每個舊cue都有新版專檔。

## 音量、loop 與去重

檔案已有製作音量差：v2刀揮約-8dBFS、命中約-3dBFS，staff空揮/命中是使用者要求的整組交換，敵槍峰值約-8dBFS、玩家槍約-3dBFS。不要全部重新正規化，也不要把已較小的刀揮再機械式降5–8dB。

包內gain_linear是製作方的**候選試聽起始值**：多數釋放0.6(-4.44dB)、命中0.65(-3.74dB)、敵槍0.55(-5.19dB)、loop0.45(-6.94dB)。這些不是目前runtime音量，不能無判斷取代或再乘上現有gain。先保留當前SFX bus設定、以現有cue作A/B，再於遊戲調整；本PR不改任何使用者音量。

目前CombatAudio：輕破風/一般命中-17dB，重刀破風-15，重命中-13；弓-15、重弓-14；盾/guard-16、guard_break-14。prop_hit -15、prop_break -12；額外stage3 sword_air/bell_fall一般-17、alarm loop -24。實際cue對照與線性倍率在runtime-reference。

VFX controller的單次基底為-20→-18dB（依progress），loop -32→-24；intensity另乘、distance最多-12dB、layered與voice_duck各-6、enemy_matchlock另-3。最大12 player、每instance5，超額先回收最早one-shot再loop；不能把製作方「同類4聲、最多3個主要命中」誤稱為已實作，目前CombatAudio仍6聲池。

六個loop候選為charge_hold_loop、spin_swing_loop與四元素loop。只在狀態有效時保留每actor同類一個instance；開始/結束淡入淡出40–80ms、循環20ms overlap crossfade。**目前VFX WAV loop只是首尾硬循環，沒有20ms crossfade或40–80ms淡停**，需要接入方另做並實聽；不能因manifest loop=true就聲稱無縫。release/cancel/死亡/換場清理、暫停恢復都要驗。一般揮擊/命中/放箭/槍聲一律one-shot；spin_finish含命中層，空揮不播。

事件入口按generation+event.id避免重播；`_weapon_release`在同batch對同actor/type/weapon去重，多箭一聲放弦。命中去重建議保留attack_id+target_id+contact語義；現有外發命中event不攜帶attack_id，接入方需補穩定ID。多個碰撞盒不可產生重複聲。穿透可每目標一聲，群怪只留最強2–3聲，其餘降量或略過（此為待實作建議）。盾擋成功只播盾聲；不要再補肉身聲。

## 44類明確對接

以下均為待接線方案；表中cue是目前播放選擇，並不表示已指向新音檔。

| 包內建議 ID | 現有入口 → cue | 接入注意 |
| --- | --- | --- |
| `sword_swing` | weapon_swing; weapon=sword or blade; action distinguishes heavy/charged → `sword_whoosh`, `sword_heavy_whoosh` | 現有刀系兩種 cue；新包三變體可供兩者共用。blade 是刀氣，不能因名稱誤當飛刀。 |
| `sword_hit_flesh` | hit/heavy_hit; weapon=sword or blade; confirmed body contact → `hit`, `heavy_hit` | 目前命中 payload 只有 weapon，沒有 flesh/armor；以普通肉身候選接現有預設命中。 |
| `sword_hit_armor` | hit/heavy_hit plus explicit target material=armor (not currently carried) → `hit`, `heavy_hit`, `shield_hit` | 需補真實受擊材質。shield_hit 還包括護甲吸收與抓住者當人盾，不能全部視為金屬甲。 |
| `bow_release` | bow_release; weapon=arrow/special_arrow; action=charged/charge_rain/special selects heavy → `bow_release`, `bow_heavy_release` | 一輪三箭或五箭只播一次放弦。新包沒有獨立重弓 bank，可共用三個 take 後調混音。 |
| `arrow_hit_body` | hit/heavy_hit; weapon=arrow/special_arrow → `arrow_hit` | 真正碰撞才播放；穿透每個目標分開去重，不在發射時播命中。 |
| `arrow_hit_wood` | prop_hit; material=wood plus projectile weapon=arrow (origin weapon absent) → `wood_hit` | 現有 prop_hit 只附 material，無投射物種類；不可把所有木製道具近戰命中換成箭入木。 |
| `staff_swing` | weapon_swing; weapon=blunt; exclude body/grab actions → `blunt_whoosh` | 長棍/錫杖共用 blunt；投摔與其他鈍擊也共用，需動作/武器語義篩選。保留 v2 已授權空揮/命中交換。 |
| `staff_hit` | hit/heavy_hit; weapon=blunt; actual staff contact → `blunt_hit`, `blunt_heavy_hit` | 需區分棍杖、膝拳與身體碰撞。不得自行把 v2 指定交換再換回。 |
| `body_collision` | run_bump; or confirmed thrown-body collision distinguished from other blunt hits → `blunt_hit`, `blunt_heavy_hit` | run_bump 可直接候選；被摔者撞人目前只有 blunt 命中，細分需接入方補語義。 |
| `charge_start` | sync: actor.action enters charge; current <family>_charged_wave activate phase → `blade_activate`, `fire_activate`, `ice_activate`, `wind_activate`, `lightning_activate` | 沒有 charge_start 全域事件；從狀態進入/既有 recipe phase 一次觸發。通用聲替換或疊層由接入方選一。 |
| `charge_hold_loop` | sync: live charge instance; current <family>_charge_loop → `blade_charge_loop`, `fire_charge_loop`, `ice_charge_loop`, `wind_charge_loop`, `lightning_charge_loop` | 目前 charge loop 並非滿蓄門檻專用。新候選需 20ms overlap；現有 WAV loop 只硬循環，未實作 crossfade。 |
| `charge_release` | weapon_swing/bow_release at charged release; existing recipe release may be silent for sampled cues → `sword_heavy_whoosh`, `bow_heavy_release` | 沒有同名全域 type。只允許一個物理釋放 owner，避免與已有刀/弓 cue 疊成兩次。取消蓄力不播 release。 |
| `spin_swing_loop` | classified spinning action enters active rotation (no dedicated global event) → 無獨立 cue | 不能把所有 charged 都當旋轉（阿市為射箭）。一 actor 同類 loop 一個，離開/死亡/換場時停止。 |
| `spin_finish` | confirmed contact at classified spin finisher; no dedicated event → `hit`, `heavy_hit` | 檔內含命中層，空揮不能播放；既有事件未攜帶 spin finisher 語義。 |
| `spear_thrust` | weapon_swing; weapon=spear; thrust action → `spear_wind` | 目前槍與薙刀/長柄共用此 cue；新包細分需 action 或 catalog art_id。 |
| `polearm_sweep` | weapon_swing; weapon=spear and sweeping polearm; or chain as optional reuse → `spear_wind`, `chain_swing` | 現有事件無 sweep 類型；鏈鎌沒有專用新聲，可明確選擇此候選或保留現有 synth。 |
| `spear_hit_flesh` | hit/heavy_hit; weapon=spear; thrust body contact → `spear_hit`, `spear_heavy_hit` | 新包三變體供輕/重 cue 候選；槍打甲可明確重用 sword_hit_armor，不在本 PR 接線。 |
| `polearm_hit_flesh` | hit/heavy_hit; weapon=spear plus polearm sweep context → `spear_hit`, `spear_heavy_hit` | 需要長柄武器/動作上下文，不能只用 family=spear 分出薙刀與槍。 |
| `staff_hit_armor` | confirmed staff contact plus target material=armor → `blunt_hit`, `blunt_heavy_hit`, `shield_hit` | 補武器/材質語義後選；成功格擋應選 shield_block，不再疊肉身命中。 |
| `knife_throw` | weapon_swing; weapon=needle → `needle_whoosh` | 現有 needle 可試用飛刀投擲候選；沒有獨立 knife token。不是 blade 刀氣。 |
| `knife_hit_flesh` | hit/heavy_hit; weapon=needle; confirmed body contact → `slash_hit`, `needle_hit` | SharedCombatVfx 接受時實際播 slash_hit，CombatAudio needle_hit 被 shared_sfx 擋掉；需改真正 owner。 |
| `knife_hit_armor` | needle hit plus explicit armor material → `slash_hit`, `needle_hit`, `shield_hit` | 目前無肉身/金屬材質欄位；箭打甲也可選此候選，但需明確規則。 |
| `punch_hit` | confirmed hand strike; existing hit/shield_hit lacks strike subtype → `blunt_hit`, `blunt_heavy_hit`, `shield_hit` | 沒有 punch_hit 事件。damage 是扣血/顯示事件，不可再播一次命中。需 attack semantic 或命中事件欄位。 |
| `headbutt_hit` | confirmed headbutt; no explicit headbutt subtype on audio event → `hit`, `blunt_hit`, `shield_hit` | 不能僅按通用 hit 判定頭槌；需要動畫接觸語義和受害者去重。 |
| `knee_hit` | grab_hit_1/2 animation contact -> damage; held target emits shield_hit → `shield_hit` | 現有膝擊實際可能走 shield_hit；須補 strike subtype，不能全域替換 shield_hit 或憑目前 actor action 猜歷史事件。 |
| `throw_swing` | throw animation victim_release/throw_release/release callback (not global event) → 無獨立 cue | 目前 _combat_contact_v33 直接 _release_grab，無 throw_swing 全域事件；不將投出造成的 heavy_hit 當空揮。 |
| `body_land` | landing; wet=false; distinguish thrown/launched body from ordinary jump → `dash_dust`, `landing` | 目前 landing payload 僅 wet，沒有落地原因。乾地被共享 dash_dust 接受；濕地原有 splash 應保留。 |
| `shield_block` | guard; shield_hit only if confirmed successful block/absorption semantics → `guard`, `shield_hit` | guard 已有成功格擋語義；shield_hit 含人盾/部分吸收，不能一律當成功盾擋。guard_break 保留獨立 cue。 |
| `musket_hit_body` | hit/heavy_hit; weapon=bullet → `blunt_impact`, `bullet_hit` | 共享 VFX 接受時真正播 blunt_impact；不是只替換 CombatAudio bullet_hit。 |
| `musket_hit_armor` | bullet contact plus explicit armor material → `blunt_impact`, `bullet_hit`, `shield_hit` | 現有命中 payload 無材質，接入方需補；不能按所有 bullet 命中播放打甲。 |
| `musket_player_shot` | gunshot; actor.team=0 -> hero_matchlock recipe release → `hero_matchlock_shot_{0..3}` | 新包3變體，舊 recipe event.id%4 為4變體；需按新 bank size 選擇，不能保留硬編碼4。原創設計非史實槍聲。 |
| `musket_enemy_shot` | gunshot; actor.team!=0 -> enemy_matchlock recipe release → `enemy_matchlock_shot_{0..3}` | 新敵槍檔已較低，另有0.55建議倍率；現有 controller 再減3dB與距離衰減，需實聽避免重複過度衰減。 |
| `sword_draw` | no dedicated draw event in current combat audio routing → 無獨立 cue | 若另做拔刀動畫接點才觸發一次；不可綁每次 light 或通用 swing。 |
| `sword_sheathe` | no dedicated sheathe event in current combat audio routing → 無獨立 cue | 需真正收刀動畫接點；取消/切招不代表已完成收刀。 |
| `grab_contact` | grab (successful _try_grab) → `grab` | 已有成功抓到 actor/target 的事件，可選此單次候選；不是伸手未命中也播放。 |
| `musket_reload` | no dedicated reload event in current combat audio routing → 無獨立 cue | 1.5秒機械 Foley 試作，不是史實裝填錄音；只在真實 reload 動作開始接一次，不跟槍聲自動疊播。 |
| `element_fire_hit` | confirmed elemental contact; recipe fire_*_hit phase where used → `fire_hit` | 不是同名全域事件；僅已確認元素接觸播放一次，持續狀態每幀繪製不等於新的音效事件。必要時與物理命中分層降量。 |
| `element_fire_loop` | active fire status/effect lifetime; no dedicated status-audio loop → `fire_charge_loop` | 現有同元素 charge_loop 是集氣，不等於持續元素狀態。接入方明確選用途並維護 instance 生命周期；新候選20ms overlap，現 controller 無此淡接。 |
| `element_ice_hit` | confirmed elemental contact; recipe ice_*_hit phase where used → `ice_hit` | 不是同名全域事件；僅已確認元素接觸播放一次，持續狀態每幀繪製不等於新的音效事件。必要時與物理命中分層降量。 |
| `element_ice_loop` | active ice status/effect lifetime; no dedicated status-audio loop → `ice_charge_loop` | 現有同元素 charge_loop 是集氣，不等於持續元素狀態。接入方明確選用途並維護 instance 生命周期；新候選20ms overlap，現 controller 無此淡接。 |
| `element_wind_hit` | confirmed elemental contact; recipe wind_*_hit phase where used → `wind_hit` | 不是同名全域事件；僅已確認元素接觸播放一次，持續狀態每幀繪製不等於新的音效事件。必要時與物理命中分層降量。 |
| `element_wind_loop` | active wind status/effect lifetime; no dedicated status-audio loop → `wind_charge_loop` | 現有同元素 charge_loop 是集氣，不等於持續元素狀態。接入方明確選用途並維護 instance 生命周期；新候選20ms overlap，現 controller 無此淡接。 |
| `element_lightning_hit` | confirmed elemental contact; recipe lightning_*_hit phase where used → `lightning_hit` | 不是同名全域事件；僅已確認元素接觸播放一次，持續狀態每幀繪製不等於新的音效事件。必要時與物理命中分層降量。 |
| `element_lightning_loop` | active lightning status/effect lifetime; no dedicated status-audio loop → `lightning_charge_loop` | 現有同元素 charge_loop 是集氣，不等於持續元素狀態。接入方明確選用途並維護 instance 生命周期；新候選20ms overlap，現 controller 無此淡接。 |

## 來源與驗收界線

來源、加工配方與原始三ZIP保留在 [package/docs/SOURCES.md](package/docs/SOURCES.md)、manifest與originals。原始ZIP hash已核對，授權頁列CC0，頁面與確認記錄見 [SOURCE-VERIFICATION.md](SOURCE-VERIFICATION.md)。原創火槍是filtered noise爆鳴設計；裝填是機械Foley試作，**兩者均非史實錄音**；甲、冰、電等同樣是遊戲設計聲。

本機以獨立libsndfile解碼98 WAV +98 OGG及MP3，檢查finite、非空、零digital clipping；報告 [verification.json](verification.json)。原包SHA214項及解壓215檔已逐檔核對。製作方稱保留v2的64音檔，其清單保留在包內QA；本次沒有另外收到獨立v2 baseline，因此不將該比較列為本機獨立重驗。

尚待使用者/接入方在遊戲主觀驗收：耳機/小喇叭與低音量、空揮與命中分離、敵我火槍辨識、多敵/穿透疊音、loop接縫與取消停止、暫停/返回標題/換場清理、SFX滑桿與語音/音樂平衡。未改runtime、未做遊戲接線測試，未merge或release。
