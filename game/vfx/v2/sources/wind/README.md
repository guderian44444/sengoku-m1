# Shared wind VFX bases

Four independent original generated RGBA sprites: `wind_arc.png`, `wind_ring.png`, `wind_wave.png`, `wind_hit.png`. Each final texture is 1024 × 1024, with at least 64 fully transparent pixels on every side. Generation used the built-in imagegen tool, one image per call; ring was inspected first before the remaining three were generated. No third-party images were used. Prompts are retained in `generation_prompts.json`; untouched 1254 × 1254 generated sources are `*_source.png`.

## Visual language

Gray-white / subdued celadon air veils, slender filaments, curling turbulence, and sparse neutral dust. Arc is an open sweeping curved gust; ring is a low elliptical vortex with an empty center; wave is a tubular gust traveling right; hit is a compact spiraling pressure puff. These are deliberately distinct from saturated blue-white blade energy and crystalline ice. Some motes are softly modeled dust rather than leaves. Alpha is mostly translucent, so use mix/straight-alpha and evaluate against both dark and light gameplay backgrounds; additive blending will erase subtle gray veils.

## Rebuild

Run `python layout_wind_assets.py` with Pillow and NumPy. It fits the complete source within 896 × 896 using uniform Lanczos scaling and centers it on a transparent 1024 × 1024 canvas. It does not remove backgrounds, threshold alpha, paint/reconstruct effects, recolor, or crop source pixels. It regenerates the manifest and alpha validation report. Source and final hashes are recorded.

## Runtime contract and limitations

- `frames=1` and `frame_count=1`: these are single base textures, not an authored frame sequence, atlas, or seamless loop. Temporal motion must be supplied by the runtime UV/mesh/particle system.
- V2 texture paths target `res://vfx/v2/art/wind_*.png`; world_size is scalar. Pivot and seam use final-texture normalized top-left coordinates. Ring pivot/flow_center is `[0.5, 0.51]`, seam 0.51; flow_radius `[0.39, 0.17]` is a visual ellipse centerline estimate, not an alpha bounding box. The ring front/back split is an approximation, not volumetric occlusion data.
- `render_padding=0.3` is an initial runtime value requested by the integrator, not a claim that every UV warp is safe. The final integration must validate padding according to its actual shader convention. The baked 64-pixel gutters alone do not guarantee rotation safety.
- All nonzero-alpha pixels, including extremely faint scattered dust, are included in bounds and rotation measurements. The ring's elliptical metric rotation needs up to about 2.193 total canvas scale if preserving every nonzero pixel plus a 64-pixel-equivalent margin. Its ordinary Euclidean rotation requires about 1.262 total scale. These are analytic support bounds, not a substitute for testing the actual runtime shader at all angles. See `alpha_validation.json` for other textures and precise values.
- Clamp samples outside the source UV domain to transparent; do not repeat the texture. Mesh scale/UV overscan must keep the texture-space pivot stable during growth. No runtime code was modified here.

## Provenance

All four source images were generated specifically for this task on 2026-10-13 with the built-in imagegen tool from the saved prompts, with transparent_background=true and no reference artwork. This statement documents provenance and does not imply an independently reviewed legal warranty. Original sources and prompt records are retained alongside the deliverables.
