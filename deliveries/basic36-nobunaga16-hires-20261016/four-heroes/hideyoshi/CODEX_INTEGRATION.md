# hideyoshi: Codex integration notes

Entry: integration_manifest.json. Nine actions are accepted under Sentinel_003f9aaa53ac819191a42c7ac9485ce8; 56 frames. Artwork acceptance and file QA do not mean runtime integration or gameplay validation. No commit/push was performed.

- Read actions.*.metadata, then frames[].integration. All integration paths are character-root-relative, frame indices are zero-based, times are milliseconds, x is right and y is down. Original metadata fields are retained for provenance; do not infer their path/index conventions from the normalized fields.
- Render the three transparent layers in each frame's layer_order. Use root_canvas_px as pivot, not crop bbox or canvas center. Different actions use different canvas heights; preserve root alignment. Do not rescale crouching/jumping/falling poses to equal bounding boxes. Standing ruler: 150px.
- PNG/GIF and native source PNG bytes are identical to accepted delivery. Do not run the historical generation/build scripts to regenerate accepted art. source_inventory.json marks active source uses and retained reference/provenance.
- Apply world_root_offset_px through a single runtime owner only. preview_offset_px is a separate review demonstration. pose_offset_already_baked_px must not be applied a second time. Hideyoshi walk/run/jump/launched have authored separate root tracks; preserve cycle end delta and inherit position through launched/down/recovering. Do not reset world position at state changes.
- Loop only actions marked loop. Review GIFs may repeat non-loop actions for inspection. Down contains impact/settling and a final death-compatible hold; do not auto-recover. Victory optional hold is recorded separately from loop.
- Both launched→down and down→recovering handoff layers are byte-identical. Hideyoshi launched/down share a contact event at the boundary; emit it once. Land/settle tags are animation tags, not collision or gameplay validation.
- Hideyoshi original foot landmarks use near/far only. Anatomical left/right are deliberately null and require runtime/rig confirmation; never relabel feet by their screen-x ordering.
- Registered approved idle and cropped portrait: registered-assets.json. Portrait is a crop, not newly generated artwork. Ordinary actions contain no FX.

Runtime work still required: import paths and pivots; controller/root-motion ownership; state timing and interruption rules; grounded/landing detection; down/death and recovery transitions; weapon/hand contact under mirroring; hitboxes/collision; visual playback at actual engine scale. No engine tests have been run.

Read-only verification: python verify_bundle.py. Historic review images may still contain the word CANDIDATE; their pixels are deliberately preserved and current acceptance is defined by integration_manifest.json.
