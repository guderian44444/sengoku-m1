extends SceneTree

const Main = preload("res://main.gd")
var checks := 0
var failures := 0
var output := "res://../artifacts/native-v21/engineering"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func mouse(button: Control, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = down
	root.push_input(event, true)

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.window_id = root.get_window_id()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	# Window routing is required: Viewport.push_input skips embedded popup windows.
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func open_dropdown(button: OptionButton) -> void:
	mouse(button, true)
	await process_frame
	mouse(button, false)
	await process_frame
	check(button.get_popup().visible, "Dropdown opens through real GUI input")

func choose(button: OptionButton, index: int) -> void:
	button.get_popup().set_focused_item(index)
	key(KEY_ENTER, true)
	await process_frame
	key(KEY_ENTER, false)
	await process_frame
	check(not button.get_popup().visible and button.selected == index, "Keyboard confirms and closes dropdown item %d" % index)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture-v21" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Save " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var app := Main.new()
	root.add_child(app)
	app.set_physics_process(false)
	await process_frame
	root.notify_mouse_entered()
	# Keep the real focus callback: the old UI test disabled it and missed this crash.
	check(not app.testing, "Real window focus handling stays enabled")
	app.training_drill = "enemies"
	app._start_training()
	app.paused = true
	app._show_menu_page("engineering")
	await process_frame
	await open_dropdown(app.factions)
	app._set_game_focus(false)
	check(app.menu_screen == "engineering" and app.factions.get_popup().visible, "Popup focus handoff keeps its owning page alive")
	await capture("01-mori-popup")
	await choose(app.factions, 0)
	for index in range(1, Main.FACTION_NAMES.size()):
		await open_dropdown(app.factions)
		await choose(app.factions, index)
		check(app.menu_screen == "engineering", "Faction selection preserves engineering page")
	await open_dropdown(app.factions)
	await choose(app.factions, 0)
	app.menu_panel.find_child("EnemyTraining", true, false).pressed.emit()
	check(app.training_active and app.selected_faction == "mori" and not app.menu.visible, "Selected Mori faction enters its trial")
	check(app.sim.state.fighters.any(func(f): return f.team == 1 and f.faction == "mori"), "Mori trial has actual Mori enemies")
	await process_frame
	await capture("02-mori-trial")
	app.paused = true
	app._open_selection(false)
	await process_frame
	for button in [app.heroes, app.difficulties]:
		await open_dropdown(button)
		app._set_game_focus(false)
		check(app.menu_screen == "select" and button.get_popup().visible, "Hero and difficulty popups keep their owning page")
		await choose(button, 1)
	app._resume()
	app._set_game_focus(false)
	check(app.paused and app.menu_screen == "pause" and app.menu.visible, "Actual gameplay focus loss still pauses safely")
	app._close_network()
	app.queue_free()
	await process_frame
	print("ENGINEERING MENU V21: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
