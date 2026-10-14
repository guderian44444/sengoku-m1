# Shared VFX + special audio: independent QA

Date: 2026-10-13. Base: `966cf8c3d48a4579554bc046a5961870faaaafa8`.

## Verdict

**PASS for asset integrity, reproducibility, offline inspection, and headless logic only.** This is a reusable asset/adapter handoff, not a claim of completed battle integration or native GPU/audio acceptance.

The frozen handoff contains 164 files. Tests ran on copied files and newly generated standalone projects; the production checkout's tracked files remained unchanged. Godot tested: 4.6.3. The game's declared 4.7.2 version, Windows, export, GPU rendering and performance were not tested.

## Verified

- All 13 runtime PNGs (three families × four base effects, plus blue-white wave) load, match manifest SHA256 and dimensions, contain real zero alpha and partial transparency, and honestly declare one authored frame. No flipbook is claimed.
- Eight blade/ice runtime layouts rebuild pixel-identically from the included source images. Five fire/blue-white textures preserve their original source pixels.
- Base art's visible alpha > 8 has margins on every side. Very faint original alpha noise remains at the fire source edges; it was not thresholded away.
- Fire-ring overscan was checked at 361 angles. Maximum boundary alpha decreased from the pre-fix 233/255 to 1/255. Blade-ring boundary maximum is 5/255. This is CPU sampling/math evidence, not a GPU pixel result.
- Ring pivot/seam and complementary front/back passes preserve the same coordinates. Per-actor back effect → actor/weapon → front effect hook ordering is documented. The offline composite visibly lets the actor occlude the rear middle of the rings.
- Single-frame sampling now sets mix to zero; the same texture is no longer double-drawn with changing alpha weights. Timing boundaries, negative time, speed/start offsets, facing and body-scaled anchors passed.
- The fire/blade demo's 720° angular flow over 72 ticks is present in the native helper path as well as the offline illustration. Fade-out and a hidden interval replace a visible phase reset. Ice crystals remain rigid; their demonstration uses positioning/fade and secondary snow, not authored frame animation.
- A clean standalone project was generated from the handoff. Headless editor import, standalone scene, six-special scene, supplied sampling test, and independent draw-callback test passed with no script errors. The independent test loaded all 13 textures, exercised front/back and both facings, and verified the six-special adapter did not mutate fighter dictionaries.
- All six special duration/hit-tick snapshots match the actual `Battle.SPECIAL_TICKS` and `SPECIAL_HIT_TICKS` constants. U-special uses raw authoritative action ticks, without ordinary-attack hero speed conversion. Visual helpers contain no damage, collision or hit generation.
- All 42 WAV hashes, 48 kHz mono PCM16 formats and durations passed. All 42 OGGs decoded with zero clipped samples. Highest OGG sample peak: −2.011 dBFS; estimated 4× true peak: −1.907 dBFS. Rebuilding audio reproduced every WAV hash and actor timing manifest.
- Audio helper tests passed once-per-cast voice, duplicate begin suppression before and after completion/cancellation, same-tick idempotence, crossing multiple cue ticks, pause/cancel, and newly created players inheriting paused state. Missing/empty/unknown authored-voice slots remain silent. Final integrated test drains the audio thread before exit and emits no leak warning.
- Existing Japanese voice metadata and new-name slots are explicitly separated. Hideyoshi `千成奇策` and Ieyasu `三河不動` recordings are missing, with null assets and silence fallback. Existing remasters do not claim to speak those new names.
- Portable source scan found no dependency on the producer's workspace or temporary directory. Asset rebuild accepts an explicit repository path. The offline font has a documented Linux default and needs an available TTF on other systems.

## Repaired during review

1. Single-frame alpha-over crossfade caused brightness pumping.
2. Demo ring flow reset while visible every 66 ticks.
3. Rotated fire tongues could clip at the original geometry boundary.
4. Optional shader multiplied warped texture by already-textured fragment COLOR; it now uses vertex tint separately.
5. Secondary particles ignored effect opacity.
6. Audio duplicate begin could repeat the same cast voice; paused new players could start unpaused.
7. Export/rebuild scripts had producer-directory assumptions, and test audio shutdown needed a brief thread drain.

## Required downstream acceptance

- Native GPU visuals, shader compilation/output, Godot 4.7.2, export and Windows/controller operation remain unverified. The optional shader's semantics were reviewed against Godot's CanvasItem documentation, not rendered on a GPU.
- Offline rendering is an illustration. It uses per-pixel CPU warp, static actor poses, and different presentation sizes/particles/timing than the native coarse mesh path. It is not gameplay footage or proof of identical pixels. A two-second offline sample was independently rebuilt and inspected.
- Raw Image loading produces Godot export warnings after import. Include original PNG/JSON files in export or use imported Texture2D resources; export is not certified by this pass.
- No subjective listening or Japanese transcription review occurred. Numerical audio checks do not establish pronunciation, emotional intensity, perceived loudness, or multi-character mix quality.
- New voice slots, final choreography, live release-origin locking, interruption/rollback lifecycle, overlapping actors, confirmed-hit sparks, camera/jump alignment, bus ducking and full battle integration still require the documented implementation and target-device checks.
- Dynamic mesh creation is a validation implementation, not a measured production performance budget.

## Evidence

Companion machine reports: `final-assets.json`, `audio-audit.json`, `handoff-freeze.json`.
Test logs: `final-editor.log`, `final-independent.log`, `final-sample.log`, `final-audio.log`, `final-standalone.log`, `final-special-scene.log`, `final-authority.log`, `audio-independent.log`, `audio-rebuild.log`, `layout-rebuild.log`, `offline-rebuild.log`.

Shader reference: https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html
