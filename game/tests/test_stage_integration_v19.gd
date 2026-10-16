extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var app := Main.new()
	app.testing = true
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._update_view()
	check(app.sim.state.stage.index == 0 and app.sim.state.faction == "imagawa" and not app.menu.visible, "Menu starts the current Imagawa campaign")
	check(app.objective_scroll.place == "%s　1／2 陣" % app.sim.state.stage.name and app.view.camera_x == 0, "First region opens at its first checkpoint and left camera edge")
	for index in range(7):
		app.sim._enter_segment(index)
		app.sim.state.fighters[0].x = 1100.0
		app._camera_scene = -1
		app._update_view()
		var spec: Dictionary = app.sim._campaign.segments[index]
		check(app.sim.state.stage.index == index and app.objective_scroll.place.begins_with(spec.name), "Order follows region " + str(index + 1))
		check(app.audio._music_key == spec.music and app.audio._music_active, "Actual region data selects its loop without stopping music")
		check(app.view.state.stage.theme == spec.theme and is_equal_approx(app.view.camera_x, Battle.camera_left(app.sim.state)), "Backdrop state and spawn camera stay on the same region")
		check(Wire.valid_snapshot(app.sim.get_state()), "Region snapshot survives the multiplayer boundary")
	# Stage the final scheduled wave; combat rules and attack-driven completion are covered separately.
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.fighters[0].x = 2250.0
	app.sim._start_checkpoint(1)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.wave = 2
	app.sim._spawn_segment_wave()
	app._update_view()
	check(app.sim.state.stage.index == 6 and app.objective_scroll.place.ends_with("2／2 陣") and app.audio._music_key == "boss", "Final commander uses the last checkpoint and battle score")
	check(app.end_label.text.contains("松井宗信") and not app.end_label.text.contains("暫停") and not app.end_label.text.contains("結束後開戰"), "Actual commander introduction keeps its name and line without a pause message")
	check(app.combat_hud.boss.get("stage_boss", false) and app.combat_hud.boss.get("display_name", "") == "松井宗信", "Compact boss HP bar identifies the actual final commander")
	var tick: int = app.sim.state.tick
	app.sim.step([{"dx":0,"dy":0,"buttons":0}])
	check(app.sim.state.tick == tick + 1 and not app.paused and not app.sim.state.intro.blocking, "Simulation advances while the introduction remains onscreen")
	check(Wire.valid_snapshot(app.sim.get_state()), "Final commander and nonblocking dialogue stay valid on the wire")
	app._close_network()
	check(not app.audio._music_player.playing and not app.audio._music_tail.playing and not app.audio._music_active, "Returning to menu releases both music players")
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("STAGE INTEGRATION V19: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
