# Original-approved Oichi color verification

This is `oichi-original-approved-20261013`, not the rejected earlier v27 art or its old 52-flag audit.

Approved portrait material ROI labels exclude the brown backdrop. Native pose RGB receives deterministic monotone lightness curves only. Alpha, dimensions and pixel positions remain exact. No whole-image histogram match is used.

All 624 measurements and unchanged diagnostic limits are in `color-audit.json` and CSV. Active-frame median L*: skin 77.36–77.74; white 90.38–90.66; red 33.13–35.66. All three materials' median/highlight L deltas meet limits. Zero missing samples.

104 residual flags remain: 54 hair comparisons, 48 red-chroma comparisons and 2 skin p90-chroma comparisons. Hair can be lighter than the portrait dark-hair ROI; red saturation is not remapped. The rotated launched 5 hair proxy is especially unreliable. These exceptions are documented individually, not silently accepted as an all-numeric pass.

Actual v19 Mori/Imagawa enemy references provide context; differently shaded skin/fabrics need not have identical medians. The approved portrait is the target.

`grading-reproduction.json` proves all 28 final decoded RGBA derivatives reproduce exactly, with byte-identical raw alpha. Complete raw inputs and implementation are in the optional recipe archive. Analysis masks never repaint production pixels. Preview images are offline composites, not gameplay captures.
