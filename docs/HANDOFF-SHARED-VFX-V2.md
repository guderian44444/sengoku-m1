# 共用 VFX v2：風／電、武器中性層與效果自帶聲音

## 交付與界線

此增量疊在 PR #4 的 v1 之上。原 164 檔 SHA 保持不變；新增檔只在 `game/vfx/v2/`、本文件、新版 scripts 與 v2 預覽。全包 28 個獨立 RGBA base、25 個 v2 recipe、41 個效果聲音 key。每張都是 **1 個作者格**，由曲線、UV 網格、粒子、幾何跟隨及 alpha 動畫驅動；沒有把單張聲稱逐格動畫。沒有修改 battle、傷害、穿透、裝填或角色控制。

五族為劍氣、火、冰、風、電。風的捲流粉塵與電的分叉白核不是同圖換色。中性武技另外一層，可獨立使用。新圖片採 1024²，實際 pivot、seam、flow radius、overscan 以 catalog 為準。來源、提示詞與版面重建都附在 sources。

v1 既有六角色必殺 preset、日文舊聲演與新名缺口仍見 v1 文件。秀吉「千成奇策」與家康「三河不動」沒有新錄聲音；不要讓舊聲音冒充新名。家康站蓄兩圈是時間上的 720°，不是畫兩條光圈。

## 素材與 recipe 清單

- v1 13 base：fire arc/ring/wave/burn；blade arc/ring/wave/hit；ice arc/ring/wave/shatter；bonus blue_white_wave。
- v2 新增 15 base：wind、lightning 各 arc/ring/wave/hit；matchlock_muzzle_flash、matchlock_smoke；neutral_slash_arc、neutral_thrust_cone、neutral_trail_strip、neutral_hit_burst、neutral_dust。
- 五族各三個 recipe：`{family}_charged_wave`、`{family}_growing_spin`、`{family}_impact`，共 15。
- 火槍：`hero_matchlock`、`enemy_matchlock`。
- 中性八種：`neutral_slash_arc`、`thrust_cone`、`arrow_trail`、`throwing_blade_trail`、`blunt_impact`、`guard_sparks`、`slash_hit`、`dash_dust`。

中性箭與飛刀共用不含武器的細尾線；鈍擊與格擋共用中性 burst，斬痕共用窄化刀弧。這些是可調的基礎表現，不表示每種武器已有專屬完整美術動畫。

## 接入：一個生命週期，同時控制畫面與聲音

```gdscript
var fx = preload("res://vfx/v2/effect_emitter.gd").new()
var sound = preload("res://vfx/v2/audio/effect_audio_controller.gd").new()
func _ready():
    add_child(fx)
    add_child(sound)
    assert(fx.configure())
    sound.configure("res://vfx/v2/audio/")
    fx.bind_audio(sound)

# authoritative action event，ID 每次施放帶 generation
func begin_charge(cast_id, tick):
    fx.trigger(cast_id, "fire_charged_wave", {"simulation_tick": tick, "face": 1})
func fixed_update(cast_id, tick):
    fx.advance(cast_id, tick)
func actual_release(cast_id, tick):
    fx.release(cast_id, tick)
func actual_hit(cast_id, unique_hit_event_id, tick):
    fx.confirmed_hit(cast_id, unique_hit_event_id, tick)
func _draw():
    fx.draw_instance(self, "actor:cast:42", Vector2(400, 450), false)
    # 在此畫人物／武器，或由相同世界深度的其他 layer 畫
    fx.draw_instance(self, "actor:cast:42", Vector2(400, 450), true)
```

示例 ID 必須與實際 trigger 一致。draw 是唯讀；前後 pass 不 advance、不觸發音效、不呼叫傷害。使用同一時鐘的 60 Hz 絕對 simulation tick。普通角色 canonical 動畫速度與 U-special raw action_tick 要在外層正確轉換；v1 U-special 的 SPECIAL_HIT_TICKS 不再套 hero_tick 倍率。

- charge 可超過 60 tick 持續 hold；release 由真動作事件決定，非按下鍵就視為命中。
- confirmed_hit 帶唯一事件 ID，只能在允許的 release/dissipate 階段。未來 tick 先 advance 到該 tick；倒退或重複事件拒絕。
- 大步進的畫面追上新時間；遲於當前 tick 超過 6 tick 的過期一次音效不補播。loop stop/finish 仍清理。此模式不是音訊 replay。
- rollback/seek 需 cancel、重新建構狀態，重建時 context.silent=true；不能把倒退 tick 當可逆播放器。
- `set_paused(true/false)` 控制畫面與綁定音訊；遊戲的 simulation clock 也必須暫停，否則恢復會追上新時間。
- `cancel(id)` 立即停止 active 或已完成但仍有尾音的 instance。自然 finish 停 loop，有限尾音自然結束。切場 `reset_scene()` 清去重表、active、retired 與音訊。generation ID 不重用，retired 表於切場清理。
- 一個 emitter 只綁一個 audio controller。不要在 signal 外再重播同一個 cue。

## phase 曲線與兩圈擴張

`effect_recipes.json` 是接入資料。phase 定義 duration_ticks、hold、next、layers、曲線與跨 tick cues。每條曲線為升序 `[normalized_time, value]`；layer 可覆蓋 phase 曲線。

- scale × radius 決定視覺大小，opacity 決定透明，particle_intensity 決定細粒子；audio_intensity 控制 loop 強度。
- uv_radians_per_second 以 rad/s 積分，跨 phase 保存角度 offset。hold 超出曲線終點沿用末值，角度仍連續。
- 冰環為剛性晶體主圖，只有半徑變化與另層雪粒，沒有主圖 720° UV 旋轉；`ice_growing_spin` 保留統一 recipe ID，但展示標為 GROWING ICE RING。若技能真要求冰晶旋轉兩周，需另作環形 UV 流或逐片晶體，不可只看曲線積分聲稱已完成。
- 其餘 growing_spin 72 tick 內半徑 .55 → 1.15 → 1.8，角速度積分恰好 4π；第 36 tick 第二周再播一次揮旋聲，結束 18 tick fade。
- charged_wave：60 tick normalization 的蓄力向心聚集，實際 release 後 24 tick 推出，接 18 tick 消散。
- `world_size`／radius 是渲染尺寸，完全不改 hitbox。若視覺越大但碰撞保持原值，設計者需明确說明，不能默認增加傷害範圍。

## 錨點、方向與遮擋

`weapon_motion.gd` 提供 hand→tip 的旋轉/比例、velocity trail 與 muzzle_anchor。灰線示範只表示武器幾何，不是新角色素材。

- 刀弧以手為旋轉原點，使用真正刀尖向量；每種武器校正美術有效弧半徑，透明畫布邊長不等於刀長。
- 槍刺尖 pivot `[.834,.516]`，尾線頭 `[.802,.504]`，揚塵地面 `[.5,.766]`。不能全設 .5。
- trail 用 projectile world velocity 決定 rotation/長度，頭在 projectile position，速度接近 0 時隱藏；world angle 已包含左右，binding face=1 避免再鏡射一次。投射物銷毀／撞擊時 cancel tail。
- muzzle 在角色局部手繪座標經 body 比例、朝向、旋轉、跳躍 z、camera_x 转到畫面；flash/smoke pivot `[.125,.5]` 從左端向 +X 展開。給 face=-1 只翻一次。
- ring 後半先畫、人物後再畫前半。seam 各素材不同，flow UV 可旋轉，遮擋切線仍在畫面深度方向。不要把前後半畫成兩次完整圈。
- 新 wind padding .65、lightning .6 是旋轉留白。舊 fire .4。若自行用 shader，Sprite 幾何也要放大 `1+2p` 並保持 pivot 世界位置，不能只設 UV uniform。

## 火槍 authoritative shot

```gdscript
fx.trigger("hero:shot:9", "hero_matchlock", {
    "simulation_tick": tick, "confirmed_shot": true,
    "shot_event_id": "combat:shot:9", "face": facing,
    "variant": 0, "distance": 0.0
})
```

必須 confirmed_shot=true 且非空全域 shot_event_id；相同事件不能重放。pressed、瞄準、裝填、取消均不觸發。英雄 flash 230／煙 245，敵兵 115／125；前 6 tick 閃光、煙再延 36／18 tick。程序火星與煙透明強度也不同。這是火繩槍單發，不是現代機槍連射。原穿透三人、1.5 秒裝填照原 combat。

敵兵可群射但共用聲音上限 12、每 instance 5；敵聲另 -3 dB，distance 0..1 最多 -12 dB。gun phase_progress 固定 1，避免 flash→smoke 時改變整段枪音音高。四 variant 用傳入 variant 或 ID hash 選一次。

## 中性與元素疊加

箭／飛刀需要 projectile_spawn_id；鈍擊／格擋／斬痕需要 confirmed_contact=true + contact_event_id。聲音只在 spawn/contact 一次，不隨尾線每幀播放。中性刀弧、槍刺、揚塵由實際動作開始事件 trigger。

元素與中性使用兩個 instance，分享同一武器／投射物錨點和事件時鐘。兩者 context.layered=true 可各降 6 dB，避免疊加過響；取消武器動作時兩者都 cancel。元素 confirmed_hit 與中性 contact 是同一 gameplay 事件的兩個視聽訂閱，不能各觸發一次 gameplay damage。

## 聲音與效能

41 keys：五族各 activate/charge_loop/release/hit/dissipate 共25；英雄/敵兵單發各4共8；中性8。另附24槍聲分層 stems 供混音，不是额外 runtime cue。48 kHz WAV、OGG，原創 DSP；聲演仍留在 v1 audio。

controller 支援 loop 去重、pause 中新 player 繼承暫停、取消清 loop、finish 尾音、voice duck（外部聲演開始/結束呼叫 set_voice_duck）。提供 duck 接口不表示已改主遊戲聲演播放管線。voice duck 降6 dB，請不要同時在外層重複 duck。數值無削波不代替人工聽感審核；手機／耳機／群射仍需實機混音。

28 張原尺寸共 127,919,312 bytes，約 122.0 MiB RGBA（5 張1254²、23張1024²），實際總數見 validation；目前 configure 會載入全部。正式手機版依關卡/武器預載子集或做分族 atlas、縮至512並視檢，不能直接聲稱已做 atlas 批次最佳化。現有 CPU mesh 每次 draw 分配，需實機 profiler 決定 cache／MultiMesh／GPU shader 移植；48 active visual 只是保護上限，不是效能保證。維持普通 alpha blend，避免火、煙、雪全 additive 洗白。Atlas 要保留 extrusion/gutter 和正確 UV，不能讓 UV flow 取到鄰格。

## 重現與驗證

依賴 Godot 4.x（本次4.6.3 headless；repo目標4.7.2）、Python3、Pillow、NumPy、ImageMagick magick、ffmpeg、DejaVu Sans。

從 repo root：

```sh
python3 scripts/vfx/verify_v2.py
python3 scripts/vfx/rebuild_v2_layout.py --out /tmp/vfx-layout-fresh
python3 scripts/vfx/build_v2_standalone.py --out /tmp/vfx-standalone-fresh
# 以下 --path 指向 game，獨立包則改成其 project.godot 所在目錄
export XDG_DATA_HOME=/tmp/vfx-data XDG_CONFIG_HOME=/tmp/vfx-config XDG_CACHE_HOME=/tmp
godot --headless --path game --editor --quit
godot --headless --path game --script res://vfx/v2/tests/test_lifecycle.gd
godot --headless --path game --script res://vfx/v2/audio/test_effect_audio.gd
godot --path game res://vfx/v2/demo/element_demo.tscn
godot --path game res://vfx/v2/demo/matchlock_demo.tscn
godot --path game res://vfx/v2/demo/neutral_demo.tscn
```

重建輸出使用未存在的新資料夾。官方 layout entry 是 `rebuild_v2_layout.py`，讀取保留 source，15 個新圖逐像素比對；Pillow 與 ImageMagick 各保持原版縮放法。槍 source crop 外只排除 alpha<=1 的近零散點（約 .0033%/.0037% alpha 質量），並沒有切掉可見核心；原 source 保留。source 是原生成像素，runtime 是重採樣／布局輸出，兩者不要混稱原像素未變。

離線預覽重建：

```sh
mkdir -p /tmp/vfx-preview-data
godot --headless --path game --script res://vfx/v2/tests/export_timeline.gd -- --output=/tmp/vfx-preview-data/v2-timeline.json
godot --headless --path game --script res://vfx/v2/tests/export_weapon_timelines.gd -- --output=/tmp/vfx-preview-data
python3 scripts/vfx/render_v2_preview.py --repo . --timeline /tmp/vfx-preview-data/v2-timeline.json --audio game/vfx/v2/audio/five_element_effects_demo_18s.wav --out /tmp/vfx-element-preview
python3 scripts/vfx/render_weapon_previews_v2.py --repo . --timeline /tmp/vfx-preview-data/gun-timeline.json --audio game/vfx/v2/audio/matchlock_cases_8s.wav --kind gun --out /tmp/vfx-gun-preview
python3 scripts/vfx/render_weapon_previews_v2.py --repo . --timeline /tmp/vfx-preview-data/neutral-timeline.json --audio game/vfx/v2/audio/neutral_cases_8s.wav --kind neutral --out /tmp/vfx-neutral-preview
```

Space 暫停、Esc清理、R重啟，以 scene 腳本提示為準。18秒片每族3.6秒；8秒槍片依次英雄、敵、十敵群射、遠方英雄；8秒中性片每秒一類。五族峰值聯絡表另附，避免只抽到 fade 空窗。

**驗證界線：** Godot headless 驗證腳本解析、載圖、真 draw callback、錨點、phase/audio 去重、暫停／取消／事件與資料隔離；此環境沒有原生 GPU 像素錄影。MP4 是由實際 emitter 時間狀態輸出做離線合成，元素 UV 是每像素 warp，native 是分段網格；離線粒子未完全複製，灰色遮擋物不是角色。槍／中性預覽只合成主圖與幾何，native 細粒子以 helper 為準。音軌由相同事件表離線混音，五族與槍展示 master 有單獨 gain，neutral 保持較安靜 runtime default；不代表 native 訊號鏈逐 sample 一致。尚需 Codex 在遊戲原生場景驗 GPU、武器實際錨點、音量、輸出匯出、手機效能。PNG/JSON/WAV/OGG 需包含在 Godot export 非資源檔規則，避免 raw Image.load 的打包缺檔。
