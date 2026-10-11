extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_weapon_ranges()
	_test_expanded_sword_geometry()
	_test_specials()
	_test_holding_and_shields()
	_test_grab_reach()
	_test_timeout_and_lifecycle()
	_test_wire_and_fixture()
	print("V06 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _arena(hero: String = "nobunaga", distance: float = 60.0):
	var battle = Battle.new()
	battle.reset_training(hero)
	battle.state.erase("training")
	battle.state.erase("mode")
	battle.state.fighters[1].x = 500.0 + distance
	return battle

func _advance(battle, frames: int, buttons: int = 0) -> Array:
	var events: Array = []
	for tick in range(frames):
		battle.step([{"buttons": buttons}])
		events.append_array(battle.state.events)
	return events

func _actor(battle, x: float, kind: String = "soldier") -> Dictionary:
	var actor: Dictionary = battle._make_fighter(1, kind, x, 480.0, 1000)
	actor.action = "stunned"
	actor.stun = 10000
	battle.state.fighters.append(actor)
	return actor

func _test_weapon_ranges() -> void:
	var short = _arena("oichi", 320)
	_advance(short, 1, Battle.LIGHT)
	_advance(short, 70)
	_check(short.state.fighters[1].hp == 1000, "needle stops short of a target 320 pixels away")
	var near = _arena("oichi", 230)
	_advance(near, 1, Battle.LIGHT)
	_advance(near, 30)
	_check(near.state.fighters[1].hp == 991, "needle still hits inside its short range")
	var bow = _arena("oichi", 600)
	_advance(bow, 1, Battle.HEAVY)
	var bow_events := _advance(bow, 60)
	_check(bow.state.fighters[1].hp == 976, "unpowered longbow reaches beyond needle range")
	_check(bow_events.any(func(event: Dictionary) -> bool: return event.type == "bow_release"), "longbow produces a dedicated release event")
	_check(bow_events.any(func(event: Dictionary) -> bool: return event.type == "heavy_hit"), "longbow impact uses the distinct heavy-hit event even after its startup ends")
	var charged = _arena("oichi", 1350)
	_advance(charged, 40, Battle.HEAVY)
	_advance(charged, 80)
	_check(charged.state.fighters[1].hp == 957, "charged bow crosses more than a 1280-pixel screen")
	var narrow = _arena()
	narrow.state.fighters[1].y += 45.0
	_advance(narrow, 1, Battle.LIGHT)
	_advance(narrow, 18)
	_check(narrow.state.fighters[1].hp == 1000, "straight downcut misses outside its narrow lane")
	for tick in range(30): narrow.step([{"buttons": Battle.LIGHT if tick in [0, 4] else 0}])
	_check(narrow.state.fighters[1].hp == 982, "wide third sweep reaches a lane the first two cuts miss")
	for weight in ["light", "heavy"]:
		var battle = _arena()
		battle.state.fighters[1].weight = weight
		for tick in range(36): battle.step([{"buttons": Battle.LIGHT if tick in [0, 4] else 0}])
		_check((battle.state.fighters[1].z > 0) == (weight == "light"), "uppercut respects " + weight + " target weight")
	var chain = _arena()
	for tick in range(48): chain.step([{"buttons": Battle.LIGHT if tick in [0, 4, 24] else 0}])
	_check(chain.state.fighters[1].hp == 952, "uppercut into third sweep lands all three hits")

func _test_expanded_sword_geometry() -> void:
	for spec in [
		["light", 110.0, 30.0, 14],
		["uppercut", 130.0, 42.0, 16],
		["sweep", 260.0, 85.0, 18],
		["heavy", 140.0, 68.0, 26],
		["charged", 255.0, 90.0, 43],
	]:
		for outside in [false, true]:
			var battle = _arena("nobunaga", spec[1] + (0.1 if outside else 0.0))
			if spec[0] == "sweep": battle.state.fighters[1].x += 42.0
			battle.state.fighters[1].y += spec[2]
			match spec[0]:
				"light":
					_advance(battle, 1, Battle.LIGHT)
					_advance(battle, 8)
				"uppercut":
					for tick in range(30): battle.step([{"buttons": Battle.LIGHT if tick in [0, 4] else 0}])
				"sweep":
					for tick in range(48): battle.step([{"buttons": Battle.LIGHT if tick in [0, 4, 24] else 0}])
				"heavy":
					_advance(battle, 1, Battle.HEAVY)
					_advance(battle, 16)
				"charged":
					_advance(battle, 40, Battle.HEAVY)
					_advance(battle, 16)
			var expected: int = 1000 if outside else 1000 - int(spec[3])
			_check(battle.state.fighters[1].hp == expected, str(spec[0]) + (" rejects beyond expanded reach" if outside else " hits the expanded reach and lane boundary"))

func _test_specials() -> void:
	for hero in ["nobunaga", "oichi"]:
		var battle = _arena(hero)
		var player: Dictionary = battle.state.fighters[0]
		player.rage = 100
		player.poison = 90
		player.poison_owner = battle.state.fighters[1].id
		_advance(battle, 1, Battle.SPECIAL)
		var immune := true
		for tick in range(Battle.SPECIAL_TICKS - 1):
			immune = immune and not battle._damage(player, 10, battle.state.fighters[1].id, true)
			battle.step([])
		_check(immune and player.hp == player.max_hp and player.action == "special", hero + " special is invulnerable through every animation tick including poison")
		battle.step([])
		_check(battle._damage(player, 10, battle.state.fighters[1].id, false), hero + " invulnerability ends with the special action")
	var sword = _arena()
	var behind := _actor(sword, 280.0)
	var distant := _actor(sword, 1500.0)
	behind.y = 570.0
	_advance(sword, 1, Battle.SPECIAL)
	_advance(sword, 30)
	_check(behind.hp < 1000 and behind.burn > 0 and distant.hp == 1000, "Nobunaga special setup burns both sides and respects its area")
	_advance(sword, 164)
	_check(behind.z > 0 and distant.hp == 1000, "Nobunaga final special pulse launches without reaching beyond its area")
	var bow = _arena("oichi")
	var distant_a := _actor(bow, 1100.0)
	var distant_b := _actor(bow, 1650.0)
	_advance(bow, 1, Battle.SPECIAL)
	_advance(bow, 82)
	_check(distant_a.hp < 1000 and distant_b.hp < 1000, "Oichi special pierces multiple targets across the screen")
	_check(distant_b.action == "frozen" and distant_b.freeze > 0, "Oichi special freezes distant targets")
	# Isolate the original stun lifecycle from ongoing ice volleys.
	bow.state.effects.clear()
	bow._begin(bow.state.fighters[0], "idle")
	distant_b.freeze = 0
	distant_b.stun = 80
	bow._begin(distant_b, "stunned")
	distant_b.invuln = 0
	bow._damage(distant_b, 5, bow.state.fighters[0].id, false)
	var stun_before: int = distant_b.stun
	_advance(bow, 20)
	_check(distant_b.stun == maxi(0, stun_before - 20) and distant_b.action == "stunned", "stun continues counting and suppressing AI after an additional hit reaction")
	_advance(bow, 90)
	_check(distant_b.stun == 0 and distant_b.action != "stunned", "interrupted stun expires without a permanent visual status")

func _test_holding_and_shields() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var body: Dictionary = battle.state.fighters[1]
	# Keep this shield test on the surviving half; v14 tests both escape outcomes separately.
	while ((battle.state.tick + 31) * 17 + player.id * 13 + body.id * 7) % 100 < 50: battle.state.tick += 1
	_advance(battle, 1, Battle.GRAB)
	_check(player.action == "holding" and body.action == "grabbed" and body.hp == 1000 and body.held_by == player.id, "holding L grabs without damage or an automatic throw")
	var x: float = player.x
	battle.step([{"dx": 1, "buttons": Battle.GRAB}])
	_check(is_equal_approx(player.x - x, 3.5 * 0.45) and is_equal_approx(body.x - player.x, 56.0), "holder moves slowly with the grabbed body attached")
	var archer := _actor(battle, 850.0, "archer")
	archer.face = -1
	battle._projectile(archer, 9, 0, false, "arrow", 700.0)
	var events := _advance(battle, 75, Battle.GRAB)
	_check(player.hp == player.max_hp and body.hp == 991 and player.action == "holding", "frontal arrow damages the held enemy instead of the player")
	_check(events.any(func(event: Dictionary) -> bool: return event.type == "shield_hit"), "shield impact emits a pain event")
	archer.kind = "soldier"
	archer.x = player.x + 75.0
	archer.target_x = player.x + 20.0
	archer.target_y = player.y
	battle._enemy_strike(archer, 85, 42, 10)
	_check(body.hp == 981 and player.hp == player.max_hp, "held enemy also absorbs a frontal small melee attack")
	archer.x = player.x - 250.0
	archer.face = 1
	battle._projectile(archer, 9, 0, false, "arrow", 700.0)
	_advance(battle, 60, Battle.GRAB)
	_check(player.hp < player.max_hp and player.grab_target == 0, "a rear arrow bypasses the shield and breaks the hold")
	var throwing = _arena()
	var collision_target := _actor(throwing, 665.0)
	_advance(throwing, 1, Battle.GRAB)
	_advance(throwing, 1)
	var thrown: Dictionary = throwing.state.fighters[1]
	_check(thrown.action == "thrown" and thrown.hp == 969 and thrown.thrown_by == throwing.state.fighters[0].id, "releasing L damages and launches the held target")
	_advance(throwing, 10)
	_check(collision_target.hp == 978 and collision_target.z > 0, "thrown body knocks down a second small enemy")
	_advance(throwing, 30)
	_check(collision_target.hp == 978 and thrown.throw_ticks == 0 and thrown.thrown_by == 0, "one throw cannot damage the same collision target repeatedly")

func _test_timeout_and_lifecycle() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var body: Dictionary = battle.state.fighters[1]
	while ((battle.state.tick + 31) * 17 + player.id * 13 + body.id * 7) % 100 < 50: battle.state.tick += 1
	_advance(battle, 1, Battle.GRAB)
	_advance(battle, 179, Battle.GRAB)
	_check(player.action == "holding" and player.action_tick == 179, "hold remains active at tick 179")
	battle._damage(body, 2, 999, false, true, true)
	_check(player.action_tick == 179, "shield damage never resets the holder timeout")
	_advance(battle, 1, Battle.GRAB)
	_check(player.action == "idle" and body.held_by == 0 and body.throw_ticks == 0 and body.hp == 998, "tick 180 safely drops the shield without throwing")
	_advance(battle, 30, Battle.GRAB)
	_check(player.grab_target == 0, "continuing to hold L after timeout cannot immediately re-grab")
	_advance(battle, Battle.DOWN_TICKS + Battle.RECOVER_TICKS - 30, Battle.GRAB)
	_advance(battle, 1)
	_advance(battle, 1, Battle.GRAB)
	_check(player.grab_target == body.id, "a fresh press can grab again after the dropped victim stands up")
	var before_hp: int = body.hp
	battle.step([{"dx": 1, "buttons": Battle.CANCEL | Battle.GRAB | Battle.LIGHT}])
	_check(player.action == "idle" and player.grab_target == 0 and body.hp == before_hp and body.throw_ticks == 0, "CANCEL dominates all attack bits and safely drops the body")
	_advance(battle, Battle.DOWN_TICKS + Battle.RECOVER_TICKS)
	_advance(battle, 1, Battle.GRAB)
	body.kind = "soldier"
	body.hp = 1
	body.stun = 20
	battle._damage(body, 10, 999, false, true, true)
	_check(body.hp == 0 and body.action == "defeated" and player.grab_target == 0 and body.held_by == 0, "shield KO clears both sides of the grab link")
	_check(body.stun == 0 and body.shield_hurt_tick == 0 and body.invuln == 0, "KO clears temporary stun and shield pain instead of leaving permanent corpse effects")
	var holder_ko = _arena()
	_advance(holder_ko, 1, Battle.GRAB)
	holder_ko.state.fighters[0].hp = 1
	holder_ko._damage(holder_ko.state.fighters[0], 10, 999, false)
	_check(holder_ko.state.fighters[0].action == "defeated" and holder_ko.state.fighters[1].held_by == 0, "holder KO drops the body and preserves defeated state")
	var reset = _arena()
	_advance(reset, 1, Battle.GRAB)
	reset.reset()
	_check(reset.state.fighters.all(func(f: Dictionary) -> bool: return f.grab_target == 0 and f.held_by == 0), "reset clears every grab relationship")
	var coop = Battle.new()
	coop.reset("normal", 2)
	coop.state.fighters[0].x = 500.0
	coop.state.fighters[1].x = 505.0
	coop.state.fighters[0].y = 480.0
	coop.state.fighters[1].y = 480.0
	coop.state.fighters[2].x = 550.0
	coop.state.fighters[2].y = 480.0
	coop.step([{"buttons": Battle.GRAB}, {"buttons": Battle.GRAB}])
	_check(coop.state.fighters[2].held_by == coop.state.fighters[0].id and coop.state.fighters[1].grab_target == 0, "two players cannot grab the same enemy")

func _test_grab_reach() -> void:
	var wide = _arena("nobunaga", 104.0)
	wide.state.fighters[1].y += 55.0
	_advance(wide, 1, Battle.GRAB)
	_check(wide.state.fighters[0].grab_target != 0, "grab reaches 104 pixels forward and the full 55-pixel lane tolerance")
	for position in [Vector2(106, 0), Vector2(80, 56), Vector2(-13, 0)]:
		var outside = _arena()
		outside.state.fighters[1].x = 500.0 + position.x
		outside.state.fighters[1].y = 480.0 + position.y
		_advance(outside, 1, Battle.GRAB)
		_check(outside.state.fighters[0].grab_target == 0, "grab excludes outside boundary " + str(position))
	var nearest = _arena("nobunaga", 100.0)
	var near := _actor(nearest, 550.0)
	_advance(nearest, 1, Battle.GRAB)
	_check(nearest.state.fighters[0].grab_target == near.id, "grab chooses nearest eligible target instead of first array entry")
	for kind in ["airborne", "boss", "heavy"]:
		var excluded = _arena()
		if kind == "airborne": excluded.state.fighters[1].z = 20.0
		elif kind == "boss": excluded.state.fighters[1].kind = "boss"
		else: excluded.state.fighters[1].weight = "heavy"
		_advance(excluded, 1, Battle.GRAB)
		_check(excluded.state.fighters[0].grab_target == 0, "grab still excludes " + kind)

func _test_wire_and_fixture() -> void:
	_check(Wire.valid_input({"dx": 0, "dy": -1, "buttons": 127}), "wire accepts the cancel bit plus existing controls")
	_check(not Wire.valid_input({"dx": 0, "dy": 0, "buttons": 256}), "wire rejects bits beyond the new guard control")
	_check(not Wire.valid_input({"dx": true, "dy": 0, "buttons": 0}), "wire rejects coercible input types")
	var battle = _arena()
	_advance(battle, 1, Battle.GRAB)
	_check(Wire.valid_snapshot(battle.get_state()), "valid bidirectional hold serializes")
	var invalid: Dictionary = battle.get_state()
	invalid.fighters[1].held_by = 99999
	_check(not Wire.valid_snapshot(invalid), "wire rejects an orphan held-by reference")
	for pair in [["weight", "unknown"], ["stun", "3"], ["shield_hurt_tick", -1], ["throw_hits", ["1"]]]:
		invalid = battle.get_state()
		invalid.fighters[1][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(invalid), "wire rejects invalid fighter " + str(pair[0]))
	var archer := _actor(battle, 950, "archer")
	battle._projectile(archer, 9, 0, false, "arrow", 700)
	for pair in [["weapon", "unknown"], ["range_left", NAN], ["hit_depth", -1], ["piercing", "yes"], ["hit_ids", [0]]]:
		invalid = battle.get_state()
		invalid.effects[-1][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(invalid), "wire rejects invalid projectile " + str(pair[0]))
	battle.reset_training("nobunaga", "shield")
	_check(battle.state.training.drill == "shield" and battle.state.fighters.size() == 4, "shield drill includes dummy, light soldier and archer")
	var valid := true
	for tick in range(450):
		battle.step([])
		valid = valid and Wire.valid_snapshot(battle.get_state())
	_check(valid and battle.state.phase == "playing" and battle.state.fighters[0].hp > 0, "shield fixture remains playable and wire-valid through real enemy attacks")
