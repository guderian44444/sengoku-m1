extends SceneTree

const Main = preload("res://main.gd")
const Profiles = preload("res://core/save_profile.gd")
var checks := 0
var failures := 0

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v22")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK,"Native screenshot " + filename)

func run() -> void:
	root.size = Vector2i(1280,720)
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	var folder := ProjectSettings.globalize_path("res://../artifacts/native-v22/menu-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("characters.json")
	app.profiles = Profiles.new(path)
	var row: Dictionary = app.profiles.character(0,"nobunaga")
	row.owned_weapons.append("sword_heshikiri")
	row.weapon_id = "sword_heshikiri"
	row.score = 2200
	app.profiles.data.characters["0:nobunaga"] = row
	var second: Dictionary = app.profiles.character(1,"nobunaga")
	second.owned_weapons.append("sword_nagamitsu")
	second.weapon_id = "sword_nagamitsu"
	app.profiles.data.characters["1:nobunaga"] = second
	check(app.profiles.save() == OK,"Fixture writes only its isolated profile path")
	app._open_selection(false)
	await process_frame
	check(app.weapon_rows[0].visible and not app.weapon_rows[1].visible,"Solo shows one equipped weapon selector")
	check(app.weapon_choices[0].item_count == 2 and app.weapon_choices[0].get_item_metadata(app.weapon_choices[0].selected) == "sword_heshikiri","Selection shows loaded owned weapons and current equipment")
	check(app.menu_pages.select.get_global_rect().end.y < 608,"Loadout page fits above shared status")
	await capture("loadout-solo.png")
	app.heroes.selected = 1
	app.heroes.item_selected.emit(1)
	check(app.weapon_choices[0].item_count == 1 and app.weapon_choices[0].get_item_metadata(0) == "bow_azusa","Changing hero switches to that hero's saved family")
	app.heroes.selected = 0
	app.heroes.item_selected.emit(0)
	app.weapon_choices[0].selected = 0
	app.weapon_choices[0].item_selected.emit(0)
	check(Profiles.new(path).character(0,"nobunaga").weapon_id == "sword_uchigatana","Actual loadout signal persists selected owned weapon")
	app.weapon_choices[0].selected = 1
	app.weapon_choices[0].item_selected.emit(1)
	app._start_solo()
	app.paused = true
	var first: Dictionary = app.sim.state.fighters[0]
	check(first.weapon_id == "sword_heshikiri" and first.score == 2200 and first.lives == 3,"Starting a real campaign applies saved equipment and attributes")
	first.score = 3300
	app._show_menu_page("pause")
	await process_frame
	check(app.menu_pages.pause.get_global_rect().end.y < 608 and app.menu_pages.pause.get_node("SaveCharacters").visible,"Pause provides a reachable manual save button")
	app.menu_pages.pause.get_node("SaveCharacters").pressed.emit()
	check(Profiles.new(path).character(0,"nobunaga").score == 3300 and app.status.text.contains("已保存"),"Manual save writes attributes and visibly acknowledges success")
	app._leave_to_menu()
	app._open_selection(true)
	app.partner_heroes.selected = 0
	app.partner_heroes.item_selected.emit(0)
	await process_frame
	check(app.weapon_rows[1].visible and app.weapon_choices[1].get_item_metadata(app.weapon_choices[1].selected) == "sword_nagamitsu","Coop same-hero second slot reads its own equipment")
	check(app.menu_pages.select.get_global_rect().end.y < 608,"Two-player loadout still fits")
	await capture("loadout-coop.png")
	app._start_local_coop()
	app.paused = true
	check(app.sim.state.fighters[0].weapon_id == "sword_heshikiri" and app.sim.state.fighters[1].weapon_id == "sword_nagamitsu","Actual coop launch does not merge same-hero inventories")
	await capture("equipped-hud.png")
	app.sim.state.fighters[1].score = 555
	app._leave_to_menu()
	check(Profiles.new(path).character(1,"nobunaga").score == 555,"Leaving automatically saves each local player's attributes")
	var unchanged := FileAccess.get_file_as_string(path)
	app._start_training()
	app.sim.state.fighters[0].score = 900000
	app._save_characters(true)
	app._leave_to_menu()
	check(FileAccess.get_file_as_string(path) == unchanged,"Engineering training cannot contaminate persistent progression")
	app.queue_free()
	await process_frame
	print("LOADOUT / MENU V22 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
