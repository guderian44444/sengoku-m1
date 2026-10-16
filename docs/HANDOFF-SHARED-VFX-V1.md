# 三族共用 VFX 交接 v1

## 交付界線

這是可重用的獨立透明美術基底、Godot 4 adapter、資料契約與隔離示範。每項 **1 張作者圖**，由連續 UV 流動、固定深度遮擋和時序驅動；不是 4/8 格逐格動畫，也不是完整遊戲技能已實裝。生圖 atlas 的格間污染版本不納入 runtime。

基底 main：`966cf8c`。沒有修改 `core/battle.gd`、`main.gd` 或既有 `battle_view.gd`。不改角色招式、傷害、碰撞、音效與存檔。美術可供所有友軍、敵人、場景使用，沒有烘焙人物或武器。

## 為何現有效果像幾何圖形

- `game/render/battle_view.gd:1111–1130` 的 `_paint_flame` 是三層純色多邊形，沒有半透明細絲與逐像素亮度層次。
- 同檔 1131 起 `_paint_ice` 是少量頂點的晶柱；1044–1063 附近劍氣用平塗 ribbon 再放七片火苗。
- `_draw_special_aura` 分散繪製 14 個元素，沒有一個連貫、有方向的火浪主形體。
- `_hero_element` 把人物固定成單一屬性（家康目前 earth）。這個包不沿用該限制；技能選 effect id，人物只供姿勢、錨點、面向與比例。
- 既有好用基礎應保留：`_draw_hero_power(..., front)` 前後層、`weapon_renderer.geometry()` 的 hand/top/bottom、`FrameAnimation` 姿勢取樣。

## 檔案

- `game/vfx/catalog.json`：唯一素材清單；原始尺寸、單格數、正規化 pivot/seam、時長、混色、SHA256。
- `game/vfx/art/`：原始透明 PNG，保留原像素及透明邊缘。
- `game/vfx/vfx_player.gd`：可直接被自訂 `_draw()` 呼叫的視覺 helper；不寫 battle state。
- `game/vfx/shaders/shared_vfx.gdshader`：Sprite2D 路徑的選用 GPU shader。
- `game/vfx/demo/vfx_demo.tscn`：隔離引擎示範，繼承 renderer 的前後效果 hook。
- `game/vfx/recipes.json`：跨角色／敵人／場景組合範例。
- `game/vfx/tests/`、`scripts/vfx/`：測試與離線合成預覽腳本。

## 三族 12 件基礎 + 1 件額外氣波

火焰：fire_arc、fire_ring、fire_wave、fire_burn。
劍氣：blade_arc、blade_ring、blade_wave、blade_hit。
冰雪：ice_arc、ice_ring、ice_wave、ice_shatter。
額外：blue_white_wave，供家康概念上升氣波風格測試。

火焰以火舌和暖色白熱絲為主；劍氣以清楚刀線／近白細絲為主；冰雪包含實體晶面、冰屑與霜粉，不是把火焰換藍色。實際尺寸與交付件數以 catalog 與檢查報告為準。

## 接入順序（先只換一招）

1. 保留當前 main 的未提交變更；把 `game/vfx/` 加入專案。不要以舊完整 ZIP 覆蓋專案。
2. 使用 `var shared_fx = preload("res://vfx/vfx_player.gd").new()`，初始化一次 `shared_fx.load_catalog()`，不要每幀載圖。
3. 在每個依 y 排序的 fighter 內，先畫 back pass，再人物／既有武器分層，再 front pass。不要把所有人的 front pass 放在全場最上面。
4. 在 `_draw_hero_power` 的同一招分支呼叫 helper。只對已切換的效果停用原多邊形 accent，避免新舊效果重疊。
5. 第一招只驗證家康雙圈與蓄力上升波，再驗信長刀尖、阿市冰弧、敵人／場景；最後才擴到其他招式。

呼叫範例（在 `_draw()` 或其子呼叫裡）：

```gdscript
# same call in back/front hook; origin is feet after camera and z correction
shared_fx.draw_pass(self, "fire_ring", sample.tick, origin - Vector2(0, 60), front, {
    "face": fighter.face, "size": height * 2.0
})
# second ring can have another height and angular speed via another effect spec
```

### 刀尖、手、角色與世界座標

`weapon_renderer.geometry(fighter, frame, height)` 的 `top` 已是按角色身高換算的局部刀尖。使用：

```gdscript
var geometry = _weapons.geometry(fighter, frame, height)
var local_tip = geometry.get("top", Vector2(75, -90))
var tip_world = ground - Vector2(0, fighter.z) + local_tip * Vector2(fighter.face, 1)
shared_fx.draw_pass(self, "blade_arc", sample.tick, tip_world, front, {
    "start_tick": 14, "size": height * 1.4, "face": fighter.face
})
```

fallback 僅供 demo；正式角色若沒有 layered weapon geometry，應量測並登記該格刀尖，不把 fallback 當全角色正確握點。`geometry.top` 不可再乘一次 body_scale。整體身體有旋轉時，刀尖須與身體同樣旋轉。角色跳躍扣 z，camera_x 只減一次。

場景效果給 world position 再減 camera；脫手波在 release 那刻鎖定 origin/face，不再每幀追手。附著燃燒／冰霜則每 tick 跟隨目標部位，目標死亡／消失／換場時清除。

### 時間與命中

所有時間使用 authoritative action tick 或 canonical sample.tick。戰鬥已有 `Battle.hero_tick(kind, tick)` 速度轉換；不可把原始 action_tick 當相同時長、也不可獨立用 render delta 決定 hit。

- demo 刀弧示例 canonical tick 14 開；蓄力上波 tick 22 開。
- 視覺 release 的 tick 由實際招式資料供應，不能把示例數字套全招。
- 每次攻擊有唯一 action-instance id，回滾、連擊、取消需清掉／重建對應 VFX。
- hit spark 只在 battle 確認 hit event 時產生；揮空只有弧／波，不產生命中特效。
- hitstop 時 age 停在 action tick；暫停／網路快照／低幀率仍一致。
- 音效、hitbox、傷害保持在 battle；VFX 不反過來觸發傷害。

### 前後半圈與旋轉

ring 的 seam 是原圖內圈中心附近的水平切線，不一定是圖高 0.5。兩個 pass 必須使用相同 tick、origin、size、face、seam。上半在人物後、下半在人物前；接縫不重覆、不留空。

不能把整張橢圓精靈旋轉再用原圖上下半裁切，會把前後遮擋翻錯。此 helper 只讓 UV 紋理沿橢圓內部連續流動，screen-horizontal seam 固定。兩圈分別改高度與速度；這是真正可見的紋理位移，不只是整圖縮放。

## 動態方式與品質界線

- fire/blade ring：單張紋理在正規化橢圓座標中連續 UV 旋轉。火舌／細丝沿圈滑動；不是每格重新繪畫的流體模擬。
- 火弧／火浪／burn：小幅時間變化 UV turbulence，保留輪廓和細絲，外加可選稀疏火星。波本身按 release-origin 與 velocity 移動。
- 冰晶主體應保持剛性；冰環可用低速運動，碎屑雪花由少量粒子／sprite 分散，不套火焰抖動。
- 4 張真不同動作若未維持形體連續，不是可接受 flipbook。未來可把 `frames/columns/cell` 改成經驗證 6–8 格 sequence；helper支援取樣与短过渡，不能以插值掩蓋不連貫造型。

## 混色、匯入與效能

預設 straight alpha／linear filtering。不要 multiply、不要把整張強制 additive，否則白背景會消失、亮背景過曝、暗邊透明破坏。獨立核心小面積 additive 是可選效果，須另驗亮／暗場景。

PNG 原像素保留，沒有抠圖或程序重畫。不要把低 alpha 細絲全閾值刪掉。貼圖邊緣不足的素材，UV 扭曲限制在低振幅；不能越出圖界採樣到隔壁。現在各項獨立 PNG，**不是已打包的大 atlas**。正式 GPU atlas 可按 family pack，保留至少8px gutter與原尺寸/pivot；測試半透明邊和mipmap。

目前 helper 的 mesh flow 每次 draw 產生動態網格，是便於接既有 immediate renderer 的驗證實作，非完成效能優化。正式大量戰鬥建議 Sprite2D + 同附 shader／預建 mesh、節點池、texture共享、屏外裁切；初始上限同屏16主要效果，每效果0–20細屑，按設備 profiling 後調整。不要在每擊 new/load texture。PNG磁碟大小不等於GPU記憶體；RGBA原圖記憶體=寬×高×4，mipmap另約+1/3。不存在已測幀率保證。

目前catalog loader走raw Image.load_from_file以配合repo既有portable約定；Godot export需包含PNG/JSON原始檔，或改用imported Texture2D resource loader。桌機試跑不是已驗證的Web/export打包。

## 執行與驗證

```sh
godot --path game res://vfx/demo/vfx_demo.tscn
godot --headless --path game --script res://vfx/tests/test_vfx.gd
python scripts/vfx/verify_vfx.py
```

demo：Tab換族、F左右翻、Space暫停、R重來。Godot引擎demo使用現有角色renderer/weapon layer，隔離於戰鬥。影片標記 OFFLINE COMPOSITING TEST，是同資料與動態公式的軟體合成，角色姿勢固定以檢查遮擋，不能當遊戲錄影。

Cloud Godot 4.6.3 headless 可檢查GDScript；repo宣告4.7.2，圖形server在此次sandbox不可用，未完成原生GPU像素、Windows、控制器、export、效能與實戰整合驗收。合併前需在目標版本做這些檢查，尤其雙人重疊y排序、牆邊／鏡頭移動／跳躍／敵人翻面／取消動作／場景切換／hitstop。

### 「旋轉兩圈」的正確意思

用戶指時間上的兩周（720°），不是兩道上下光環。示範保留雙層來檢查遮擋，但 fire/blade 在72ticks內使用 `angular_speed = TAU * 2 / (72.0/60.0)`，確實完成兩周，之後消失48ticks再開始下一次示範。起末淡入/淡出，禁止在仍可見時把phase硬歸零。圖層數與旋轉周數是獨立參數。冰晶主體保持剛性，只做雪屑漂移，不宣稱其本體UV旋轉。

### 影片與引擎demo的具體差異

影片採目前main的角色底圖固定姿勢檢查遮擋，**不表示回退另案已核准的新角色美術**。它是離線每像素UV合成；引擎helper是24×8分段mesh。影片與native的展示位置／尺寸／粒子密度／動作時窗不完全相同，不能當作逐像素一致或原生效能證據；相同的是素材、單作者格宣告、環的seam/pivot、紋理旋轉公式與前後層契約。

Fire頁的上升示範用額外 `blue_white_wave`；`fire_wave` 是向前橙火低浪。上升／前推使用不同recipe，不能只把水平方向火浪標成上升波。冰雪素材主體沒有火舌turbulence，只有位移／透明度／碎屑雪花；火焰及劍氣主紋理才走UV流動。

單作者格或取樣前後格相同時，helper只繪製一次，不做兩次alpha疊加，以免週期性亮度脈動。多作者格的簡易alpha-over crossfade不是線性RGBA混合，未來擴flipbook需另驗。

## 六武將必殺技擴展

`special_presets.json` 與 `special_preset_adapter.gd` 提供六種不同构图與节奏，`demo/special_demo.tscn` 可獨立檢查：

- 信長：炎刀弧帶出橫向火浪，5次節奏。
- 阿市：晶體刀弧配地面冰環，5次冰雪節奏。
- 秀吉：上下錯位快速刀風，8次legacy節奏；核准新案「千成奇策」的3段動作另列authoring proposal，未修改battle。
- 家康：三次低位大火浪配地環，對齊legacy 36/102/168tick；新案「三河不動」另列，不把站立蓄力的兩周炎輪當作U必殺。
- 光秀：每段三路窄劍氣向前疾射。
- 忠勝：長槍方向窄長火浪，4次強力貫穿構圖。

U-special與一般招式的時間不同：**U-special直接用 raw authoritative action_tick 和 Battle.SPECIAL_HIT_TICKS，不套 hero_tick 倍率**。每人全長210ticks；一般招式才按 canonical sample／hero_tick 接。`test_special_presets.gd` 比對六人快照與 Battle 常數。adapter呼叫端傳當前Battle hit ticks，避免快照變成第二份戰鬥規則。

```gdscript
special_fx.draw_special(self, fighter, ground, height, front,
    Battle.SPECIAL_HIT_TICKS[fighter.kind])
```

原音台詞與新作者命名分開：信長「天魔の刃！」、阿市「氷の羽！」、秀吉legacy「大返し！」、家康legacy「三河の意地！」、光秀「月光一閃！」、忠勝「蜻蛉切！」。全配音使用日文。秀吉「千成奇策」、家康「三河不動」新名目前需另配；不能把舊音說成已喊新名。未錄部分留給Codex，聲音問題不阻擋素材交付。音訊包另有交接，沒有聲音播放成功／新聲演已完成的虛假宣告。

命中特效屬 confirmed hit event；preset只畫放招構圖，不製造假的碰撞命中。声音也是每action-instance只喊一次，release冲击可以多段，不能每hit都重喊。

## 可重現與獨立專案

此repo中的「現有角色demo」需要完整遊戲main，不能只搬game/vfx後直接跑；纯VFX最小demo不依賴人物／battle，可產生獨立專案：

```sh
python scripts/vfx/build_standalone.py --out ../shared-vfx-standalone
godot --path ../shared-vfx-standalone
# six preset visual markers:
godot --path ../shared-vfx-standalone res://vfx/demo/special_demo.tscn
```

只套patch的方式：clone guderian44444/sengoku-m1，checkout此交接分支（或基底966cf8c後套VFX新增檔），保留現有改動，跑Godot原角色demo。

Pillow、NumPy、ffmpeg為離線預覽依賴；字型預設Linux DejaVuSans（`/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`）。其他系統可修改預覽script的fontfile為可用TTF，Godot本體不依賴Pillow/ffmpeg。

```sh
godot --headless --path game --script res://vfx/tests/export_demo_actors.gd -- --output=/absolute/path/actors
python scripts/vfx/render_offline_preview.py --root . --actors /absolute/path/actors --out /absolute/path/preview --seconds 12
python scripts/vfx/rebuild_layout.py --out /absolute/path/layout-replay
```

`rebuild_layout.py`重現8張blade/ice 896→1024純layout，逐像素比較通過；PNG壓縮編碼hash可能隨Pillow版本變化。Fire5張runtime就是原始生成圖。來源像素保留在sources，blade/ice runtime經等比重採樣與透明padding，不宣稱重採樣後逐像素仍與原圖一致。原圖沒有去背／alpha閾值／重畫。來源manifest只供provenance，runtime以頂層catalog為準。

## Overscan修正

fire_ring原圖火舌沿橢圓轉動時可能超出原圖方框。helper使用`render_padding=.4`擴繪製幾何與UV邏輯範圍，保留火舌，沒有裁掉像素。seam按`(seam+p)/(1+2p)`在擴框中重新歸一；pivot世界位置不變。獨立shader若用Sprite2D路徑，也必須把精靈幾何寬高擴為原本`1+2p`倍，offset減去`p*原尺寸`保持原pivot，再設render_padding uniform；只設uniform會錯誤縮小內容。Shader只是選用路徑，沒有經GPU像素驗證。

## 音訊包已納入但不啟用到battle

`game/vfx/audio/` 已納入42組 WAV+OGG：18段既有日文聲演保守remaster、18段六英雄原創charge/release/final SFX、6段4.5秒聲音預覽。不是新錄喊聲，也尚未聽覺驗收。詳見該目錄README與VOICE_HANDOFF_JA.md。

```gdscript
var audio = preload("res://vfx/audio/special_audio.gd").new()
add_child(audio)
audio.configure("res://vfx/audio/")
# one unique id for each action instance, do not use hero name alone in production
# begin_cast once; advance_cast using raw special action_tick; cancel on interruption
```

需要接既有Voice/SFX bus音量、pause/hitstop、同屏2人聲音上限與ducking；不擅改使用者音量設定。`begin_cast(..., allow_legacy_voice=false)`可只放新SFX而不喊錯新名字；新的voice_slots缺音檔時保持靜音並交Codex，不偷偷回退舊名。原聲與新名的選擇需要沿用用戶後續決定。

```sh
godot --headless --path game --script res://vfx/audio/test_helper.gd
python game/vfx/audio/validate.py
```
