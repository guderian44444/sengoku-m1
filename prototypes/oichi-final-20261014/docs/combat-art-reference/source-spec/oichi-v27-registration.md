# Oichi original-approved production: registration contract

Production ID: `oichi-original-approved-20261013`. This production follows the
original approved Oichi identity, long ponytail, costume and painted texture.
The rejected earlier v27 artwork is not its identity reference or color target.
The technical `v27` identifier is retained for source compatibility.

This revision replaces only Oichi's body artwork. The weapon catalog, weapon art,
other heroes, combat timings, and v22/v23/v26 historical assets remain untouched.
Runtime animations retain the `v22_` key prefix and `source: v22` because those
identify the established six-frame layering contract. `source_version: v27`,
`source_file`, and `source_rect` identify the actual new artwork. The HUD portrait
uses the same active source folder as the body renderer.

## Inputs

- Exactly 26 canonical final RGB-graded RGBA PNGs named after `CLIPS` in
  `scripts/register-oichi-v27.py`, mapping to six distinct runtime frames each.
- The default layout is 3 columns × 2 rows. Canonical sources require at least
  1,000,000 total pixels, rather than a fixed minimum on each image dimension.
  A native 1774 × 887 sheet is valid when all six `source_region` rectangles
  are explicitly measured; dimensions need not divide into a uniform grid.
  Smaller one-figure override files are also supported. Actual file counts,
  override names and split-sheet layouts are recorded in the manifest, not
  assumed from an earlier production.
- Each full figure must remain isolated. When art crosses nominal cell seams,
  explicitly author a larger `source_region` and, where necessary, reviewed
  metadata-only clipping geometry to exclude a neighboring figure.
- `pose-anchors.json` contains **manually measured full-sheet pixel coordinates**.
  The registration script never guesses feet, hands, anatomical size, or angles.
- Image generation authors the poses. Before registration, approved deterministic
  RGB curves/levels grade the raw sources to the original-approved color target.
  This intentionally changes RGB; raw and final RGBA/PNG hashes must not be
  described as identical. Native alpha, dimensions, geometry and texture locations
  remain unchanged and must be verified by the separate grading workflow.
- Registration preserves the FINAL graded PNG bytes and decoded RGBA. Runtime
  transformations are lossless rectangular extraction, transparent two-pixel
  texture padding, reviewed renderer polygon clipping when needed, and the
  existing world-scale transform. There is no runtime palette filter, source-alpha
  cleanup, garment patch, warp, blur or synthesized replacement pixel. Exact
  source crops remain unmodified in textures, including pixels outside a clipping
  polygon.

## Authoring commands

```sh
python scripts/register-oichi-v27.py --source-dir /absolute/generated/sources --measure
python scripts/register-oichi-v27.py --source-dir /absolute/generated/sources \
  --init-poses /absolute/generated/pose-anchors.json
```

The template intentionally leaves measurements blank. Alpha bounds are provided
only as review information and never copied into anatomical or hand metadata.
For a non-grid source, the template records its hash but leaves every rectangle
for manual authoring. `--measure` on such a source requires `--poses` containing
explicit frame regions; a uniform grid is never silently inferred.
For irregular native sources, rerun `--measure --poses <measured-anchors.json>`
to inspect the actual six runtime rectangles and file overrides. A clip-level
`source_figure_count: 3` describes the canonical half of the split run source;
runtime frame count remains six.
Fill each clip's `body_height` and `anatomical_measurement`. The former is the
equivalent standing anatomical head-to-sole ruler at that source's drawn scale.
The latter describes the actual visible ruler/reference used. For a bent, prone,
or airborne pose, measure anatomy (for example body segments or an appropriate
standing reference at the same drawn scale), not the image's axis-aligned height.
Use a frame-level `body_height` override when native figure scale genuinely varies.
Each clip's `source_sha256` binds measurements to the exact FINAL graded PNG.
Regeneration requires new measurements. A verified RGB-only grade preserves
anchor coordinates, but all source hashes must be rebound to the final bytes
and raw-to-final alpha/dimension equality must be recorded.

Each clip has six `frames` with:

- `file` and `source_sha256` (optional together): alternate final graded PNG for this
  particular frame, such as a separately generated replacement for the last
  prone pose. A replacement requires its own explicit `source_region` and
  `body_height`; it need not be a 3 × 2 sheet or use the sheet dimensions. The
  canonical sheet remains recorded, while this frame's final PNG and unchanged
  registered crop hashes point to the replacement. The registration `sources`
  dictionary lists every FINAL source file to package. Raw sources and grading
  inputs are recorded separately in `provenance`.
- `source_region: [x,y,w,h]` (optional): manually inspected isolated source
  rectangle when a pose crosses nominal 3 × 2 cell boundaries. Defaults to its
  equal grid cell only when source dimensions divide exactly by 3 × 2. Explicit
  regions bypass that default for non-grid sources. The crop contains every
  nonzero native-alpha pixel in this region. Body pixels (alpha > 32) touching
  the boundary are rejected;
  faint native alpha noise is left unchanged. Check disconnected details and
  neighboring-figure exclusion visually, especially in irregular rectangles.
- `clip_component` (optional): reviewed row-major figure index used to generate
  metadata-only isolation geometry when an expanded rectangle contains another
  pose. `component_count` declares 1, 3 or 6 native figures (default 6). The
  contour is validated to retain every selected core pixel (alpha > 32) and
  exclude every neighboring major component. It never modifies the native PNG
  or cropped texture. Inspect disconnected details and soft edges separately.
  A manually authored `clip_polygon` can be supplied instead.
- `foot: [x,y]`: measured support/root point. A jump may use a virtual support
  point inside its cell; empty pixels are included so the anchor is not clipped.
- `hand: [x,y]`: left bow-grip point for archery, or body stow point for a bow
  carried behind. It must be on opaque source body pixels.
- `weapon_angle`: degrees in the existing renderer convention, clockwise from
  the upright bow artwork. This is authored from the pose, not guessed from a box.
- `weapon_behind`, `weapon_visible`: explicit booleans.
- `second_hand: [x,y]` (optional): string-draw hand, present only while pulling the
  bowstring. Do not set for a two-handed bash/guard merely to indicate its hand:
  the renderer uses this field to bend the bowstring to that location.
- `hand_occluders: [[x,y,w,h], ...]`: measured source regions to redraw over a
  front-layer bow. Required for visible front-layer weapons. Keep them tight
  around the actual hand, not an arbitrary rectangle covering the whole arm.

Also measure `portrait: {file: "idle.png", rect: [x,y,w,h]}` from a new source.
The schema root is:

```json
{
  "schema_version": 1,
  "version": "v27",
  "hero": "oichi",
  "production_id": "oichi-original-approved-20261013",
  "provenance": {},
  "grid": [3, 2],
  "coordinate_space": "full_sheet_pixels",
  "portrait": {"file": "idle.png", "rect": [0, 0, 1, 1]},
  "clips": {}
}
```

The example is a schema illustration, not usable measurement or grading data.

## Grading provenance

The builder requires the exact production ID above and a `provenance` dictionary,
and copies both into registration. Final-art acceptance requires nonempty
provenance. For every canonical or override source, retain the raw imagegen file,
raw PNG/RGBA/alpha hashes and dimensions; the final graded file and corresponding
hashes/dimensions; the exact grading profile and implementation with their hashes;
and the observed alpha/dimension equality checks. Use reproducible relative paths
in the delivered records. Keep the original-approved master and its measured
material mask; a brown background must not enter skin/material measurements.

Reapply each deterministic profile to its raw source and compare final decoded
RGBA byte-for-byte. Alpha equality must be proved against raw source pixels, not
merely asserted by a descriptive label. The registration builder verifies final
source hashes, crop hashes and unchanged copied bytes. It preserves the supplied
provenance record but does not independently execute grading or validate raw files;
those checks belong to the grading workflow and its retained verification output.

## Build, activate, verify

```sh
python scripts/register-oichi-v27.py --source-dir /absolute/generated/sources \
  --poses /absolute/generated/pose-anchors.json
python scripts/register-oichi-v27.py --check
python scripts/test-oichi-v27.py
GODOT_BIN=/usr/local/bin/godot TEST_ARTIFACT_DIR="$PWD/artifacts/oichi-v27-tests" \
  node scripts/test-v19.mjs --only=oichi_layers_v27,hero_layers_v22,weapon_render_v22,projectile_v22
```

Draft review does not activate the runtime:

```sh
python scripts/register-oichi-v27.py --source-dir /absolute/generated/sources \
  --poses /absolute/generated/pose-anchors.json --draft /absolute/review/registration.draft.json
python scripts/preview-oichi-v27.py --registration /absolute/review/registration.draft.json \
  --sources /absolute/generated/sources --out /absolute/review/scale-148
```

The preview is an offline native-asset composite at the renderer's anatomical
world scale, not a game viewport screenshot. Use `--weapon bow_azusa` for the
default bow; the default preview choice is the long `bow_awase_yumi`.
`game/tests/capture_oichi_draft_v27.gd` accepts `--manifest`, `--sources`,
`--output` and optional `--height` user arguments for direct engine validation;
viewport screenshots require a display-enabled Godot process.

Native alpha acceptance remains strict: more than 15% of each source must be
exactly transparent. Each selected region requires more than 7,000 pixels with
alpha > 100, an independently measured anatomical ruler of at least 280 pixels,
and no boundary pixel above alpha 32 unless reviewed component isolation is used.
Alpha residue fractions (0, ≤8, ≤32) and canvas-edge maximum
are recorded in each source record. Near-transparent haze does not automatically
pass as transparency. No analysis threshold authorizes removing it.

The build validates the entire source set before copying final graded files,
then writes `game/assets/v27/oichi/registration.json` last, atomically. That manifest
activates the v27 folder for Oichi. The runtime also checks `complete: true`,
26 clip entries, and six frames per clip before selecting that folder.
The `--check` path writes no files. Hashes cover final PNG bytes, decoded final
RGBA, alpha planes, and each registered crop.
Technical registration does not itself establish visual approval or publish a
commit. Existing HEAD and the deployed baseline remain unchanged until a separately
authorized publication.

`python scripts/test-oichi-v27.py --unit-only` tests the builder without requiring
the final art. Synthetic fixture rectangles exist only inside temporary test
directories; they are never registered as game assets.

## Action fidelity and manual review

All 26 source semantics are in the script and registration. Key distinctions:

- Light 1/2, rising, low sweep, dash strike, and air light are empty-hand needle
  attacks. Their needles and VFX are separate runtime effects.
- **Light 3 is the turning roundhouse kick**, including a back-facing pivot.
- Heavy 1/2, charged upper/slam, air heavy, and special are bow draw/release poses.
- **Dash heavy is a two-handed horizontal bow bash**, not an archery shot.
- Guard is a diagonal two-handed bow guard; throw has no painted opponent.
- Down ends fully prone, recovering starts prone, and launched is airborne.
- Down frame 6 and recovering frame 1 intentionally share the same accepted
  original-approved prone drawing and exact root/ruler/bow metadata, avoiding
  a direction snap between states. There are **156 registered frames / 155 unique drawn
  poses**; each individual clip still has six unique poses. The manifest records
  `registered_frame_count`, `unique_drawn_pose_count`, and `shared_drawn_poses`.
  Final tests verify the actual shared group's frame IDs, source and crop hash;
  they do not require an old override filename.

Automatic validation proves geometry, distinct pixels, source integrity, and
state routing. It cannot prove character likeness, action readability, anatomical
quality, costume consistency, garment coverage, or absence of painted weapons.
Review all 156 poses, actual layered weapons, mirror rendering, and the HUD face
before declaring visual acceptance. Regenerate faulty source artwork through
image generation; do not hide it by changing source alpha or painting over it.
