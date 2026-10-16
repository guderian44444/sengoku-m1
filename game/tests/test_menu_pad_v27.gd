extends SceneTree

const Main = preload("res://main.gd")
var checks := 0
var failures := 0
var confirmed := 0

class App extends Main:
	func _connected_pads() -> Array[int]: return [0,3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func button(device: int, code: JoyButton) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func run() -> void:
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	var app := App.new()
	root.add_child(app)
	app.testing = true
	app.set_physics_process(false)
	await process_frame
	for device in [0,3,7]:
		app._show_menu_page("title")
		button(device,JOY_BUTTON_A)
		check(app.menu_screen == "players","Pad %d confirms title into player login once" % device)
		app._show_menu_page("main")
		var focus := root.gui_get_focus_owner()
		button(device,JOY_BUTTON_DPAD_DOWN)
		check(root.gui_get_focus_owner() != focus,"Pad %d moves menu focus" % device)
		app.menu_pages.main.get_node("Solo").grab_focus()
		button(device,JOY_BUTTON_A)
		check(app.menu_screen == "players","Pad %d opens player login" % device)
		app.players_continue.grab_focus()
		button(device,JOY_BUTTON_A)
		check(app.menu_screen == "roster","Pad %d proceeds from login to hero choice" % device)
		app.roster_choices[0].grab_focus()
		button(device,JOY_BUTTON_A)
		await process_frame
		check(app.roster_choices[0].get_popup().visible,"Pad %d opens an option list" % device)
		button(device,JOY_BUTTON_B)
		await process_frame
		check(not app.roster_choices[0].get_popup().visible and app.menu_screen == "roster","Pad %d closes only the option list" % device)
		app._request_confirmation(func(): confirmed += 1,"Test confirmation")
		await process_frame
		button(device,JOY_BUTTON_A)
		check(app.menu_screen == "roster" and confirmed == 0,"Pad %d defaults to Cancel" % device)
		app._request_confirmation(func(): confirmed += 1,"Test confirmation")
		await process_frame
		button(device,JOY_BUTTON_DPAD_DOWN)
		check(root.gui_get_focus_owner() == app.menu_pages.confirm.get_node("Confirm"),"Pad %d moves focus to Confirm" % device)
		button(device,JOY_BUTTON_A)
		check(app.menu_screen == "roster" and confirmed == 1,"Pad %d can choose and activate Confirm exactly once" % device)
		confirmed = 0
		await process_frame
		button(device,JOY_BUTTON_B)
		check(app.menu_screen == "players","Pad %d returns to login with Back" % device)
	app._show_menu_page("title")
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	check(app.menu_screen == "players","Keyboard Enter still confirms into login")
	app._start_solo()
	app.paused = true
	app._show_menu_page("pause")
	var row: Dictionary = app.profiles.character(0,"nobunaga")
	var equipment = preload("res://core/equipment.gd")
	for id in ["sword_nagamitsu","war"]: equipment.pack(row,equipment.add(row,id),true)
	app.profiles.records[app.profiles.selected[0]].data.characters["0:nobunaga"] = row
	app._open_collection(0)
	button(3,JOY_BUTTON_RIGHT_SHOULDER)
	check(app.collection.categories.current_tab == 1 and app.collection.listed.size() == 1 and app.collection.listed[0].category == "刀","Shoulder button filters actual carried items to swords")
	button(3,JOY_BUTTON_LEFT_SHOULDER)
	check(app.collection.categories.current_tab == 0 and app.collection.listed.size() == 2,"Left shoulder returns to both carried categories")
	app._menu_back()
	app.menu_pages.pause.get_node("Leave").grab_focus()
	button(3,JOY_BUTTON_A)
	check(app.active and app.menu_screen == "confirm","Leaving a battle still requires confirmation")
	await process_frame
	button(3,JOY_BUTTON_A)
	check(app.active and app.menu_screen == "pause","Default Cancel preserves the battle")
	app.menu_pages.pause.get_node("Leave").grab_focus()
	button(3,JOY_BUTTON_A)
	await process_frame
	button(3,JOY_BUTTON_DPAD_DOWN)
	button(3,JOY_BUTTON_A)
	check(not app.active and app.menu_screen == "main","Explicit confirmation returns to the main menu")
	print("V27 MENU PAD %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	app.queue_free()
	quit(0 if failures == 0 else 1)
