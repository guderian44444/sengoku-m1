# Four heroes / 36 accepted base actions

Entry: `manifest.json`. Unified per-frame contracts: `contracts/<character>/<action>.json`. Integration instructions and actual unfinished runtime work: `CODEX_HANDOFF.md`.

- All36 latest actions are accepted under `Sentinel_003f9aaa53ac819191a42c7ac9485ce8`.
- 212 frames, four registered combat idles, four portraits cropped from approved artwork.
- Final Ieyasu run is **run_v5**. Other selected revisions are listed in each character entry.
- Original high-resolution PNGs, three transparent gameplay layers, timing, roots/feet/grips, weapon angles/order, events, preview/world separation, representative sheets and provenance are included.
- No accepted motion pixels were changed during final packaging. Missing or malformed metadata was corrected with legacy evidence preserved.
- Existing combat materials, runtime and review site were not modified by this handoff.

Validate after copying/unzipping:

    python tools/verify_final_bundle.py

Requires Python3 and Pillow. It checks36 accepted actions,212 layer reconstructions, clear alpha canvas edges, metadata dimensions, character/root SHA inventories, run_v5 selection and every file below100MB. This is export validation, not engine testing.

Commit this expanded directory, not the transport ZIP. Keep original sources; do not regenerate from small game frames. Some legacy review captions still say candidate: current manifests/acceptance records supersede those historical labels.
