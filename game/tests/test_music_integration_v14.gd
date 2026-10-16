extends SceneTree

class VirtualPads:
	extends "res://main.gd"
	func _connected_pads() -> Array[int]: return [3, 7]
	func _stop_rumble() -> void: pass
	# This fixture verifies audio after the user has confirmed the mode change.
	func _confirm_end(_action: Callable, _message: String) -> bool: return false

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
	check(music.playing and not music.stream_paused and app.audio._music_key == "title_intro", "Title screen starts the approved one-shot intro")
	check(is_equal_approx(music.volume_linear, 1.0), "Title files retain their supplied gain without a second attenuation")
	var title_playback := music.get_stream_playback()
	app._show_menu_page("main")
	app._open_options()
	check(music.playing and not music.stream_paused and music.get_stream_playback() == title_playback, "Main menu and audio options preserve the title theme without restarting it")
	app._menu_back()
	app.session = "solo"
	app._start_training()
	music = app.audio._music_player
	check(music.playing and not music.stream_paused, "Training starts the battle score")
	app.audio.stop_speech()
	music.seek(20.0)
	app._reset_training()
	check(music.playing and music.get_playback_position() >= 19.0, "Practice reset continues the score instead of restarting the opening")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_input(escape)
	check(app.paused and music.playing and not music.stream_paused, "Escape pauses combat while the score continues")
	app._open_options()
	check(app.paused and music.playing and not music.stream_paused, "Pause options leave the score playing so music volume can be heard")
	app._menu_back()
	app._show_controls()
	app._close_controls()
	check(app.paused and music.playing and not music.stream_paused, "Closing F1 preserves the existing combat pause and continuous score")
	app._resume()
	check(music.playing and not music.stream_paused, "Resume continues the score")
	app._show_controls()
	check(app.paused and music.playing and not music.stream_paused, "F1 pauses local combat while music continues")
	app._close_controls()
	check(not app.paused and music.playing and not music.stream_paused, "Closing F1 resumes combat without interrupting music")
	app._set_game_focus(false)
	check(app.paused and music.playing and not music.stream_paused, "Focus loss pauses combat while music continues")
	app._set_game_focus(true)
	app._resume()
	app._joy_changed(3, false)
	check(app.paused and music.playing and not music.stream_paused, "Controller disconnect pauses combat while music continues")
	app._leave_to_menu()
	music = app.audio._music_player
	check(music.playing and not music.stream_paused and app.menu.visible and app.menu_screen == "main" and app.audio._music_key == "title_loop", "Leaving an encounter restores the menu loop without replaying intro")
	app._start_local_coop()
	music = app.audio._music_player
	check(music.playing and not music.stream_paused, "Two-player battle starts its score")
	app.session = "client"
	app._show_controls()
	check(not app.paused and not music.stream_paused, "Network F1 keeps music running with the unpaused shared battle")
	app._close_controls()
	app._leave_to_menu()
	app._start_solo()
	music = app.audio._music_player
	check(music.playing and not music.stream_paused, "Solo battle starts its score")
	app.sim.state.phase = "won"
	app._physics_process(1.0 / 60.0)
	check(app.audio._music_key == "victory_jingle" and app.audio._music_player.playing and not music.playing, "Victory stops battle music and starts its one-shot celebration beneath the result voice")
	app.sim.state.phase = "lost"
	app.terminal_voice_played = false
	app._physics_process(1.0 / 60.0)
	check(not app.audio._music_player.playing and not app.audio._music_tail.playing, "Defeat stops both campaign scores")
	app._start_art_demo()
	check(not app.audio._music_player.playing and not app.audio._music_tail.playing, "Art demonstration does not inherit battle music")
	app._leave_to_menu()
	app._start_solo()
	app._fail("test disconnect")
	music = app.audio._music_player
	check(music.playing and not music.stream_paused and app.menu.visible and app.menu_screen == "main" and app.audio._music_key == "title_loop", "Connection failure restores the menu loop without replaying intro")
	app._close_network()
	check(not app.audio._music_player.playing and not app.audio._music_tail.playing, "Direct network cleanup still stops both music players")
	app.queue_free()
	await process_frame
	await create_timer(.2).timeout
	print("V20 MUSIC INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
