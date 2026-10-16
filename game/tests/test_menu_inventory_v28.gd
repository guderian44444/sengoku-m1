extends SceneTree

const Main = preload("res://main.gd")
const Players = preload("res://core/player_store.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var captures := false

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void:
	captures = "--capture-v28" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func screenshot(name: String) -> void:
	if not captures: return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("TEST_ARTIFACT_DIR")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../artifacts/native-v28")
	DirAccess.make_dir_recursive_absolute(output)
	check(get_root().get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Menu screenshot saved: "+name)

func run() -> void:
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	app.profiles = Players.new("user://menu-v28-%d" % Time.get_ticks_usec(),"user://no-legacy-v28.json")
	app._open_selection(false)
	check(app.character_panel.is_visible_in_tree() and app.character_panel.preview.fighter.kind == "nobunaga","Independent character screen renders standing hero")
	var profile = app.profiles.records[app.profiles.selected[0]]
	var row: Dictionary = app.profiles.character(0,"nobunaga")
	var blade := Equipment.add(row,"sword_heshikiri")
	var charm := Equipment.add(row,"war")
	Equipment.add(row,"wind")
	Equipment.add(row,"mirror")
	Equipment.sync(row)
	profile.data.characters["0:nobunaga"] = row
	app._refresh_loadouts()
	var before: String = app.character_panel.stats.text
	app._equip_inventory(0,blade)
	check(app.character_panel.stats.text != before and app.character_panel.preview.fighter.weapon_id == "sword_heshikiri","Equipping weapon changes actual preview and numbers immediately")
	before = app.character_panel.stats.text
	app._equip_inventory(0,charm)
	check(app.character_panel.stats.text != before and app.character_panel.preview.fighter.shield_kind == "war","Equipping charm changes protection and attack immediately")
	await process_frame
	await process_frame
	var preview = app.character_panel.preview
	var preview_frame: Dictionary = preview._art.animation_frame("nobunaga",preview._fighter_animation(preview.fighter))
	var icon_bounds := View.buff_rect(preview_frame,155)
	icon_bounds = Rect2(preview.position+icon_bounds.position*preview.scale,icon_bounds.size*preview.scale)
	check(Rect2(Vector2.ZERO,preview.get_parent().size).encloses(icon_bounds),"Character preview keeps the overhead function icon fully inside its panel")
	check(app.profiles.character(0,"nobunaga").weapon_uid == blade,"Equipment saved for selected player")
	await screenshot("character-select")
	app._open_collection(0)
	check(app.collection.entries.size() == 4,"Warehouse shows distinct instances; permanent baseline occupies no storage")
	check(app.collection.sell_button.disabled,"Equipped gear cannot be sold")
	await screenshot("inventory")
	var spare: int = app.profiles.character(0,"nobunaga").inventory.filter(func(item): return item.item_id == "wind")[0].uid
	app.collection.select_item(str(spare))
	app._request_sale(str(spare))
	check(app.menu_screen == "confirm","Sale shows concrete item and price before confirmation")
	app._cancel_confirmation()
	check(app.profiles.character(0,"nobunaga").inventory.size() == 4,"Cancelled sale preserves inventory")
	app._request_sale(str(spare))
	app._accept_confirmation()
	check(app.profiles.character(0,"nobunaga").inventory.size() == 3 and app.profiles.character(0,"nobunaga").gold > 0,"Confirmed sale removes one instance and credits money")
	app._menu_back()
	app._open_achievements(0)
	check(app.achievements_list.item_count == 30,"Achievement page lists all 30 conditions")
	await screenshot("achievements")
	app._menu_back()
	app._open_players()
	app.player_name_input.text = "新武士"
	app._add_player()
	check(app.profiles.name_for(0) == "新武士" and app.profiles.character(0,"nobunaga").score == 0,"Player settings create and switch to a fresh account")
	await screenshot("players")
	app._menu_back()
	app._open_selection(true)
	app.partner_heroes.selected = 0
	app._refresh_loadouts()
	for slot in range(2):
		var choice: OptionButton = app.character_panel.player_choices[slot]
		check(choice.get_item_metadata(choice.selected) == app.profiles.selected[slot] and choice.text == app.profiles.name_for(slot),"Player selector visibly matches the account used by the character screen")
	await screenshot("coop-select")
	for slot in range(2):
		var choice: OptionButton = app.character_panel.player_choices[slot]
		check(choice.get_item_metadata(choice.selected) == app.profiles.selected[slot] and choice.text == app.profiles.name_for(slot),"Rendered selector still matches its player's save after layout")
	row = app.profiles.character(0,"nobunaga")
	var uid := Equipment.add(row,"wind")
	Equipment.pack(row,uid,true)
	app.profiles.records[app.profiles.selected[0]].data.characters["0:nobunaga"] = row
	app._start_local_coop()
	check(app.active and app.session == "local","Two different local players can start together")
	app.sim.state.fighters[0].score = 1234
	app.sim.state.fighters[1].score = 5678
	app._save_characters(true)
	var restored := Players.new(app.profiles.directory,"user://no-legacy-v28.json")
	check(restored.character(0,"nobunaga").score == 1234 and restored.character(1,"nobunaga").score == 5678,"Same hero in co-op saves to separate account files")
	app.paused = true
	app._show_menu_page("pause")
	app._open_collection(0)
	row = app.profiles.character(0,"nobunaga")
	var health: int = app.sim.state.fighters[0].hp
	app._equip_inventory(0,uid)
	check(app.sim.state.fighters[0].shield_kind == "wind" and app.sim.state.fighters[0].hp == health,"Pause equipment changes preserve live HP and update charm")
	check(View.shield_glow_color(app.sim.state.fighters[0]).a == 0,"Charm no longer produces surrounding glow")
	app._menu_back()
	app._leave_to_menu()
	app._accept_confirmation()
	check(not app.active,"Confirmed leave flushes progress before returning")
	app._open_selection(false)
	app.heroes.selected = 5
	app._refresh_loadouts()
	await screenshot("tadakatsu-select")
	var spearman: Dictionary = app.character_panel.preview.fighter
	spearman.action = "light"
	spearman.combo = 1
	spearman.action_tick = Battle.fighter_tick(spearman,6)
	app.character_panel.preview.art_demo = false
	var sample: Dictionary = app.view._fighter_animation(spearman)
	var frame: Dictionary = app.view._art.animation_frame("tadakatsu",sample)
	var pose: Dictionary = app.view._weapons.geometry(spearman,frame,155)
	check(absf(Weapons.spear_reach(spearman)-maxf(pose.top.x,pose.bottom.x)) < 0.01,"Authoritative melee extent equals renderer's tip at contact frame")
	for id in Weapons.ids_for("tadakatsu"):
		for attack in [["light",1,6],["light",2,6],["light",3,6],["heavy",1,14],["heavy",2,14]]:
			var actor := spearman.duplicate(true)
			actor.weapon_id = id
			actor.action = attack[0]
			actor.combo = attack[1]
			actor.heavy_combo = attack[1]
			actor.attack_speed = float(Weapons.item(id).attack_speed)
			actor.action_tick = Battle.fighter_tick(actor,attack[2])
			sample = app.view._fighter_animation(actor)
			frame = app.view._art.animation_frame("tadakatsu",sample)
			pose = app.view._weapons.geometry(actor,frame,155)
			check(absf(Weapons.spear_reach(actor)-maxf(pose.top.x,pose.bottom.x)) < 0.01,"Every spear's primary contact frame shares its collision extent: " + id + "/" + str(attack))
	for hero_index in [1,2]:
		app.heroes.selected = hero_index
		var hero: String = Battle.HEROES[hero_index]
		row = app.profiles.character(0,hero)
		var charm_uid := Equipment.add(row,"marici")
		Equipment.sync(row)
		app.profiles.records[app.profiles.selected[0]].data.characters["0:"+hero] = row
		app._refresh_loadouts()
		app._equip_inventory(0,charm_uid)
		await process_frame
		await process_frame
		preview = app.character_panel.preview
		preview_frame = preview._art.animation_frame(hero,preview._fighter_animation(preview.fighter))
		icon_bounds = View.buff_rect(preview_frame,148 if hero == "oichi" else 155).grow_individual(24,0,24,0)
		icon_bounds = Rect2(preview.position+icon_bounds.position*preview.scale,icon_bounds.size*preview.scale)
		check(Rect2(Vector2.ZERO,preview.get_parent().size).encloses(icon_bounds),hero+" preview fits all three charm icons without clipping")
		await screenshot(hero+"-select-v30")
	if captures:
		app._open_selection(true)
		app.heroes.selected = 2
		app.partner_heroes.selected = 1
		app._refresh_loadouts()
		app._start_local_coop()
		for index in range(2):
			var fighter: Dictionary = app.sim.state.fighters[index]
			fighter.x = 440+index*280
			fighter.y = 540
			Equipment.equip(fighter,Equipment.add(fighter,"marici" if index == 0 else "atago"))
		check(Wire.valid_snapshot(app.sim.state),"The new two-hero battle capture uses legal equipment and state")
		app._update_view()
		await screenshot("battle-oichi-hideyoshi-v30")
	print("MENU INVENTORY V28 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	app.free()
	quit(1 if failures else 0)
