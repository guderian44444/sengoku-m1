# Reverse throw: approved-composite visible layers

The 16 approved 1800 × 1700 straight-RGBA frames remain unchanged. Each frame is 50 ms; total duration is 800 ms. No pose, placement, alignment, camera scale, feet, or runtime/site contract was changed.

## Files

- `layers/body/000.png`–`015.png`: character, costume, scabbard, throwing/non-gripping hand, and every remaining source pixel
- `layers/weapon-visible/000.png`–`015.png`: visible sword pixels only
- `layers/hand-foreground/000.png`–`015.png`: visible gripping-hand foreground pixels, including both gripping hands in the final guard
- `masks/{layer}/`: matching binary pixel-ownership masks
- `frame-manifest.json`: source hashes, exact inherited palm centers/root/sole contacts, hand-authored blade base/tip measurements and angle conventions, identity transforms, paths, hashes and durations
- `layer-manifest.json`: layer order, scope and important limitations
- `validation.json`: per-frame exact RGBA recomposition tests
- `verify_layers.py` and `independent-verification.json`: separate verification of source hashes, layer hashes, exact RGBA, disjoint ownership and unchanged landmark/transform metadata
- `qa/`: approved/recomposed frames, ownership maps, layer contact sheets, and native close-ups
- `segmentation-annotations.json`: inspectable native-coordinate mask envelopes
- `build_layers.py`: deterministic extraction and verification; reads approved sources without modifying them

## Compositing and geometry

1. Start with the `body` RGBA image.
2. Source-over `weapon-visible` at (0, 0).
3. Source-over `hand-foreground` at (0, 0).

Use identity transforms and the same 1800 × 1700 canvas. Never independently normalize, re-register, move, or scale these extracted layers. Original source pixel RGBA values are copied verbatim, including anti-aliasing. Binary pixel ownership means there is no alpha overlap between visible layers.

Starting from the body image also retains the source's invisible RGB bytes beneath alpha=0. Compositing all layers onto an initially empty canvas is visually identical but some compositors discard those irrelevant hidden RGB bytes; the strict four-channel test initializes with body.

## Important limits

This is a reviewable visible-pixel partition, not a complete layered redraw. Hidden body and sword pixels are unavailable and are not fabricated. The body contains holes where visible sword and gripping hands were extracted. The weapon is not an independently movable complete sword asset. Moving a layer can expose those holes and mixed-color edge pixels already present in the flattened source.

Manual native-image polygon envelopes are snapped to actual low-chroma blade and warm skin pixels; guard and handle regions are traced manually. Boundary classification is approximate, especially at dark contact edges. Exact recomposition proves unchanged approved appearance; it does not establish perfect semantic separation. Remaining uncertain edge pixels are retained with the source rather than repainted.

Frame 005 has a partly torso-hidden sword: visible hilt/guard and visible blade are separate fragments. Frame 015's blade reaches the top of the canvas; a complete tip is not available. The visible-tip angle is a curved-blade chord and is advisory. Existing source-art artifacts are retained, including some recovery-frame blade-removal remnants. Scabbard, costume fittings and unclassified artifacts stay with body.

Palm coordinates are inherited manual anatomical landmarks, not calibrated runtime sockets. No hitbox, hurtbox, collision, event, victim attachment, or gameplay movement track is supplied or altered.

## Rebuild

With Python, Pillow, NumPy and SciPy installed:

`python build_layers.py --source /path/to/throw_reverse_planted_v2`

The source must contain its original `frame-manifest.json` and `frames-native/000.png`–`015.png`. Every source SHA-256 is checked against the frozen original manifest before extraction. The rebuild writes only inside this package. `author_annotations.py` records the manually inspected coordinates and can recreate the annotation JSON; do not run it after hand-editing that JSON unless intentionally restoring those coordinates.
