import render_v2 as b,json
for f in b.frames:f['arrow_direction']=[1,0]
b.frames[7]['arrow_tail_override']=[787.245,465.633]
r=b.render('charge_release_horizontal',[5,7,8,9,0],[120,70,130,160,180])
m=json.load(open(r/'animation.json'));m.update(action='charge_release',revision='horizontal_projectile_only',projectile_direction=[1,0],projectile_spawn_anchor=[767.245,465.633],release_origin='last nocked arrow on full draw pose, arrow passes bow before release followthrough lowers left hand',character_art_unchanged=True);json.dump(m,open(r/'animation.json','w'),indent=2)
