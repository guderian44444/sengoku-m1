extends SceneTree

const Main = preload("res://main.gd")
const Profiles = preload("res://core/save_profile.gd")
const Collection = preload("res://ui/collection_panel.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
var checks := 0
var failures := 0
var output: String

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK,"Capture " + name)

func run() -> void:
	root.size = Vector2i(1280,720)
	output = OS.get_environment("TEST_ARTIFACT_DIR")
	if output == "": output = ProjectSettings.globalize_path("res://../artifacts/native-v26")
	DirAccess.make_dir_recursive_absolute(output)
	var generic := Collection.new()
	root.add_child(generic)
	generic.configure("測試",[
		{"id":"weapon","name":"武器","category":"武器","description":"能力","can_equip":true},
		{"id":"material","name":"素材","category":"材料","description":"未來物品","can_equip":false}
	],["weapon"])
	check(generic.categories.item_count == 3,"Categories come from item rows, including a non-weapon category")
	generic.categories.selected = 2
	generic.refresh_list()
	check(generic.listed.size() == 1 and generic.selected_id == "material" and generic.equip_button.disabled,"Non-equipment rows use the same page without weapon-specific behavior")
	generic.configure("空收藏",[],[])
	check(generic.selected_id == "" and generic.equip_button.disabled,"Empty collection clears stale actions")
	var full_collection := []
	for id in Weapons.ids_for("nobunaga"):
		full_collection.append({"id":id,"name":str(Weapons.item(id).name),"category":"武器","can_equip":true,"description":"階位、傷害與距離"})
	generic.configure("1P 信長　總積分 1000000000　生命追加 +10000",full_collection,["sword_uchigatana"])
	generic.select_item(str(full_collection[-1].id))
	await process_frame
	check(generic.listed.size() == 16 and generic.selected_id == full_collection[-1].id,"All sixteen collected weapons remain selectable")
	check(generic.equip_button.get_global_rect().end.y < 720 and generic.notice.get_global_rect().end.y <= 720,"Largest permanent values and full collection fit the equipment page")
	generic.queue_free()
	await process_frame
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	var path := output.path_join("characters-" + str(Time.get_ticks_usec()) + ".json")
	app.profiles = Profiles.new(path)
	for slot in range(2):
		var row: Dictionary = app.profiles.character(slot,"nobunaga")
		row.owned_weapons.append("sword_heshikiri" if slot == 0 else "sword_nagamitsu")
		app.profiles.data.characters["%d:nobunaga" % slot] = row
	app._open_selection(false)
	app.weapon_rows[0].get_node("Collection0").pressed.emit()
	await process_frame
	check(app.menu_screen == "collection" and app.collection.entries.size() == 2,"Selection opens only the player's collected equipment")
	check(app.collection.equipment_summary.text.contains("打刀") and app.collection.picture.texture != null,"Current weapon slot and actual weapon image are shown")
	check(not app.collection.entries.any(func(row): return row.id == "sword_dojigiri"),"Uncollected gear cannot enter the equipment list")
	check(app.collection.get_global_rect().end == Vector2(1280,720),"Equipment page fills the intended viewport")
	await capture("collection-selection")
	app.collection.details_requested.emit("sword_heshikiri")
	check(app.menu_screen == "encyclopedia" and app.encyclopedia.selected_id == "sword_heshikiri","Collected item opens its historical details")
	app._menu_back()
	check(app.menu_screen == "collection","Closing details returns to equipment, not character selection")
	app.collection.closed.emit()
	check(app.menu_screen == "select","Equipment page returns to its selection entry")
	app._start_solo()
	app.paused = true
	app.sim._enter_segment(2)
	app.sim.state.stage.checkpoint = 1
	app.sim.state.wave = 2
	var fighter: Dictionary = app.sim.state.fighters[0]
	fighter.hp = 66
	fighter.lives = 2
	fighter.score = 1234
	fighter.x = 930.0
	app._show_menu_page("pause")
	await process_frame
	check(app.menu_pages.pause.get_global_rect().end.y < 608,"Pause still fits after adding equipment controls")
	app.menu_pages.pause.get_node("Collections/Collection0").pressed.emit()
	app.collection.select_item("sword_heshikiri")
	app.collection.equip_button.pressed.emit()
	check(fighter.weapon_id == "sword_heshikiri","Pause equipment applies immediately to the current battle")
	check(fighter.hp == 66 and fighter.lives == 2 and fighter.score == 1234 and app.sim.state.stage.index == 2,"Changing gear preserves health, lives, score and the ongoing scene")
	check(Profiles.new(path).character(0,"nobunaga").weapon_id == "sword_heshikiri" and app.collection.notice.text.contains("已保存"),"Equipment persists and confirms success on the page")
	await capture("collection-paused")
	app._menu_back()
	check(app.menu_screen == "pause" and app.paused,"Equipment close returns to paused battle")
	app._save_characters(true)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.chapter == 1 and saved.completed_chapter == 0,"Save records the major chapter")
	check(not saved.has("stage") and not saved.characters["0:nobunaga"].has("x") and not saved.characters["0:nobunaga"].has("hp"),"Save contains no location, checkpoint, wave or battle snapshot")
	app._start_solo()
	app.paused = true
	fighter = app.sim.state.fighters[0]
	check(app.sim.state.stage.index == 0 and app.sim.state.stage.checkpoint == 0 and app.sim.state.wave == 1 and fighter.x < 300,"New sortie starts at the saved chapter's beginning")
	check(fighter.weapon_id == "sword_heshikiri" and fighter.score == 1234 and fighter.hp == fighter.max_hp and fighter.lives == 3,"Only permanent character and equipment data survive the restart")
	app.sim.state.phase = "won"
	app._save_characters(true)
	saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.completed_chapter == 1 and saved.chapter == 2,"Completing a chapter records its completion and next major chapter")
	app._leave_to_menu()
	app._open_selection(true)
	check(app.chapter_choice.item_count == 1 and app.chapter_choice.get_item_metadata(0) == 1,"Only implemented chapters appear; unavailable future chapters are not playable placeholders")
	check(app.status.text.contains("尚未開放"),"Completed chapter progress is retained and unavailable next chapter is explained")
	app.partner_heroes.selected = 0
	app._refresh_loadouts()
	app._start_local_coop()
	app.paused = true
	app.heroes.selected = 1
	app.partner_heroes.selected = 1
	app._show_menu_page("pause")
	app.menu_pages.pause.get_node("Collections/Collection1").pressed.emit()
	check(app.collection.title.text.contains("2P 信長"),"Battle gear uses the actual fighter even if hidden selection changed")
	app.collection.select_item("sword_nagamitsu")
	app.collection.equip_button.pressed.emit()
	check(app.sim.state.fighters[1].weapon_id == "sword_nagamitsu" and app.sim.state.fighters[0].weapon_id == "sword_heshikiri","Cooperative players equip independently even with the same hero")
	check(Profiles.new(path).character(1,"nobunaga").weapon_id == "sword_nagamitsu","Second-player equipment survives save reload")
	await capture("collection-coop")
	var valid: Dictionary = app.profiles.data.duplicate(true)
	for value in [0,25,1.5,INF,"1"]:
		var bad := valid.duplicate(true)
		bad.chapter = value
		check(not Profiles.valid(bad),"Reject invalid chapter value " + str(value))
	valid.erase("chapter")
	valid.erase("completed_chapter")
	check(Profiles.valid(valid),"Existing v1 character/equipment saves need no destructive migration")
	app._leave_to_menu()
	app._start_training()
	app._show_menu_page("pause")
	check(not app.menu_pages.pause.get_node("Collections").visible,"Engineering mode has no persistent equipment entry")
	app.queue_free()
	await process_frame
	print("COLLECTION / CHAPTER V26 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
