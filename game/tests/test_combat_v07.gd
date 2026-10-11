extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_rising()
	_test_slam()
	_test_input_lifecycle()
	_test_wire()
	print("V07 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _arena(hero: String = "nobunaga"):
	var battle = Battle.new()
	battle.reset_training(hero)
	return battle

func _step(battle, frames: int, buttons: int = 0, dy: int = 0) -> void:
	for tick in range(frames): battle.step([{"dx": 0, "dy": dy, "buttons": buttons}])

func _enemy(battle, x: float, y: float = 480.0) -> Dictionary:
	var target: Dictionary = battle._make_fighter(1, "soldier", x, y, 1000)
	target.action = "stunned"
	target.stun = 10000
	target.home_x = x
	target.home_y = y
	battle.state.fighters.append(target)
	return target

func _test_rising() -> void:
	for hero in ["nobunaga", "oichi"]:
		for weight in ["light", "medium", "heavy"]:
			var battle = _arena(hero)
			var player: Dictionary = battle.state.fighters[0]
			var target: Dictionary = battle.state.fighters[1]
			target.weight = weight
			_step(battle, 1, Battle.LIGHT, -1)
			_check(player.action == "rising" and player.combo == 0 and player.y == 480.0, hero + " up-light selects rooted directional action independently of combo")
			_step(battle, 9)
			_check(target.hp < target.max_hp and (target.z > 0) == (weight == "light"), hero + " rising damages and respects " + weight + " launch limit")
	var fan = _arena("oichi")
	fan.state.fighters[1].x = 710.0
	var upper := _enemy(fan, 710.0, 453.0)
	var lower := _enemy(fan, 710.0, 507.0)
	var far := _enemy(fan, 780.0)
	_step(fan, 1, Battle.LIGHT, -1)
	_step(fan, 6)
	_check(fan.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile" and e.get("rising", false)).size() == 3, "Oichi rising emits three short upward needles")
	_step(fan, 18)
	_check(upper.hp == 986 and lower.hp == 986 and far.hp == 1000, "needle fan hits adjacent lanes once and remains short range")
	var sword = _arena()
	sword.state.fighters[1].x = 645.0
	sword.state.fighters[1].y = 528.0
	var beyond := _enemy(sword, 645.1, 528.0)
	_step(sword, 1, Battle.LIGHT, -1)
	_step(sword, 6)
	_check(sword.state.fighters[1].hp == 982 and beyond.hp == 1000, "rising sword respects 145 forward and 48 lane boundary")

func _test_slam() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var near: Dictionary = battle.state.fighters[1]
	var far := _enemy(battle, 765.0)
	var outside := _enemy(battle, 796.0)
	var wide := _enemy(battle, 555.0, 577.0)
	var flying := _enemy(battle, 565.0)
	flying.z = 800.0
	var boss := _enemy(battle, 580.0)
	boss.weight = "heavy"
	_step(battle, 1, Battle.HEAVY, 1)
	_check(player.action == "charge" and player.y == 480.0 and player.heavy_combo == 0, "down-heavy holds rooted charge until release")
	_step(battle, 1)
	_check(player.action == "ground_slam", "short down-heavy release selects the ordinary slam")
	_step(battle, 14)
	_check(near.hp == 1000 and battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == "shockwave"), "ground impact creates wave at tick 14 before travel damage")
	_step(battle, 4)
	_check(near.hp == 968 and far.hp == 1000, "shockwave reaches near targets before far targets")
	_check(boss.hp == 968 and boss.z == 0, "ground wave damages heavy targets without launching them")
	_step(battle, 20)
	_check(far.hp == 968 and near.hp == 968, "expanding wave reaches farther ground targets once each")
	_check(outside.hp == 1000 and wide.hp == 1000 and flying.hp == 1000, "wave excludes outside ellipse and airborne enemies")
	_step(battle, 10, Battle.HEAVY, 1)
	_check(player.action == "idle" and battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave").is_empty(), "holding down-heavy during slam recovery never repeats the attack")
	var bow = _arena("oichi")
	_step(bow, 40, Battle.HEAVY, 1)
	_check(bow.state.fighters[0].action == "charge", "Oichi down-heavy charges the ground ice branch")
	_step(bow, 1)
	_check(bow.state.fighters[0].action == "charged_slam", "Oichi held down-heavy release selects the new ice field")

func _test_input_lifecycle() -> void:
	for spec in [[Battle.LIGHT, -1, "rising"], [Battle.HEAVY, 1, "ground_slam"]]:
		var battle = _arena()
		_step(battle, 1, spec[0], spec[1])
		_step(battle, 1, Battle.CANCEL | spec[0], spec[1])
		_step(battle, 60)
		_check(battle.state.training.hit_count == 0 and battle.state.fighters[0].action == "idle", str(spec[2]) + " cancels before impact without stale follow-up")
		battle.reset_training()
		battle.state.fighters[0].z = 100.0
		_step(battle, 1, spec[0], spec[1])
		_check(battle.state.fighters[0].action != spec[2], str(spec[2]) + " requires grounded feet")
	var light = _arena()
	_step(light, 1, Battle.LIGHT)
	_step(light, 1)
	_step(light, 1, Battle.LIGHT, -1)
	_step(light, 17)
	_check(light.state.fighters[0].action == "rising", "buffered up-light preserves press direction after W is released")
	var heavy = _arena()
	_step(heavy, 1, Battle.HEAVY)
	_step(heavy, 1)
	_step(heavy, 1, Battle.HEAVY, 1)
	_step(heavy, 35)
	_check(heavy.state.fighters[0].action == "ground_slam", "buffered down-heavy preserves press direction after S is released")
	_step(heavy, 1, Battle.CANCEL)
	_step(heavy, 1, Battle.HEAVY)
	_check(heavy.state.fighters[0].action == "charge", "cancel clears buffered slam intent for later normal heavy")

func _test_wire() -> void:
	for spec in [["nobunaga", Battle.HEAVY, 1], ["oichi", Battle.LIGHT, -1]]:
		var battle = _arena(spec[0])
		_step(battle, 1, spec[1], spec[2])
		var valid := Wire.valid_snapshot(battle.get_state())
		for tick in range(60):
			_step(battle, 1)
			valid = valid and Wire.valid_snapshot(battle.get_state())
		_check(valid, str(spec[0]) + " directional action and effects serialize through their entire lifecycle")
	var snapshot: Dictionary = _arena().get_state()
	snapshot.effects = [{"type": "shockwave", "x": 555.0, "y": 480.0, "life": 24, "max_life": 24, "radius": 240.0, "owner": 1, "team": 0, "face": 1, "damage": 32, "hit_ids": []}]
	for field in ["radius", "owner", "team", "damage", "face", "hit_ids"]:
		var invalid := snapshot.duplicate(true)
		invalid.effects[0].erase(field)
		_check(not Wire.valid_snapshot(invalid), "wire rejects incomplete shockwave " + field)
	snapshot.effects[0]["rising"] = "yes"
	_check(not Wire.valid_snapshot(snapshot), "wire rejects coercible rising flag")
