# Final visual QA

All 232 current layer partitions were included in final compositing verification; all visible RGBA and alpha pixels reproduce their native masters exactly. All 16 GIF hashes, frame counts and individual frame durations match the approved references.

Semantic review inspected all per-clip ownership sheets and native close-ups of ambiguous contact regions. Corrections made without changing a master pixel:
- light_1 003/005/006: restored omitted grip regions; removed hand-from-weapon misclassification.
- light_2 004: corrected reversed blade axis and both grip masks.
- light_3 013/014, heavy013, charge_ready001, dash_heavy010/011/012: removed face/neck ownership contamination and traced actual grips.
- grab_hit_1 and grab_hit_2 002/004: removed gold belt medallion from hand layer.
- grab_start000–007: used original canonical steel alpha rather than automatic blade detection; corrected001 face/neck and002 fists;009 recovered gripping hand, removing nearby armor.
- throw_forward009–018: copied corrected exact-identical grab_start layer partitions, including015/016/017 fixes.
- air_heavy014: copied the corrected exact-identical heavy013 layers.
- charge_release24 frames: used original authored body/steel depth plus local hand regions and FX back/front. Edge-on blade008/016 is preserved without forcing a fictitious long blade.
- reverse throw16: manual native envelopes and blade-edge tracing; independent all-RGBA byte equality verified.

Final targeted review confirms complete grip regions in light_1 005/006 and throw_forward009/015/016/017. The final neck-spill correction for grab_start001/throw_forward017 was viewed at native crop scale; see final-grip-face-boundary.png. Root-foot reference dots were inspected; light_3 secondary sole metadata and displayed dot were restored from authored passing_sole_native. These remain art landmarks, not runtime collision contacts.

White collar/armor and dark cloth were inspected on checker backgrounds in light_1 005, charge_ready004, throw_forward009 and air_heavy010. No obvious detail loss was seen there. Source-alpha holes at grab_start003/throw_forward015 are inherited and explicitly retained. General matte/edge limitations and hidden-fill gaps remain as documented; exact recomposition is not proof of complete independent weapon geometry.
