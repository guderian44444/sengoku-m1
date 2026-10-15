# Correct identity06 grab candidates, 2026-10-15

Only the six requested grab actions; no Git/runtime changes. This supersedes the incorrect older teal/bearded identity for this task. All character raster pixels were newly generated from reference/identity06.png: pale gray-white patterned jinbaori, navy sleeves, black/gold armor, gray pants, younger slim build and narrow moustache/chin beard. Identity SHA256: 73d95ef35bf18fb18346b902f7cbbe3b41c4a0ee9bc3798498c5c63011cc2000.

## Current outputs
- grab_start: 6 frames, 600 ms
- grab_hold: 6 frames, 600 ms
- grab_hit_1: 6 frames, 600 ms
- grab_hit_2: 6 frames, 600 ms
- throw_forward: 13 frames, 1000 ms
- throw_reverse: 12 frames, 1100 ms

The two headbutts explicitly share the user-selected second-headbutt motion, redrawn in identity06, and retain independent action keys and grab_hit_1_contact / grab_hit_2_contact events at zero-based frame 3. Their durations are independently deep-copied: [100,120,70,70,100,140] ms. They are separate user inputs, not automatic double attacks.

Body standing-equivalent scale is 152 px. Original transparent sources, full cropped character PNGs, separate sheathed-weapon and neutral-proxy layers, normal/3x slow/body-only GIFs, and contact sheets are included. Gray measurement proxy is NOT formal enemy animation. Weapons use the provided separate tachi/saya reference layers; no weapon/opponent pixels are baked into characters.

## Throw expansion and actual cause of jumping
The prior reverse sequence had a narrowed-foot right/back-facing pose followed by an upright backward-leaning raised-hand pose, then deep forward folding. The left/right foot x positions jumped from approximately 93/207 to 113/181 and back to 92/209. It also lacked the leftward loaded-shoulder and forward-pressure transitions. Its infinitely looping GIF snapped from left-facing recovery to right-facing initial grab.

Revision replaces those two unsuitable poses with actual newly drawn back-left shoulder turn and forward-loaded left shoulder poses, and adds two genuine release/recovery transitions: 10 becomes 12. Left support is locked to x=94 in the loaded/recovery phase. This is registration only, not translated copies presented as new motion. Twelve body PNG hashes are distinct. Final left-facing recovery is preserved. Normal and slow throw GIFs are ONE SHOT (no GIF loop extension); reopen to replay rather than treating opposite facings as a valid cyclic boundary.

Forward throw adds three genuinely drawn hip-turn, release-arm and recovery transitions, 10 becomes 13. Thirteen body hashes are distinct. Total duration remains 1000 ms. Reverse remains 1100 ms. Both release at zero-based frame 6, with independently moving measurement proxies afterward.

## QA performed
- Visually inspected correct identity reference, original generated sources, all registered body sheets, and final composite contact sheets.
- Isolated each source figure's connected alpha region; this removes neighboring sprite intrusions from overlapping rectangular crops.
- Checked full heads/topknots/feet, same costume and facial identity, two arms/hands, body scale and real torso turns.
- The first new reverse-transition source clipped the top-left topknot. It was repaired using image_gen into reverse_transitions_fixed.png, visually rechecked, and only the fixed version is used.
- Verified GIF encoded frame counts/durations, per-pose SHA256, and exact shared hold boundary body/weapon/proxy bytes for grab_start end, hold first/last, both headbutts first/last, and both throws first frame.
- Hand centers are visual measurements at 152 px scale, approximately +/-3 px. They are not a substitute for production enemy retargeting or physics.
- Real-time normal/slow animation playback has NOT been visually reviewed in a reachable browser. Contact-sheet review and encoded timing checks are not represented as live-playback acceptance.

## Sources and reproducibility
registration.json holds source crop rectangles and SHA256 per frame, scale/translation, root, actual measured screen-left/right feet, hand/grasp centers, frame timing, view yaw, release events and layer order. library.json maps the six current GIF identities/versions. SHA256SUMS covers the persisted files. before_throw_expansion/ retains the preceding ten-frame throw state for reproducible revision and comparison; it is not the current deliverable.

Rebuild order from this folder (Pillow, NumPy, SciPy):
1. python build.py
2. python align_boundaries.py
3. python compose.py
4. python revise_throws.py
5. python compose_expanded_throws.py
6. python finalize.py

The transition reviser deliberately uses its saved before_throw_expansion baseline, so rerunning it does not compound foot translations or reapply pose substitutions. Repeated boundary poses are explicitly declared as shared endpoints, never counted as newly generated transition artwork. No local image generation model, optical flow, or raster motion interpolation was used.
