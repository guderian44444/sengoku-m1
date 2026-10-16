extends SceneTree
# v34 locks the original two-hero tuning; delivered heroes have their own v36 regression.

const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Wire = preload("res://core/wire.gd")
const Frames = preload("res://render/frame_animation.gd")
var checks := 0
var failures := 0
var records: Array = []
var combo_records: Array = []

class LegacyPushBattle extends Battle:
	func _combat_push_v33(fighter: Dictionary, reach: float, depth: float, speed: float) -> void:
		super._combat_push_v33(fighter,reach,depth,5 if fighter.action == "light" else speed)

class ReleaseBattle extends Battle:
	var contacts: Array = []
	func _combat_contact_v33(fighter: Dictionary, event: String) -> void:
		if event.begins_with("contact") or event == "projectile_release": contacts.append({"action":fighter.action,"face":fighter.face,"tick":state.tick})
		super._combat_contact_v33(fighter,event)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(hero: String, weapon: String = "", charm: String = "", distance: float = 70, legacy_push: bool = false) -> Battle:
	var battle := LegacyPushBattle.new() if legacy_push else Battle.new()
	battle.reset_training(hero)
	battle.state.props.clear()
	battle.state.effects.clear()
	var player: Dictionary = battle.state.fighters[0]
	if weapon != "": Equipment.equip(player,Equipment.add(player,weapon))
	if charm != "": Equipment.equip(player,Equipment.add(player,charm))
	var target: Dictionary = battle.state.fighters[1]
	target.x = player.x+distance
	target.hp = 100000
	target.max_hp = 100000
	return battle

func start(battle: Battle, action: String, combo: int = 1) -> void:
	var player: Dictionary = battle.state.fighters[0]
	player.combo = combo
	player.combo_tick = 600
	if action.begins_with("air_"):
		player.z = 50.0
		player.combat_air_start = 50.0
	battle._begin(player,action)

func measure(hero: String, action: String, distance: float = 70, weapon: String = "", charm: String = "", combo: int = 1) -> Dictionary:
	var battle := fresh(hero,weapon,charm,distance)
	var player: Dictionary = battle.state.fighters[0]
	var target: Dictionary = battle.state.fighters[1]
	start(battle,action,combo)
	var recovery := 0
	var contact := 0
	var first_damage := 0
	var max_reach := 0.0
	var start_x := float(player.x)
	for tick in range(1,241):
		battle.state.tick = tick
		battle._tick_effects()
		battle._tick_motion(target)
		battle._tick_fighter(target)
		if recovery == 0:
			battle._tick_motion(player)
			battle._tick_fighter(player)
			if player.action == "idle": recovery = tick
		for effect in battle.state.effects:
			if effect.type == "projectile": max_reach = maxf(max_reach,absf(effect.x-player.x)+effect.range_left)
			elif effect.type in ["sky_arrow","arrow_rain"]: max_reach = maxf(max_reach,float(effect.radius))
		max_reach = maxf(max_reach,float(player.get("attack_reach",0)))
		if contact == 0 and target.hp < 100000:
			contact = tick
			first_damage = 100000-int(target.hp)
		if recovery > 0 and not battle.state.effects.any(func(e): return e.type in ["projectile","sky_arrow","arrow_rain"]): break
	var charge_ticks := ceili(float(Moves.registration(hero).clips.charge_ready.duration_ms)*.06) if action in ["charged","charge_rain"] else 0
	var damage := 100000-int(target.hp)
	return {"hero":hero,"action":action,"combo":combo,"weapon":player.weapon_id,"charm":charm,"damage":damage,"first_damage":first_damage,"first_hit_ticks":contact+charge_ticks,"recovery_ticks":recovery+charge_ticks,"dps":float(damage)*60/maxi(1,recovery+charge_ticks),"reach":max_reach,"distance":distance,"step":player.x-start_x}

func projectile_range_tests() -> void:
	for weapon in Weapons.ids_for("oichi"):
		for action in ["heavy","charged"]:
			var row := measure("oichi",action,500,weapon,"moon")
			var intended := (1450.0 if action == "charged" else 760.0)+float(Weapons.item(weapon).get("reach_bonus",0))+12
			check(is_equal_approx(row.reach,intended),"Bow range matches registered equipment after hand-anchor adjustment: "+weapon+"/"+action)
	for weapon in Weapons.ids_for("nobunaga"):
		var row := measure("nobunaga","heavy",270,weapon,"moon")
		var intended := 290.0+float(Weapons.item(weapon).get("reach_bonus",0))+12
		check(is_equal_approx(row.reach,intended),"Sword wave retains weapon and charm reach: "+weapon)
		var edge_hit := measure("nobunaga","heavy",intended+20,weapon,"moon")
		check(edge_hit.damage > 0,"Sword-wave lifetime reaches the last swept collision segment: "+weapon)
	var edge := measure("oichi","heavy",780)
	check(edge.damage == 24,"Ordinary arrow hits a body overlapping the final part of its advertised 760px range")
	var outside := measure("oichi","heavy",800)
	check(outside.damage == 0,"Ordinary arrow cannot exceed its range plus target body width")

func regressions() -> void:
	for hero in ["nobunaga","oichi"]:
		for weapon in Weapons.ids_for(hero):
			var battle := fresh(hero,weapon)
			var player: Dictionary = battle.state.fighters[0]
			var stats := Battle.character_stats(player)
			var row := measure(hero,"heavy" if hero == "oichi" else "light",200 if hero == "oichi" else 70,weapon)
			check(row.first_damage == stats.damage,"Displayed baseline hit matches live v33 damage: "+weapon)
			check(is_equal_approx(row.reach,stats.reach),"Displayed baseline range matches live v33 range: "+weapon)
	var rear := fresh("nobunaga","","",-100)
	start(rear,"charged")
	for tick in range(12):
		rear.state.tick += 1
		rear._tick_fighter(rear.state.fighters[0])
	check(rear.state.fighters[1].hp < 100000 and rear.state.fighters[1].knockback < 0,"Full-circle charged hit launches rear enemies away from the player")
	for hero in ["nobunaga","oichi"]:
		for facing in [-1,1]:
			for distance in [70,85]:
				for legacy_push in [true,false]:
					var chain := fresh(hero,"","",distance*facing,legacy_push)
					var player: Dictionary = chain.state.fighters[0]
					player.face = facing
					for stage in range(3):
						chain.step([{"buttons":Battle.LIGHT}])
						for tick in range(120):
							chain.step([{}])
							if player.action == "idle": break
					combo_records.append({"hero":hero,"facing":facing,"distance":distance,"legacy_push":legacy_push,"hits":chain.state.training.hit_count,"damage":chain.state.training.total_damage,"ticks":chain.state.tick,"launched":chain.state.fighters[1].airborne_lock})
					if legacy_push: continue
					check(chain.state.training.hit_count == 3 and chain.state.training.total_damage == 54,"A three-press combo keeps a nearby target in range without repositioning it: "+hero+"/"+str(facing)+"/"+str(distance))
					check(chain.state.fighters[1].airborne_lock,"The real third combo hit launches its target: "+hero)
		for weapon in [Weapons.default_for(hero),Weapons.ids_for(hero)[-1]]:
			for early in [true,false]:
				var charge := fresh(hero,weapon,"marici")
				var player: Dictionary = charge.state.fighters[0]
				charge.step([{"buttons":Battle.HEAVY}])
				var threshold := ceili(float(Moves.registration(hero).clips.charge_ready.duration_ms)*.06)
				for tick in range(threshold-(2 if early else 1)): charge.step([{"buttons":Battle.HEAVY}])
				charge.step([{}])
				check(player.action == ("heavy" if early else "charged"),"Charge threshold follows the authored ready pose even with attack-speed equipment: "+weapon)

func light_cadence_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for weapon in Weapons.ids_for(hero):
			for stage in [1,2,3]:
				var battle := fresh(hero,weapon)
				var player: Dictionary = battle.state.fighters[0]
				start(battle,"light",stage)
				var row := measure(hero,"light",70,weapon,"",stage)
				check(row.first_hit_ticks == roundi(Battle.fighter_tick(player,6)*1.3),"Light contact takes 30 percent longer: "+hero+"/"+weapon+"/"+str(stage))
				check(row.recovery_ticks == roundi(Battle.fighter_tick(player,19)*1.3),"Light recovery takes 30 percent longer: "+hero+"/"+weapon+"/"+str(stage))
		var chain := fresh(hero)
		var player: Dictionary = chain.state.fighters[0]
		for tick in range(62):
			chain.step([{"buttons":Battle.LIGHT if tick in [0,3,21] else 0}])
			if tick in [18,36]:
				check(player.action == "light" and player.combo == (2 if tick == 18 else 3) and player.action_tick == 0,"Buffered light cancels recovery after contact and commitment: "+hero)
		check(player.action == "idle" and chain.state.training.hit_count == 3 and chain.state.training.total_damage == 54,"Three buffered lights finish in 61 ticks with three hits and unchanged damage: "+hero)
		check(chain.state.fighters[1].airborne_lock,"Fast third hit still launches: "+hero)
		var interrupted := fresh(hero)
		var interrupted_player: Dictionary = interrupted.state.fighters[0]
		interrupted.step([{"buttons":Battle.LIGHT}])
		interrupted.step([{}])
		interrupted.step([{"buttons":Battle.LIGHT}])
		interrupted_player.invuln = 0
		interrupted._damage(interrupted_player,1,interrupted.state.fighters[1].id,false)
		for tick in range(45): interrupted.step([{}])
		check(interrupted_player.action == "idle" and interrupted.state.training.hit_count == 0,"Being hit cancels buffered light; no delayed automatic attack: "+hero)

func action_chain_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for action in ["light","heavy","charged","dash_heavy","air_light","air_heavy"]:
			var battle := fresh(hero)
			var player: Dictionary = battle.state.fighters[0]
			start(battle,action)
			var spec := Moves.spec(player)
			var original_id := int(player.attack_id)
			var contact := 0.0
			for event in spec.events: contact = maxf(contact,float(event.ms))
			var contact_tick := 8 if action == "light" else (6 if hero == "oichi" and action == "air_heavy" else ceili(contact*.06))
			var finish_tick := 25 if action == "light" else (27 if hero == "oichi" and action == "air_heavy" else ceili(float(spec.duration_ms)*.06))
			if hero == "oichi" and action == "heavy": contact_tick = 19; finish_tick = 38
			var switched := 0
			for tick in range(1,finish_tick+1):
				battle.step([{"buttons":Battle.LIGHT if tick == 1 else 0}])
				if player.attack_id != original_id:
					switched = tick
					break
			check(switched == contact_tick+(10 if action == "light" else 8) and switched < finish_tick, "Queued action waits for every contact plus commitment, then skips the visual tail: "+hero+"/"+action)
			check(player.action in ["light","air_light"], "Buffered light is consumed exactly once")
		for next_action in [Battle.HEAVY, Battle.JUMP, Battle.GRAB]:
			var battle := fresh(hero)
			var player: Dictionary = battle.state.fighters[0]
			battle.step([{"buttons":Battle.LIGHT}])
			battle.step([{"buttons":next_action}])
			for tick in range(17): battle.step([{}])
			if next_action == Battle.HEAVY: check(player.action == "heavy", "Buffered heavy tap does not become a stuck charge")
			if next_action == Battle.JUMP: check(player.z > 0 and player.action == "idle", "Jump can cancel the light recovery")
			if next_action == Battle.GRAB: check(player.action == "grab_start" and player.grab_target != 0, "Grab can follow a light contact")
		var jump := fresh(hero)
		var jumper: Dictionary = jump.state.fighters[0]
		jump.step([{"buttons":Battle.LIGHT}])
		jump.step([{"buttons":Battle.JUMP}])
		jump.step([{"buttons":Battle.HEAVY}])
		for tick in range(16): jump.step([{}])
		check(jumper.action == "air_heavy" and jumper.z > 0, "Buffered jump then heavy retains the jump modifier")
		var walk := fresh(hero)
		walk.step([{"buttons":Battle.LIGHT}])
		for tick in range(18): walk.step([{"dx":1}])
		check(walk.state.fighters[0].action == "idle", "Movement also leaves recovery after the commitment window")
		var grapple := fresh(hero)
		var holder: Dictionary = grapple.state.fighters[0]
		grapple.step([{"buttons":Battle.GRAB}])
		for next_move in ["grab_hit_1","grab_hit_2","throw","light"]:
			grapple.step([{"buttons":Battle.LIGHT}])
			var transitioned := false
			for tick in range(90):
				grapple.step([{}])
				if holder.action == next_move:
					transitioned = true
					break
			check(transitioned, "Buffered grapple stages retain the victim through both hits and the throw: "+next_move)
		check(holder.grab_target == 0 and grapple.state.fighters[1].held_by == 0 and grapple.state.training.total_damage == 55, "Throw-to-light chains only after one release and the original grapple damage")
		for cancel in [false, true]:
			var stopped := fresh(hero)
			var player: Dictionary = stopped.state.fighters[0]
			stopped.step([{"buttons":Battle.LIGHT}])
			stopped.step([{"buttons":Battle.HEAVY | Battle.JUMP}])
			if cancel: stopped.cancel_input()
			else: stopped._damage(player,1,stopped.state.fighters[1].id,false)
			for tick in range(60): stopped.step([{}])
			check(player.action == "idle" and player.z == 0 and stopped.state.training.hit_count == 0, "Cancel or hurt clears all buffered commands")

func dash_momentum_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for facing in [-1, 1]:
			for obstacle in ["open", "prop", "wall", "hurt"]:
				var battle := fresh(hero,"","",700)
				var player: Dictionary = battle.state.fighters[0]
				player.x = 1000.0
				battle.state.fighters[1].x = player.x + facing * 700
				battle.step([{"dx":facing}])
				battle.step([{}])
				battle.step([{"dx":facing}])
				check(player.sprinting, "Double tap enters sprint")
				if obstacle == "wall": player.x = battle._left_edge()+10 if facing < 0 else battle._right_edge()-10
				battle.step([{"buttons":Battle.HEAVY,"dx":facing}])
				check(player.action == "dash_heavy", "Sprint plus heavy starts the charge attack")
				var origin := float(player.x)
				var spec := Moves.spec(player)
				if obstacle == "prop":
					battle.state.props.append({"id":999,"kind":"crate","x":origin+facing*80,"y":player.y,"width":40.0,"depth":40.0,"hp":100000,"max_hp":100000,"broken":false,"drop":""})
				var previous := origin
				for tick in range(80):
					battle.step([{}])
					if tick < 3 and obstacle == "open": check((player.x-previous)*facing > 0, "Dash carries forward immediately instead of stopping on startup")
					if obstacle == "hurt" and tick > 4: check(is_equal_approx(player.x,previous), "Interrupted dash has no residual forward drift")
					if obstacle == "hurt" and tick == 4:
						battle._damage(player,1,battle.state.fighters[1].id,false)
						player.knockback = 0
					previous = player.x
					if player.action == "idle": break
				var travel: float = (float(player.x)-origin)*facing
				if obstacle == "open": check(is_equal_approx(travel,float(spec.frames[-1].root_step)+72), "Dash adds two short steps, then stops")
				if obstacle == "prop": check(travel <= 40.01, "Dash cannot pass through an intact prop")
				if obstacle == "wall": check(travel <= 10.01, "Dash respects the encounter boundary")

func throw_cadence_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for weapon in Weapons.ids_for(hero):
			for reverse in [false, true]:
				var battle := fresh(hero,weapon)
				var player: Dictionary = battle.state.fighters[0]
				var target: Dictionary = battle.state.fighters[1]
				battle._try_grab(player)
				player.throw_clip = "throw_reverse" if reverse else "throw_forward"
				player.throw_face = -1 if reverse else 1
				battle._begin(player,"throw")
				var spec := Moves.spec(player)
				var speed := float(player.attack_speed)
				var release_at := ceili(float(spec.events[0].ms)*.06*.65/speed)
				var finish_at := ceili(float(spec.duration_ms)*.06*.65/speed)
				var release_tick := 0
				var finish_tick := 0
				for tick in range(1,100):
					battle.step([{}])
					if release_tick == 0 and target.held_by == 0:
						release_tick = tick
						check(target.thrown_by == player.id and target.knockback * player.throw_face > 0, "Faster throw releases victim in the correct direction")
					if player.action == "idle":
						finish_tick = tick
						break
				check(release_tick == release_at and finish_tick == finish_at, "Throw release and recovery take 65 percent of the original time: " + hero + "/" + weapon)
				check(battle.state.training.hit_count == 1 and battle.state.training.total_damage == 31, "Faster throw keeps one damage event and original damage")
				check(Wire.valid_snapshot(battle.state), "Faster throw remains valid for co-op")

func light_step_tests() -> void:
	for hero in Moves.HEROES:
		for stage in [1,2,3]:
			for facing in [-1,1]:
				for blocked in [false,true]:
					var battle := fresh(hero,"","",700)
					var player: Dictionary = battle.state.fighters[0]
					player.x = 1000.0
					player.face = facing
					var origin := float(player.x)
					if blocked:
						battle.state.props.append({"id":999,"kind":"crate","x":origin+facing*50,"y":player.y,"width":40.0,"depth":40.0,"hp":100000,"max_hp":100000,"broken":false,"drop":""})
					start(battle,"light",stage)
					var expected := 0.0
					for frame in Moves.spec(player).frames: expected = maxf(expected,float(frame.root_step)*(3.0 if hero == "oichi" else 1.5))
					for tick in range(50):
						var previous := float(player.x)
						battle.step([{}])
						check((float(player.x)-previous)*facing >= -0.001,"Light recovery never pulls the forward step back: "+hero)
					var travel: float = (float(player.x)-origin)*facing
					check(is_equal_approx(travel,10.0 if blocked else expected), "Each light step advances in facing direction, respecting solid obstacles: "+hero+"/"+str(stage))

func heavy_direction_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for action in ["heavy","charged","dash_heavy","air_heavy"]:
			var battle := fresh(hero,"","",700)
			var player: Dictionary = battle.state.fighters[0]
			var target: Dictionary = battle.state.fighters[1]
			start(battle,action)
			var spec := Moves.spec(player)
			var event_tick := 6 if hero == "oichi" and action == "air_heavy" else ceili(float(spec.events[0].ms)*.06)
			if hero == "oichi" and action == "heavy": event_tick = 19
			var attack_id := int(player.attack_id)
			for tick in range(1,event_tick):
				var facing := -1 if tick % 2 == 1 else 1
				battle.step([{"dx":facing}])
				check(player.face == facing and player.action_tick == tick and player.attack_id == attack_id, "Heavy steering changes facing without restarting the move")
			target.x = player.x-70
			battle.step([{"dx":-1}])
			check(player.face == -1 and player.attack_id == attack_id, "Contact-frame turn retains the same attack")
			if hero == "oichi" and action in ["heavy","charged","air_heavy"]:
				var arrows: Array = battle.state.effects.filter(func(e): return e.type == "projectile")
				check(not arrows.is_empty() and arrows.all(func(e): return e.vx < 0), "The arrow uses direction pressed on its release frame")
				battle.step([{"dx":1}])
				check(player.face == 1 and arrows.all(func(e): return e.vx < 0), "Follow-through can turn without redirecting released arrows")
			else:
				check(target.hp < 100000, "Melee hits toward the direction pressed on its contact frame")
			check(Wire.valid_snapshot(battle.state), "Steered heavy snapshot stays valid")

func early_charge_release_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		var threshold := ceili(float(Moves.registration(hero).clips.charge_ready.duration_ms)*.06)
		for weapon in Weapons.ids_for(hero):
			for charm in ["", "marici"]:
				for held_ticks in [1, threshold / 2, threshold - 1, threshold]:
					var battle := ReleaseBattle.new()
					battle.reset_training(hero)
					battle.state.props.clear()
					var player: Dictionary = battle.state.fighters[0]
					Equipment.equip(player,Equipment.add(player,weapon))
					if charm != "": Equipment.equip(player,Equipment.add(player,charm))
					var speed := float(Battle.HERO_PROFILES[hero].attack_speed)*float(Weapons.item(weapon).get("attack_speed",1))*(1+Equipment.bonus(player,"attack_speed_bonus"))
					var windup := ceili(float(Moves.registration(hero).clips.heavy.events[0].ms)*.06/speed)
					if hero == "oichi": windup = ceili(19/minf(speed,1.0))
					battle.state.fighters[1].x = player.x + 1000
					battle.step([{"buttons":Battle.HEAVY}])
					for tick in range(1,held_ticks): battle.step([{"buttons":Battle.HEAVY}])
					check(battle.contacts.is_empty(),"Holding never attacks before release")
					battle.step([{"dx":-1}])
					var release_tick := int(battle.state.tick)
					var full: bool = held_ticks == threshold
					var immediate: bool = not full and held_ticks >= windup
					check(player.action == ("charged" if full else "heavy"),"Release preserves the charge threshold: "+weapon)
					check(battle.contacts.size() == (1 if immediate else 0),"Only a completed normal windup can attack immediately on release: "+hero+"/"+weapon+"/"+str(held_ticks))
					if not full: check(player.action_tick == mini(held_ticks,windup),"Release credits elapsed charge time without skipping unfinished windup")
					if not full and not battle.contacts.is_empty():
						check(battle.contacts[0].face == -1 and battle.contacts[0].tick == battle.state.tick,"Immediate attack uses release-frame direction")
						check(not battle._can_chain(player),"Immediate release still retains normal follow-through commitment")
						var pose := Frames.hero_v22_sample(player,{"v33_heavy":true})
						check(pose.released and pose.frame > 0,"Visible normal heavy resumes at release instead of replaying windup")
						if hero == "oichi":
							var arrows: Array = battle.state.effects.filter(func(e): return e.type == "projectile" and e.owner == player.id)
							check(arrows.size() == 1 and not arrows[0].piercing and not arrows[0].charged and arrows[0].vx < 0,"Partial bow charge emits one ordinary arrow immediately")
					for tick in range(180): battle.step([{}])
					if not full and not battle.contacts.is_empty(): check(battle.contacts[0].tick == release_tick+maxi(0,windup-held_ticks),"Short releases finish only the remaining windup, never a repeated full startup")
					check(battle.contacts.size() == (2 if full and hero == "nobunaga" else 1),"Release contacts happen once with no repeat during recovery")
					check(player.action == "idle" and Wire.valid_snapshot(battle.state),"Released attack finishes with a valid snapshot")
		for cancel in [true,false]:
			var interrupted := ReleaseBattle.new()
			interrupted.reset_training(hero)
			interrupted.step([{"buttons":Battle.HEAVY}])
			if not cancel: interrupted._begin(interrupted.state.fighters[0],"hurt")
			interrupted.step([{"buttons":Battle.CANCEL if cancel else 0}])
			for tick in range(90): interrupted.step([{}])
			check(interrupted.contacts.is_empty(),"Cancelled or interrupted charge cannot fire on release")
		for weapon in Weapons.ids_for(hero):
			var rapid := ReleaseBattle.new()
			rapid.reset_training(hero)
			rapid.state.props.clear()
			var player: Dictionary = rapid.state.fighters[0]
			Equipment.equip(player,Equipment.add(player,weapon))
			Equipment.equip(player,Equipment.add(player,"marici"))
			var speed := float(Battle.HERO_PROFILES[hero].attack_speed)*float(Weapons.item(weapon).get("attack_speed",1))*(1+Equipment.bonus(player,"attack_speed_bonus"))
			var windup := ceili(float(Moves.registration(hero).clips.heavy.events[0].ms)*.06/speed)
			if hero == "oichi": windup = ceili(19/minf(speed,1.0))
			for tick in range(300): rapid.step([{"buttons":Battle.HEAVY if tick%2 == 0 else 0}])
			check(rapid.contacts.size() >= 3,"Rapid tapping still produces consecutive normal heavy attacks")
			var shortest := 300
			for index in range(1,rapid.contacts.size()):
				var interval: int = rapid.contacts[index].tick-rapid.contacts[index-1].tick
				shortest = mini(shortest,interval)
				check(interval >= windup+8,"Repeated taps cannot bypass the next windup and become machine-gun attacks: "+weapon)
			if hero == "oichi" and speed >= 1.0: check(shortest == 27,"Oichi can fire every 0.45 seconds, but attack-speed equipment cannot exceed that cap: "+weapon)

func charge_direction_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for full in [false, true]:
			var battle := fresh(hero)
			var player: Dictionary = battle.state.fighters[0]
			var origin := Vector2(player.x,player.y)
			battle.step([{"buttons":Battle.HEAVY,"dx":1}])
			var hold_ticks := ceili(float(Moves.registration(hero).clips.charge_ready.duration_ms)*.06) if full else 4
			for tick in range(hold_ticks):
				battle.step([{"buttons":Battle.HEAVY,"dx":-1 if tick % 2 == 0 else 1}])
				check(player.action == "charge" and player.charge == tick+1, "Turning never resets or releases the charge: " + hero)
				check(player.face == (-1 if tick % 2 == 0 else 1), "Charge follows held horizontal direction: " + hero)
			battle.step([{"buttons":Battle.HEAVY,"dx":-1}])
			battle.step([{"buttons":Battle.HEAVY}])
			check(player.face == -1 and Vector2(player.x,player.y) == origin, "Neutral stick retains aim without walking during charge")
			var facing := 1 if full else -1
			battle.state.fighters[1].x = player.x + facing * 70
			battle.step([{"dx":1 if full else 0}])
			check(player.face == facing and player.action == ("charged" if full else "heavy"), "Release uses final direction and preserves charge strength")
			for tick in range(90): battle.step([{}])
			check(battle.state.training.total_damage > 0, "Turned charge actually hits the target in the selected direction")

func arrow_rain_range_tests() -> void:
	var radius := 1230.0*.2948766456*1.5
	for angle in range(0,360,45):
		for offset in [-.1,.1]:
			var battle := fresh("oichi")
			var player: Dictionary = battle.state.fighters[0]
			var target: Dictionary = battle.state.fighters[1]
			player.x = 1200.0
			var edge: Vector2 = Vector2.from_angle(deg_to_rad(angle))*(radius+offset)
			target.x = player.x+edge.x
			target.y = player.y+edge.y*.2
			start(battle,"charge_rain")
			var phases := {}
			for tick in range(120):
				battle.step([{}])
				for effect in battle.state.effects:
					if effect.type in ["sky_arrow","arrow_rain"]:
						phases[effect.type] = true
						check(is_equal_approx(effect.radius,radius),"Arrow rain shares its 50-percent larger radius across launch, rendering and damage")
			check(phases.size() == 2,"Arrow rain goes through both launch and falling phases")
			check(100000-target.hp == (43 if offset < 0 else 0),"Expanded rain hits once inside every ellipse edge, never outside")

func aerial_range_tests() -> void:
	var reaches := [320.0,600.0,900.0]
	for weapon in Weapons.ids_for("oichi"):
		for facing in [-1,1]:
			for height in [10.0,80.0,150.0]:
				var battle := fresh("oichi",weapon)
				var player: Dictionary = battle.state.fighters[0]
				battle.state.fighters = [player]
				player.x = 1200.0
				player.face = facing
				start(battle,"air_heavy")
				player.z = height
				player.action_tick = Battle.fighter_tick(player,6)
				battle._tick_combat_v33(player)
				var arrows: Array = battle.state.effects.filter(func(e): return e.type == "projectile")
				check(arrows.size() == 3,"Aerial spread remains exactly three arrows")
				var origins: Array = arrows.map(func(e): return e.x)
				for index in range(arrows.size()):
					check(is_equal_approx(arrows[index].range_left,reaches[index]),"Three aerial angles cover near, middle and far distances")
					check(arrows[index].vz < 0 and arrows[index].vx*facing > 0 and not arrows[index].piercing,"Aerial fan descends forward without changing attack type")
				for tick in range(60): battle._tick_effects()
				for index in range(arrows.size()):
					var travel: float = (arrows[index].x-origins[index])*facing
					check(absf(travel-reaches[index]) < .01 and arrows[index].z < .01,"Arrow really reaches its planned landing point before expiring: "+weapon)
				check((arrows[-1].x-origins[-1])*facing >= float(ProjectSettings.get_setting("display/window/size/viewport_width"))*2/3,"Farthest aerial arrow travels at least two thirds of the screen")
	for facing in [-1,1]:
		for height in [10.0,80.0,150.0]:
			for distance in [200.0,400.0,650.0,854.0]:
				var battle := fresh("oichi")
				var player: Dictionary = battle.state.fighters[0]
				var target: Dictionary = battle.state.fighters[1]
				player.x = 1200.0
				player.face = facing
				target.x = player.x+distance*facing
				start(battle,"air_heavy")
				player.z = height
				player.action_tick = Battle.fighter_tick(player,6)
				battle._tick_combat_v33(player)
				for tick in range(60): battle.step([{}])
				check(target.hp < 100000,"Extended aerial fan hits standing enemies at "+str(distance)+" from height "+str(height))

func oichi_response_tests() -> void:
	for weapon in Weapons.ids_for("oichi"):
		for delay in [0, 1, 8, 16, 24, 30, 33]:
			var battle := fresh("oichi",weapon,"",200)
			var player: Dictionary = battle.state.fighters[0]
			var arrows := 0
			var release_tick := -1
			var release_height := 0.0
			for tick in range(75):
				battle.step([{"buttons":(Battle.JUMP if tick == 0 else 0) | (Battle.HEAVY if tick >= delay else 0)}])
				if tick == delay:
					check(player.action == "air_heavy", "Jump then heavy, including same-frame input, starts an aerial volley: " + str(delay))
				for effect in battle.state.effects:
					if effect.type != "projectile" or effect.life != effect.max_life: continue
					arrows += 1
					if release_tick < 0:
						release_tick = tick
						release_height = player.z
						check(Wire.valid_snapshot(battle.state), "Early volley remains valid for co-op")
						var spec := Moves.spec(player)
						check(Battle.combat_time_ms(player) >= float(spec.events[0].ms), "Bow pose and projectile release share the same clock")
			check(release_tick >= delay and release_tick - delay <= Battle.fighter_tick(player,6), "Aerial release responds within six attack ticks: " + weapon + "/" + str(delay))
			check(release_height > 0, "Even a late descending volley releases before landing: " + str(delay))
			check(arrows == 3 and player.action == "idle", "Holding heavy emits one three-arrow volley and recovers")
			check(battle.state.training.total_damage > 0, "Responsive jump volley hits a standing target ahead instead of only the ground")
	for charm in ["", "moon"]:
		for action in ["light", "air_light"]:
			for facing in [-1, 1]:
				var battle := fresh("oichi","",charm)
				var player: Dictionary = battle.state.fighters[0]
				var target: Dictionary = battle.state.fighters[1]
				player.face = facing
				start(battle,action)
				var expected := ((115.0 if action == "light" else 138.0) + Equipment.bonus(player,"reach_bonus")) * 1.3
				for offset in [-0.1, 0.1]:
					target.x = player.x + facing * (expected + offset)
					target.invuln = 0
					target.hp = 100000
					battle._combat_contact_v33(player,"contact")
					check(is_equal_approx(player.attack_reach,expected), "Oichi light range including charm gains exactly 30 percent")
					check((target.hp < 100000) == (offset < 0), "Extended light hits at the new boundary, never beyond it")
					if offset < 0 and action == "light": check(target.knockback * facing >= 3, "Newly reachable light targets receive the intended push")

func _initialize() -> void:
	for hero in ["nobunaga","oichi"]:
		for action in ["light","heavy","charged","dash_heavy","air_light","air_heavy"]:
			var distance := 200 if hero == "oichi" and action in ["heavy","charged","air_heavy"] else 70
			var row := measure(hero,action,distance)
			records.append(row)
			check(row.damage > 0 and row.recovery_ticks > 0,"Move connects and finishes: "+hero+"/"+action)
		for combo in [2,3]: records.append(measure(hero,"light",70,"","",combo))
	records.append(measure("oichi","charge_rain"))
	projectile_range_tests()
	regressions()
	light_cadence_tests()
	oichi_response_tests()
	aerial_range_tests()
	arrow_rain_range_tests()
	charge_direction_tests()
	early_charge_release_tests()
	heavy_direction_tests()
	light_step_tests()
	dash_momentum_tests()
	throw_cadence_tests()
	action_chain_tests()
	var folder := "res://../artifacts/test-balance-v34"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var output := FileAccess.open(folder.path_join("balance.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"moves":records,"combo_push_comparison":combo_records},"\t"))
	output.close()
	print("BALANCE V34 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
