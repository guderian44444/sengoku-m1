Honda Tadakatsu air_heavy v2: 8 real key poses / 0.72 seconds.

Requested change: full spear extends during the downward strike, with hands near the tail; add two cloud-generated key poses. All eight frames retain the complete270px spear, with no shortening, projection compression or clipping. The primary grip is source y900 for frames1-5; the second hand is also in the rear portion. Grip then slides900→700→621 during the descent/recovery.

Two new drawn poses: frame3 early forward downswing; frame8 firm horse-stance landing with the spear almost horizontal and safely clear of the ground. The six original character poses are reused at their original scale, with adjusted vertical airborne positions. Old landing/recover drawings become short descending regrip phases before the new grounded final pose. The tail-held cut/contact happens high enough that the full extended spear never crosses the floor. Every weapon pixel was checked against floor y376.

Canvas640x420, floor376. Original character scale160/430 preserved; new two-pose source uses fixed .235 based on matching helmet/antler/chest size. Source sheets, base frames, prompts, build.py, metadata, normal/3x-slow GIFs, contact and separate character/weapon/hand-occlusion/effect layers are included. Original action directory was not modified.

Limits: contact is a preview event; enemy collision, damage/range, landing runtime and gameplay remain unverified. Whole character poses are not articulated limb rigs. Regripping is sampled rather than continuously simulated. Guide-removal overlap pixels may need repaint if the weapon is repositioned. No optical flow, reversed poses or duplicate added frames.
