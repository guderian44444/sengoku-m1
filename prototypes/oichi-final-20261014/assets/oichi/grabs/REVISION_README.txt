Requested visual revisions only; no runtime or combat changes.
Knee: four original poses plus two cloud-generated transitions, 6 frames 420ms, contact at 190ms.
Forward: isolated all eight complete figures instead of uniform sheet cells. This removes neighbor hands/hair while preserving source alpha union.
Reverse: same isolation plus two newly generated turn drawings, 10 frames 960ms.
Victims and weapon layers remain independent. Prototype anchors still require production registration.
Rebuild from extracted root: python grab_hit_1_six/rebuild.py OR python throw_fixes/rebuild.py throw_forward OR python throw_fixes/rebuild.py throw_reverse then python throw_fixes/build_reverse_ten.py, according to this package. Requires Pillow, numpy and scipy.
