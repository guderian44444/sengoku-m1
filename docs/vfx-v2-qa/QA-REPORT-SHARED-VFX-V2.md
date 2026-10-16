# Shared VFX v2: independent QA

Date: 2026-10-13. This report covers the incremental five-element lifecycle, hero/enemy matchlock effects, neutral weapon effects, and effect-bound SFX.

## Verdict

**PASS for asset integrity, reproducibility, offline inspection and headless logic. No publication blocker remains in this tested scope.** No native GPU, target-device performance, full battle integration or subjective listening approval is implied.

## Verified scope

- 28 transparent single-frame bases: 13 unchanged v1, eight wind/lightning, two shared matchlock bases, five neutral bases. All manifest dimensions/SHA256/true and partial alpha passed. The eight neutral recipes intentionally reuse five bases; these are not eight distinct artworks or authored flipbooks.
- All 15 new layouts rebuilt pixel-identically from included source images using the documented Pillow/ImageMagick layout operations. Wind/lightning and neutral retain their original alpha through layout. Matchlock crops remove only alpha ≤ 1/255 outside the retained region, about 0.0033% and 0.0037% of source alpha mass; no visible core was clipped.
- Ring boundary sweeps use 361 angles and the configured overscan. Fire's maximum boundary alpha is 1/255, blade 5/255, wind 0/255 and lightning 1/255. These are CPU sampling/math checks, not native-renderer screenshots.
- 25 recipes resolve every layer, impact and audio reference: five families × three lifecycle recipes, two matchlock recipes, eight neutral recipes. No dangling asset or audio key was found.
- Growing spins increase radius from 0.55 to 1.15 to 1.8 over 72 ticks; blade/fire/wind/lightning complete two temporal revolutions. Ice retains rigid crystal art and is accurately labeled a growing ice ring, not a rotating 720° base. Dissipate starts at the same radius/alpha. UV angular integration is analytical and now carries an offset across phases. Holding beyond a charge duration does not restart the phase.
- Trigger/release/confirmed-hit/cancel use simulation ticks, with explicit duplicate-ID/event rejection. Same-tick repeats do not replay cues. Older ticks are rejected; rewinding requires reset or a new generation, not silent clock reversal. One-shots more than six simulation ticks late are suppressed rather than burst-replayed after a large jump; the near-phase-end large-jump edge case was tested.
- Future confirmed hits advance the visual clock first; duplicate/older hits are rejected. Charge cannot invent a hit. Visual growth never modifies battle reach, collision or damage.
- Actual Node2D draw callbacks exercised every recipe in rear/front passes and mirrored orientation without emitting any audio. Binding the same audio controller twice is idempotent. Pause affects existing/new audio players; cancelling active or retired instances stops their remaining tails. Scene reset clears active/retired/shot/contact/projectile dedup state and audio.
- Muzzle-anchor math passed facing, body scale, body rotation, camera offset and jumping z cases. Matchlock triggers require a unique authoritative shot event; input press/reload alone, duplicate shot IDs and confirmed-hit events do not fire another shot. Hero/enemy recipes have separate audio keys and effect size/particle/smoke settings. Muzzle flash lasts six ticks; hero/enemy smoke lasts 36/18 additional ticks.
- Weapon bindings passed hand-to-tip slash angle, spear tip binding, world-facing velocity rotation, zero-speed hidden trails and velocity-derived tail length. Trails can remain visible for 600 ticks without replaying their one-shot whoosh. Impact/guard recipes require deduplicated confirmed contact; projectile recipes require unique spawn IDs. Element overlays are separate instances and can retain the neutral physical mark with per-layer audio attenuation.
- All 41 new WAV hashes/formats/durations and 41 OGG decodes passed with no clipped samples. Rebuilding the five-family → matchlock → neutral audio chain reproduced every WAV hash. The 24 matchlock stems sum to their eight mixes within three PCM16 LSBs. Highest OGG sample peak is −6.659 dBFS; estimated 4× true peak is −6.033 dBFS.
- Five charge-loop boundaries had no exceptional wrap discontinuity: boundary steps were below each file's 99th-percentile ordinary adjacent-sample difference. This numerical test does not replace listening.
- Audio stress passed 100 cue requests, a ten-enemy volley, global 12-player/per-instance five-player caps, paused spawning, exact −6 dB voice duck, −12 dB distance attenuation, enemy −3 dB relative gain and −6 dB layered attenuation. Natural completion stops loops, preserves short tails, then clears contexts. Cancellation/reset stops them immediately. The cap reclaims active players; it is not a preallocated object pool.
- All three v2 scenes ran for 600 fixed simulation frames with no script errors. The v1 sampler and six-character audio regression tests passed. Fifty nonempty five-family native/offline cue ticks, keys and operations matched exactly; sample-level mixing was not asserted identical.
- All 164 frozen v1 files remained byte-identical. No existing battle/core/render/audio mapping was changed by this incremental handoff.

## Issues repaired during review

- Confirmed-hit clock ordering and cancellation of tails after natural visual completion.
- Missing native support for audio `finish` lifecycle and cleanup after the final tail.
- Mid-phase sound cues resetting audio progress/intensity to phase-start values.
- UV phase offset continuity and suppression of stale cues, including a cue near the end of a skipped phase.
- Integrated audio test retaining standalone-root resource paths.
- An off-by-one loop-stop timestamp in exported cue metadata, and a generic "two turns" label incorrectly applied to the rigid ice ring.
- Missing neutral/matchlock raw source subdirectories and a matchlock layout script depending on the producer's workspace. Portable replay now passes independently.

## Limits and downstream work

- Tested engine: Godot 4.6.3 headless. No DISPLAY/native GPU pixels, Godot 4.7.2, Windows/controller/export or FPS acceptance was performed. Headless drawing callbacks validate execution, not appearance.
- Raw Image loading retains the documented export warning: ship original PNG/JSON or switch to imported Texture2D resources before export acceptance.
- Offline videos use software compositing and presentation audio gain. They are demonstrations, not captured gameplay or pixel-identical native rendering. Character/weapon anchor and overlap quality still needs target-game inspection.
- Lightning modulation is small/localized in the implementation; there is no full-screen flash pass. This is not a photosensitivity certification.
- No Japanese transcription or subjective listening review occurred. Existing v1 Japanese remasters stay unchanged; missing new-name voice slots remain missing/silent for the later voice handoff.
- Gun power, projectile/reload rules, penetration, hitboxes, damage and character behavior are unchanged. Game integration must supply measured anchors and authoritative unique events, lock release origins where appropriate, cancel removed projectiles, and reset scene-level dedup records.
- Scalar curves and shader/mesh quality, sound-stop clicks, overlapping game music/voices, multiple players, and performance require native visual/listening acceptance. Single-file headroom and bounded SFX players do not certify the entire game's mix.

## Evidence files

`final-assets.json`, `audio-audit.json`, `loop-boundaries.json`, `matchlock-stems.json`, `test_independent_emitter.log`, `test_weapons.log`, `test_integrated.log`, `audio-independent.log`, `audio-test.log`, `integrated-audio-test.log`, `verify_v2.log`, `rebuild_v2_layout.log`, `editor-import.log`, `event-parity.json`, `preview-media.json`, and scene smoke logs.

## Final freeze

Final candidate `v2-final-candidate-20261013`: all 204 incremental file hashes match the supplied freeze manifest; all 164 v1 file hashes remain unchanged. The frozen package was copied to a clean repository, built as a fresh standalone project, editor-imported, and retested. Seven headless tests and all three scenes (600 fixed frames each) exited zero with no script errors. All 15 new source layouts rebuilt pixel-identically again. Final frozen PNG/audio checks passed. Ice preview labeling was checked after correction.

Freeze manifest: `handoff-v2-freeze.json`. Final logs use the `final-` prefix. Raw-image export warnings remain the documented, non-certified export limitation.
