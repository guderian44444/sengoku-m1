# 第三關 Codex 接入與完整性入口

2026-10-16。**第三關機制原型可通關；正式關卡尚未完成。** M4 程式在 `220922b71ad875c45e70edeaffa3dd42c95378b3`，新敵軍綜合預覽已確認並授權 Git 交付，但本批新 PNG／metadata 尚未接入 runtime。本輪只新增美術交接與文件，不把來源包當成遊戲已換圖。

## 先讀與啟動

- 分支 `feature/stage03-imagawa-camp`；獨立 worktree `D:/AI/吞食戰國/artifacts/stage03-imagawa-camp`。保留其他 checkout 與未提交工作。
- [試玩入口與操作](STAGE03-PLAYTEST.md)、[關卡設計](STAGE03-IMAGAWA-CAMP.md)、[M4 驗證](STAGE03-VALIDATION-M4.md)、[素材完成度](STAGE03-ASSETS.md)。正常章節選單仍隱藏 `prototype: true` 的第三關。
- [敵軍包入口](../deliveries/stage03-enemies-20261016/README.md)、[37 招逐格資料表](../deliveries/stage03-enemies-20261016/ACTION-INDEX.md)、[結構化接入資料](../deliveries/stage03-enemies-20261016/integration-contract.json)、[驗證結果](../deliveries/stage03-enemies-20261016/validation.json)。
- [原包播放 manifest](../deliveries/stage03-enemies-20261016/source/manifest.json)是最終 PNG 路徑、逐格 ms、最終 root、loop 的入口；metadata 保留各作者事件／末格保持及重建來源。不能把同名 `manifest.json` 都當同一 schema。

已接流程：警鐘多柱全斷停援 → 三層必要木障 → 錯落陣形、後排真實走位及延遲補兵 → 帳內雙小王 → 90 tick 安全出場 → 義元 → 義元死亡即勝利。帳內切換保留玩家及存活雜兵，義元死亡不需清餘兵；所有數值是可調原型預設。

## 角色 ID 與 runtime 對照

以下是接入定位及建議配對，**尚未寫入 registry 或改名 A／B**。角色條件需限定第三關及目前遭遇／今川陣營，不能把全遊戲同 `kind` 都換圖。

| 包內 ID | 新外觀／固定武器 | M4 定位 | 接入注意 |
|---|---|---|---|
| `shield` | 盾兵，盾／槍已合成 | `role=shield_spear`；底層 kind 經 ENEMY_ROLES 正規化 | 6 組26格；不能直接用 kind=shield_spear 找角色。不要再疊現有盾與槍裝備。 |
| `spear` | 槍兵，固定槍 | 第三關 `kind=soldier`，排除 `role=shield_spear` | 5 組22格；先核對實際 AI 招式與近戰判定，不能只改 renderer 名稱。 |
| `archer` | 弓兵，固定弓 | `kind=archer` | 5 組22格；人物放箭事件接既有獨立投射物。 |
| `ii_naomori` | 井伊直盛，固定槍 | 建議帳內 `lieutenant_slot=1`／A | 6 組32格；現行 A 仍為 `naginata` 占位，含 thrust／sweep／counter，並非每招都有對應新素材。 |
| `ujinori` | 蒲原氏德，固定刀 | 建議帳內 `lieutenant_slot=2`／B | 6 組30格；現行 B 的 dual_swords／double／counter／thrust 與單刀 slash 不完全對應，需後續核對動作選單。 |
| `yoshimoto` | 今川義元，固定武器隨姿勢合成 | `kind=boss && is_yoshimoto=true` | 9 組46格；沿用既有唯一 ID、目標、瞄準、冷卻、人口與血條。 |

原始生成來源與修正前備份沒有隨這份審閱包交付；metadata內的作者工作路徑不是本repository檔案。本包可核對與播放，不宣稱能完整重建生成流程。

來源 JSON 的 `imagawa_shield`／`imagawa_spear`／`imagawa_archer` 是原作者身份欄位；統一播放入口的 canonical IDs 是上表英文 key。角色外觀審閱確認不代表既有 A／B 招式設計已完成改寫或歷史人物編排為史實。

| 新動作 | 既有 runtime 定位／待接 |
|---|---|
| `idle`, `walk` | 待機／移動顯示；既有敵人移動可能保留 `action=idle` 並由 `move_dx/move_dy`／entering 判斷步態。不要直接往快照塞未註冊的 art action ID。 |
| 三兵種 `attack` | 依兵種接現有近戰或 `bow_shot`。盾／槍來源 `hit=3`，弓兵 `release_arrow=3`；權威傷害／放箭只由 Battle 觸發一次。 |
| `thrust`, `slash`, `naginata_slash` | 分別對應新槍刺／刀斬／義元近斬的視覺素材；現有 `boss_thrust/boss_sweep/boss_double/boss_counter` 不可盲做一對一別名。缺招先明列，不以錯誤武器姿勢冒充。 |
| `block`, `guard_retreat`, `retreat` | 視覺跟隨既有 guard／tactic／移動狀態；guard_retreat 不自動新增無敵或整段格擋。 |
| `yoshimoto/bow_shot` | 對接 `boss_arrow`，來源 projectile event 480ms、origin `[460,240]`、右向 `[1,0]`。 |
| `yoshimoto/sword_energy` | 對接 `boss_sword_wave`，來源外部 FX event 460ms、origin `[490,395]`、右向 `[1,0]`。人物共用 naginata_slash，**沒有新劍氣投射物圖**。 |
| `hurt`, `down` | 依受傷、倒地、死亡狀態選取；down 單次後保持末格。屍體期限、復活與遭遇死亡墓碑仍由既有邏輯控制。 |

本包不含 run／jump／recovering／victory，也未交付完整 grabbed／thrown／launched 專用組。現有 runtime 會用到的狀態須逐項核對可接受的重用或補圖；不能只因指定37組齊全就宣稱引擎全部狀態已覆蓋。

## 逐格時長、根點與縮放

- 共37組、178個播放格，實際為163種 PNG SHA256；每組4–9格。按 frame `duration_ms` 累積選格，`loop=true` 才取模，單次動作到末尾由 runtime 換狀態，倒地保持末格。不要套固定六格、固定 FPS 或每格等時。
- [完整表](../deliveries/stage03-enemies-20261016/ACTION-INDEX.md)列出所有逐格時長、總時長、畫布與 root。三兵種640×320、root `[260,285]`；蒲原一般660×510、root `[270,480]`；井伊一般680×550、root `[70,500]`；義元640×560、root `[200,480]`。
- **井伊 down 例外**：760×550、root `[150,500]`，為恢復左側手／槍尾增加的邊界。不可繼續套一般 root。
- **蒲原 slash 例外**：最終 manifest root `[140,480]`，其他動作 `[270,480]`。原資料的 preview_anchor 為後腳參考，與其他招身體中心語義不同；須校正跨動作 visual socket，不能把130px差值加到世界座標。
- 義元來源子格 `root_px`／source_anchor／translation 與最終 PNG 的 root 並非同一空間。最終 PNG 已組裝，勿再次套 source_box、sheet_scale 或來源平移；原始數值只供追溯／重建。
- 以 `x = world_x + face * scale * (pixel_x - root_x)`、`y = world_y - z + scale * (pixel_y - root_y)` 對齊角色。面向反轉同時作用於整張含武器 PNG 與事件 origin 的相對向量，不只鏡像人物。
- manifest 中0.7／0.52／0.58／0.62是綜合影片各角色預覽倍率，不是已核准 runtime 尺規。接入時固定每角色比例，再按可靠的動作 root／socket校正；不能以當格不透明外框重算等高，否則蹲姿、跳躍與倒地會膨脹。

## 固定武器、位移與事件權責

六人 PNG 已包含固定弓、刀、槍、盾等所需武器。敵人不換裝，**不需要可替換武器層、手遮罩或重新拆武器**。未來使用此包的顯示路徑須避免重畫目前 WeaponRenderer／enemy role 裝備；只對新素材路徑處理，不影響玩家及其他敵人。

動作是原地播放。`preview_world_displacement`／preview_displacement／preview_root_motion 是預覽資訊；`world_motion=runtime-owned`、world_displacement為null或`[0,0]`不代表停止AI。世界位置、退避距離、碰撞、擊退、入場與離地高度由 Battle／遭遇狀態決定，不把來源裁切／translation 再累加成 root motion。

預覽毫秒時間與目前權威時序不同：例如義元素材放箭480ms，M4 `boss_arrow` 在第42 tick出手；刀氣素材460ms，M4在第50 tick出手。接入需對齊預備／出手／收招相位，或經另次授權調整戰鬥時序；不能讓 renderer 播一次 event 又由 Battle 再生一發。

| 來源事件／結束 | 交接規則 |
|---|---|
| 盾／槍 `event_frames.hit=3`；弓 `release_arrow=3` | 原PNG編號01起，來源標第3格；接入先原速核對。可作視覺同步點，不取代既有權威命中窗口。 |
| 三兵種 down `grounded=4` | 落地效果按狀態轉移去重；單次播放、末格保持，不循環倒下。 |
| 井伊 guard_retreat `block_active_frames=[2,3]` | 作者提示，需與現有有限格擋窗口核對，不可把全部退避當無敵。 |
| 井伊 hurt `impact_frame=2`；down `ground_contact_frame=5` | 原資料格號保留，接入核對接觸；末格保持。 |
| 蒲原 down `land_frame=3`，idle／walk `loop_seam=[4,1]` | 動作落地後保持末格；只有idle／walk閉環。 |
| 義元 down `hold_last=true` | 沒有獨立明示 grounded event，需補定落地時點；不得以總870ms自動當命中事件。 |
| 義元 retreat `loop=true` | 反序重用walk；循環只在既有短退狀態內，AI時間／距離上限仍生效。 |
| 義元 sword_energy外部FX事件 | 包內只有角色施放動作與事件；箭飛行圖、劍氣投射物圖另缺，可沿用既有原型繪製後再驗收正式效果。 |

蒲原slash時序缺檔已套用製作者最小修補：補回原始`metadata/ujinori/slash/timing.json`，六份清單以`../slash/timing.json`正確引用。8格／800ms、主manifest及所有PNG／影片不變；586筆來源frame引用與六份timing引用已核對存在。原始timing仍明載世界位移／命中由接入方處理，這是正常runtime接線工作，不是缺檔待辦。盾block的有效窗口、井伊thrust命中點、義元近斬權威對時等也需要接入方核對，原資料沒有的欄位不得自行填成已驗收值。

## 完整性盤點與驗收工作

| 項目 | 目前已有 | 尚缺／未驗 |
|---|---|---|
| 關卡機制 | M1–M4四場景、兩階段帳內、有限增援／走位、箭／刀氣、勝敗與重開 | 真人正常攻擊完整通關、難度／人口／掉落與節奏調校。 |
| 新敵軍美術 | 已確認綜合預覽；6人37組178格、固定武器、來源與時長 | registry／renderer接線、舊動作ID對照、缺少狀態、武器雙重疊圖、左右向與跨招root校正。 |
| 正式場景 | 原型沿用營地／門／室內底圖，已有碰撞及帳門流程 | 警鐘營地、障礙區、帳前陣地、帳內正式可用底圖、前後景／遮擋、鏡頭邊界與資產登錄。**概念圖與核准旗紋不是完整場景資產**；敵軍ZIP沒有場景圖。 |
| 警鐘與支柱 | 高鐘、兩地面支柱、受傷／斷裂／停響原型 | 正式完好／受損／重損／斷裂柱、鐘鳴擺動／傾斜／落下／停止、碎屑／塵土／接點與分層。 |
| 木障與帳篷 | 三排不可繞過的碰撞、破壞流程、帳簾占位 | 木障完整／受損／崩裂／殘骸、帳篷外觀／入口／帳簾前後景，正式素材未在本包。 |
| 投射物與VFX | M4箭／弧形刀氣真實碰撞與占位、有限格擋 | 本包無箭飛行／劍氣圖；正式命中、格擋、碎木／塵土等效果及原生合成驗收。 |
| 音效／配樂／語音 | 基底沿用曲目與警鐘占位音，狀態控制循環停止 | 本包無音檔；專屬警鐘／停響、柱裂／木障、弓弦／刀氣、格擋、義元／小王語音及真人聽感。 |
| 單人／雙人／同步 | M4選定12組回歸、義元119 checks，Wire／本機決定性及人工安排原生畫面 | 新美術原生播放、實體雙搖桿／震動、鏡頭夾位、跨機主客端、延遲／斷線／重連；自動狀態fixture不是這些驗收。 |
| 正式開放／發布 | 專用隔離試玩入口 | 正常章節解鎖／流程、存檔策略、發行包驗證。本次只推分支／開PR，不merge或發布遊戲。 |

建議下一位依序：驗包與讀37招表 → 在新工作範圍實作限定第三關的固定武器顯示adapter → 補齊動作／事件缺口與跨招root → 核對權威時序及左右向 → 原生單人／雙人完整試玩 → 正式場景／物件／聲音與跨機驗收。這是接手順序，不是本次已接線聲明。

## 版本、來源與 PR 範圍

機制驗證依據保留在 M1–M4文件；本輪只驗新增包、文件與原始位元組，沒有為新素材重跑並宣稱遊戲已換圖。驗包指令：

```powershell
python -X utf8 deliveries/stage03-enemies-20261016/verify_delivery.py
```

遠端main查驗時是`966cf8c3d48a4579554bc046a5961870faaaafa8`，本分支基底是本機v0.31 `d28717797584dc2ea794c57b9b01b2980f6a7c82`。PR歷史因此包含既有v0.30 `6d916cba`及v0.31 `d2871779`兩筆依賴；不能把相對main的全部差異都當本輪新寫。純第三關機制範圍可用 `git diff d2871779..220922b7` 檢視，之後的美術交接commit另看本次差異。未匯入主工作樹未提交v33–v36、其他美術工作、Godot產物或私人下載助手。

若要拆開審核v0.30／v0.31依賴，先規劃基底交付再決定合併順序；本輪保留既有分支歷史，不改寫main、不force push、不自行把第三關移植回舊基底。
