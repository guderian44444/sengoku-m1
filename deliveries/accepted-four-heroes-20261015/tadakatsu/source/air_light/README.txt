TADAKATSU 08 AIR LIGHT v5 — Forward thrust, 12 unique poses, 720 ms

LATEST USER OVERRIDE
Message Sentinel_fcf9acb655148191b5ba708f50b698c3: 「這招應該從握持到前戳就可以了，不用把槍頭轉到後面」.
This explicitly supersedes the earlier air-light sweep/body-turn instructions and the older generic character specification. Current sequence is forward guard -> direct forward thrust -> withdrawal and airborne descent. The spear tip remains forward-right throughout. No back-facing coil or rotational sweep remains.

DELIVERABLES
normal.gif: 12 frames / 720 ms. slow.gif: 2160 ms. contact.png: 4 columns x 3 rows.
frames-manifest.json: website-ready relative PNG paths, exact per-frame duration/start time, canvas dimensions, root, hands, weapon tip, events and all compositing layers. Consume composite/00.png through composite/11.png directly for a transparent-frame web preview; resolve paths relative to this directory. The manifest sets loop=false because this is a single attack, while the review GIF loops for convenience.
config.json and metadata.json: latest override, timing, source extraction/scale, grip registration and approximate preview event. QA.json: checks and limitations. FILES.json: complete file listing with hashes.

ARTWORK AND SCALE
All 12 character poses are newly drawn by the cloud image-generation tool, saved as source-A.png and source-B.png (six each). Exact prompts and original identity/forward-grip reference are included. Each sheet uses the same fixed .43 scale, matched to existing helmet/chest size; no per-frame bbox scaling, mirrored/reversed sequence or optical-flow interpolation.
Canvas640x340, floor reference y296. Airborne root progresses from(300,180), through apex near(316,148), to(344,200). Lowest foot pixels by frame:247,238,227,219,217,220,216,225,234,258,269,284. Every foot stays above the floor.
Each sprite is extracted by its own connected alpha component rather than by fixed grid cell, preventing neighboring sprite fragments and edge cuts. Complete capes, hands, boots and antlers are preserved.

WEAPON AND HANDS
Approved spear_suyari.png is an independent complete285px weapon at fixed scale and width. No perspective shortening is applied. Its tip stays right of both hands in all12 frames. Anatomical right hand is the rear grip, anatomical left the forward grip. Both gloves follow the fitted magenta guide axis; the temporary guide is removed and glove occlusion sits over the registered official spear. Primary weapon source grip is[188,740].
Layers: character, weapon_back(empty for this action), weapon_front, hand_occlusion, composite. These are whole-body image poses, not articulated limb sprites.

REBUILD
python build.py
python validate.py
Requires Python, Pillow, NumPy, SciPy. Essential build inputs: source-A.png, source-B.png, spear_suyari.png and build.py. No parent directory or network/model call is needed for rebuilding. All generated frame PNGs, JSON and previews are recreated locally.

LIMITS
Sources and contact sheet visually inspected; timing/frame order and exact285px weapon transform checked programmatically. Live animated playback was not independently watched. No opponent sprite, collision, damage/range or game-runtime test. The contact event is an estimated preview marker, not a verified collision. Tiny guide-overlap pixels beneath the weapon are masked, not separately repainted. No Git/runtime changes were made; other actions and old versions remain untouched.
