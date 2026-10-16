# Four heroes: accepted base-animation handoff

## Entry and scope
Start at `manifest.json`, then each character's `integration_manifest.json`. There are 36 base actions and 212 frames, plus four formally registered shared combat idles and four portraits cropped from approved art. The final Ieyasu run is **run_v5**, not v4. All latest motions were accepted by user event `Sentinel_003f9aaa53ac819191a42c7ac9485ce8`: “動作都OK了，把後續都處理好就上GIT”.

This is an expanded, Git-ready asset handoff. It contains no oversized ZIP archives. The bundle itself does not change the runtime, existing combat animations, review site or Git repository. Older drafts remain outside this bundle. Historical source-generation and preview documents can contain earlier candidate labels; current integration manifests and the acceptance event determine final status.

## Scale and rendering contract
- Tadakatsu r3: 163 px anatomical standing ruler, excluding horns/decorations.
- Hideyoshi: 150 px; approved head ratio 95%.
- Ieyasu06: 152 px, gray-white coat; run_v5 preserves accepted leg pixels/foot trajectories while revising only upper-body motion.
- Kennyo03: 163 px, white cowl.

Do not normalize each pose to its bounding box. Crouching, airborne, fallen and weapon-raised poses intentionally have different bounds. Preserve the recorded source-to-game scale and original high-resolution PNGs. The registered combat idle is reused unchanged; portraits are crops, not new drawings.

Use transparent body, weapon and hand_occlusion layers in each frame's recorded back-to-front order. For Ieyasu's canonical three-layer export, body includes the sheath. Do not render the sheath again. Keep transparent alpha; GIF backgrounds and enlarged proof sheets are review-only.

Read the per-frame timing and anchor metadata. Character canvases and roots differ; do not align by bounding-box center. Use the declared root canvas coordinate and convert it once to the engine pivot. Frame indices vary in legacy data, so preserve explicit indexing until conversion. Original feet may be named left/right, near/far, or landmark indices. Unknown anatomical left/right values are intentionally unresolved; do not invent them by sorting screen x.

## Motion and state machine
Preview displacement and proposed/engine-controlled world displacement are separate. Do not add preview motion to world motion or double-apply pose offsets already baked into sprites. A zero world delta is not a tested speed or jump trajectory.

Walk/run/stunned are looping states. Other actions are one-shot even if their review GIF repeats. Use supplied event/terminal tags for takeoff, apex, landing, down/death hold and settling to idle. Events are animation markers, not tested gameplay callbacks. Down's final pose can hold for death; recovering ends in the registered combat idle. Verify event deduplication at loop boundaries and chained state transitions.

## Required runtime work, not claimed complete
1. Atlas/import configuration, texture filtering, alpha behavior and frame timing conversion.
2. Pivot/root conversion and facing/mirroring conventions; anatomical foot mapping if IK or foot locks are used.
3. Controller input and state transitions, locomotion speeds, jump/knockback physics, gravity and ground contact.
4. Collision and hitbox/hurtbox setup, gameplay cancellation/priority, invulnerability and movement permissions.
5. Released weapon placement/pickup, including avoiding duplicate weapon rendering.
6. Death hold and recovery transitions; check pose and world-position continuity in actual play.
7. In-engine playback/performance tests at game scale, animation-speed changes, direction changes, collision edges and low frame rate.

No runtime integration, collision correctness, gameplay balancing, atlas test, engine performance test or audio is asserted. Ordinary base actions have no FX. Visual acceptance, exported-layer equality and metadata checks do not substitute for runtime validation.

## QA and provenance
Each character contains QA, source provenance and hashes. The root QA report verifies the final inventory, SHA checks, file-size ceiling and explicit run_v5 selection. See representative pose sheets and their captions to locate entry, passing, apex, impact, down hold and recovery poses without replacing animation playback. Preserve original PNGs; generated detail must not be recreated repeatedly from small game sprites.
