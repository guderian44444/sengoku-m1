extends SceneTree

const Main = preload("res://main.gd")
const Players = preload("res://core/player_store.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0
var captures := false
var output := ""

class App extends Main:
	func _connected_pads() -> Array[int]: return [3, 7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	assert(value, message)

func settle() -> void:
	for frame in range(4): await process_frame

func capture(name: String) -> void:
	if not captures: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Screenshot: " + name)

func page_check(app: Node, name: String) -> void:
	await settle()
	check(app.menu_screen == name and app.menu_pages[name].is_visible_in_tree(), "Visible page: " + name)
	check(app.menu_pages.values().filter(func(page): return page.is_visible_in_tree()).size() == 1, "Only current page shown: " + name)
	for page in app.menu_pages.values():
		if page.get_parent() is PanelContainer:
			check(page.get_parent().visible == page.visible, "Paper follows page visibility")
	var viewport := Rect2(0, 0, 1280, 666)
	for control in app.menu_pages[name].find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or control is ScrollBar: continue
		if control is BaseButton or control is LineEdit or control is ItemList or control is Slider:
			check(viewport.encloses(control.get_global_rect().grow(-1)), "%s/%s fits usable screen: %s" % [name, control.name, control.get_global_rect()])
	check(app.menu_footer.is_visible_in_tree() and app.menu_footer.get_global_rect().end.y <= 709, "Navigation hint is visible")
	await capture(name)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	captures = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	output = OS.get_environment("TEST_ARTIFACT_DIR")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../artifacts/ui-v34")
	DirAccess.make_dir_recursive_absolute(output)
	var app := App.new()
	root.add_child(app)
	app.testing = true
	app.set_physics_process(false)
	app.profiles = Players.new("user://ui-flow-%d" % Time.get_ticks_usec(), "user://ui-flow-no-legacy.json")
	await page_check(app, "title")
	app._show_menu_page("main")
	await page_check(app, "main")
	app._open_login(true)
	await page_check(app, "players")
	app._open_roster()
	await page_check(app, "roster")
	var row: Dictionary = app.profiles.character(0, "nobunaga")
	for id in ["sword_heshikiri", "sword_nagamitsu", "war", "wind", "mirror"]:
		Equipment.add(row, id)
	app.profiles.records[app.profiles.selected[0]].data.characters["0:nobunaga"] = row
	app._open_selection(true)
	await page_check(app, "select")
	app._open_collection(0)
	await page_check(app, "collection")
	app._open_weapon_encyclopedia(0, "collection")
	await page_check(app, "encyclopedia")
	app._open_achievements(0)
	await page_check(app, "achievements")
	app._open_options()
	await page_check(app, "options")
	app.engineer_entry.pressed.emit()
	await page_check(app, "engineering")
	app._request_confirmation(func(): pass, "出售 十文字大身槍（耐久 100）獲得 12345 文？\n請確認此物品已不再需要。")
	await page_check(app, "confirm")
	check(app.menu_pages.confirm.get_node("Cancel").has_focus(), "Destructive confirmation defaults to Cancel")
	app._cancel_confirmation()
	app._open_login(false)
	app.player_name_input.grab_focus()
	var press := InputEventJoypadButton.new()
	press.device = 3
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	press.pressed = false
	Input.parse_input_event(press.duplicate())
	Input.flush_buffered_events()
	await settle()
	await capture("keyboard")
	app.menu_input.keyboard.finish(false)
	app._start_solo()
	app._update_view()
	await settle()
	await capture("battle-hud")
	app.paused = true
	app._show_menu_page("pause")
	await page_check(app, "pause")
	app._show_controls()
	await settle()
	await capture("controls")
	app._close_controls()
	app.queue_free()
	await process_frame
	print("UI FLOW V34 PASS: %d checks" % checks)
	quit()
