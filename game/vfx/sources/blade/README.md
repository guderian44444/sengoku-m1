> PROVENANCE ONLY. These are authoring-stage suggestions. Final runtime paths, timings, and behavior are in ../../catalog.json and docs/HANDOFF-SHARED-VFX-V1.md. No discarded ring v1 is included.

# Shared blade-pressure VFX

Four independent reusable transparent sprites: `blade_arc.png`, `blade_ring.png`, `blade_wave.png`, `blade_hit.png`. Import settings and scene hints are in `blade_manifest.json`. Default mix/straight-alpha blend retains fine air textures; optional additive is for a small secondary glow only and can wash out the near-white core.

## Authorship and animation truth

Each asset has exactly ONE generated still image. Built-in image generation was used separately for each design, followed by one image-generation ring revision for more margin. These are base art, **not authored frame-by-frame animations**. Full generation prompts are preserved in `generation_prompts.json`. Original 1254×1254 images remain as `*_base.png`; ring v2 is selected; the discarded v1 is not shipped.

Runtime sprites are 1024×1024 RGBA. The only post-generation operation is layout: uniform 896×896 resampling of the whole source onto a centered transparent canvas, with no alpha threshold, background removal or effect painting. Outer 64px padding is truly transparent. `alpha_validation.json` verifies every outer-edge alpha is zero. Original generated low-alpha wisps/noise are retained.

## Integration

Copy the four runtime PNGs into Godot `vfx/art/`. Use the matching manifest texture paths, a single cell, columns=rows=frames=1, and normal alpha blend. All pivots and seam coordinates are normalized from the top-left. Do not trim the transparent canvas, since it defines common transform coordinates.

- Arc: 20 ticks at 60Hz, 280-unit sprite. Reveal/fade with a small sweep rotation; right-facing, mirror X for left. Never describe this transform as hand-authored frames.
- Ring: 30 ticks, 420-unit sprite. Back and front must use the SAME source texture and transform. Split UV y at 0.5335, back above, front below, with complementary masks. Actor pivot `[0.5, 0.5335]`. This is the ring's actual side-turn seam, not the canvas midpoint. Gentle elliptical UV flow is a procedural demonstration.
- Wave: 32 ticks, 340-unit sprite, origin near its lower launch point `[0.5, 0.80]`. May rise and travel right; mirror X for left. Keep the base and tail below its advancing crest.
- Hit: 14 ticks, 190-unit sprite, pivot on flash core `[0.5, 0.548]`. Quick growth and decay. Do not maintain a static impact indefinitely.

Every effect is one-shot. No seamless loop is claimed. Runtime animation, actor occlusion and gameplay timing are owned by the shared VFX integration, not baked into these still textures. The blade family is pale blue-white compressed air with filament texture: no ice crystals, snow or fire tongues.
