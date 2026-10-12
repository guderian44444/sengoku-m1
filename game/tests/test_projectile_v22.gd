extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var view := View.new()
	for face in [-1, 1]:
		for action in ["light", "heavy", "mixed_finisher", "mixed_rising", "charged_slam"]:
			test_action(view, face, action)
	view.free()
	print("V22 PROJECTILE: %d checks, %d failures; production release-hand and delayed snapshot regression" % [checks, failures])
	quit(0 if failures == 0 else 1)

func test_action(view, face: int, action: String) -> void:
	var battle = Battle.new()
	battle.reset_training("oichi")
	var player: Dictionary = battle.state.fighters[0]
	player.face = face
	battle.state.fighters[1].x = 2200.0
	var shots: Array = []
	var seen: Dictionary = {}
	for tick in range(140):
		var input: Dictionary = {}
		if action == "charged_slam":
			if tick < 40: input = {"dy": 1, "buttons": Battle.HEAVY}
		elif action in ["light", "heavy"]:
			if tick in [0, 4]: input = {"buttons": Battle.LIGHT if action == "light" else Battle.HEAVY}
		else:
			if tick == 0: input = {"buttons": Battle.LIGHT if action == "mixed_finisher" else Battle.HEAVY}
			if tick == 2: input = {"buttons": Battle.HEAVY if action == "mixed_finisher" else Battle.LIGHT}
		battle.step([input])
		view.state = battle.get_state()
		for effect in battle.state.effects:
			if effect.type != "projectile" or effect.get("action", "") != action: continue
			if int(effect.life) != int(effect.max_life): continue
			# Fan arrows share an attack snapshot, but each trajectory must be checked.
			var key := "%s:%s:%s:%s" % [effect.action_tick, effect.combo, effect.heavy_combo, effect.vy]
			if seen.has(key): continue
			seen[key] = true
			var sample: Dictionary = view._fighter_animation(player)
			check(sample.get("source", "") == "v22" and sample.get("count", 0) == 6, action + " uses the six-pose production renderer")
			check(sample.get("released", false) and sample.cell == 3, action + " launches on the actual v22 release pose")
			var frame: Dictionary = view._art.animation_frame("oichi", sample)
			check(frame.has("hand_offset") and frame.has("weapon_hand"), action + " has a registered weapon grip")
			if not frame.has("hand_offset"): continue
			check(frame.hand_offset.is_equal_approx(frame.weapon_hand), action + " release hand matches layered weapon grip")
			var hand: Vector2 = frame.hand_offset * 148.0 / float(frame.body_height)
			var expected_offset := Vector2((hand.x - 105.0) * face, hand.y + 124.0)
			var actual: Vector2 = Vector2(effect.x, effect.y - effect.z - 96.0) + view._projectile_offset(effect)
			var expected := Vector2(player.x + hand.x * face, player.y + hand.y - player.z)
			check(actual.is_equal_approx(expected), action + " launches at the registered hand in world coordinates, face %d" % face)
			shots.append({"effect": effect.duplicate(true), "offset": expected_offset, "launch_tick": battle.state.tick})
		if not shots.is_empty() and player.action == "idle" and tick > 50: break
	check(shots.size() == (3 if action == "charged_slam" else 2), action + " produces every expected projectile")
	check(player.action == "idle", action + " reaches idle through real simulation")
	# First rendering can occur after recovery, a turn, and a reset combo.
	var delayed: Dictionary = battle.get_state()
	delayed.fighters[0].face = -face
	delayed.fighters[0].combo = 0
	delayed.fighters[0].heavy_combo = 0
	view.state = delayed
	view._projectile_origins.clear()
	for shot in shots:
		# Preserve launch identity in the cache even when several same-weapon shots arrive together.
		shot.effect.life = int(shot.effect.max_life) - (int(delayed.tick) - int(shot.launch_tick))
		check(view._projectile_offset(shot.effect).is_equal_approx(shot.offset), action + " delayed release reconstructs the launch grip and facing")
		check(view._projectile_release_offset(shot.effect).is_equal_approx(shot.offset), action + " cached release preserves the same grip")
