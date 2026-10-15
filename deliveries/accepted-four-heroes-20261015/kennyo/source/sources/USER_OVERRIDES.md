# 顯如03最新製作決定

- 人物身份：2026-10-15使用者選新版03白頭巾、尖鬚長臉、局部甲、大念珠，來源人設已留存identity/approved-concept03.png。
- 身高：比照最新版忠勝，排除鹿角/飾冠，以頭頂到腳底約163px為站立等效顯示尺規。見identity/scale-contract.json。同一動作來源固定頭/軀幹骨長；蹲下跳躍不依當格bbox拉成等高。
- 集氣：站立念經，短合掌過渡可動，保持段人物完全固定，不呼吸晃動/上下擺。最新版覆蓋source/specs裡舊頭頂高舉武器的描述。
- 滿蓄放開：頸念珠取下，放大拉長左右連打三輪，一輪右擊+左擊，共6揮。加入獨立「南無阿弥陀仏」佛號粒子，不新增治療、召喚或未授權狀態。
- 其餘招沿最新專屬表：輕手左揮/右揮/第三甩一圈；普通重手收杖一步上打；空輕近揮/空重下砸；抓後頭槌兩次/前拋/反向過肩；跑重前揮。
- 長棍、飾頭長錫杖、薙刀為已要求的可替換長柄外觀；03展示薙刀不改其棍系動作規格。
- 此目錄僅素材與可檢查預覽，尚未runtime接入或遊戲測試，未改Git。

2026-10-15 latest: regular previews must carry ornate shakujo. Charging explicitly stows complete staff behind body. Necklace release uses flexible closed-chain curved/lagging motion, not rigid hoop. Buddha glyphs emit on six strike events, independently move and fade; no attachment to necklace. Sources: Sentinel_cdb8beb795508191a5589cacf69c444e and Sentinel_8bcec2531cfc8191a2cf7901ac2d94fb.

2026-10-15 revision after first sixteen previews:
- light_1: +3 genuine frames, 7→10 at 670ms. Hands near tail, most full staff extended forward with actual stepping/torso swing. Source Sentinel_a8f17de9b86c8191b77d03589f127fd1.
- light_2: one clear right sweep and one contact; near-body recovery must not re-extend as a second strike. Source Sentinel_2eb1a17b8ed88191b3f9fde03897f81c.
- light_3 overrides source one-circle: face front throughout, small upper torso rotation, large upper-left to lower-right diagonal staff sweep, no back view or full rotation. 11 frames / 950ms. Sources Sentinel_8da189a409e881918219e65f31757be3, Sentinel_baa53fc1f6a08191be1c2472acc610b5.
- Both headbutts use approved second animation (6 frames/600ms), with separate events. Do not implement superseded first-headbutt +2 request. Source Sentinel_c136248efc008191b0cfe0ac008dde1b.
- Forward throw 10→12 frames/980ms: lower hips and support opponent's weight, lift with leg/shoulder drive, continuous hand contact until release, recover. Source Sentinel_0ae62d98d0bc819191e06f301b9ea3ad.
- Reverse throw 10→12 frames/1030ms with weight-bearing turn and shoulder transition. Source Sentinel_1b3cab5445a08191aa20f4c288a85347.
- GIF timing must distribute rounding remainder rather than truncate each frame. Preserve exact total in 10ms units. Air-heavy source945ms is nearest representable950ms; all other requested totals are exact.

- Release latest source Sentinel_aafc91c649f08191945ab39ee29adf39: body playback keys33→38 (not FX samples54); pull left through overhead to right with real torso/shoulder force, three rounds/six strikes,3170ms. Implemented charge_release_v3 with new overhead body sheet.
- air_light8→11 /770ms and air_heavy8→11 /GIF950ms: +3 true poses each. Sources Sentinel_b08aef632a44819189f25fd3c3ead857, Sentinel_14b7d4340f94819196c2dcee5dc7311e.
- dash_heavy now long forward thrust, tail-end two-hand grip, arms extend and full staff projects forward, not downward swing.7 frames730ms. Source Sentinel_871e0cd3429c8191ac435e773964808e.

- light2 latest Sentinel_470f475084348191ac079419be7815e7: start normal separated-hand grip, slide toward tail only at maximum strike, then recover normal guard. Only light2 revised. Implemented light_2_v3,7 frames680ms.
- Release body v3 accepted. FX-only override Sentinel_aec5b6cb114c8191af8a073aba939c3f: replace Buddha chant words with upright Buddhist 卍 (U+534D), heavy fast projected impacts with short trails and light scatter. Implemented charge_release_v4; body/bead/weapon/occlusion190files byte-identical to acceptedv3;38 frames3170ms unchanged.

- Final light1 revision sources Sentinel_45df8cb2e0ac81918d0384b3cbbf7f33 and Sentinel_ee63af796c708191b1dbe90ea053ea27: real angled swing rather than thrust, same anatomical left foot/screen-right forefoot locked at(330.484,325), other foot moves and waist drives. Implemented light_1_v3,10frames670ms; actual staff arc approximately140degrees; measured pivot pixels within1px.

FX-only latest Sentinel_9adee52fca148191a0ab35b731c0f49f: outward/upward irregular ballistic scatter, varied angles/speeds/heights, fixed seed202610150409, short tangent trails and gravity; no synchronized straight rows. Six pulses unchanged.190 approved body/bead/staff/hand layers byte-identical;38 frames3170ms. Other15 actions unchanged.

Latest light3 timing Sentinel_e28a8502309081919cb92f8f2f1ad2ee: preparation first4frames360ms unchanged, downstroke frames5-7 accelerated180→90ms, saved90ms added to recovery.11frames950ms; all decoded frame pixels unchanged; contact480→420ms.

Batch V5 feedback: light1 Sentinel_8f4973efb0248191aee7da1c0494751d lower torso and faster strike; air_light Sentinel_03b2186c43b4819197e7e88b517660b9 continuous staff swing; air_heavy Sentinel_0bf940b07e6c8191a85ef86e7bd0088b two added deep landing/recovery keys. Air-heavy rise/recovery grip ordering also corrected locally to remove head-tail discontinuity, preserving13/950 and landing keys. These are review candidates, not inferred final approval.

Batch V6 feedback Sentinel_c032fecf072c81919a118c453eaac1ab: air_heavy add2 genuine transition poses,13 to15frames950ms. Latest Sentinel_af8c4959d8a08191b7e6d0702997c388 fixes visual continuity at4/6/9/10/13/14 and jump trajectory. Sentinel_0eace63933688191921865af3484c86d clean normal-action previews: body+weapon only, FX remain separate. Single playback avoids22px action-root loop reset. Other15 actions unchanged. These are review candidates, not inferred final approval.
