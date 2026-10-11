extends SceneTree

const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func _init() -> void:
	for hero in ["nobunaga", "oichi"]:
		for attack in [Battle.LIGHT, Battle.HEAVY]:
			_test_chain(hero, attack, true)
			_test_chain(hero, attack, false)
			_test_buffered(hero, attack)
		_test_directional(hero)
	_test_two_players()
	print("V12 COMBO MOVEMENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func arena(hero: String):
	var battle = Battle.new()
	battle.reset_training(hero)
	battle.state.fighters[1].x = 2200.0
	return battle

func _test_chain(hero: String, attack: int, complete: bool) -> void:
	var battle = arena(hero)
	var player: Dictionary = battle.state.fighters[0]
	for tick in range(4): battle.step([{"dx": 1}])
	var start_x: float = player.x
	var stages: Array = []
	var rooted := true
	var waiting := false
	var finisher_resumed := false
	var presses: Array = ([0, 24, 48] if attack == Battle.LIGHT else [0, 42]) if complete else [0]
	var maximum := 3 if attack == Battle.LIGHT else 2
	for tick in range(110):
		battle.step([{"dx": 1, "buttons": attack if tick in presses else 0}])
		for event in battle.state.events:
			if event.type == "swing" and event.actor == player.id:
				stages.append(event.get("combo", 0) if attack == Battle.LIGHT else event.get("heavy_combo", 0))
		var stage: int = player.combo if attack == Battle.LIGHT else player.heavy_combo
		var window: int = player.combo_tick if attack == Battle.LIGHT else player.heavy_combo_tick
		if player.action == "idle" and stage > 0 and stage < maximum and window > 0:
			waiting = true
			rooted = rooted and is_equal_approx(player.x, start_x)
		if player.action == "idle" and stage == maximum and window > 0:
			finisher_resumed = finisher_resumed or player.x > start_x
	var label := "%s attack %d complete=%s" % [hero, attack, complete]
	check(stages == ([1, 2, 3] if attack == Battle.LIGHT else [1, 2]) if complete else stages == [1], label + " keeps exact fresh-press combo stages while RIGHT stays held")
	check(waiting and rooted, label + " ignores ordinary horizontal movement in the continuation window")
	check(player.action == "idle" and player.x > start_x, label + " resumes the still-held direction after finish or timeout")
	if complete: check(finisher_resumed, label + " finisher resumes movement without waiting for the old combo timer")

func _test_directional(hero: String) -> void:
	for dy in [-1, 1]:
		var battle = arena(hero)
		battle.step([{"dx": 1}])
		var x: float = battle.state.fighters[0].x
		battle.step([{"dx": 1, "dy": dy, "buttons": Battle.LIGHT}])
		check(battle.state.fighters[0].action == ("rising" if dy < 0 else "low_sweep") and battle.state.fighters[0].x == x, hero + " held horizontal direction preserves W/S + light")
		battle = arena(hero)
		battle.step([{"dx": 1}])
		battle.step([{"dx": 1, "dy": dy, "buttons": Battle.HEAVY}])
		battle.step([{"dx": 1}])
		check(battle.state.fighters[0].action == ("upper_heavy" if dy < 0 else "ground_slam"), hero + " held horizontal direction preserves W/S + heavy")
	var dash = arena(hero)
	var x: float = dash.state.fighters[0].x
	dash.step([{"dx": 1, "buttons": Battle.LIGHT}])
	check(dash.state.fighters[0].action == "dash_strike", hero + " fresh direction + light still selects dash strike")
	for tick in range(9): dash.step([{"dx": 1}])
	check(is_equal_approx(dash.state.fighters[0].x, x + 54.0), hero + " dash strike retains its own nine forward steps")
	var held = arena(hero)
	held.step([{"dx": 1}])
	var swings := 0
	for tick in range(80):
		held.step([{"dx": 1, "buttons": Battle.LIGHT}])
		for event in held.state.events:
			if event.type == "swing": swings += 1
	check(swings == 1, hero + " holding LIGHT still never invents fresh attacks")

func _test_buffered(hero: String, attack: int) -> void:
	var battle = arena(hero)
	battle.step([{"dx": 1}])
	var stages: Array = []
	var presses: Array = [0, 4, 24] if attack == Battle.LIGHT else [0, 4]
	for tick in range(85):
		battle.step([{"dx": 1, "buttons": attack if tick in presses else 0}])
		for event in battle.state.events:
			if event.type == "swing": stages.append(event.combo if attack == Battle.LIGHT else event.heavy_combo)
	check(stages == ([1, 2, 3] if attack == Battle.LIGHT else [1, 2]), hero + " rapid presses buffer the complete chain while RIGHT stays held")

func _test_two_players() -> void:
	var battle = Battle.new()
	battle.reset("normal", 2, ["nobunaga", "oichi"])
	for fighter in battle.state.fighters:
		if fighter.team == 1:
			fighter.kind = "dummy"
			fighter.x = 2200.0
	for tick in range(4): battle.step([{"dx": 1}, {"dx": -1}])
	var stages: Array = [[], []]
	for tick in range(100):
		battle.step([{"dx": 1, "buttons": Battle.LIGHT if tick in [0, 24, 48] else 0}, {"dx": -1, "buttons": Battle.HEAVY if tick in [0, 42] else 0}])
		for event in battle.state.events:
			if event.type != "swing": continue
			if event.actor == battle.state.fighters[0].id: stages[0].append(event.combo)
			if event.actor == battle.state.fighters[1].id: stages[1].append(event.heavy_combo)
	check(stages == [[1, 2, 3], [1, 2]], "two players independently complete light/heavy chains while holding opposite directions")
