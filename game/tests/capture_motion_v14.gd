extends "res://tests/capture_motion_v13.gd"

# Reuse the v13 event/snapshot recorder, but drive new v14 scenarios below.
const LABELS := [
	"雙人步態｜12 fps 走路・16 fps 跑步・停止立即站姿",
	"信長輕手三連｜真按鍵連段・第三刀只踏出一步",
	"信長重手二連｜真短按與緩衝・加長加寬刀氣",
	"阿市蓄力｜冰波與三箭同時放出・上蓄單支冰箭",
	"毛利小王｜指定 AI 起始循環：橫掃／砸地",
	"毛利小王｜指定 AI 起始循環：長鏈／近抓摔",
	"雜兵抓取｜掙扎・半秒逃脫・放手摔出・倒地不可抓",
]
const AssetChecks = preload("res://tests/capture_v14_assets.gd")

class StagedBattle extends Battle:
	var allow_ai := {}
	func _enemy_input(fighter: Dictionary) -> void:
		fighter.move_dx = 0
		fighter.move_dy = 0
		if allow_ai.has(fighter.id):
			super._enemy_input(fighter)
			if Battle.ENEMY_TIMING.has(fighter.action): allow_ai.erase(fighter.id)

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v14/motion")
	var require_assets := "--require-v14" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	var missing: Array = AssetChecks.missing(app.view._art)
	var report := {"version":"0.14","input_driven":true,"simulation_fps":60,"ticks_per_trial":TRIAL_TICKS,"technical_preview":not require_assets,"missing_assets":missing,"setup_policy":"Players use actual Battle input frames. Autonomous troops are held in formation. Boss scenes explicitly reset positions and seed ai_cycle before allowing one live AI decision. Grab scene seeds the deterministic half-second escape roll.","trials":[],"passed":false}
	if require_assets and not missing.is_empty():
		report.error = "Final capture requires every registered v14 clip"
		_write_report(output,report)
		push_error(str(report.error) + ": " + str(missing))
		app.queue_free()
		await process_frame
		quit(1)
		return
	app._start_solo()
	app.sim = StagedBattle.new()
	app.sim.boss_intros = {}
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28,84)
	caption.add_theme_font_size_override("font_size",20)
	app.hud.get_parent().add_child(caption)
	for trial in range(LABELS.size()):
		var record := _setup_trial(app,trial)
		report.trials.append(record)
		caption.text = ("技術預覽／素材未驗收　" if not require_assets else "正式素材錄製　") + LABELS[trial]
		app._update_view()
		app.view._update_motion()
		for tick in range(TRIAL_TICKS):
			_stage(app,record,trial,tick)
			var inputs := _inputs(trial,tick)
			app.sim.step(inputs)
			app._events(app.sim.state.events)
			super._record_tick(app,record,tick,inputs)
			app._update_view()
			app.view._update_motion()
			var observed := {"tick":tick,"fighters":[],"accents":[]}
			for fighter in app.sim.state.fighters:
				var sample: Dictionary = app.view._fighter_animation(fighter)
				observed.fighters.append({"id":fighter.id,"kind":fighter.kind,"team":fighter.team,"x":fighter.x,"y":fighter.y,"z":fighter.z,"hp":fighter.hp,"action":fighter.action,"action_tick":fighter.action_tick,"combo":fighter.combo,"heavy_combo":fighter.heavy_combo,"held_by":fighter.held_by,"grab_target":fighter.grab_target,"pull_owner":fighter.pull_owner,"thrown_by":fighter.thrown_by,"clip":sample.clip,"frame":sample.frame,"source":sample.source,"sprinting":fighter.sprinting})
				if fighter.team == 0:
					var accent: Dictionary = app.view.strike_accent(fighter,sample)
					if not accent.is_empty(): observed.accents.append({"actor":fighter.id,"action":fighter.action,"style":accent})
			record.states.append(observed)
			await process_frame
			if tick % 12 == 0 or _important_tick(trial,tick):
				await RenderingServer.frame_post_draw
				var filename := "trial-%d-tick-%03d.png" % [trial,tick]
				_check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK,"Saved " + filename,record)
				record.captures.append({"file":filename,"tick":tick,"camera_x":app.view.camera_x,"players":_player_samples(app)})
		_validate_trial(trial,record)
		_write_report(output,report)
	report.passed = failures == 0
	_write_report(output,report)
	print("V14 MOTION CAPTURE: %d trials, %d simulation ticks, %d failures; technical_preview=%s; %s" % [LABELS.size(),LABELS.size()*TRIAL_TICKS,failures,not require_assets,output])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _setup_trial(app, trial: int) -> Dictionary:
	app.session = "local"
	app.training_active = false
	app.sim.reset("normal",2,["nobunaga","oichi"],"mori")
	app.sim.allow_ai.clear()
	app.sim.state.wave = 3
	app.sim.state.props = []
	app.sim.state.drops = []
	app.sim.state.intro = {}
	app.sim.state.civilian_spawn_enabled = false
	var players: Array = app.sim.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0)
	for i in range(2):
		players[i].x = 500.0 + i * 160.0
		players[i].y = 430.0 + i * 140.0
		players[i].face = 1
		players[i].rage = 0
	app.sim.state.fighters = players
	app.last_event = -1
	app.end_label.text = ""
	var record := {"trial":trial,"title":LABELS[trial],"player_ids":[players[0].id,players[1].id],"combos":[[],[]],"actions":[[],[]],"events":[],"effects":[],"inputs":[],"targets":{},"captures":[],"checks":[],"snapshots_valid":true,"phase_playing":true,"states":[],"setups":[]}
	if trial in [0,1,2,3,6]: _add_target(app,record,"sentinel",2300,360)
	if trial in [1,2]: _add_target(app,record,"front",620,430)
	if trial == 3:
		_add_target(app,record,"ice_front",780,595)
		_add_target(app,record,"upper_target",1010,570)
	if trial == 6: _add_target(app,record,"grab_target",565,430)
	return record

func _stage(app, record: Dictionary, trial: int, tick: int) -> void:
	if trial in [4,5] and tick in [0,120]:
		var action_index := (0 if trial == 4 else 2) + (1 if tick == 120 else 0)
		var player: Dictionary = app.sim.state.fighters[0]
		for fighter in app.sim.state.fighters:
			if fighter.team != 0: continue
			app.sim._begin(fighter,"idle")
			for key in ["z","vz","knockback","stun","freeze","burn","invuln","pull_owner"]: fighter[key] = 0
			fighter.airborne_lock = false
		player.x = 590.0 if action_index == 2 else 790.0
		player.y = 440.0
		app.sim.state.fighters[1].x = 440.0
		app.sim.state.fighters[1].y = 595.0
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0)
		app.sim.state.effects.clear()
		var boss: Dictionary = app.sim._make_fighter(1,"boss",890,440,1000)
		boss.face = -1
		boss.ai_cycle = action_index
		boss.cooldown = 30
		app.sim.state.fighters.append(boss)
		app.sim.allow_ai[boss.id] = true
		record.setups.append({"tick":tick,"method":"Reset formation, then allow one live AI choice after 30 ticks","boss_id":boss.id,"ai_cycle":action_index,"distance":boss.x-player.x})
	if trial == 6 and tick in [0,85,165]:
		var player: Dictionary = app.sim.state.fighters[0]
		var target: Dictionary = app.sim._fighter(record.targets.grab_target.id)
		app.sim._begin(player,"idle")
		app.sim._begin(target,"idle")
		for fighter in [player,target]:
			for key in ["z","vz","knockback","invuln","held_by","grab_target","throw_ticks","thrown_by"]: fighter[key] = 0
			fighter.airborne_lock = false
		player.x = 500.0
		player.y = 430.0
		target.x = 565.0
		target.y = 430.0
		if tick == 0:
			# Capture at local tick10; the only escape roll is 30 ticks later.
			var seed_tick := 0
			while ((seed_tick + 41)*17 + player.id*13 + target.id*7) % 100 >= 50: seed_tick += 1
			app.sim.state.tick = seed_tick
			record.setups.append({"tick":tick,"method":"Deterministic escape seed; grab input remains held","simulation_tick":seed_tick})
		elif tick == 85:
			record.setups.append({"tick":tick,"method":"Standing formation reset; release grab before escape roll"})
		else:
			app.sim._begin(target,"down")
			record.setups.append({"tick":tick,"method":"Seed a grounded downed target; actual GRAB must refuse it"})

func _inputs(trial: int, tick: int) -> Array:
	var inputs := [{"dx":0,"dy":0,"buttons":0},{"dx":0,"dy":0,"buttons":0}]
	match trial:
		0:
			if tick >= 15 and tick < 75 or tick == 90 or tick >= 92 and tick < 152 or tick >= 180:
				for input in inputs: input.dx = 1
		1:
			if tick in [30,34,54]: inputs[0].buttons = Battle.LIGHT
		2:
			if tick in [30,50]: inputs[0].buttons = Battle.HEAVY
		3:
			if tick >= 30 and tick < 70 or tick >= 150 and tick < 190:
				inputs[1].buttons = Battle.HEAVY
				inputs[1].dy = 1 if tick < 70 else -1
		6:
			if tick >= 10 and tick < 60 or tick >= 95 and tick < 119 or tick == 170: inputs[0].buttons = Battle.GRAB
	return inputs

func _important_tick(trial: int, tick: int) -> bool:
	if trial == 0: return tick in [14,15,74,75,90,91,92,151,152,179,180,239]
	if trial == 1: return tick in [54,55,59,60,61,65,66,67,68,73]
	if trial == 2: return tick in [31,44,45,50,66,67,80,81]
	if trial == 3: return tick in [70,97,98,99,190,211,212,213]
	if trial in [4,5]: return tick in [29,30,54,55,56,68,69,70,76,77,83,84,120,149,150,174,175,176,197,198,203,204,205]
	return tick in [9,10,20,30,39,40,41,42,59,60,95,105,115,118,119,120,164,165,169,170,171]

func _validate_trial(trial: int, record: Dictionary) -> void:
	_check(record.snapshots_valid,"All native simulation snapshots validate",record)
	_check(record.phase_playing,"Formation remains alive throughout capture",record)
	match trial:
		0:
			for slot in range(2):
				var walk_frames := []
				var run_frames := []
				var valid := true
				for state in record.states:
					var f: Dictionary = state.fighters[slot]
					var tick: int = state.tick
					if tick >= 15 and tick < 75:
						valid = valid and f.clip == "walk" and f.frame == int((tick-15)/5)%12
						if not walk_frames.has(f.frame): walk_frames.append(f.frame)
					elif tick >= 92 and tick < 152:
						valid = valid and f.clip == "run" and f.frame == floori((tick-92)*16.0/60.0)%12
						if not run_frames.has(f.frame): run_frames.append(f.frame)
					elif tick in [75,91,152,179]: valid = valid and f.clip == "idle"
					elif tick == 180: valid = valid and f.clip == "walk" and f.frame == 0
				_check(valid and walk_frames.size()==12 and run_frames.size()==12,"Player%d shows all fixed-clock walk/run frames, immediate idle and fresh frame0" % slot,record)
		1:
			_check(record.combos == [[1,2,3],[]],"Real input completes the full light chain",record)
			var third: Array = record.states.filter(func(s: Dictionary) -> bool: return s.fighters[0].action == "light" and s.fighters[0].combo == 3)
			_check(not third.is_empty() and is_equal_approx(third[-1].fighters[0].x - third[0].fighters[0].x,42.0),"The third cut advances exactly42 pixels once",record)
		2:
			var heavy: Array = record.events.filter(func(e: Dictionary) -> bool: return e.type == "swing" and e.action == "heavy")
			_check(heavy.size()==2 and heavy[0].heavy_combo==1 and heavy[1].heavy_combo==2,"Two short heavy presses produce both combo stages",record)
			_check(record.states.any(func(s: Dictionary) -> bool: return s.accents.any(func(a: Dictionary) -> bool: return a.action == "heavy")),"The renderer receives the actual expanded heavy strike accent",record)
		3:
			var arrows: Array = record.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile" and e.get("action","") == "charged_slam")
			var waves: Array = record.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave" and e.get("element","") == "ice")
			_check(arrows.size()==3 and waves.size()==1 and arrows.all(func(e: Dictionary) -> bool: return e.tick == waves[0].tick and e.action_tick == 28),"One real ice wave and three arrows are born on exactly the same action tick28",record)
			var upper: Array = record.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile" and e.get("action","") == "charged_upper")
			_check(upper.size()==1 and not upper[0].piercing and not upper[0].has("burst_radius"),"Upward full charge fires exactly one nonpiercing ice arrow",record)
		4,5:
			var expected := ["boss_sweep","boss_smash"] if trial==4 else ["boss_chain","boss_grab_throw"]
			var actual := []
			for event in record.events:
				if event.type=="swing" and event.get("actor_kind","")=="boss": actual.append(event.action)
			_check(actual == expected,"Seeded live boss AI selects " + str(expected),record)
			_check(record.events.any(func(e: Dictionary) -> bool: return e.type=="damage" and e.get("actor_kind","")=="boss"),"Boss's real hit logic damages a player",record)
			if trial==5:
				_check(record.states.any(func(s: Dictionary) -> bool: return s.tick<120 and s.fighters[0].action=="pulled"),"Long chain actually pulls the player",record)
				_check(record.states.any(func(s: Dictionary) -> bool: return s.tick>=120 and s.fighters[0].action=="thrown" and s.fighters[0].z>0),"Close chain actually throws the player airborne",record)
		6:
			var victim_id: int = record.targets.grab_target.id
			var held_frames := []
			var escaped := false
			var thrown := false
			for state in record.states:
				var victims: Array = state.fighters.filter(func(f: Dictionary) -> bool: return f.id==victim_id)
				var victim: Dictionary = victims[0]
				if state.tick>=10 and state.tick<40 and victim.action=="grabbed" and not held_frames.has(victim.frame): held_frames.append(victim.frame)
				if state.tick==40: escaped = state.fighters[0].grab_target==0 and victim.held_by==0 and victim.action=="idle"
				if state.tick>=119 and state.tick<165 and victim.action=="thrown": thrown = true
			_check(held_frames.size()>=3,"The held enemy cycles at least three actual struggle drawings",record)
			_check(escaped,"At exactly30 hold ticks the seeded escape frees both links without a throw",record)
			_check(thrown,"A separate short hold followed by button release actually throws",record)
			_check(record.states[170].fighters[0].grab_target==0,"Fresh grab input refuses the downed target",record)
