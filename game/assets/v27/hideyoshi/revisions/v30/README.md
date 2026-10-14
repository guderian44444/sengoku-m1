# 秀吉動作修訂（2026-10-13）

使用內建 imagegen 生成，沒有使用 API／CLI fallback。正式素材為 `locomotion.png`（走路六格、跑步六格）及 `fan-slam.png`（扇震地六格）；保持原 v27 身體、前景、提案與 SHA 記錄。`registration.json` 是這兩張圖的原生像素量測資料，由 `scripts/register-hideyoshi-v30.py` 納入正式註冊。

生成格線只供排版；每個裁框按完整輪廓量測，保留腳、扇與透明邊緣。頭部尺規以待機 55 像素／站姿等效高度 416 像素為基準，避免把蹲姿或抬手範圍當人物尺寸。新走跑固定同一隻近側右手握刀，採信長的直立刀面方向；劍、握柄與掌面遮擋由引擎組合。震地只繪製圖中一把扇與入鞘刀，不再疊一把主刀。

原地重手沿用經校正的重手六格：第一段下劈，第二段上挑擊飛；基礎範圍 210／220，傷害 32／40 加武器等級，最後仍套秀吉人物與裝備倍率。小劍氣與近戰共用命中範圍，每段只算一次傷害。衝刺重手使用向前下劈，前方擊倒。

原地蓄力三連斬採既有 `light1`、`light2`、`heavy1` 三組校正姿勢。基準接觸 tick 12／34／56，結束 tick 66；每次接觸前走 42 世界像素，共 126，牆壁仍限制位移。前三刀傷害為 20／20／34 加武器等級，第三刀擊倒命中的普通與重型敵人。前兩刀保留短擊退及按攻速計算的受擊保護，讓後續斬擊能接上；沒有無條件穿過既有無敵。下＋蓄力重手在 tick 28 用扇震地，地面波基礎半徑 240，結束 tick 72。

原生雙朝向、三把刀的實際動作路由截圖：`artifacts/hideyoshi-forward-v30/poses/`。合成每格不修改人物狀態。測試包含向前命中／後方不命中、兩段重手、三次接觸、分段位移、第三刀擊倒重型敵人、四種攻速、扇波範圍及動畫接觸格。這些是模擬與原生渲染證據；真人手把手感另行驗收。

## 生成提示

參考圖：原 `body/idle/01.png` 作身份／服装／色調，`body/special_2/04.png` 作金色葫蘆扇形狀。第一版扇圖用作一次修訂的參考，未作正式 runtime 素材。

### 扇震地初稿

```text
Use case: stylized-concept. Asset type: production 2D fighting game sprite sheet, exactly SIX full body frames, 3 columns by 2 rows, landscape 1536x1024 if possible, genuine transparent background. Input image1 is the identity/color/style reference (Hideyoshi idle); image2 is the exact GOLD GOURD SHAPED WAR FAN reference. Create the SAME Hideyoshi wearing navy haori with RED lapels, black samurai armor with subtle GOLD edging, grey loose pants, BLUE knee ties, straw sandals, black topknot, narrow receding hairline face and goatee. Same warm muted game painting style, no face/clothes redesign. NEW ACTION: facing RIGHT, charged downward-heavy attack with the gold gourd-shaped rigid fan, smashing the GROUND IN FRONT of him. Six sequential distinct poses row-major: 1 sheathed sword and reaches for fan at waist, 2 fan gripped in right hand rising to shoulder, 3 lifts fan overhead preparing downward swing, 4 clearly leans forward with bent knees and fan head contacting ground at FRONT RIGHT of character, 5 grounded low follow-through fan still down in front, 6 recovering to guard with fan near waist. Sword stays fully SHEATHED all six, only one scabbard. ONLY ONE fan, relocate the stowed fan when holding it. Right hand always anatomically right (near camera shoulder), left hand balances, no extra hands/fingers. Uniform head size, limb proportions and standing-equivalent scale across all six cells; every body and fan entirely inside its equal cell with 20px margin, both feet visible. Plain transparent with no ground, NO shadow, NO dust, NO impact glow, NO sword energy, NO blurred or repeated limbs, NO text or labels. Clear readable silhouettes and crisp strokes, view from identical game side three-quarter angle in all frames. Keep charcoal/navy/brick-red palette identical to reference, no high saturation or grey color drift.
```

### 扇震地修訂（正式圖）

```text
Use case: precise-object-edit. Edit this exact six-frame sprite sheet. PRESERVE all six poses, character identity, outfit colors, scale, frame layout and right-facing direction. Fix ONLY these production problems: (1) completely REMOVE EVERY colored/brown glow background, backdrop, floor shadow and ambient haze. Every pixel outside the crisp character/fan/scabbard silhouettes must have ZERO alpha, true transparent background. No radial glow whatsoever. (2) There is exactly ONE gold gourd-shaped war fan in each cell. In frames 2,3,4,5,6 the fan is held in his right hand; REMOVE the duplicate gold gourd motif/fan from the chest, revealing plain black laced samurai breastplate there. In frame 1 he grasps the fan's short brown/gold stem at chest preparing to take it out; remove the loose sword/hilt held across the waist in his right hand. Sword stays fully sheathed at hip in every frame, one scabbard only. Keep the six distinct slam animation poses and gold held fan unchanged. (3) Six subjects entirely fit their grid cells without overlap; exact 3-column 2-row equal grid, 1536x1024. No text, no extra weapons, no blurred outlines. Transparent clean production sprite silhouettes, not a poster.
```

### 一致握刀的走跑（正式圖）

```text
Use case: identity-preserve. Create a GAME ANIMATION BODY sprite sheet of the exact same samurai Hideyoshi in the reference, matching his narrow face/goatee/topknot, navy coat RED lapels, BLACK armor GOLD edging, GREY trousers, BLUE knee cords and straw sandals. Exactly TWELVE full-body poses in an equal 3 COLUMN by 4 ROW grid, portrait 1536x2048 if possible. First two rows = six WALK poses; last two rows = six RUN poses. Row-major ordering. WALK: relaxed upright six-frame full stride loop; RUN: forward-leaning six-frame full stride loop; alternate feet naturally through left contact/down/pass/right contact/down/pass. Same side three-quarter facing RIGHT in every cell, no turning torso to opposite side. Fixed camera, uniform head size/limb proportions/standing-equivalent scale and consistent muted palette in all twelve frames. IMPORTANT: anatomical RIGHT arm is the near camera shoulder, preserve SAME sword-carry arm all twelve; hold that near RIGHT empty CLOSED fist slightly in front of his waist, forearm nearly horizontal, fist at nearly identical relative-to-torso position throughout. Left far arm balances naturally. Do not swap arms or switch hands. Hands are EMPTY because engine draws a separate upright sword through the right fist; absolutely NO held sword blade, NO held hilt, NO blade shards. The single sheathed scabbard at hip has NO visible sword hilt because sword is drawn; empty scabbard only. ONE gold gourd-shaped stowed fan at chest. Frame1 and frame7 match the same identity/scale as reference. Crisp readable silhouettes, no blurred limbs, no smear frames, no perspective size changes. Full body completely inside each equal cell with 25px margin and feet visible, no cell overlap, no text. Genuine transparent background: ZERO alpha outside character contours; NO brown glow, NO floor, NO shadows, NO halo, NO backdrop. Reference image is identity/style only, not a background. Asset must be ready for a 2D beat-em-up game, clean isolated sprites.
```
