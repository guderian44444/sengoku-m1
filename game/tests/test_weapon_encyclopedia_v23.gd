extends SceneTree

const Archive = preload("res://core/weapon_encyclopedia.gd")
const EncyclopediaPanel = preload("res://ui/weapon_encyclopedia_panel.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Main = preload("res://main.gd")
const Profiles = preload("res://core/save_profile.gd")
const Typography = preload("res://render/game_typography.gd")
var checks := 0
var failures := 0

class App extends Main:
	func _set_game_focus(_focused: bool) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var archive := Archive.new()
	check(archive.warning == "", "Encyclopedia JSON loads")
	check(archive.entries.size() == 48,"48 historical and reconstructed entries")
	for id: String in Weapons.ITEMS:
		var entry: Dictionary = archive.entry(id)
		check(archive.entries.has(id),"Historical entry: " + id)
		check(not entry.facts.is_empty() and not entry.sources.is_empty(),"Facts and source: " + id)
		check(Archive.stats(id).contains(str(Weapons.item(id).damage_bonus)),"Stats read catalog: " + id)
		for source in entry.sources: check(Archive.safe_url(str(source.url)),"HTTPS source: " + id)
	check(not Archive.stats("sword_kanesada_mino").contains("+-"),"Negative short-blade reach displays correctly")
	check(not Archive.image_allowed({"url":"https://example.org/image.jpg","source_url":"https://example.org","license":"unknown"}),"Unknown image rights blocked")
	check(not Archive.image_allowed({"url":"file:///tmp/image.jpg","source_url":"https://example.org","license":"CC0"}),"Non-HTTPS image blocked")
	check(Archive.image_allowed({"url":"https://example.org/image.jpg","source_url":"https://example.org","license":"CC0","embed_allowed":true,"credit":"Test museum","local_path":"res://assets/v22/weapons/references/test.png"}),"Explicit public license and local reference schema allowed")
	var panel := EncyclopediaPanel.new()
	panel.theme = Typography.theme()
	root.add_child(panel)
	panel.configure("nobunaga",["sword_uchigatana","sword_heshikiri"],"sword_uchigatana")
	await process_frame
	await process_frame
	check(panel.listed_ids.size() == Weapons.ITEMS.size(),"List includes all weapons regardless of ownership")
	check(panel.equip_button.disabled,"Equipped item cannot be re-equipped")
	panel.select_weapon("sword_heshikiri")
	check(not panel.equip_button.disabled,"Owned same-family item can be equipped")
	check(panel.game_text.text.contains("火"),"Element comes from catalog")
	panel.select_weapon("sword_dojigiri")
	check(panel.equip_button.disabled,"Unowned item cannot be equipped")
	panel.select_weapon("bow_azusa")
	check(panel.equip_button.disabled,"Foreign family cannot be equipped")
	panel.filter.selected = 1
	panel.filter.item_selected.emit(1)
	check(panel.listed_ids.size() == 16,"Sword filter has sixteen entries")
	for id in panel.listed_ids: check(Weapons.item(id).family == "sword","Filter does not leak other families")
	panel.filter.selected = 0
	panel.refresh_list()
	for id in panel.listed_ids:
		panel.select_weapon(id)
		await process_frame
		check(panel.history_text.size.x >= 200,"History column readable: " + id)
		check(panel.game_text.get_global_rect().end.x <= 1258,"Gameplay column fits screen: " + id)
		check(panel.sources_box.get_child_count() > 0,"Sources clickable: " + id)
		if archive.entry(id).reference_images.is_empty():
			check(panel.references_box.get_child(0).text.contains("實物照片待授權"),"Honest image placeholder: " + id)
	var local_reference: Dictionary = archive.entry("spear_jumonji").reference_images[0]
	panel.show_reference(local_reference)
	check(panel.preview.visible and panel.preview_texture.texture != null,"Licensed local reference opens at larger size")
	panel.preview.confirmed.emit()
	panel.preview.hide()
	check(panel.preview_texture.texture == null,"Image dismissal clears texture")
	panel.configure("oichi",["bow_azusa"],"bow_azusa")
	check(panel.selected_id == "bow_azusa" and panel.listed_ids.size() == Weapons.ITEMS.size(),"Reopening resets filter and selection for correct player")
	panel.cancel_preview()
	panel.cancel_preview()
	check(panel.preview_texture.texture == null,"Repeated image dismissal safely clears preview")
	if DisplayServer.get_name() != "headless":
		panel.select_weapon("sword_kanesada_mino")
		await process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://../artifacts/native-v23")
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join("weapon-encyclopedia.png")) == OK,"Encyclopedia screenshot")
	panel.queue_free()
	await process_frame
	if "--integration" in OS.get_cmdline_user_args(): await integration()
	print("WEAPON ENCYCLOPEDIA V23 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)

func integration() -> void:
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	var folder := ProjectSettings.globalize_path("res://../artifacts/native-v23/encyclopedia-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	app.profiles = Profiles.new(folder.path_join("characters.json"))
	var saved: Dictionary = app.profiles.character(0,"nobunaga")
	saved.owned_weapons.append("sword_heshikiri")
	app.profiles.data.characters["0:nobunaga"] = saved
	app._open_selection(false)
	await process_frame
	app.weapon_rows[0].get_node("Encyclopedia0").pressed.emit()
	check(app.menu_screen == "encyclopedia" and app.encyclopedia.selected_id == "sword_uchigatana","Loadout button opens selected player's encyclopedia")
	check(not app.status.visible and not app.engineer_entry.visible,"Archive hides overlapping status and engineering controls")
	app.encyclopedia.select_weapon("sword_heshikiri")
	app.encyclopedia.equip_button.pressed.emit()
	check(Profiles.new(folder.path_join("characters.json")).character(0,"nobunaga").weapon_id == "sword_heshikiri","Archive equipment persists via profile")
	check(app.encyclopedia.equipped == "sword_heshikiri","Archive equipped marker refreshes")
	app.encyclopedia.show_reference(app.encyclopedia.archive.entry("spear_jumonji").reference_images[0])
	app._menu_back()
	check(app.menu_screen == "encyclopedia" and not app.encyclopedia.preview.visible,"Back dismisses photo before leaving archive")
	app.encyclopedia.closed.emit()
	check(app.menu_screen == "select" and app.status.visible,"Archive close restores selection and status")
	check(app.weapon_choices[0].get_item_metadata(app.weapon_choices[0].selected) == "sword_heshikiri","Loadout selector matches archive equipment")
	app._open_selection(true)
	app.partner_heroes.selected = 1
	app._refresh_loadouts()
	for repeat in range(3):
		app.weapon_rows[1].get_node("Encyclopedia1").pressed.emit()
		check(app.encyclopedia.selected_id == "bow_azusa","Repeated open uses second-player inventory")
		app._menu_back()
		check(app.menu_screen == "select","Back returns to selection without losing cooperative context")
	app.queue_free()
	await process_frame
