extends SceneTree

class VirtualPads:
	extends "res://main.gd"
	func _connected_pads() -> Array[int]: return [3, 7]
	func _stop_rumble() -> void: pass

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var app := VirtualPads.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	var music: AudioStreamPlayer = app.audio._music_player
	check(not music.playing, "Menu starts without battle music")
	check(is_equal_approx(music.volume_db, -19.0), "Battle music stays below character voices")
	app._start_training()
	check(music.playing and not music.stream_paused, "Training starts the battle score")
	app.audio.stop_speech()
	music.seek(20.0)
	app._reset_training()
	check(music.playing and music.get_playback_position() >= 19.0, "Practice reset continues the score instead of restarting the opening")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_input(escape)
	check(app.paused and music.stream_paused, "Escape pauses game and score together")
	app._show_controls()
	app._close_controls()
	check(app.paused and music.stream_paused, "Closing F1 preserves an existing pause")
	app._resume()
	check(music.playing and not music.stream_paused, "Resume continues the score")
	app._show_controls()
	check(app.paused and music.stream_paused, "F1 pauses local battle music")
	app._close_controls()
	check(not app.paused and not music.stream_paused, "Closing F1 restores local music playback")
	app._set_game_focus(false)
	check(app.paused and music.stream_paused, "Focus loss pauses local music")
	app._set_game_focus(true)
	app._resume()
	app._joy_changed(3, false)
	check(app.paused and music.stream_paused, "Controller disconnect pauses local music")
	app._leave_to_menu()
	check(not music.playing, "Leaving the encounter stops music")
	app._start_local_coop()
	check(music.playing and not music.stream_paused, "Two-player battle starts its score")
	app.session = "client"
	app._show_controls()
	check(not app.paused and not music.stream_paused, "Network F1 keeps music running with the unpaused shared battle")
	app._close_controls()
	app._leave_to_menu()
	app._start_solo()
	check(music.playing and not music.stream_paused, "Solo battle starts its score")
	app.sim.state.phase = "won"
	app._physics_process(1.0 / 60.0)
	check(not music.playing, "Victory stops the battle loop for the result voice")
	app._start_art_demo()
	check(not music.playing, "Art demonstration does not inherit battle music")
	app._leave_to_menu()
	app._start_solo()
	app._fail("test disconnect")
	check(not music.playing and app.menu.visible, "Connection failure stops the score")
	app.queue_free()
	await process_frame
	print("V14 MUSIC INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
