HONDA TADAKATSU: NEW-SPEC GRAB AND THROW ACTIONS

6 actions, 48 distinct generated keyframes. Cloud-generated from the approved v22 identity; no game files, repository, runtime or local image model changed.

grab_start: 6 frames / 0.64s
grab_hold: 6 frames / 0.90s
grab_hit_1: 9 frames / 0.78s
grab_hit_2: 9 frames / 0.80s
throw_forward: 9 frames / 0.88s
throw_reverse: 9 frames / 0.92s

Each action directory contains a normal-speed GIF, a 3x slower GIF, a contact sheet, a transparent character sprite sheet, per-frame transparent character/weapon_back/composite PNGs, isolated original-resolution source crops, generation prompt and metadata. Full original generated RGBA sheets are at package root. The first rejected clipped attempt is excluded from the ZIP.

PROCESS
Connected-character alpha masks, not rectangular grid cuts, isolate each pose. Only 2px edge dilation is used to preserve antialiasing. A fixed scale is applied across each generated source sheet, chosen by approved helmet/antler landmarks and chest-scale comparison rather than pose bounding boxes. The supporting boot is measured again AFTER resize. The reverse throw uses an explicit horizontal boot track to prevent the lowest-pixel detector from switching between boots during rotation. Every contact-sheet pose was visually checked. Normal and slow GIF sequences were decoded to verify unique keyframes, order and exact timing. The same palette is used across every GIF frame. No optical flow, frame reversal, generated in-betweens or pose warping.

LAYERS AND EVENTS
The spear is the verified complete suyari asset, cleaned by its own alpha contour and composited behind the character. It is stowed, never impales a grabbed target. Reverse-throw spear angle progresses with the body turn. Per-frame glove contacts are manual visual estimates. Knee events are independent. Forward throw opens its hands at frame 6; reverse throw opens at frame 7. Reverse poses are new front/side/back/opposite-side drawings, never mirrored or reversed frontthrow poses. Thrown-target collisions and landing belong to the downstream target simulation.

KNOWN LIMITS
The character pose is one transparent layer, not a per-limb articulated rig. Generated costume microdetail and apparent volume can vary slightly between poses. No victim is baked in; glove contact coordinates require matching to the game's victim rig. Preview loops restart actions; runtime transitions, collision tests and in-game playback have not been performed. Live cloud-browser playback of the local review page was blocked by the browser's allowed-URL-protocol policy; all poses and decoded timing were checked instead.

REBUILD
Python 3 with Pillow, numpy and scipy is required. Run build_grabs.py ACTION SOURCE --durations comma-separated-ms --events JSON. Then run finalize_pack.py to add visual contact annotations, validate outputs. The parent creates the final combined package. The verified reference character and spear are included in references/. Review.html shows normal and slow previews side-by-side when opened locally.

CANONICAL GAME-SCALE REVISION
All main previews and per-frame layers are now 640x340 with floor y=296, the same body160/approximately200px including-antlers scale as the main action pack. Complete spear length is 270px. Fixed source-sheet factors: grab_start .410, grab_hold .440, grab_hit_1 .500, grab_hit_2 .500, throw_forward .490, throw_reverse .535. Metadata stores the measured identity head reference and per-sheet landmarks. canonical-scale-comparison.png visually compares the main light_1 reference, all six grabs, and air_light v2. Original generated source sheets are unchanged. Previously uploaded standalone GIF IDs still refer to the earlier large review previews; use current local GIFs for the final combined delivery.
