extends SceneTree

const Profiles = preload("res://core/player_store.gd")
const Stages = preload("res://core/stage_data.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var capture_dir := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func chapter_ids(app) -> Array:
	var ids := []
	for index in app.chapter_choice.item_count:
		ids.append(int(app.chapter_choice.get_item_metadata(index)))
	return ids

func title_to_selection(app) -> void:
	check(app.menu_screen == "title" and not app.active,"Normal main scene opens the title")
	app.menu_pages.title.get_node("Start").pressed.emit()
	check(app.menu_screen == "players","Title enters the normal player roster")
	app.players_continue.pressed.emit()
	check(app.menu_screen == "roster","Player roster enters hero selection")
	app.menu_pages.roster.get_node("Continue").pressed.emit()
	check(app.menu_screen == "select","Hero selection enters normal chapter selection")

func capture(app, name: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name+".png")) == OK,"Capture "+name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		assert(DisplayServer.get_name() != "headless")
		assert(DirAccess.make_dir_recursive_absolute(capture_dir) == OK)
		root.size=Vector2i(1280,720)
	var profile_dir := "user://stage05-campaign-flow-%d" % Time.get_ticks_usec()
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.profiles=Profiles.new(profile_dir,"user://missing-campaign-flow-legacy.json")
	check(not app.testing and not app.training_active and not app.demo_active,"Normal runtime, without a test-mode chapter override")
	check(Stages.available().map(func(s):return int(s.id)) == [1,2,3,4,5],"All five production chapters are registered")
	await capture(app,"01-title")
	title_to_selection(app)
	check(chapter_ids(app) == [1],"A new player keeps normal progress gating")
	# Fixture: a player has completed chapter three; the remaining path uses normal menus and saves.
	app.profiles.capture_chapter(3,true)
	check(app.profiles.save() == OK,"Save chapter-three fixture in the isolated test profile")
	app._open_selection(false)
	check(chapter_ids(app) == [1,2,3,4],"Chapter four is available and five remains locked before victory")
	check(int(app.chapter_choice.get_item_metadata(app.chapter_choice.selected)) == 4,"Normal selection defaults to the saved next chapter")
	app.character_panel.begin_requested.emit()
	check(app.active and app.session == "solo" and int(app.sim.state.stage.id) == 4,"Normal sortie starts chapter four")
	# Fixture: final encounter cleanup; retain the actual retreat, victory, autosave and menu code.
	app.sim._enter_segment(app.sim.state.stage.total-1)
	app.sim._start_checkpoint(app.sim.state.stage.checkpoint_total-1)
	app.sim.state.intro.clear()
	for tick in 2100:
		for enemy in app.sim.state.fighters:
			if enemy.team == 1: enemy.hp=0;enemy.entering=false
		app._physics_process(1.0/60)
		if app.sim.state.phase == "won": break
	check(app.sim.state.phase == "won" and app.sim.state.mikawa.escape_complete,"Actual final retreat and checkpoint completion produce chapter-four victory")
	for tick in 121: app._physics_process(1.0/60)
	var persisted := Profiles.new(profile_dir,"user://missing-campaign-flow-legacy.json")
	check(persisted.data.chapter == 5 and persisted.data.completed_chapter == 4,"Normal victory autosave persists chapter-five unlock")
	app._leave_to_menu()
	check(app.menu_screen == "confirm","Normal return asks to save and leave")
	app.menu_pages.confirm.get_node("Confirm").pressed.emit()
	check(app.menu_screen == "main" and not app.active,"Return to the full main menu after chapter-four victory")
	app.queue_free()
	await process_frame
	# A fresh Main instance reads the persisted profile, as a restart of the full launcher does.
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.profiles=Profiles.new(profile_dir,"user://missing-campaign-flow-legacy.json")
	title_to_selection(app)
	check(chapter_ids(app) == [1,2,3,4,5],"Restarted normal chapter selection includes chapter five")
	check(int(app.chapter_choice.get_item_metadata(app.chapter_choice.selected)) == 5,"Chapter five is the default next sortie after chapter-four victory")
	await capture(app,"02-chapter-five-selected")
	app.character_panel.begin_requested.emit()
	check(app.active and app.session == "solo" and int(app.sim.state.stage.id) == 5,"Normal sortie signal enters chapter five without the direct-entry script")
	check(app.sim.state.stage.index == 0 and app.sim.state.ikki.node == 1,"Chapter five starts at its first normal encounter")
	check(Wire.valid_snapshot(app.sim.state),"Normal chapter-five state passes wire validation")
	for tick in 60: app._physics_process(1.0/60)
	check(app.sim.state.tick >= 60 and app.sim.state.phase == "playing","Chapter-five combat advances through normal Main physics")
	await capture(app,"03-chapter-five-playing")
	app.queue_free()
	await process_frame
	print("STAGE05_CAMPAIGN_FLOW_PASS %d checks; title -> stage-four victory -> persisted unlock -> title -> chapter five" % checks)
	quit()
