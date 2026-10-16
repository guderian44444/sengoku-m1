extends SceneTree
const Entry = preload("res://tests/play_stage03_alarm.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Yoshi = preload("res://core/stage03_yoshimoto.gd")
const Wire = preload("res://core/wire.gd")
var output := ""
var captures := []

func _initialize(): run.call_deferred()

func advance(app: Node, ticks: int):
	for tick in range(ticks):
		for p in app.sim.state.fighters:
			if p.team == 0: p.invuln = 5
		app.sim.step([])

func capture(app: Node, name: String):
	app._camera_scene = -1
	app._update_view()
	assert(Wire.valid_snapshot(app.sim.get_state()))
	if output.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name)) == OK)
	captures.append(name)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.is_empty():
		assert(DisplayServer.get_name() != "headless")
		assert(DirAccess.make_dir_recursive_absolute(output) == OK)
		root.size = Vector2i(1280,720)
	var app := Entry.App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.testing = true
	app.session = "local"
	app._start_alarm(2)
	app.sim._enter_segment(3)
	for b in app.sim.state.encounter.leaders: app.sim._damage(app.sim._fighter(b.id),10000,app.sim.state.fighters[0].id,true,false,true)
	Encounter.tick(app.sim)
	await capture(app,"01-final-boss-introduction.png")
	advance(app,90)
	var f: Dictionary = app.sim._fighter(app.sim.state.encounter.yoshimoto_id)
	assert(f.get("is_yoshimoto",false) and f.stage_boss)
	f.entering = false
	f.x = 1400
	f.y = 480
	f.motion_ready_tick = 100000
	f.cooldown = 0
	f.ranged_ready_tick = app.sim.state.tick
	var party: Array = app.sim.state.fighters.filter(func(p):return p.team == 0)
	party[0].x = 700
	party[0].y = 480
	party[1].x = 1200
	party[1].y = 540
	Yoshi.steer(app.sim,f,party[0])
	advance(app,18)
	assert(f.action == "boss_arrow")
	assert(app.combat_hud.leaders.size() == 2) # Last sync was during the introduction.
	await capture(app,"02-bow-windup-placeholder.png")
	assert(app.combat_hud.leaders.is_empty() and app.combat_hud.boss.id == f.id)
	advance(app,24)
	assert(app.sim.state.effects.any(func(e):return e.get("yoshimoto_projectile",false) and not e.boss_wave))
	advance(app,8) # Show flight clear of the placeholder bow.
	await capture(app,"03-locked-arrow.png")
	app.sim.state.tick = f.ranged_ready_tick
	app.sim.state.effects.clear()
	app.sim._begin(f,"idle")
	f.cooldown = 0
	f.x = 1400
	f.y = 480
	Yoshi.steer(app.sim,f,party[0])
	assert(f.action == "boss_sword_wave")
	advance(app,20)
	await capture(app,"04-sword-wave-windup.png")
	advance(app,30)
	assert(app.sim.state.effects.any(func(e):return e.get("boss_wave",false)))
	advance(app,8)
	await capture(app,"05-locked-sword-wave.png")
	app.sim.state.effects.clear() # Keep the guard capture separate from the preceding wave.
	app.sim._begin(f,"idle")
	f.cooldown = 0
	f.ai_cycle = 2
	f.guard_ready_tick = 0
	party[0].x = f.x - 120
	Yoshi.steer(app.sim,f,party[0])
	assert(f.action == "guard")
	await capture(app,"06-frontal-guard.png")
	advance(app,18)
	assert(f.tactic == "recover")
	await capture(app,"07-guard-recovery.png")
	f.invuln = 0
	app.sim._damage(f,10000,party[0].id,true,false,true)
	app.sim.step([])
	assert(app.sim.state.phase == "won" and app.sim.state.encounter.tickets.is_empty())
	app.paused = false
	app._physics_process(0)
	await capture(app,"08-prototype-victory.png")
	assert("合戰大捷" in app.end_label.text)
	assert(app.audio._music_key in ["victory_jingle","victory_loop"])
	if not output.is_empty():
		await create_timer(7.5).timeout
		assert(app.audio._music_key == "victory_loop" and app.audio._music_player.playing)
		print("CAMPAIGN MUSIC NATIVE: victory jingle naturally completed and bright loop is playing")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"capture":"Native Main. Positions, clock and selected actions staged for visual QA; normal Battle ticks drive releases. Not a human playthrough.","files":captures,"all_snapshots_valid":true,"formal_art":false},"  ")+"\n")
	print("STAGE03 YOSHIMOTO VIEW PASS: final-boss HUD, bow/wave, guard/recovery and victory")
	app.queue_free()
	await process_frame
	quit()
