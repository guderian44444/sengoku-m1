extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var view := View.new()
	for face in [-1, 1]:
		_test_charged_slam(view, face)
		for action in ["mixed_finisher", "mixed_rising"]: _test_mixed(view, face, action)
		for attack in [Battle.LIGHT, Battle.HEAVY]: _test_second_stage(view, face, attack)
	view.free()
	print("V12 PROJECTILE: %d checks, %d failures; simulation and release-coordinate regression only" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func arena(face: int):
	var battle = Battle.new()
	battle.reset_training("oichi")
	battle.state.fighters[0].face = face
	battle.state.fighters[1].x = 2200.0
	return battle

func projectiles(battle, action: String) -> Array:
	return battle.state.effects.filter(func(effect: Dictionary) -> bool: return effect.type == "projectile" and effect.get("action", "") == action)

func release(view, player: Dictionary, effect: Dictionary, clip: String, tick: int) -> Dictionary:
	var sample: Dictionary = view._fighter_animation(player)
	check(sample.sheet == "v12_" + clip and sample.cell == 6, "%s at %d uses its actual release drawing" % [clip, tick])
	check(view._art.animations.oichi["v12_" + clip][6].has("hand_offset"), clip + " release has a measured hand")
	check(effect.get("action_tick", -1) == tick and effect.get("combo", -1) == player.combo and effect.get("heavy_combo", -1) == player.heavy_combo, clip + " core captures attack time and combo stages")
	return {"effect": effect.duplicate(true), "clip": clip}

func delayed_offsets(view, battle, shots: Array, duration: int) -> void:
	var player: Dictionary = battle.state.fighters[0]
	for tick in range(duration):
		if player.action == "idle" or player.action_tick >= duration - 2: break
		battle.step([])
	check(player.action != "idle", "delay fixture reaches recovery before checking the first render")
	for phase in ["recovery", "idle"]:
		if phase == "idle":
			for tick in range(duration + 2):
				if player.action == "idle": break
				battle.step([])
			check(player.action == "idle", "real simulation finishes the attack before the delayed render")
		# A delayed network effect can arrive after its owner has turned or reset the chain.
		var current: Dictionary = battle.get_state()
		current.fighters[0].face = -int(shots[0].effect.face)
		current.fighters[0].combo = 0
		current.fighters[0].heavy_combo = 0
		view.state = current
		view._projectile_origins.clear()
		for shot in shots:
			var effect: Dictionary = shot.effect
			var frame: Dictionary = view._art.animations.oichi["v12_" + str(shot.clip)][6]
			var hand: Vector2 = frame.hand_offset * 148.0 / float(frame.body_height)
			var expected := Vector2((hand.x - 105.0) * int(effect.face), hand.y + 124.0)
			var actual: Vector2 = view._projectile_offset(effect)
			check(actual.is_equal_approx(expected), "%s first render during %s stays at snapshot release hand, facing %d" % [shot.clip, phase, effect.face])

func _test_charged_slam(view, face: int) -> void:
	var battle = arena(face)
	var player: Dictionary = battle.state.fighters[0]
	for tick in range(40): battle.step([{"dy": 1, "buttons": Battle.HEAVY}])
	battle.step([])
	check(player.action == "charged_slam" and player.action_tick == 0, "held S+heavy enters the real charged-slam action")
	var early_arrows := false
	for tick in range(1, 29):
		battle.step([])
		if tick < 28: early_arrows = early_arrows or not projectiles(battle, "charged_slam").is_empty()
		if tick == 28: check(battle.state.effects.any(func(effect: Dictionary) -> bool: return effect.type == "shockwave"), "charged-slam wave still starts at tick 28")
		if tick == 27: check(view._fighter_animation(player).cell == 5, "bow remains fully drawn immediately before tick 28")
	var arrows := projectiles(battle, "charged_slam")
	check(not early_arrows and arrows.size() == 3, "charged-slam core creates its three arrows with the wave exactly at tick 28")
	var shots: Array = []
	view.state = battle.get_state()
	view._projectile_origins.clear()
	for arrow in arrows:
		shots.append(release(view, player, arrow, "charged_slam", 28))
		var frame: Dictionary = view._art.animations.oichi.v12_charged_slam[6]
		var hand: Vector2 = frame.hand_offset * 148.0 / float(frame.body_height)
		var expected := Vector2(player.x + hand.x * face, player.y + hand.y - player.z)
		var actual: Vector2 = Vector2(arrow.x, arrow.y - arrow.z - 96.0) + view._projectile_offset(arrow)
		check(actual.is_equal_approx(expected), "every fan arrow starts at the same measured bow hand, facing %d" % face)
	if arrows.size() == 3:
		check(arrows[0].vy < 0.0 and arrows[1].vy == 0.0 and arrows[2].vy > 0.0, "the three arrows separate during flight rather than spawning in offset lanes")
	if not shots.is_empty(): delayed_offsets(view, battle, shots, 72)

func _test_mixed(view, face: int, action: String) -> void:
	var battle = arena(face)
	var player: Dictionary = battle.state.fighters[0]
	var first := Battle.LIGHT if action == "mixed_finisher" else Battle.HEAVY
	var second := Battle.HEAVY if action == "mixed_finisher" else Battle.LIGHT
	battle.step([{"buttons": first}])
	battle.step([])
	battle.step([{"buttons": second}])
	battle.step([])
	for tick in range(60):
		if player.action == action: break
		battle.step([])
	check(player.action == action and player.action_tick == 0, action + " starts through buffered real input")
	var shots: Array = []
	for tick in range(1, 28):
		battle.step([])
		if tick not in [9, 27]: continue
		var created: Array = projectiles(battle, action).filter(func(effect: Dictionary) -> bool: return effect.get("action_tick", -1) == tick)
		check(created.size() == 1 and created[0].weapon == ("needle" if tick == 9 else "arrow"), action + " emits the intended needle/bow stage")
		if not created.is_empty(): shots.append(release(view, player, created[0], "light2" if tick == 9 else ("charged_upper" if action == "mixed_rising" else "charged_slam"), tick))
	if shots.size() == 2: delayed_offsets(view, battle, shots, 48)

func _test_second_stage(view, face: int, attack: int) -> void:
	var battle = arena(face)
	var player: Dictionary = battle.state.fighters[0]
	var action := "light" if attack == Battle.LIGHT else "heavy"
	var stage_key := "combo" if attack == Battle.LIGHT else "heavy_combo"
	var shot: Dictionary = {}
	for tick in range(70):
		battle.step([{"buttons": attack if tick in [0, 4] else 0}])
		for effect in projectiles(battle, action):
			if int(effect.get(stage_key, 0)) == 2: shot = effect
		if not shot.is_empty(): break
	check(not shot.is_empty(), "real " + action + " combo reaches its second-stage projectile")
	if not shot.is_empty(): delayed_offsets(view, battle, [release(view, player, shot, action + "2", 6 if attack == Battle.LIGHT else 14)], 19 if attack == Battle.LIGHT else 36)
