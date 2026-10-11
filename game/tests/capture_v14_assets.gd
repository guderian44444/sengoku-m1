extends RefCounted
const Battle = preload("res://core/battle.gd")

static func missing(art) -> Array:
	var absent := []
	for kind in ["soldier","flag","commander","archer","gunner","boss"]:
		var expected := {"idle":6 if kind=="boss" else 1,"walk":12 if kind=="boss" else 6,"hurt":6 if kind=="boss" else 3,"death":6}
		if kind != "boss": expected.struggle = 3
		var attacks: Array = ["bow_shot"] if kind=="archer" else (["gun_shot"] if kind=="gunner" else Battle.ENEMY_ATTACKS[kind])
		for action in attacks: expected[action] = 6
		for clip in expected:
			var key: String = "mori:" + kind + ":" + clip
			var frames: Array = art.enemy_clips.get(key,[])
			if frames.size()!=expected[clip] or not frames.all(func(f: Dictionary) -> bool: return f.source=="v14" and f.body_height>=220): absent.append(key)
	if art.animations.nobunaga.get("v14_run",[]).size()!=12: absent.append("nobunaga:v14_run")
	var flags: Array = art.prop_frames.get("mori-camp-flag",[])
	if flags.size()!=6 or not flags.all(func(f: Dictionary) -> bool: return f.source=="v14"): absent.append("prop:mori-camp-flag")
	return absent
