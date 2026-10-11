extends SceneTree

const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var sheets := {"v12_launched":range(12),"v12_down":range(12),"v12_recovering":range(12),"v12_throw":range(12)}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func sample(fighter: Dictionary) -> Dictionary:
	return Frames.hero_v12_sample(fighter,0,155,sheets)

func _initialize() -> void:
	for hero in ["nobunaga","oichi"]:
		for lethal in [false,true]:
			test_landing(hero,lethal)
	test_throw()
	test_wire()
	print("V12 LANDING TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func test_landing(hero: String, lethal: bool) -> void:
	var battle := Battle.new()
	battle.reset("normal",2,[hero,"oichi" if hero == "nobunaga" else "nobunaga"])
	battle.state.props = []
	battle.state.drops = []
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[2]
	for fighter in battle.state.fighters:
		if fighter.team == 1:
			fighter.cooldown = 10000
			fighter.x = 2200
	check(not player.down_from_air,"New fighters start without landing history")
	battle._launch(player,1,0,3)
	if lethal:
		battle._damage(player,10000,enemy.id,false)
		check(player.action == "defeated","Lethal air hit uses the real defeated state")
	var flight_ok := true
	var valid_wire := true
	for tick in range(120):
		if not player.airborne_lock: break
		flight_ok = flight_ok and sample(player).sheet == "v12_launched" and not player.down_from_air
		battle.step([])
		valid_wire = valid_wire and Wire.valid_snapshot(battle.get_state())
	check(flight_ok,"Alive and defeated heroes keep airborne drawings through every bounce")
	check(valid_wire,"Flight and landing snapshots remain valid")
	check(not player.airborne_lock and player.landing_count == 3,"The real launch finishes all three contacts")
	check(player.down_from_air,"Only final touchdown marks the settled fall")
	var landed := sample(player)
	check(landed.sheet == "v12_down" and landed.frame >= 6,"Landing never replays a standing fall pose")
	check(player.action_tick <= 1,"The landing fix does not skip simulation time")
	if lethal:
		for tick in range(24): battle.step([])
		check(sample(player).frame == 11,"Defeated hero remains in the final flat pose")
		return
	check(player.down_ticks == Battle.DOWN_TICKS,"Knockdown duration is unchanged")
	for tick in range(Battle.DOWN_TICKS - int(player.action_tick) - 1): battle.step([])
	check(player.action == "down","Hero stays down for the full original duration")
	battle.step([])
	check(player.action == "recovering" and not player.down_from_air,"Starting recovery clears the landing flag")
	for tick in range(Battle.RECOVER_TICKS): battle.step([])
	check(player.action == "idle","Recovery still lasts its original duration")
	battle._damage(player,1,enemy.id,true)
	check(player.action == "down" and not player.down_from_air,"A later ground hit cannot inherit an old landing")
	check(sample(player).frame == 0,"A fresh ground knockdown retains its complete falling sequence")

func test_throw() -> void:
	var battle := Battle.new()
	battle.reset_training("nobunaga")
	var player: Dictionary = battle.state.fighters[0]
	var target: Dictionary = battle.state.fighters[1]
	target.x = player.x + 60
	target.y = player.y
	battle._try_grab(player)
	check(player.action == "holding" and sample(player).frame == 0,"Holding still starts in its first preparation pose")
	player.action_tick = 25
	check(sample(player).frame == 5,"Holding still holds its final preparation pose")
	battle._release_grab(player,true)
	var release := sample(player)
	check(target.airborne_lock and player.action == "throw","The grab release launches the target immediately")
	check(release.frame == 6 and release.released and release.duration == 24,"Throw starts at its actual release drawing")
	for tick in range(23): battle.step([])
	check(player.action == "throw" and sample(player).frame == 11,"Throw reaches its final recovery drawing before it ends")
	battle.step([])
	check(player.action == "idle","Throw keeps its original 24-tick gameplay duration")

func test_wire() -> void:
	var state: Dictionary = Battle.new().get_state()
	state.fighters[0].down_from_air = true
	check(Wire.valid_snapshot(state),"Wire accepts the boolean landing marker")
	for malformed in [1,"true",[]]:
		state.fighters[0].down_from_air = malformed
		check(not Wire.valid_snapshot(state),"Wire rejects non-boolean landing markers")
	state.fighters[0].erase("down_from_air")
	check(Wire.valid_snapshot(state),"Older snapshots without the optional marker remain compatible")
