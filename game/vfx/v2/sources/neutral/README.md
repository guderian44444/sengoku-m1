# Neutral physical weapon VFX

Five generated base images support eight runtime recipes. All final PNGs are 1024 × 1024 RGBA with at least 64 px wholly transparent gutter. Generated using built-in imagegen with transparent-background enabled. The full exact prompt for each output is in `generation_prompts.json`; original outputs are in `sources/`.

These are single authored frames plus runtime procedural motion, **not frame-by-frame sprite animation**. No weapon, character, text, checkerboard, elemental aura, or baked scene is included. Use normal alpha mix, never additive glow. Off-white stroke bodies are intentionally readable; recommended runtime opacity is recorded in the manifest.

## Rebuild and validate

Run `bash layout_neutral_assets.sh`, then `python validate_neutral_assets.py` (Pillow and NumPy required for analysis). Layout uses ImageMagick Lanczos fit of the entire source to 896 × 896, centered within 1024 × 1024 transparency. No background removal, thresholding, pixel painting, recoloring, or opaque matte is applied. Validation records exact alpha bounds, gutter, partial transparency, source/final SHA-256.

## Binding and ratios

- `neutral_slash_arc`: center pivot; rotate along actual hand-to-tip angle. Brief rotation/fade. Thin physical brush path, distinct from elemental energy blade art.
- `neutral_thrust_cone`: right tip pivot (.834,.516), wide tail to left. Attach to true spear tip and rotate to thrust direction. Suggested visible width:height 1.5–3.5.
- `neutral_trail_strip`: right head pivot (.802,.504), fine fading tail to left. Rotate to projectile velocity; clamp length to prevent overly long trails. Visible width:height 8–24. Texture square does not imply square rendered trail.
- `neutral_hit_burst`: center pivot; brief physical scratches for impact; no bright center light orb.
- `neutral_dust`: ground pivot (.5,.766), grey-brown translucent dust; low opacity .25–.45.

The pivots are actual generated-art measurements, not prompt coordinates. Faint alpha speckles can extend beyond the main visible feature; do not derive the contact pivot from alpha bbox extremity.

## Eight intended recipes

1. slash: blade arc
2. thrust: spear cone
3. arrow trail: trail strip
4. throwing knife trail: trail strip with shorter lifetime/length
5. blunt hit: hit burst and optional low-opacity dust
6. slash hit: small blade arc plus hit burst
7. guard/parry: hit burst plus runtime tiny non-elemental metal sparks
8. dust: physical step/ground-contact puff

Audio is produced separately. Suggested sound duration: slash .20 s, thrust .16 s, arrow .14 s, knife .12 s, blunt .12 s, slash hit .15 s, guard .18 s, dust .24 s. Trigger once at swing/projectile launch or actual impact, never every trail update.
