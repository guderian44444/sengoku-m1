extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _init() -> void:
	for face in [-1, 1]:
		for action in ["upper_heavy", "charged_upper"]:
			_test_arcs(face, action)
	print("V27 OICHI ARROWS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _test_arcs(face: int, action: String) -> void:
	var battle = Battle.new()
	battle.reset_training("oichi")
	battle.state.props = []
	battle.state.effects = []
	var player: Dictionary = battle.state.fighters[0]
	player.x = 1200.0
	player.face = face
	player.weapon_id = "bow_shigeto"
	player.owned_weapons.append("bow_shigeto")
	battle.state.fighters = [player]
	for distance in [180.0, 420.0, 680.0]:
		battle.state.fighters.append(battle._make_fighter(1, "dummy", player.x + face * distance, player.y, 1000))
	battle._begin(player, action)
	for tick in range(22 if action == "charged_upper" else 12):
		battle._tick_fighter(player)
	var arrows: Array = battle.state.effects.filter(func(e): return e.type == "projectile")
	_check(arrows.size() == 3, "%s facing %d fires three arrows" % [action, face])
	_check(Wire.valid_snapshot(battle.get_state()), "arcs can be sent to the other player")
	if arrows.size() != 3: return
	for i in range(3):
		var arrow: Dictionary = arrows[i]
		var target: Dictionary = battle.state.fighters[i + 1]
		_check(is_equal_approx(arrow.target_x, target.x), "near/middle/far landing follows facing")
		for tick in range(int(arrow.flight_ticks / 2)):
			battle._tick_arc_arrow(arrow)
		_check(arrow.z > arrow.start_z and target.hp == 1000, "arrow rises before descending; no premature ground hit")
		while arrow.life > 0:
			battle._tick_arc_arrow(arrow)
		_check(is_zero_approx(arrow.z) and target.hp < 1000, "arrow damages its target on landing")
		_check(target.freeze == 0 and target.action == "hurt" and not target.airborne_lock, "ice bow causes neither freezing nor knockdown")
