# Cloud image generation provenance

All character generation used image_gen with transparent_background=true. Correct identity06 was viewed first and used as reference. Shared instructions: exact young/slim identity, narrow moustache/chin beard, pale gray-white patterned sleeveless jinbaori, navy sleeves, black/gold armor, gray trousers and gold-cord sandals; no teal/green costume, large beard, weapons, scabbards, opponent, floor, shadow, text or effects. Full bodies, fixed game camera, consistent body scale, actual redrawn poses.

Source outputs:
- grab_hold.png: exec-8287412c-924c-4672-9731-a5cf3b60e733.png. Six subtle breathing/grasp poses, 3x2.
- grab_start.png: exec-81bd8f1a-8084-4c21-b202-b7b46a1b4d90.png. Ready, reach, full reach, grip, pull, stable hold, 3x2.
- grab_hit_2.png: exec-9e27c740-7529-4b84-8d9a-88459059d70c.png. Hold, head back, forward thrust, deep forehead contact, recoil, hold; no knee or punch. Shared by both separate action keys.
- throw_forward.png: exec-e55dacb5-0a57-4459-869d-8289ad00b7a5.png. Ten genuine hip-turn/lift/release/recovery poses, 5x2.
- throw_reverse.png: exec-1e00ebcc-2b7f-4b5a-b2da-1b51479ec23e.png. Ten right/back/left over-shoulder poses, 5x2. Unsuitable narrow-foot/backward-arch poses are excluded from final revision.
- forward_transitions.png: exec-9dbe67d3-9728-4674-b8dd-0bdbdd976685.png. Three new poses: mid hip turn, forward arm release transition, partial-arm-retraction recovery.
- reverse_transitions.png: exec-93c2698d-4159-49b1-a3bb-7a36cfbf9b20.png. Four new poses: back-left shoulder load, left-facing forward-loaded shoulder, 45-degree forward fold/release, halfway recovery. Topknot framing failed; source retained for provenance only.
- reverse_transitions_fixed.png: exec-e103a2b7-d3c6-429d-8e2b-115c6846ee94.png. Targeted image_gen framing repair preserving the four poses and identity, restoring complete top-left topknot and transparent margins. This is the used source.

Actual SHA256 values are recorded in registration.json and SHA256SUMS. The old teal v10 character pixels are not used anywhere in these new identity06 character frames.
