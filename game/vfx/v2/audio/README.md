# 五元素效果本體音效 v2（增量）

本包獨立於原42音包；不修改既有角色喊招或舊版資產。
25段原創程序合成音效：blade / fire / ice / wind / lightning，各有 activate、charge_loop、release、hit、dissipate。48kHz mono PCM16 WAV及Ogg Vorbis q6；無素材庫取樣、錄音、音樂或新配音。
刀氣採金屬窄頻與短促切風；火焰採低中頻燃燒噪聲；冰採高頻晶粒与非整倍泛音；風採寬頻渦旋脈動；電採脈衝鋸齒buzz與高頻劈啪瞬態。這是合成設計說明，不代表已聽感驗收。

## 統一接口

EffectEmitter是唯一時序所有者；EffectAudioController是唯一效果SFX播放器。不要同時開舊generic special SFX與新效果音軌。
- configure("res://vfx/v2/audio/")
- handle_cue(instance_id,cue_key,operation,context={})，operation=start / loop_start / loop_stop / stop_all
- update_instance(instance_id,intensity,phase_progress)，0..1；charge gain隨phase上升8dB；環旋pitch只0.98..1.06，gain最多增加2dB
- set_paused(bool)：所有現存及新spawn的player一致暫停
- stop_instance(id)：立即停所有該ID聲音、清loop和context；cancel不觸發dissipate
- stop_all()：換場/重新載入清空全部
- set_voice_duck(bool)：由既有Voice系統active count決定；效果音降6dB，不重新播voice、不改用户音量設定

cue命名完整例：lightning_activate / lightning_charge_loop / lightning_release / lightning_hit / lightning_dissipate。
第四參context接受intensity与phase_progress（progress為兼容alias）。無效cue返回false不出聲。loop_start只允許loop資產；同id+loopkey重复不会restart。loop_stop立即停，release前由Emitter先發loop_stop。

## 事件責任與生命週期

每spawn使用包含generation的唯一instance_id，cancel後可重用外層邏輯ID但生成新generation最佳。
Emitter用absolute simulation ticks推動；拒絕倒退tick，真正seek/重播先stop_instance再重建generation。AudioController不自建wall-clock時序，也不自行在update中生成命中。
confirmed_hit只來自實際命中且Emitter去重hit_event_id；同一發射穿多人可有多個合法hit事件。對誤命中或cancel不放命中/消散音。
Charge loop從0tick開始，到release立即停止；暫停中cancel仍停止，不留下loop；停止後新spawn可正常重用ID。

## 混音與容量

全局12 voices、每instance5 voices，上限時優先回收最舊oneshot，沒有oneshot才回收最舊loop。這會在極端負載下犧牲較舊效果層，避免無限疊音。loop dictionary同步清理，可安全restart。
單檔sample peak -7dBFS（loop -10）。controller oneshot最高gain -18dB、loop最高-24dB；12份同相oneshot理论sample峰值上界约-3.4dBFS，不包含音樂/語音或外部增益。pitch interpolation與其他遊戲音軌仍要master true-peak limiter -1dBTP；用實機驗證多人場景，不能只靠單檔峰值保證全遊戲不削波。
Ogg供封裝選用；helper預設WAV，能直接設定sample-accurate loop不依賴import flags。
慢動作下cue跟simulation tick，播放保持正常時間；若要蓄力音隨時停，必須以Emitter phase轉換停loop，不以預測duration計時。

## 數值QA及重建

python build_audio_v2.py（已安装NumPy/SciPy與ffmpeg），python validate.py。只覆寫本增量包，不讀舊版或外部音源。manifest包含SHA、時長、RMS、sample/4x估算true peak。validation含OGG檢查與短檔EBUR128數據。
Godot test_effect_audio.gd覆蓋五元素並存、loop重入、loop→release、instance ID重用、rewind前reset、pause中spawn/cancel、Voice duck、全局/單instance cap及清場。
工程數值檢查≠聽感驗收。本批未聽覺驗收；保持這項缺口。

## 自然完成與展示

operation=finish立即結束該instance loops，保留正在播放的oneshot尾音，最後一個tail結束才清context。換場必須controller.stop_all()，不能僅cancel仍active的Emitter，否則已退休但有尾音者未被取消。容量限制是回收舊player再新建，不是預建物件池。

展示音軌five_element_effects_demo_18s.wav，按demo_events.json（60事件）與render_demo_audio.py生成，逐族3.6秒；上排蓄力60tick釋放、72tick確認命中、84tick消散；下排72tick兩圈，tick0/36各一次旋斬聲、72tick消散。無角色喊聲。離線展示有固定master增益便於試聽，記在demo_mix_report，非遊戲Master設定。整合者必須使用同時間表，不能把聲音任意貼到不同動畫。離線音軌是事件對齊示範，並非從Godot實際音訊輸出擷取；實機混音仍需驗收。

## 火槍分層增量

build_matchlock.py在五元素生成後執行，追加8段mix：hero_matchlock_shot_0..3、enemy_matchlock_shot_0..3；每段保留crack/body/powder共24個stems。英雄是低中頻厚爆裂＋較長火藥尾聲，敵兵是較亮短乾瞬態＋較短body，非同檔單純normalize改音量。mix均sample peak -7dBFS，微變體有頻帶/細部波形/尾長差異，禁止重播時一律強pitch。

由實際gunshot/fire事件單次start，和muzzle flash同tick；reload/charge不得再發shot。shot_event_id在Emitter層去重；變體選擇可用事件IDhash % 4防止render重入時改選。取消不發不存在的shot。每shot用獨立instance generation，finish保留尾響，換場stop_all。
context.distance在0近、1遠之間線性衰減0..-12dB，enemy額外-3dB，voice duck仍-6dB。這裡只有距離gain，未聲稱做了幾何遮蔽、傳播延遲或環境混響；若遊戲要距離low-pass可在另設spatial bus接入。
matchlock_cases_8s.wav由matchlock_demo_events.json驅動：0秒英雄單發、2秒敵兵單發、4秒10敵兵50ms間隔群射、6秒英雄遠距離單發（distance=1）。固定展示master增益另記，未改戰鬥damage、射速或實際敵人數。

完整可重建順序：python build_audio_v2.py → python build_matchlock.py → python validate.py → python render_demo_audio.py。五元素build會重置manifest，故火槍build放第二步。所有stems只供編輯，不需在遊戲同時播放mix與stem。

## 無屬性武技增量

build_neutral.py在matchlock後執行，再跑validate。8個單次cue與recipe同名：neutral_slash_arc刀風、thrust_cone集中刺風、arrow_trail箭飛掠、throwing_blade_trail短掠風、blunt_impact鈍擊低響、guard_sparks金屬格擋、slash_hit斬擊瞬音、dash_dust塵土落地。全為非loop、無魔法hum；箭尾/飛刀視覺可持續，但音訊只發一次近距飛掠，不每frame重播、不做無限loop。命中/格擋需對應真實事件；移動落地可用對應動作事件。

與元素疊加時兩層都傳context.layered=true，各減6dB，不把两層滿音量相加。controller update會保留distance及layered狀態，不重播效果。全局12音/每instance5音/voice duck適用所有新增cue。
