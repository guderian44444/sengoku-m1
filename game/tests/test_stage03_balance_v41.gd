extends SceneTree

const Battle = preload("res://core/battle.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Wire = preload("res://core/wire.gd")
const Audio = preload("res://render/combat_audio.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func _initialize() -> void: run.call_deferred()

func kill(sim, f: Dictionary) -> void:
	f.entering = false
	f.invuln = 0
	f.action = "idle"
	sim._damage(f,10000,sim.state.fighters[0].id,false,false,true)

func run() -> void:
	for players in [1,2]:
		var sim := Battle.new()
		sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
		check(sim.state.props.filter(func(p):return p.kind == "bell_pillar").all(func(p):return p.hp == 480),"pillars have triple original HP")
		for p in sim.state.props:
			if p.kind == "bell_pillar": sim._damage_prop(p,10000,sim.state.fighters[0].id)
		Encounter.tick(sim)
		check(not sim.state.events.any(func(e):return e.type == "bell_fall"),"bell waits for ground contact")
		sim.state.tick += 35
		Encounter.tick(sim)
		check(not sim.state.encounter.bell_landed,"bell still falling at tick 35")
		sim.state.tick += 1
		Encounter.tick(sim)
		Encounter.tick(sim)
		check(sim.state.events.filter(func(e):return e.type == "bell_fall").size() == 1 and Wire.valid_snapshot(sim.get_state()),"one serialized bell landing event")
		sim._enter_segment(1)
		var e: Dictionary = sim.state.encounter
		check(Encounter.population(sim.state) == e.target,"first barrier starts with defenders")
		var positions := {}
		for guard in sim.state.fighters.filter(func(f):return f.team == 1): positions[Vector2(guard.x,guard.y)] = true
		check(positions.size() == e.target,"guard group starts in separate positions")
		for p in sim.state.props:
			for hero in sim.state.fighters.filter(func(f):return f.team == 0): hero.x = p.x - 200
			Encounter.tick(sim)
			for cycle in range(3):
				for enemy in sim.state.fighters:
					if enemy.team == 1 and enemy.hp > 0: kill(sim,enemy)
				for hero in sim.state.fighters.filter(func(f):return f.team == 0): hero.x = p.x-900 if cycle == 1 else p.x-200
				sim.state.tick = e.next_admit_tick
				var before: int = e.spawned_count
				Encounter.tick(sim)
				check(e.spawned_count == before+1,"intact barrier continues replenishing even when players retreat")
				Encounter.tick(sim)
				check(e.spawned_count == before+1 and Wire.valid_snapshot(sim.get_state()),"admission rate and wire state remain bounded")
			sim._damage_prop(p,10000,sim.state.fighters[0].id)
			var count: int = e.spawned_count
			sim.state.tick += 300
			Encounter.tick(sim)
			check(e.spawned_count == count,"broken barrier stops; next guard group waits for approach")
		for enemy in sim.state.fighters:
			if enemy.team == 1: kill(sim,enemy)
		Encounter.tick(sim)
		check(e.phase == "complete" and Wire.valid_snapshot(sim.get_state()),"all barriers and surviving troops required for completion")
		sim._enter_segment(3)
		var bosses: Array = sim.state.fighters.filter(func(f):return f.kind == "boss")
		check(bosses[0].max_hp == roundi(520*(1.35 if players == 2 else 1)) and bosses[1].max_hp == roundi(480*(1.35 if players == 2 else 1)),"both lieutenants have double base HP with coop multiplier")
		for boss in bosses:
			boss.action = boss.boss_actions[0]
			var baseline: Dictionary = boss.duplicate(true)
			baseline.erase("lieutenant_slot")
			check(boss.cooldown <= 48 and Battle.enemy_timing(boss)[1] < Battle.enemy_timing(baseline)[1],"lieutenants start sooner and recover faster")

	for hero in Battle.HERO_PROFILES:
		var sim := Battle.new()
		sim.reset_training(hero,"dummy")
		sim.state.props.clear()
		var p: Dictionary = sim.state.fighters[0]
		var target: Dictionary = sim.state.fighters[1]
		target.x = p.x + 60
		p.face = 1
		sim._begin(p,"heavy")
		sim._melee(p,200,100,10,true,0,true)
		check(target.airborne_lock and is_equal_approx(target.knockback,2.2) and target.bounces_left == 0,"short close-heavy launch: "+hero)
		var start: float = target.x
		for tick in range(35): sim._tick_motion(target)
		check(target.x-start < 90,"short launch stays within nearby combo space: "+hero)
		for stage_boss in [false,true]:
			for action in ["heavy","air_heavy","charged","charged_upper","charged_slam","dash_heavy"]:
				var boss: Dictionary = sim._make_fighter(1,"boss",p.x+80,p.y,10000)
				boss.stage_boss = stage_boss
				boss.action = "hurt"
				sim.state.fighters.append(boss)
				sim._begin(p,action)
				check(sim._damage(boss,10,p.id,true,true,false,true),"heavy damage accepted")
				check(boss.action == "hurt" and not boss.airborne_lock and boss.z == 0 and boss.knockback == 10,"boss remains standing with longer push: "+hero+"/"+action)

	var audio := Audio.new()
	audio.settings_path = "user://audio-v41-test.cfg"
	root.add_child(audio)
	await process_frame
	for material in ["wood","box","wicker","ceramic","stone"]:
		for action in ["hit","break"]:
			var cue: String = material+"_"+action
			check(audio._sound_variants[cue].size() == 3,"three recorded material variants")
			for stream in audio._sound_variants[cue]: check(stream.get_length() >= 1.14,"longer recorded material tail")
			audio.play_event({"type":"prop_"+action,"material":material})
			check(audio._prop_players.any(func(p):return p.playing and p.volume_db >= -6),"louder dedicated prop playback")
	audio.play_event({"type":"bell_fall"})
	for index in range(20): audio.play_event({"type":"heavy_hit","weapon":"sword"})
	check(audio._bell_player.playing and audio._bell_player.stream.get_length() >= 2.59,"crowded fight cannot steal bell tail")
	check(audio._prop_players.any(func(p):return p.playing),"weapon impacts cannot steal prop tails")
	audio.queue_free()
	await process_frame
	print("STAGE03 BALANCE V41 PASS: %d checks" % checks)
	quit()
