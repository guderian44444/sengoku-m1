# Kennyo03 accepted base actions

Entry: integration_manifest.json. Use each action integration_frames.json for explicit layer files, timing and anchors. All53 game frames and the registered idle preserve approved pixels; original metadata/source PNGs remain for provenance. The source landmark arrays do not guarantee anatomical left/right ordering; do not sort feet by screen x to create leg identity.

Weapon angles are clockwise from the upward staff axis. Draw body, weapon, hand_occlusion in the recorded order. Released staff frames have no active grip; retain the recorded released anchor and implement pickup before restoring the grip.

Standing anatomical height is163px excluding staff. Do not scale crouched/airborne/fallen poses to a common bounding box. Source-to-game scale varies between high-resolution master sheets but is fixed within each calibrated master. Original build scripts are historical reproduction aids; they can emit old candidate labels. integration_manifest.json and acceptance.json govern acceptance, not text embedded in review GIFs.

Runtime work remains: import/atlas packing; convert canvas anchors to engine pivots; map facing and anatomical foot IDs if IK is used; configure state transitions, input, speed, jump/knockback physics, collisions and death holding. Preview offsets must not be added to world movement. No engine speed, hitbox, cancel window, integration or in-game playback validation is claimed. Visual review GIFs loop for convenience; use metadata.loop for the state machine. NoFX/noaudio.
