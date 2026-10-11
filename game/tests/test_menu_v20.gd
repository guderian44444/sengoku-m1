extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0
var output := ""

class App extends Main:
	func _connected_pads() -> Array[int]: return [3, 7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless" or "--capture-v20" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Save " + name)

func check_page(app: Node, name: String) -> void:
	check(app.menu.visible and app.menu_screen == name and app.menu_pages[name].visible, "Page visible: " + name)
	check(app.menu_pages.values().filter(func(page): return page.visible).size() == 1, "Only one menu page visible")
	check(app.menu_pages[name].get_global_rect().end.y < 608, "Page fits above shared status: " + name)

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v20/menu")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var app := App.new()
	root.add_child(app)
	app.testing = true
	app.set_physics_process(false)
	# Exercise persistence callbacks without changing the player's real settings.
	app.audio.settings_path = output.path_join("test-volume.cfg")
	await process_frame
	check_page(app, "title")
	check(app.menu_logo.texture != null and app.menu_backdrop.texture != null, "Title has actual logo and background images")
	check(not app.hud.visible and not app.combat_hud.visible, "No stale combat HUD on title")
	check(app.engineer_entry.position.y >= 660 and app.engineer_entry.visible and not app.menu_panel.visible, "Engineering has only a bottom entry by default")
	check(app.menu_pages.title.get_node("Start").has_focus(), "Keyboard/controller starts on PRESS START")
	await capture("01-title")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	Input.parse_input_event(enter)
	Input.flush_buffered_events()
	enter.pressed = false
	Input.parse_input_event(enter)
	Input.flush_buffered_events()
	check(app.menu_screen == "main", "Real Enter input activates the focused start button")
	app._menu_back()
	var start := InputEventJoypadButton.new()
	start.pressed = true
	start.button_index = JOY_BUTTON_START
	app._input(start)
	await process_frame
	check_page(app, "main")
	await capture("02-main")
	app.menu_pages.main.get_node("Options").pressed.emit()
	await process_frame
	check_page(app, "options")
	for entry in [["music", 35.0], ["sfx", 70.0], ["voice", 90.0]]:
		app.volume_sliders[entry[0]].value = entry[1]
	for entry in [["music", 0.35], ["sfx", 0.7], ["voice", 0.9]]:
		check(is_equal_approx(app.audio.get_category_volume(entry[0]), entry[1]), "Correct independent volume callback: " + entry[0])
	var saved := ConfigFile.new()
	check(saved.load(app.audio.settings_path) == OK and is_equal_approx(saved.get_value("audio", "music"), 0.35), "Options saves settings via audio API")
	check(app.audio._music_player.playing and not app.audio._music_player.stream_paused, "Music remains audible in options")
	await capture("03-options")
	app.menu_pages.options.get_node("Back").pressed.emit()
	app.menu_pages.main.get_node("Solo").pressed.emit()
	await process_frame
	check_page(app, "select")
	check(not app.partner_row.visible, "Solo selects one hero")
	app.heroes.selected = 0
	await capture("04-select-solo")
	app.menu_pages.select.get_node("Back").pressed.emit()
	app.menu_pages.main.get_node("LocalCoop").pressed.emit()
	await process_frame
	check(app.partner_row.visible and app.selection_coop, "Co-op selects two heroes")
	await capture("05-select-coop")
	app.engineer_entry.pressed.emit()
	await process_frame
	check_page(app, "engineering")
	check(not app.engineer_entry.visible, "No duplicate engineering entry inside engineering page")
	await capture("06-engineering")
	app.menu_panel.get_node("Back").pressed.emit()
	app._open_selection(true)
	app.menu_pages.select.get_node("Begin").pressed.emit()
	check(app.active and app.session == "local" and not app.menu.visible and app.player_devices == [3, 7], "Co-op begins with two separately assigned controllers")
	check(app.combat_hud.visible and app.hud.visible, "Starting play restores combat UI")
	check(app.combat_hud.players.size() == 2 and not app.hud.text.contains("波"), "Two character HUD records without wave information")
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.fighters[0].x = 440.0
	app.sim.state.fighters[1].x = 680.0
	app._update_view()
	await capture("07-battle")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	app._unhandled_input(escape)
	await process_frame
	check_page(app, "pause")
	check(app.paused and app.audio._music_player.playing, "Pause stops gameplay without stopping music")
	await capture("08-pause")
	app.menu_pages.pause.get_node("Options").pressed.emit()
	check(app.options_return == "pause", "Pause options remembers return target")
	var back := InputEventJoypadButton.new()
	back.pressed = true
	back.button_index = JOY_BUTTON_B
	app._input(back)
	check(app.menu_screen == "pause" and app.paused, "Controller cancel returns from options to pause")
	app._input(start)
	check(not app.paused and not app.menu.visible, "START resumes battle")
	app.sim.state.stage.go = true
	app.sim.state.stage.phase = "exit"
	for fighter in app.sim.state.fighters: fighter.x = app.sim.state.stage.encounter_end - 160.0
	for tick in range(180): app._update_view()
	var before: float = app.view.camera_x
	check(is_equal_approx(before, app.sim.state.stage.encounter_end - 1280.0), "GO never exposes locked next checkpoint")
	await capture("09-go-boundary")
	app.sim._start_checkpoint(1)
	app._update_view()
	check(app.view.camera_x > before and app.view.camera_x <= before + 10.0, "Unlock scrolls smoothly, at most ten pixels per simulation update")
	for tick in range(180): app._update_view()
	check(is_equal_approx(app.view.camera_x, Battle.camera_left(app.sim.state)), "Smooth camera reaches authoritative party target")
	for fighter in app.sim.state.fighters:
		if fighter.team == 0:
			fighter.hp = 0
			fighter.action = "dead"
			fighter.action_tick = 80
	app.sim.state.phase = "lost"
	app._update_view()
	check(is_equal_approx(app.view.camera_x, Battle.camera_left(app.sim.state)) and app.view.camera_x > 0, "Full wipe retains corpse camera at the later checkpoint")
	app._physics_process(1.0 / 60.0)
	await capture("10-defeat")
	app._leave_to_menu()
	check(app.menu_screen == "main" and not app.hud.visible and app.audio._music_player.playing, "Leaving clears HUD and restores main menu music")
	app._start_training()
	check(not app.hud.text.contains("波"), "Engineering trial also removes upper wave count")
	app.training_drill = "ranged"
	app.paused = true
	app._show_menu_page("pause")
	app.menu_pages.pause.get_node("Restart").pressed.emit()
	check(app.training_active and app.sim.state.training.drill == "ranged", "Restart preserves engineering training mode")
	app.paused = true
	app._show_menu_page("engineering")
	app._open_selection(false)
	app.menu_pages.select.get_node("Back").pressed.emit()
	check(app.menu_screen == "pause" and app.paused, "Selection back returns an active battle to pause, not title")
	app._close_network()
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("MENU V20: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
