extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var snapshots_valid := true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func arena(face: int = 1):
	var battle := Battle.new()
	battle.reset_training("tadakatsu")
	battle.state.props.clear()
	battle.state.fighters.resize(1)
	battle.state.fighters[0].x = 1100.0
	battle.state.fighters[0].face = face
	return battle

func target(battle, x: float, y: float = 480.0) -> Dictionary:
	var fighter: Dictionary = battle._make_fighter(1,"dummy",x,y,1000)
	fighter.home_x = x
	fighter.home_y = y
	battle.state.fighters.append(fighter)
	return fighter

func step(battle, ticks: int = 1, buttons: int = 0, dx: int = 0, dy: int = 0) -> void:
	for tick in range(ticks):
		battle.step([{"buttons":buttons,"dx":dx,"dy":dy}])
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(battle.get_state())

func _initialize() -> void:
	test_rush()
	test_slam()
	test_light()
	test_victory()
	test_interruptions()
	test_grip_alignment()
	check(snapshots_valid,"Every real-input scenario preserves the multiplayer snapshot contract")
	print("V17 TADAKATSU COMBAT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func test_grip_alignment() -> void:
	for kind in ["tadakatsu","nobunaga","oichi"]:
		for face in [-1,1]:
			var battle = arena(face)
			battle.state.fighters[0].kind = kind
			var player: Dictionary = battle.state.fighters[0]
			var victim := target(battle,player.x + face * 80.0)
			step(battle,1,Battle.GRAB)
			var offset := 72.0 if kind == "tadakatsu" else 56.0
			check(player.action == "holding" and victim.held_by == player.id,"Grip remains real input driven for " + kind)
			check(is_equal_approx(victim.x - player.x,face * offset),"Victim meets the character's registered outstretched hand in either facing")
			step(battle,12,Battle.GRAB,face)
			check(is_equal_approx(victim.x - player.x,face * offset),"Moving shield preserves the same hand-to-victim offset")
			step(battle)
			check(player.action == "throw" and victim.action == "thrown" and victim.held_by == 0 and victim.knockback * face > 0,"Release still launches immediately forwards from the held body")

func test_rush() -> void:
	for face in [-1,1]:
		var battle = arena(face)
		var player: Dictionary = battle.state.fighters[0]
		step(battle,40,Battle.HEAVY)
		step(battle)
		check(player.action == "charged","Neutral full heavy charge starts the forward spear rush")
		var start: float = player.x
		var hit_ticks := []
		var last_x: float = player.x
		var last_camera: float = player.x - 540.0
		for tick in range(1,Battle.hero_tick("tadakatsu",36) + 1):
			step(battle)
			var delta: float = (player.x - last_x) * face
			var camera: float = clampf(player.x - 540.0,0.0,1100.0)
			check(delta > 0 and delta < 9.0 if tick <= Battle.hero_tick("tadakatsu",15) else is_zero_approx(delta),"Rush movement advances continuously only during its active window")
			check(absf(camera - last_camera) < 9.0,"The actual following-camera formula cannot inherit a 52px rush jump")
			for event in battle.state.events:
				if event.type == "weapon_swing" and event.actor == player.id: hit_ticks.append(tick)
			last_x = player.x
			last_camera = camera
		check(is_equal_approx((player.x - start) * face,156.0),"Rush retains its intended total distance in both facings")
		check(hit_ticks == [Battle.hero_tick("tadakatsu",5),Battle.hero_tick("tadakatsu",10),Battle.hero_tick("tadakatsu",15)],"Three authored thrust contacts retain their original attack timings")
		check(player.action == "idle","Rush returns to idle after its recovery")
	var edge = arena()
	edge.state.fighters[0].x = 2290.0
	step(edge,40,Battle.HEAVY)
	step(edge,46)
	check(edge.state.fighters[0].x == 2300.0,"Continuous rush still obeys the arena boundary")

func test_slam() -> void:
	for face in [-1,1]:
		for powered in [false,true]:
			var battle = arena(face)
			var player: Dictionary = battle.state.fighters[0]
			var left := target(battle,1000.0)
			var right := target(battle,1200.0)
			var far := target(battle,1800.0)
			var origin := Vector2(player.x,player.y)
			step(battle,40 if powered else 1,Battle.HEAVY,0,1)
			check(player.action == "charge" and player.charge_direction == 1,"Down-heavy holds the upright spear preparation")
			step(battle)
			var action := "charged_slam" if powered else "ground_slam"
			var hit := Battle.hero_tick("tadakatsu",28 if powered else 14)
			check(player.action == action,"Down-heavy release selects " + action)
			step(battle,hit - 1)
			check(battle.state.effects.is_empty(),"Spear-butt shockwave waits for ground contact")
			step(battle)
			var waves: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave")
			check(waves.size() == 1,"Spear ground contact emits exactly one shockwave")
			if waves.size() != 1: continue
			var wave: Dictionary = waves[0]
			check(Vector2(wave.x,wave.y).is_equal_approx(origin) and wave.arc_degrees == 360.0 and wave.element == "earth","Wave expands from beneath the spear bearer in every direction")
			check(wave.charged == powered and wave.knockdown,"Powered state and knockdown survive network serialization")
			check(is_equal_approx(wave.radius,(320.0 if powered else 240.0) * sqrt(Battle.HERO_PROFILES.tadakatsu.reach)),"Wave radius follows the same bounded character scaling as existing heroes")
			step(battle,16)
			check(left.hp < 1000 and right.hp < 1000 and left.knockback < 0 and right.knockback > 0,"Nearby troops on both sides are knocked outward")
			check(left.airborne_lock and right.airborne_lock,"Both nearby troops are genuinely launched by the shockwave")
			check(far.hp == 1000,"The shockwave cannot hit troops beyond its limited radius")
			check(Vector2(player.x,player.y).is_equal_approx(origin),"Ground slam plants the player instead of moving the camera")

func test_light() -> void:
	for combo in [1,2,3]:
		var battle = arena()
		var player: Dictionary = battle.state.fighters[0]
		player.combo = combo
		player.combo_tick = 42
		battle._begin(player,"light")
		step(battle,Battle.hero_tick("tadakatsu",6))
		var swings: Array = battle.state.events.filter(func(e: Dictionary) -> bool: return e.type == "weapon_swing" and e.actor == player.id)
		var slashes: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "slash")
		check(swings.size() == 1 and slashes.size() == 1,"Each spear light contact executes once rather than falling through to generic sword logic")
		check(is_equal_approx(player.x,1142.0 if combo == 3 else 1100.0),"Only the third spear light advances one step")

func test_victory() -> void:
	var battle = arena()
	var player: Dictionary = battle.state.fighters[0]
	battle.state.phase = "won"
	step(battle)
	check(player.action == "victory" and player.action_tick == 0,"Honda victory starts from its first drawing")
	step(battle,130,Battle.HEAVY,1,1)
	check(player.action_tick == Battle.VICTORY_TICKS and player.x == 1100.0,"Honda completes and holds victory without accepting combat input")

func test_interruptions() -> void:
	var held = arena()
	var player: Dictionary = held.state.fighters[0]
	step(held,90,Battle.HEAVY,0,1)
	check(player.action == "charge" and player.charge >= 35 and held.state.effects.is_empty(),"A fully charged downward spear can remain held without automatically attacking")
	step(held,1,Battle.CANCEL)
	check(player.action == "idle" and player.charge == 0,"Input cancellation clears the held spear charge")
	step(held,100)
	check(held.state.effects.is_empty() and player.action == "idle","Cancelled charge cannot leak a delayed slam")
	for released in [false,true]:
		for direction in [0,1]:
			var battle = arena()
			player = battle.state.fighters[0]
			var enemy := target(battle,1800)
			step(battle,40,Battle.HEAVY,0,direction)
			if released:
				step(battle)
				step(battle,3)
			var position: float = player.x
			check(battle._damage(player,10,enemy.id,false),"An ordinary accepted hit can interrupt a charge or its unreleased attack windup")
			check(player.action == "hurt","Interrupted spear bearer enters the real hurt action")
			var late_attacks := []
			for tick in range(100):
				step(battle)
				for event in battle.state.events:
					if event.actor == player.id and event.type == "weapon_swing": late_attacks.append(event)
			check(late_attacks.is_empty(),"An interrupted spear move cannot emit its cancelled contacts later")
			check(is_equal_approx(position,player.x) and player.action == "idle","Interrupting a rush stops further authored movement and recovers normally")
