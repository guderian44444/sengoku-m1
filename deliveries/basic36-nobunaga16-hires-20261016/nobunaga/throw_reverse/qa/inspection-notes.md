# Visual inspection and limits

All 16 original native images were inspected in labeled weapon/grip close-ups. All four extracted-layer contact sheets were inspected. Additional enlarged extracted-layer checks covered the initial grip, partial torso occlusion, hand/handle boundaries, blade crossing black trousers, and final two-hand guard.

- 000–003: blade, guard and visible handle separated; source edge antialiasing and darker uncertain contact outlines remain unchanged.
- 004: the source contains a thin dark diagonal artifact near the blade. It is not repainted or treated as confirmed sword geometry.
- 005: torso hides part of the sword. The hilt/guard and visible blade are separate fragments. The dark metallic blade is segmented using a broader color tolerance than other frames; hidden connecting pixels remain unavailable.
- 006–008: throwing hand stays in body. Only the hand gripping the sword is the foreground hand layer.
- 009–010: the open dark gaps at finger/hilt contact are inherited source pixels. Separate bright blade-edge components are retained and the interior between edges is filled as pixel ownership, without painting pixels.
- 011: the sword passes over dark trousers. A stricter bright-edge envelope prevents large trouser patches from being classified as blade. Interior sword pixels are assigned between the observed edges.
- 012–015: both gripping hands are foreground. Existing source artifacts around the blade replacement remain in their original pixels. Frame 014's nearby face/ear is excluded from the guard envelope. Frame 015's blade tip is clipped by the original top edge.

The masks are a conservative, manually reviewed segmentation, not a complete semantic redraw. Some mixed-color/dark contour pixels, small costume-edge spill, and contact-edge ambiguity remain. The weapon is visible-only and cannot safely be moved independently. The body also contains the corresponding holes. Use the approved composites for runtime-authoritative animation, or use all three layers at identity transforms with exact alignment.

Pixel equality has a separate, strict meaning: every source RGBA byte is recovered by the documented recomposition order. It proves preservation of the approved composite, not perfect segmentation or new animation capability.
