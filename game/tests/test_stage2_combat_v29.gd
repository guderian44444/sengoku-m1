extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const Equipment = preload("res://core/equipment.gd")
const Players = preload("res://core/player_store.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func arena(role: String, count: int = 1) -> Battle:
	var battle := Battle.new()
	battle.reset("normal",count,["nobunaga","oichi"],"oda")
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.props = []
	battle.state.drops = []
	battle.state.effects = []
	battle.state.fighters[0].x = 500.0
	battle.state.fighters[0].y = 480.0
	if role != "": battle.state.fighters.append(battle._make_fighter(1,role,580.0,480.0,100))
	return battle

func _initialize() -> void:
	_test_shield()
	_test_fire()
	_test_raider()
	_test_escort()
	_test_boss()
	_test_wire()
	print("STAGE 2 COMBAT V29 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)

func _test_shield() -> void:
	var battle := arena("shield_spear")
	var player: Dictionary = battle.state.fighters[0]
	var guard: Dictionary = battle.state.fighters[-1]
	check(guard.kind == "soldier" and guard.role == "shield_spear","Shield role reuses soldier art and actions")
	var durability: int = Equipment.instance(player,player.weapon_uid).durability
	check(not battle._damage(guard,20,player.id,false,true,false,false,player.x,player.y,"light") and guard.hp == 100,"Frontal light strike is blocked")
	check(Equipment.instance(player,player.weapon_uid).durability == durability,"Blocked strike consumes no weapon durability")
	check(battle.state.events.any(func(e): return e.type == "guard"),"Successful block is visible as a guard event")
	guard.invuln = 0
	check(battle._damage(guard,20,player.id,false,true,false,false,player.x,player.y,"heavy") and guard.hp == 80,"First heavy strike breaks the frontal shield even without knockdown flag")
	check(battle.state.events.any(func(e): return e.type == "guard_break"),"Heavy counter emits a shield break cue")
	guard.action = "idle"
	guard.invuln = 0
	player.x = 660.0
	check(battle._damage(guard,20,player.id,false,true,false,false,player.x,player.y,"light") and guard.hp == 60,"Rear light strike bypasses shield")
	guard.action = "spear_thrust"
	guard.action_tick = 24
	guard.invuln = 0
	player.x = 500.0
	check(battle._damage(guard,10,player.id,false,true,false,false,player.x,player.y,"light"),"Attack recovery exposes shield soldier")
	guard.action = "idle"
	guard.invuln = 0
	battle._try_grab(player)
	check(guard.held_by == player.id and player.grab_target == guard.id,"Shield soldier can be grabbed from the front")
	check(battle._damage(guard,10,player.id,false,true,true,false,player.x,player.y,"light"),"Grabbed shield no longer blocks damage")
	check(Wire.valid_snapshot(battle.state),"Shield/grab result remains valid on the network")

func _test_fire() -> void:
	var battle := arena("fire_archer",2)
	var player: Dictionary = battle.state.fighters[0]
	var archer: Dictionary = battle.state.fighters[-1]
	archer.x = 980.0
	archer.cooldown = 0
	battle._enemy_input(archer)
	check(archer.action == "bow_shot","Fire archer starts an ordinary readable bow windup")
	check(battle.state.effects.any(func(e): return e.type == "arrow_target" and e.get("element","") == "fire" and e.radius == 78.0),"Area warning appears when aiming starts")
	var aim_x: float = player.x
	player.x += 220.0
	archer.action_tick = 30
	battle._tick_enemy_attack(archer)
	var arrow: Dictionary = battle.state.effects.filter(func(e): return e.type == "projectile")[0]
	check(arrow.fire_area and arrow.target_x == aim_x,"Fire arrow keeps the announced point rather than tracking after release")
	check(Wire.valid_snapshot(battle.state),"Announced fire arrow has valid network state")
	for frame in range(arrow.flight_ticks): battle._tick_effects()
	var fires: Array = battle.state.effects.filter(func(e): return e.type == "fire_patch")
	check(fires.size() == 1,"Landing creates one bounded fire area")
	if fires.is_empty(): return
	var patch: Dictionary = fires[0]
	player.x = patch.x
	player.y = patch.y
	player.invuln = 0
	var hp: int = player.hp
	for frame in range(29): battle._tick_effects()
	check(player.hp == hp,"Fire grants another30 ticks to leave before area damage")
	battle._tick_effects()
	check(player.hp == hp-8,"Ground fire applies actual damage at the announced radius")
	check(Wire.valid_snapshot(battle.state),"Live fire damage state passes validation")
	battle.state.fighters.erase(archer)
	check(Wire.valid_snapshot(battle.state),"Lingering fire stays valid after its archer is removed")
	player.invuln = 0
	player.z = 60.0
	for frame in range(45): battle._tick_effects()
	check(player.hp == hp-8,"Jumping above the ground avoids fire damage")
	player.z = 0.0
	player.invuln = 0
	var outside: Dictionary = battle.state.fighters[1]
	outside.x = patch.x + 79.0
	outside.y = patch.y
	var outside_hp: int = outside.hp
	for frame in range(45): battle._tick_effects()
	check(player.hp == hp-16,"Lingering fire damage safely resolves without its original actor")
	check(outside.hp == outside_hp,"Player beyond visible fire radius avoids an actual damage pulse")
	player.x = patch.x + 79.0
	for frame in range(45): battle._tick_effects()
	for frame in range(40): battle._tick_effects()
	check(not battle.state.effects.any(func(e): return e.type == "fire_patch"),"Fire disappears at its fixed lifetime")
	var normal := arena("archer")
	normal._arc_arrow(normal.state.fighters[-1],10)
	var ordinary: Dictionary = normal.state.effects.filter(func(e): return e.type == "projectile")[0]
	check(not ordinary.fire_area,"Existing ordinary archers retain ordinary arrows")

func _test_raider() -> void:
	var slow := arena("commander")
	var quick := arena("raider")
	for battle in [slow,quick]:
		battle.state.fighters[-1].x = 950.0
		battle.state.fighters[-1].cooldown = 0
		battle._enemy_input(battle.state.fighters[-1])
	check(quick.state.fighters[-1].x < slow.state.fighters[-1].x,"Raider closes distance faster than a commander")
	check(quick.state.fighters[-1].y != 480.0 and slow.state.fighters[-1].y == 480.0,"Raider takes a side lane instead of marching straight")
	check(Wire.valid_snapshot(quick.state),"Raider movement has valid state")
	quick.state.fighters[-1].x = 580.0
	quick.state.fighters[-1].y = 480.0
	quick._enemy_melee(quick.state.fighters[-1],145.0,65.0,16)
	check(quick.state.fighters[0].hp == quick.state.fighters[0].max_hp-13,"Fast raider has reduced melee damage")

func _test_escort() -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",2,["nobunaga","oichi"],2)
	check(Wire.valid_snapshot(battle.state),"Chapter2 starts with a valid optional cart")
	var cart: Dictionary = battle.state.challenge
	check(cart.status == "active" and cart.reward == 300,"First scene introduces the optional300 gold escort")
	for player in battle.state.fighters:
		if player.team == 0: player.x = 1000.0
	var start: float = cart.x
	battle._tick_escort()
	check(cart.x == start,"Unattended cart waits instead of completing itself")
	battle.state.fighters[0].x = cart.x + 60
	battle.state.fighters[0].y = cart.y
	battle._tick_escort()
	check(cart.x == start + 1.5,"Living nearby escort moves cart")
	var raider := battle._make_fighter(1,"raider",cart.x+80,cart.y,82)
	raider.cooldown = 0
	battle.state.fighters.append(raider)
	battle.state.fighters[0].x = cart.x-300
	raider.entering = true
	raider.entry_x = raider.x-10.0
	battle._enemy_input(raider)
	check(raider.x < cart.x+80.0,"Entering raider may select cart without requiring hero-only fields")
	raider.entering = false
	battle._enemy_input(raider)
	check(raider.action.begins_with("commander_"),"Nearby raider deliberately attacks cart instead of a distant player")
	var hp: int = cart.hp
	battle._enemy_melee(raider,145,65,16)
	check(cart.hp == hp-13,"Raider attack damages cart")
	battle._enemy_melee(raider,145,65,16)
	check(cart.hp == hp-13,"Cart cooldown prevents stacked instant damage")
	check(Wire.valid_snapshot(battle.state),"Damaged cart has valid wire state")
	battle.state.tick += 90
	battle._enemy_melee(raider,145,65,16)
	check(cart.hp == hp-26,"Cart can be damaged again after90 ticks")
	cart.x = battle.state.stage.encounter_end-80.0
	battle.state.fighters[0].x = cart.x
	battle.state.fighters[0].y = cart.y
	battle._tick_escort()
	check(cart.x == battle.state.stage.encounter_end-80.0,"Cart waits behind a closed checkpoint")
	battle._start_checkpoint(1)
	cart.x = cart.target_x-1
	for player in battle.state.fighters:
		if player.team == 0:
			player.x = cart.x
			player.y = cart.y
			player.gold = 0
	battle.state.fighters[0].gold = 999999950
	for player in battle.state.fighters:
		if player.team == 0:
			player.hp = 0
			player.lives = 0
	battle._tick_escort()
	check(cart.status == "active" and battle.state.fighters[1].gold == 0,"All defeated party cannot finish escort or collect gold")
	for player in battle.state.fighters:
		if player.team == 0:
			player.hp = player.max_hp
			player.lives = 3
	battle._tick_escort()
	check(cart.status == "complete" and battle.state.fighters[0].gold == 1000000000 and battle.state.fighters[1].gold == 300,"Completion rewards both current players and respects the gold cap")
	check(battle.state.events.any(func(e): return e.type == "challenge_complete" and e.amount == 300),"Completion emits a UI event")
	battle._tick_escort()
	check(battle.state.fighters[1].gold == 300,"Completed cart cannot pay twice")
	check(Wire.valid_snapshot(battle.state),"Completed escort reward has valid state")
	var profile_dir := "user://stage2-escort-%d" % Time.get_ticks_usec()
	var profiles := Players.new(profile_dir,"user://stage2-missing-legacy.json")
	for player in battle.state.fighters:
		if player.team == 0: profiles.capture(player)
	check(profiles.save() == OK,"Escort gold can be saved through the actual player store")
	var reloaded := Players.new(profile_dir,"user://stage2-missing-legacy.json")
	check(int(reloaded.character(0,"nobunaga").gold) == 1000000000 and int(reloaded.character(1,"oichi").gold) == 300,"Co-op rewards reload in separate player records")
	battle._enter_segment(2)
	cart = battle.state.challenge
	check(cart.hp == 210 and cart.reward == 450,"Granary has its own larger optional escort")
	raider = battle._make_fighter(1,"raider",cart.x+80,cart.y,82)
	battle.state.fighters.append(raider)
	cart.hp = 1
	battle._enemy_melee(raider,145,65,16)
	check(cart.status == "failed" and cart.hp == 0 and battle.state.phase == "playing","Destroyed cart fails only the optional challenge")
	var gold: int = battle.state.fighters[0].gold
	cart.x = cart.target_x
	battle._tick_escort()
	check(battle.state.fighters[0].gold == gold,"Destroyed cart cannot be rewarded")
	check(Wire.valid_snapshot(battle.state),"Failed optional challenge has valid state")
	battle._enter_segment(3)
	check(not battle.state.has("challenge"),"Leaving an escort scene clears cart state")
	battle.reset_campaign("normal",1,["nobunaga"],1)
	check(not battle.state.has("challenge"),"First chapter does not inherit escort changes")

func _test_boss() -> void:
	var battle := Battle.new()
	battle.boss_intros = {"oda":{"line_key":"wrong_oda_name","ticks":100,"name":"織田"}}
	battle.reset_campaign("normal",1,["nobunaga"],2)
	battle._enter_segment(5)
	battle._start_checkpoint(1)
	battle.state.wave = 2
	battle._spawn_segment_wave()
	var boss: Dictionary = battle.state.fighters.filter(func(f): return f.kind == "boss")[0]
	check(boss.display_name == "佐久間盛重" and boss.boss_variant == "long_yari","Final boss uses the chapter-specific name and long spear")
	check(boss.boss_actions == ["boss_thrust","boss_sweep","boss_dash","boss_double"],"Final boss uses authored supported attacks")
	check(battle.state.intro.line_key == "" and battle.state.intro.line.begins_with("佐久間"),"New boss never speaks another character's fallback name")
	var before: int = battle.state.fighters.size()
	battle.state.tick = battle.state.stage.next_reinforce_tick
	battle._tick_segment()
	check(battle.state.fighters.size() == before+4,"Final boss reinforcement schedule uses the four authored enemies")
	check(battle.state.fighters[-4].get("role","") == "shield_spear" and battle.state.fighters[-2].get("role","") == "raider","Reinforcements preserve new enemy behavior")
	check(Wire.valid_snapshot(battle.state),"Boss and reinforcement snapshot validates")

func _test_wire() -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",1,["nobunaga"],2)
	for field in ["hp","reward","next_hit_tick"]:
		var bad: Dictionary = battle.get_state()
		bad.challenge[field] = -1
		check(not Wire.valid_snapshot(bad),"Reject invalid cart " + field)
	var bad: Dictionary = battle.get_state()
	bad.challenge.status = "complete"
	check(not Wire.valid_snapshot(bad),"Reject completion before cart reaches target")
	bad = battle.get_state()
	bad.challenge.target_x = 999999
	check(not Wire.valid_snapshot(bad),"Reject out-of-stage escort target")
	bad = battle.get_state()
	bad.fighters[0].role = "raider"
	check(not Wire.valid_snapshot(bad),"Player cannot masquerade as an enemy role")
	var fire := arena("fire_archer")
	fire._effect("fire_patch",400.0,480.0,150,{"radius":78.0,"owner":fire.state.fighters[-1].id,"team":1,"damage":8,"warmup":30,"interval":45})
	check(Wire.valid_snapshot(fire.state),"Valid fire patch is accepted")
	for field in ["warmup","interval","radius","damage"]:
		bad = fire.get_state()
		bad.effects[-1][field] = 0
		check(not Wire.valid_snapshot(bad),"Reject unsafe fire " + field)
