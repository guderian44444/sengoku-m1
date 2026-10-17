MIKAWA RETURN / 三河歸途 — initial core prop pack

17 separate transparent PNG assets: wooden barricade, chevaux-de-frise, supply cart, crate and barrel each in intact/damaged/broken states, plus shared debris and muddy ground overlay.

Use sprites/ for placement. Each is 1664 x 1536, anchor (832,1000), translation-only registered, no individual rescaling. Preserve that scale across state changes. Choose one uniform family scale in game. raw/ retains 1536 x 1024 imagegen originals. manifest.json includes offsets, alpha bounds and SHA256.

All artwork generated with built-in image_gen and true transparent_background=true. Alpha retained, not color-keyed. Visual review on gray-blue composite showed no background rectangle or obvious fringe. Alpha range is 0..254 as generated. No claim of runtime acceptance: transitions, collisions and scale against live characters remain untested. Damaged geometry is recognizable but not pixel-identical to intact. Ground anchor is lower solid-alpha bound, not a physics collider.

Contact rows: barricade / chevaux-de-frise / supply cart. Columns: intact / damaged / broken.

Reference: existing camp-environments-v1.png, stage3 art. Cool overcast key, dark wet wood, hemp rope, umber mud. No people, concealed enemies, decorative ground baked into interactive props.

Crate/barrel follow-on states are included.
