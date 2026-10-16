Honda Tadakatsu r3: nine base actions, 2026-10-15

All nine latest delivered base actions are accepted under user event Sentinel_14a43a0d05ec8191b50a482834f7a976. This update changes acceptance records only; every PNG and GIF is unchanged. The latest jump includes strengthened crouch/chest anticipation and leg/arm takeoff.

Each action directory contains three transparent RGBA layers per frame (body, weapon, hand_occlusion), composites, normal and slow review GIFs, same-scale approved-idle comparison, metadata.json and QA.json; frame configuration is in config.json (walk uses build_walk.py). High-resolution originals are preserved in source/ folders. Review GIFs repeat for inspection; consult metadata.loop for runtime behavior. Down has a full impact/settle sequence and terminal death-compatible hold, not merely a static hold. Launched/down and down/recovering handoffs are pixel-identical.

Standing ruler is163px. Paired upright sources use163/740; high-resolution single falling/recovery sources use163/1050 anatomical ruler. Approved combat idle is reused unchanged at163/370. No per-frame bbox equalization. Native source PNGs are preserved and reduced only once into body layers. All new source figures exceed600px effective height; old approved idle reuse is explicitly marked. Rejected source attempts may remain in source/ but are not selected in config.json.

world_delta is zero for all frames; runtime controller owns world displacement. Walk world-preview is a separate foot-lock demonstration. pose/body_offset records visible local pose placement (including jumping or knockback illustration offsets); it does not authorize runtime world motion. Keep these offsets separate when importing.

identity/ contains exact approved combat idle registration and a portrait crop, not a newly drawn portrait. All ordinary actions have noFX. No existing combat source, site or Git repository was modified.

manifest.json lists all actions and status. unified-frame-index.json normalizes frame timing, events, roots, feet, hands, weapon angles, layers and motion fields. base-actions-library.json lists current delivery IDs.

Acceptance: acceptance.json. Formal approved idle and cropped portrait inventory: registered-assets.json.
