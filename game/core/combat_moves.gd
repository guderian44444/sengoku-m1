extends RefCounted

static var _registrations: Dictionary = {}
const HEROES := ["nobunaga","oichi","hideyoshi","ieyasu","mitsuhide","tadakatsu"]
const HEIGHTS := {"nobunaga":155.0,"oichi":148.0,"hideyoshi":150.0,"ieyasu":152.0,"mitsuhide":163.0,"tadakatsu":163.0}

static func active(fighter: Dictionary) -> bool:
	return fighter.get("team",0) == 0 and fighter.get("kind","") in HEROES

static func registration(hero: String) -> Dictionary:
	if not _registrations.has(hero):
		var path := "res://assets/v33/%s/registration.json" % hero
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(value is Dictionary and value.get("complete",false),"Incomplete combat registration: "+hero)
		_registrations[hero] = value
	return _registrations[hero]

static func clip(fighter: Dictionary) -> String:
	var action := str(fighter.get("action","idle"))
	if action == "light": return "light_%d" % clampi(int(fighter.get("combo",1)),1,3)
	if action == "charged": return "charge_release"
	if action == "holding": return "grab_hold"
	if action == "throw": return str(fighter.get("throw_clip","throw_forward"))
	if action == "charge": return "charge_ready" if float(fighter.get("charge",0))*1000/60 < float(registration(str(fighter.kind)).clips.charge_ready.duration_ms) else "charge_hold"
	return action

static func spec(fighter: Dictionary) -> Dictionary:
	return registration(str(fighter.kind)).clips.get(clip(fighter),{}) if active(fighter) else {}

static func frame_index(specification: Dictionary, milliseconds: float) -> int:
	var time := maxf(0,milliseconds)
	if specification.get("loop",false): time = fposmod(time,float(specification.duration_ms))
	if specification.has("animation_duration_ms"): time *= float(specification.animation_duration_ms)/float(specification.duration_ms)
	for index in range(specification.frames.size()):
		time -= float(specification.frames[index].duration_ms)
		if time < -0.000001: return index
	return specification.frames.size()-1
