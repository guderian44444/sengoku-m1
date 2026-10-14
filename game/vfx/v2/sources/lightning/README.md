# Lightning VFX bases

Generated with the built-in imagegen tool on 2026-10-13. Four independent single-frame textures: `lightning_arc.png`, `lightning_ring.png`, `lightning_wave.png`, `lightning_hit.png`. Each is 1024x1024 genuine RGBA with a verified empty outer 64px gutter. This is not a multi-frame authored animation library.

Original 1254x1254 outputs are retained as `*_source.png`; the denser first ring attempt is retained separately as `lightning_ring_rejected_dense_source.png`. Accepted prompts are in `generation_prompts_accepted.json`; the first ring prompt is in `generation_prompts.json`.

Run `python rebuild_layout.py` to reproduce the uniform Lanczos resize/transparent padding and validation JSON. The script only changes layout; no alpha extraction, recoloring, effect painting, or background removal was applied.

Use `lightning_manifest.json` for frame count, pivot, seam, scalar world sizes, bounds, blend and ring flow metrics. The ring is designed for back/front splitting at normalized y=0.5. Radius values are visual estimates of the electrical centerline, not a physical calibration. `render_padding=0.30` is an initial integration setting and requires runtime QA against the actual UV/mesh deformation.

Branching white-core violet/cobalt bolts distinguish this family from smooth wind arcs, flame tongues, and ice shards. The generated glow is wider than the prompt requested, so the bases retain a baked violet-blue halo; this limitation is explicit rather than presented as exact line-only art. Use local short sparks and low-amplitude pulses; do not drive high-frequency whole-screen flashes. Texture alpha maxima are 254; this is genuine alpha, not a painted checkerboard. Near-transparent generated specks explain why alpha>0 bounds extend much further than visually significant alpha>=16 bounds.

Visual QA: ring accepted by the integrating worker. Arc, wave and hit visually inspected for distinct silhouette and electric branches. Engine integration and runtime boundary checks belong to the v2 integrator; no engine code, repository commits or pushes were performed here.
