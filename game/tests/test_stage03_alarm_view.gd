extends SceneTree
const Main = preload("res://main.gd")
const Entry = preload("res://tests/play_stage03_alarm.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var app := Entry.App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_solo()
	app._update_view()
	assert(app.active and app.sim.state.stage.id == 3)
	assert("支柱 0/2" in app.hud.text)
	assert(app.audio._alarm_player.playing)
	app.audio.set_music_paused(true)
	assert(app.audio._alarm_player.stream_paused)
	app.audio.set_music_paused(false)
	assert(not app.audio._alarm_player.stream_paused)
	for prop in app.sim.state.props:
		if prop.kind == "bell_pillar": app.sim._damage_prop(prop,1000,app.sim.state.fighters[0].id)
	Main.Battle.Stage03Encounter.tick(app.sim)
	app._update_view()
	assert("支柱 2/2" in app.hud.text and "警鐘已停" in app.hud.text)
	assert(not app.audio._alarm_player.playing)
	assert(Wire.valid_snapshot(app.sim.get_state()))
	app.audio.sync_encounter({})
	assert(not app.audio._alarm_player.playing)
	app.queue_free()
	await process_frame
	print("STAGE03 ALARM VIEW PASS: entry, objective HUD, looping/pause/stop audio, snapshot")
	quit()
