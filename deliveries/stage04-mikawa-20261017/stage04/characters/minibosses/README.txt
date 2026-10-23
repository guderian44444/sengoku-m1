Stage 4 miniboss motion review v1 — 2026-10-17

CONTENTS
104 authored character animation frames: 52 Tominaga and 52 Kira.
Each character: three 8-frame combat/command sequences; 4-frame walk; 4-frame retreat/withdrawal; 8-frame knockdown/recovery; 4-frame idle; 4-frame hurt; 4-frame stunned.
8 separate VFX frames: four sweep stages, two arrow streak stages, wood impact and settling debris.

Unzip all three archives into the same folder. Files are non-overlapping:
01-tominaga: six character atlases.
02-kira: six character atlases.
03-shared: current manifest, eight-frame VFX atlas, canonical crest masters, prompt records and this README.
The standalone MP4 plays actual authored frames, preserving their proposed timing. There is no optical flow or fabricated in-between motion. Preview backgrounds and captions are review presentation only.

The manifest provides source windows, ground anchors, crest anchors/visibility, per-frame durations, attack and voice cues, fatigue/open-combo windows, independent VFX mapping, and Kira escort event requirements. All timing and hit windows are proposed tuning. No collision, AI, spawning, damage or other game runtime is implemented. Audio is provided separately by the voice task, not included in this silent review video.

CREST / EQUIPMENT
Canonical Kira ring with two horizontal bars is supplied unmodified as an external SVG layer and official PNG. Review playback overlays that exact master at chest anchors, hidden where back-facing or obscured. Tominaga carries Kira allegiance heraldry, not an asserted personal family mon. Tominaga uses odachi; Kira retains yumi and waist katana. Source art has no accepted AI-redrawn mon. Composite the exact supplied crest using frame metadata when importing into an engine.

KIRA ESCORT REQUIREMENTS
Six archers enter with Kira, follow him, continuously shoot the player, and replace one for each death. The command gesture is a visual cue, not a condition that stops continuous shooting. Slot refill should be one-for-one and deduplicated. Replacement delay, entry position, firing stagger and stop-on-defeat tuning remain unconfirmed. This package documents events; it does not implement escort runtime or contain six separately designed escort characters.

KNOWN REVIEW LIMITATIONS
This is authored-pose review v1, not polished runtime animation. Fine hand grip, bow-string continuity, exact chest/cloth occlusion and cross-action scale consistency still need animation cleanup. Variable-width source windows preserve extended swords in combat strips. Supporting pose crops and crest anchors are review registration rather than pixel-perfect production masks. No weapon disappears in the reviewed sequences, but minor peripheral clipping/pose discontinuity may remain. Validate the final engine render before shipping.

PROVENANCE
All character and VFX art produced with built-in image_gen using approved individual character reference PNGs. Code only assembles/re-times authored frames, applies the supplied canonical badge and packages assets; it does not synthesize intermediate character motion. No Git, website deployment or runtime integration performed.
