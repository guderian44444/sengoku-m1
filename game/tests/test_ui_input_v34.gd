extends SceneTree

const Main = preload("res://main.gd")
var checks := 0
var failures := 0

class App extends Main:
	func _connected_pads() -> Array[int]: return [0, 3, 7]
	func _set_game_focus(_focused: bool) -> void: pass
	func simulate_game_focus(focused: bool) -> void: super._set_game_focus(focused)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func button(code: JoyButton, device: int = 3) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func key(code: Key, unicode: int = 0) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func axis(code: JoyAxis, value: float, device: int = 7) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	var app := App.new()
	root.add_child(app)
	app.testing = true
	app.set_physics_process(false)
	await process_frame
	await process_frame
	var nav = app.menu_input
	for page in app.menu_pages:
		app._show_menu_page(page)
		await process_frame
		var controls: Array[Control] = nav.focusables()
		check(not controls.is_empty(), page + " has a focusable action")
		var reached: Array[Control] = []
		for step in range(controls.size()):
			var focus := root.gui_get_focus_owner()
			check(focus in controls and focus.is_visible_in_tree(), page + " focuses only visible controls")
			if focus not in reached: reached.append(focus)
			nav.cycle(1)
		check(reached.size() == controls.size(), page + " cycle reaches every active control")
	app._open_login(false)
	await process_frame
	for device in [0, 3, 7]:
		app.player_name_input.text = "舊名"
		app.player_name_input.grab_focus()
		button(JOY_BUTTON_A, device)
		check(nav.keyboard.visible, "Pad %d opens text keyboard" % device)
		check(nav.keyboard.editor.text == "舊名", "Opening preserves draft source")
		nav.keyboard.editor.clear()
		button(JOY_BUTTON_A, device)
		check(nav.keyboard.editor.text == "林", "Pad selects a Traditional Chinese name character")
		check(app.player_name_input.text == "舊名", "Draft does not change target before confirmation")
		button(JOY_BUTTON_B, device)
		check(not nav.keyboard.visible and app.player_name_input.text == "舊名", "Cancel preserves original")
		check(root.gui_get_focus_owner() == app.player_name_input, "Cancel restores field focus")
		button(JOY_BUTTON_A, device)
		nav.keyboard.editor.clear()
		button(JOY_BUTTON_A, device)
		button(JOY_BUTTON_RIGHT_SHOULDER, device)
		button(JOY_BUTTON_A, device)
		check(nav.keyboard.editor.text == "林a", "Pad changes to Latin character bank")
		button(JOY_BUTTON_X, device)
		check(nav.keyboard.editor.text == "林", "Pad deletes exactly one character")
		button(JOY_BUTTON_START, device)
		check(app.player_name_input.text == "林" and not nav.keyboard.visible, "Pad commits text")
	app.player_name_input.clear()
	app.player_name_input.grab_focus()
	key(KEY_A, 97)
	key(KEY_SPACE, 32)
	key(KEY_B, 98)
	key(KEY_NONE, "龍".unicode_at(0))
	check(app.player_name_input.text == "a b龍", "Native LineEdit receives spaces, Latin and committed Chinese text")
	check(app.menu_screen == "players", "Typing does not trigger menu actions")
	app.demo_active = true
	key(KEY_S, 115)
	key(KEY_SPACE, 32)
	check(app.player_name_input.text == "a b龍s ", "Demo shortcuts do not consume text on menu pages")
	app.demo_active = false
	app.player_name_input.text = "a b龍"
	button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != app.player_name_input, "Pad can leave a text field")
	app.player_name_input.grab_focus()
	button(JOY_BUTTON_A)
	nav.keyboard.editor.clear()
	key(KEY_Z, 122)
	check(nav.keyboard.editor.text == "z", "Physical typing moves into overlay editor")
	for count in range(35): nav.keyboard.insert_character("林")
	check(nav.keyboard.editor.text.length() == 20, "Virtual keyboard respects name length")
	key(KEY_ESCAPE)
	check(app.player_name_input.text == "a b龍", "Escape discards long overlay draft")
	app._show_menu_page("engineering")
	await process_frame
	app.address.grab_focus()
	button(JOY_BUTTON_A)
	check(nav.keyboard.bank == 3, "Address starts on numeric and symbol bank")
	nav.keyboard.editor.clear()
	for character in "192.168.1.8": nav.keyboard.insert_character(character)
	button(JOY_BUTTON_START)
	check(app.address.text == "192.168.1.8", "Address commits punctuation")
	app.port.get_line_edit().grab_focus()
	var old_port: int = int(app.port.value)
	button(JOY_BUTTON_DPAD_RIGHT)
	check(int(app.port.value) == old_port + 1, "SpinBox uses horizontal adjustment")
	button(JOY_BUTTON_A)
	check(nav.keyboard.numeric, "Port opens a numeric keyboard")
	check(nav.keyboard.editor.text == str(int(app.port.value)), "Port keyboard starts with number without UDP prefix")
	nav.keyboard.editor.text = "27900"
	button(JOY_BUTTON_START)
	check(int(app.port.value) == 27900, "Port confirmation updates numeric value")
	button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != app.port.get_line_edit(), "SpinBox can be left with down")
	app._show_menu_page("options")
	await process_frame
	var slider: Slider = app.volume_sliders.values()[0]
	slider.value = 40
	slider.grab_focus()
	button(JOY_BUTTON_DPAD_RIGHT)
	check(slider.value > 40, "Slider adjusts with horizontal navigation")
	button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != slider, "Slider does not trap vertical navigation")
	app._open_roster()
	await process_frame
	for device in [0, 3, 7]:
		app.roster_choices[0].selected = 0
		app.roster_choices[0].grab_focus()
		button(JOY_BUTTON_A, device)
		await process_frame
		var popup: PopupMenu = app.roster_choices[0].get_popup()
		check(popup.visible, "Pad %d opens popup" % device)
		button(JOY_BUTTON_DPAD_DOWN, device)
		button(JOY_BUTTON_A, device)
		check(not popup.visible and app.roster_choices[0].selected == 1, "Pad %d selects popup entry once" % device)
		await process_frame
		button(JOY_BUTTON_A, device)
		await process_frame
		check(popup.visible, "Pad %d can reopen selected popup" % device)
		button(JOY_BUTTON_B, device)
		await process_frame
		check(not popup.visible and app.menu_screen == "roster", "Popup cancel does not leave page")
	app._open_achievements(0)
	await process_frame
	app.achievements_list.grab_focus()
	app.achievements_list.select(app.achievements_list.item_count - 1)
	button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != app.achievements_list, "ItemList bottom exits instead of trapping focus")
	app.achievements_list.grab_focus()
	button(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner() != app.achievements_list, "ItemList horizontal exit")
	app._open_weapon_encyclopedia(0)
	await process_frame
	await process_frame
	app.encyclopedia.detail_scroll.grab_focus()
	app.encyclopedia.detail_scroll.scroll_vertical = 0
	button(JOY_BUTTON_DPAD_DOWN)
	check(app.encyclopedia.detail_scroll.scroll_vertical > 0, "Focused detail text scrolls")
	var scroll_before: int = app.encyclopedia.detail_scroll.scroll_vertical
	axis(JOY_AXIS_RIGHT_Y, 1.0)
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	check(app.encyclopedia.detail_scroll.scroll_vertical > scroll_before, "Right stick scrolls detail text")
	app._show_menu_page("main")
	await process_frame
	var before := root.gui_get_focus_owner()
	axis(JOY_AXIS_LEFT_Y, 1.0)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	check(root.gui_get_focus_owner() != before, "Left stick moves focus on nonzero device")
	axis(JOY_AXIS_LEFT_Y, 1.0)
	axis(JOY_AXIS_RIGHT_Y, 1.0)
	app._joy_changed(7, false)
	check(nav.held == Vector2i.ZERO and is_zero_approx(nav.scroll_axis), "Disconnecting a controller clears held menu motion and scrolling without a release event")
	axis(JOY_AXIS_LEFT_Y, 0.0)
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	axis(JOY_AXIS_LEFT_Y, 1.0)
	app.simulate_game_focus(false)
	check(nav.held == Vector2i.ZERO, "Focus loss clears held menu navigation immediately")
	app.simulate_game_focus(true)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	app._has_focus = false
	before = root.gui_get_focus_owner()
	button(JOY_BUTTON_DPAD_DOWN)
	button(JOY_BUTTON_A)
	check(root.gui_get_focus_owner() == before and app.menu_screen == "main", "Background controller events cannot navigate or accept")
	app._has_focus = true
	axis(JOY_AXIS_LEFT_Y, 1.0)
	app._show_controls()
	check(nav.held == Vector2i.ZERO, "Opening instructions clears held menu navigation")
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await process_frame
	button(JOY_BUTTON_B, 7)
	check(not app.controls_dialog.visible, "Any controller closes instructions")
	check(app.menu_screen == "main", "Closing instructions does not also leave page")
	app._show_controls()
	app._has_focus = false
	var background_cancel := InputEventJoypadButton.new()
	background_cancel.button_index = JOY_BUTTON_B
	background_cancel.pressed = true
	nav._controls_input(background_cancel)
	check(app.controls_dialog.visible, "Background controller cannot close instructions")
	app._close_controls()
	check(app.paused, "Closing unfocused instructions never resumes battle")
	app._has_focus = true
	print("V34 UI INPUT %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	app.queue_free()
	quit(0 if failures == 0 else 1)
