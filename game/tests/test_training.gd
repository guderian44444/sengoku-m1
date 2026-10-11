extends SceneTree

const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_light_and_recovery()
	_test_heavy_chain()
	_test_reset_and_cancel()
	print("TRAINING TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _training(hero: String = "nobunaga"):
	var battle = Battle.new()
	battle.reset_training(hero)
	return battle

func _advance(battle, count: int, buttons: int = 0) -> void:
	for tick in range(count): battle.step([{"buttons": buttons}])

func _test_light_and_recovery() -> void:
	for hero in ["nobunaga", "oichi"]:
		var battle = _training(hero)
		var dummy: Dictionary = battle.state.fighters[1]
		_check(dummy.kind == "dummy" and battle.state.fighters.size() == 2 and battle.state.drops.is_empty(), hero + " training has only hero and dummy")
		for tick in range(80): battle.step([{"buttons": Battle.LIGHT if tick in [0, 4] else 0}])
		_check(battle.state.training.hit_count == 2, hero + " two presses cause exactly two hits")
		_check(dummy.z == 0 and dummy.knockback == 0 and (dummy.x > 585.0 if hero == "nobunaga" else dummy.x == 585.0), hero + " sword uppercut settles while needle pair stays planted")
		_check(battle.state.training.last_damage > 0 and battle.state.training.total_damage == dummy.max_hp - dummy.hp, hero + " training reports real damage")
		battle.reset_training(hero)
		for tick in range(48): battle.step([{"buttons": Battle.LIGHT if tick in [0, 4, 24] else 0}])
		dummy = battle.state.fighters[1]
		_check(battle.state.training.hit_count == 3 and dummy.z > 0 and dummy.x > 585, hero + " third fresh press launches")
		_advance(battle, 180)
		_check(dummy.hp == dummy.max_hp and dummy.x == 585 and dummy.z == 0 and dummy.action == "idle", hero + " dummy settles, refills and returns home")
		_check(battle.state.phase == "playing" and battle.state.wave == 1 and battle.state.fighters.size() == 2, hero + " training never advances waves or wins")
		battle.reset_training(hero)
		_advance(battle, 80, Battle.LIGHT)
		_check(battle.state.training.hit_count == 1, hero + " held light does not auto-chain")
	var battle = _training()
	var dummy: Dictionary = battle.state.fighters[1]
	battle.state.fighters[0].x = dummy.x - 130.0
	battle.state.fighters[0].y = 420.0
	for tick in range(48): battle.step([{"buttons": Battle.LIGHT if tick in [0, 4, 24] else 0}])
	_check(battle.state.training.hit_count == 1 and dummy.z > 0, "third sweep alone reaches the wider forward and lane area")
	battle.reset_training()
	dummy = battle.state.fighters[1]
	battle._damage(dummy, 10000, battle.state.fighters[0].id, true)
	_check(dummy.hp == 1 and dummy.action != "defeated", "practice dummy survives lethal damage")
	_advance(battle, 150)
	_check(dummy.hp == 1000 and battle.state.phase == "playing", "lethal practice damage also recovers")
	battle.reset_training()
	_advance(battle, 1, Battle.SPECIAL)
	_advance(battle, 58)
	_check(battle.state.training.hit_count == 1 and battle.state.fighters[0].rage == 100, "special hits dummy and replenishes meter")
	battle.reset_training()
	battle.state.fighters[0].x = battle.state.fighters[1].x - 60.0
	_advance(battle, 1, Battle.GRAB)
	_advance(battle, 1)
	_check(battle.state.training.hit_count == 1 and battle.state.fighters[1].x > 585, "moving close to the dummy supports a real throw")

func _test_heavy_chain() -> void:
	for hero in ["nobunaga", "oichi"]:
		var battle = _training(hero)
		_advance(battle, 1, Battle.HEAVY)
		_advance(battle, 18)
		var dummy: Dictionary = battle.state.fighters[1]
		_check(battle.state.training.hit_count == 1 and dummy.action == "hurt" and dummy.x == 585 and dummy.z == 0, hero + " first heavy staggers in place")
		_advance(battle, 80)
		_check(battle.state.training.hit_count == 1, hero + " one heavy tap never auto-completes second")
		battle.reset_training(hero)
		for tick in range(58): battle.step([{"buttons": Battle.HEAVY if tick in [0, 5] else 0}])
		dummy = battle.state.fighters[1]
		_check(battle.state.training.hit_count == 2 and battle.state.fighters[0].heavy_combo == 2, hero + " fresh buffered heavy tap connects the second stage")
		_check(dummy.z > 0 and dummy.x > 585, hero + " second heavy launches")
		battle.reset_training(hero)
		_advance(battle, 40, Battle.HEAVY)
		_check(battle.state.training.hit_count == 0, hero + " holding K charges without an early strike")
		_advance(battle, 18)
		_check(battle.state.training.hit_count == 1 and battle.state.fighters[0].action == "charged" and battle.state.fighters[0].heavy_combo == 0, hero + " held release is a separate charged strike")
		_check(battle.state.fighters[1].z > 0, hero + " charged strike launches")
	var battle = _training()
	for tick in range(60):
		battle.step([{"buttons": Battle.HEAVY if tick == 0 or (tick >= 5 and tick < 45) else 0}])
	_check(battle.state.training.hit_count == 2 and battle.state.training.last_damage == 43 and battle.state.fighters[0].heavy_combo == 0, "holding buffered K preserves charge duration instead of becoming an automatic second heavy")
	battle.reset_training()
	_advance(battle, 1, Battle.HEAVY)
	_advance(battle, 85)
	_advance(battle, 1, Battle.HEAVY)
	_advance(battle, 1)
	_check(battle.state.fighters[0].heavy_combo == 1, "expired heavy window starts again at stage one")

func _test_reset_and_cancel() -> void:
	var battle = _training()
	var initial: Dictionary = battle.get_state()
	_advance(battle, 1, Battle.LIGHT)
	_advance(battle, 1)
	_advance(battle, 1, Battle.LIGHT)
	battle.cancel_input()
	_advance(battle, 80)
	_check(battle.state.training.hit_count == 0 and battle.state.fighters[0].combo == 0, "input cancellation removes uncommitted light and queued followup")
	_advance(battle, 12, Battle.HEAVY)
	battle.cancel_input()
	_advance(battle, 45)
	_check(battle.state.training.hit_count == 0 and battle.state.fighters[0].action == "idle", "focus-style cancellation never releases a stored charged attack")
	battle.reset_training()
	_check(battle.get_state() == initial, "R-style reset restores dummy, counters, inputs and hero")
	battle.reset_training("oichi")
	_check(battle.state.fighters[0].kind == "oichi" and battle.state.training.hit_count == 0, "switching hero starts fresh Oichi practice")
	battle.reset()
	_check(not battle.state.has("training") and not battle.state.has("mode") and battle.state.fighters[1].kind == "soldier", "return to original battle removes training state")
