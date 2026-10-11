extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const TRIAL_TICKS := 240
const TITLES := [
	"雙人走路｜固定12 fps・停止待機・再走從首格",
	"信長輕手三連｜30／34／54 tick按鍵・末段短距刀氣",
	"雙人衝刺重手｜先雙點衝刺・再按重手",
	"阿市爆裂冰箭｜首敵與近鄰凍結・範圍外不凍",
	"雙人蓄力地陣｜信長全周火・阿市前方冰波與三箭",
]
const CAPTURE_TICKS := [
	[0,14,15,20,45,74,75,100,119,120,125,179,180,239],
	[0,29,30,35,36,49,54,55,68,73,74,82,96,130,239],
	[0,30,31,32,34,35,41,46,47,48,56,69,96,130,239],
	[0,30,60,69,70,83,84,85,86,96,110,145,180,239],
	[0,30,60,69,70,97,98,112,115,116,117,124,135,160,200,239],
]

# Cooldown alone still lets soldiers walk. Only their autonomous decisions are
# disabled here; inputs, damage, elements, knockback, landing and recovery use Battle.
class FormationBattle extends Battle:
	func _enemy_input(fighter: Dictionary) -> void:
		fighter.move_dx = 0
		fighter.move_dy = 0

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v13/motion")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK, "Cannot create motion output directory")
	root.size = Vector2i(1280,720)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_solo()
	app.sim = FormationBattle.new()
	app.sim.boss_intros = {}
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28,120)
	caption.add_theme_font_size_override("font_size",22)
	app.hud.get_parent().add_child(caption)
	var report := {"version":"0.13","input_driven":true,"simulation_fps":60,"ticks_per_trial":TRIAL_TICKS,"stationary_enemy_ai":true,"enemy_cooldown":10000,"trials":[],"passed":false}
	for trial in range(TITLES.size()):
		var record := _setup_trial(app, trial)
		report.trials.append(record)
		caption.text = TITLES[trial]
		app._update_view()
		app.view._update_motion()
		for tick in range(TRIAL_TICKS):
			var inputs := _inputs(trial, tick)
			app.sim.step(inputs)
			app._events(app.sim.state.events)
			_record_tick(app, record, tick, inputs)
			app._update_view()
			if trial == 0: _record_walk(app, record, tick)
			await process_frame
			if tick in CAPTURE_TICKS[trial]:
				await RenderingServer.frame_post_draw
				var filename := "trial-%d-tick-%03d.png" % [trial,tick]
				var saved := root.get_texture().get_image().save_png(output.path_join(filename))
				_check(saved == OK, "Key frame was saved: " + filename, record)
				record.captures.append({"file":filename,"tick":tick,"camera_x":app.view.camera_x,"players":_player_samples(app)})
		_validate_trial(trial, record)
		# Keep completed trial evidence even if a later assertion or renderer fails.
		_write_report(output, report)
	report.passed = failures == 0
	_write_report(output, report)
	print("V13 MOTION CAPTURE: %d trials, %d simulation ticks, %d failures; %s" % [TITLES.size(),TITLES.size() * TRIAL_TICKS,failures,output])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
	assert(failures == 0, "v13 motion capture must pass the real input and target-state checks in verification.json")


func _setup_trial(app, trial: int) -> Dictionary:
	app.session = "local"
	app.training_active = false
	app.sim.reset("normal",2,["nobunaga","oichi"])
	app.sim.state.wave = 3
	app.sim.state.props = []
	app.sim.state.drops = []
	app.sim.state.intro = {}
	app.sim.state.civilian_spawn_enabled = false
	app.sim.state.civilian_flee_tick = 0
	var players: Array = app.sim.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0)
	players[0].x = 450.0
	players[0].y = 440.0
	players[1].x = 1050.0
	players[1].y = 580.0
	if trial == 2:
		players[0].x = 420.0
		players[1].x = 1000.0
	elif trial == 3:
		players[0].x = 500.0
		players[1].x = 950.0
		players[1].y = 570.0
	elif trial == 4:
		players[0].y = 420.0
		players[1].y = 530.0
	for player in players:
		player.face = 1
		player.rage = 0
	app.sim.state.fighters = players
	app.last_event = -1
	app.end_label.text = ""
	var record := {"trial":trial,"title":TITLES[trial],"player_ids":[players[0].id,players[1].id],"combos":[[],[]],"actions":[[],[]],"events":[],"effects":[],"inputs":[],"targets":{},"captures":[],"checks":[],"snapshots_valid":true,"phase_playing":true,"walk_valid":[true,true],"walk_samples":[]}
	match trial:
		0:
			# An unseen living target prevents the empty arena from ending at the first tick.
			_add_target(app,record,"offscreen_sentinel",2300.0,360.0)
		1:
			_add_target(app,record,"nobunaga_close",players[0].x + 100.0,players[0].y)
			_add_target(app,record,"blade_air_reach",players[0].x + 240.0,players[0].y + 35.0)
		2:
			for i in range(2): _add_target(app,record,"dash_front_%d" % i,players[i].x + 180.0,players[i].y + (35.0 if i == 1 else 0.0))
			_add_target(app,record,"needle_fan",players[1].x + 315.0,players[1].y - 34.0)
		3:
			_add_target(app,record,"first_arrow_target",players[1].x + 150.0,players[1].y)
			_add_target(app,record,"near_upper",players[1].x + 190.0,players[1].y - 25.0)
			_add_target(app,record,"near_lower",players[1].x + 210.0,players[1].y + 25.0)
			_add_target(app,record,"outside_burst",players[1].x + 340.0,players[1].y)
		4:
			for i in range(2):
				_add_target(app,record,"wave_front_%d" % i,players[i].x + (110.0 if i == 1 else 100.0),players[i].y + (35.0 if i == 1 else 0.0))
				_add_target(app,record,"wave_rear_%d" % i,players[i].x - 120.0,players[i].y)
			_add_target(app,record,"upper_arrow_target",players[1].x + 280.0,players[1].y - 45.0)
			_add_target(app,record,"center_arrow_target",players[1].x + 280.0,players[1].y)
			_add_target(app,record,"lower_arrow_target",players[1].x + 280.0,players[1].y + 45.0)
	return record


func _add_target(app, record: Dictionary, label: String, x: float, y: float) -> void:
	var fighter: Dictionary = app.sim._make_fighter(1,"soldier",x,y,500)
	fighter.cooldown = 10000
	app.sim.state.fighters.append(fighter)
	record.targets[label] = {"id":fighter.id,"spawn_x":x,"spawn_y":y,"initial_hp":fighter.hp,"final_hp":fighter.hp,"first_damage":0,"first_freeze":{},"first_burn":{},"first_airborne":{},"damage_events":[]}


func _inputs(trial: int, tick: int) -> Array:
	var inputs := [{"dx":0,"dy":0,"buttons":0},{"dx":0,"dy":0,"buttons":0}]
	match trial:
		0:
			if tick >= 15 and tick < 75 or tick >= 120 and tick < 180:
				for input in inputs: input.dx = 1
		1:
			if tick in [30,34,54]: inputs[0].buttons = Battle.LIGHT
		2:
			if tick == 30 or tick >= 32 and tick <= 35:
				for input in inputs: input.dx = 1
			if tick == 35:
				for input in inputs: input.buttons = Battle.HEAVY
		3:
			if tick >= 30 and tick < 70: inputs[1].buttons = Battle.HEAVY
		4:
			if tick >= 30 and tick < 70:
				for input in inputs:
					input.dy = 1
					input.buttons = Battle.HEAVY
	return inputs


func _record_tick(app, record: Dictionary, tick: int, inputs: Array) -> void:
	record.snapshots_valid = record.snapshots_valid and Wire.valid_snapshot(app.sim.get_state())
	record.phase_playing = record.phase_playing and app.sim.state.phase == "playing"
	# Retain input transitions rather than 240 identical idle records.
	if record.inputs.is_empty() or record.inputs[-1].players != inputs:
		record.inputs.append({"tick":tick,"players":inputs.duplicate(true)})
	for event in app.sim.state.events:
		if event.type in ["swing","damage","bow_release","heavy_hit","landing"]:
			var observed: Dictionary = event.duplicate(true)
			observed.tick = tick
			record.events.append(observed)
		if event.type == "swing":
			var slot: int = record.player_ids.find(event.actor)
			if slot >= 0:
				record.actions[slot].append(event.action)
				if event.action == "light": record.combos[slot].append(event.combo)
		if event.type == "damage":
			for target in record.targets.values():
				if target.id != event.target: continue
				if target.damage_events.is_empty(): target.first_damage = event.amount
				target.damage_events.append({"tick":tick,"amount":event.amount,"actor":event.actor,"x":event.x,"y":event.y})
	for fighter in app.sim.state.fighters:
		if fighter.team == 0: continue
		for target in record.targets.values():
			if target.id != fighter.id: continue
			target.final_hp = fighter.hp
			if fighter.freeze > 0 and target.first_freeze.is_empty():
				target.first_freeze = {"tick":tick,"x":fighter.x,"y":fighter.y,"owner":fighter.freeze_owner}
			if fighter.burn > 0 and target.first_burn.is_empty():
				target.first_burn = {"tick":tick,"x":fighter.x,"y":fighter.y,"owner":fighter.burn_owner}
			if fighter.airborne_lock and target.first_airborne.is_empty():
				target.first_airborne = {"tick":tick,"x":fighter.x,"y":fighter.y,"action":fighter.action}
	for effect in app.sim.state.effects:
		if effect.life != effect.max_life: continue
		if effect.type in ["shockwave","blade_wave","projectile"] or effect.get("burst",false):
			var observed: Dictionary = effect.duplicate(true)
			observed.tick = tick
			record.effects.append(observed)


func _record_walk(app, record: Dictionary, tick: int) -> void:
	var moving := tick >= 15 and tick < 75 or tick >= 120 and tick < 180
	var expected := int((tick - (15 if tick < 75 else 120)) / 5) % 12 if moving else 0
	for i in range(2):
		var sample: Dictionary = app.view.animation_sample("nobunaga" if i == 0 else "oichi")
		record.walk_valid[i] = record.walk_valid[i] and (sample.clip == "walk" and sample.frame == expected if moving else sample.clip == "idle")
		if tick in CAPTURE_TICKS[0]:
			record.walk_samples.append({"tick":tick,"player":i,"clip":sample.clip,"frame":sample.frame,"expected_walk_frame":expected if moving else -1})


func _player_samples(app) -> Array:
	var samples := []
	for fighter in app.sim.state.fighters:
		if fighter.team != 0: continue
		var sample: Dictionary = app.view.animation_sample(fighter.kind)
		samples.append({"id":fighter.id,"kind":fighter.kind,"x":fighter.x,"y":fighter.y,"action":fighter.action,"action_tick":fighter.action_tick,"clip":sample.clip,"frame":sample.frame,"source":sample.get("source","")})
	return samples


func _validate_trial(trial: int, record: Dictionary) -> void:
	_check(record.snapshots_valid, "Every real battle snapshot validates", record)
	_check(record.phase_playing, "The trial remains an active simulation for all 240 ticks", record)
	match trial:
		0:
			_check(record.walk_valid == [true,true], "Both heroes walk at fixed 12 fps, stop immediately and restart at frame zero", record)
			_check(record.actions == [[],[]], "Walking trial contains no attacks", record)
		1:
			_check(record.combos == [[1,2,3],[]] and record.actions[1].is_empty(), "Only Nobunaga completes the actual 30/34/54 input light chain", record)
			_check(record.effects.any(func(e: Dictionary) -> bool: return e.type == "blade_wave" and e.get("combo",0) == 3), "Light three emits its real short blade-air effect", record)
			_check(record.targets.blade_air_reach.damage_events.size() == 1 and record.targets.blade_air_reach.first_damage == 18, "The extended blade air hits the distant troop once", record)
		2:
			_check(record.actions == [["dash_heavy"],["dash_heavy"]], "Both double-tap sprints enter dash_heavy directly from HEAVY input", record)
			for i in range(2): _check(not record.targets["dash_front_%d" % i].first_airborne.is_empty(), "Dash heavy actually launches player %d's front troop" % (i + 1), record)
			var needles: Array = record.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile" and e.get("action","") == "dash_heavy" and e.get("weapon","") == "needle")
			_check(needles.size() == 5 and record.targets.needle_fan.first_damage == 8, "Oichi releases five real fan needles and an outer needle hits beyond the bow sweep", record)
		3:
			_check(record.actions == [[],["charged"]], "Only Oichi releases a neutral full charge through real held input", record)
			_check(record.effects.filter(func(e: Dictionary) -> bool: return e.get("burst",false)).size() == 1, "The primary arrow creates exactly one explosion", record)
			_check(record.targets.first_arrow_target.first_damage == 43 and not record.targets.first_arrow_target.first_freeze.is_empty(), "The first target receives the primary 43-damage frozen hit", record)
			for label in ["near_upper","near_lower"]:
				_check(record.targets[label].first_damage == 6 and record.targets[label].damage_events.size() == 1 and not record.targets[label].first_freeze.is_empty(), label + " receives exactly one six-damage freeze", record)
			_check(record.targets.outside_burst.first_freeze.is_empty() and record.targets.outside_burst.damage_events.is_empty(), "The target outside the small explosion is neither frozen nor hit by piercing", record)
		4:
			_check(record.actions == [["charged_slam"],["charged_slam"]], "Both players release downward full charge through held input", record)
			for label in ["wave_front_0","wave_rear_0"]:
				_check(not record.targets[label].first_burn.is_empty() and not record.targets[label].first_airborne.is_empty(), "Nobunaga's full-circle fire hits, launches and burns " + label, record)
			_check(record.targets.wave_front_1.first_damage == 6 and record.targets.wave_front_1.damage_events.size() == 1 and not record.targets.wave_front_1.first_freeze.is_empty() and record.targets.wave_front_1.first_airborne.is_empty(), "Oichi's ice-only front troop takes six damage and freezes without being knocked down", record)
			_check(record.targets.wave_rear_1.first_freeze.is_empty() and record.targets.wave_rear_1.damage_events.is_empty(), "Oichi's rear troop stays outside the forward ice sector", record)
			for label in ["upper_arrow_target","center_arrow_target","lower_arrow_target"]:
				var target: Dictionary = record.targets[label]
				_check(target.first_damage == 10 and target.damage_events.filter(func(event: Dictionary) -> bool: return event.amount == 10).size() == 1 and not target.first_airborne.is_empty(), "A separate fan arrow hits and knocks down " + label + " for exactly ten base damage", record)
			var arrows: Array = record.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile" and e.get("action","") == "charged_slam")
			_check(arrows.size() == 3 and arrows.all(func(e: Dictionary) -> bool: return e.damage == 10 and not e.piercing), "The forward ice skill releases exactly three low-damage nonpiercing arrows", record)
			if arrows.size() == 3:
				_check(arrows.all(func(e: Dictionary) -> bool: return e.x == arrows[0].x and e.y == arrows[0].y) and arrows[0].vy < 0.0 and arrows[1].vy == 0.0 and arrows[2].vy > 0.0, "All three arrows start together and fan out along distinct flight paths", record)
			var waves: Array = record.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave")
			_check(waves.size() == 2 and waves[0].radius == 320.0 and waves[0].arc_degrees == 360.0 and waves[1].radius == 320.0 and waves[1].arc_degrees == 120.0, "The actual wave geometry is radius320 with 360/120-degree coverage", record)


func _check(ok: bool, message: String, record: Dictionary) -> void:
	record.checks.append({"passed":ok,"message":message})
	if not ok:
		failures += 1
		push_error("Trial %d: %s" % [record.trial,message])


func _write_report(output: String, report: Dictionary) -> void:
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file != null, "Cannot write motion verification report")
	file.store_string(JSON.stringify(report,"\t"))
