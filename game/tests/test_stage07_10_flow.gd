extends SceneTree

const Main = preload("res://main.gd")
const Profiles = preload("res://core/player_store.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var output := ""

class CoopApp extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	assert(ok,message)

func ids(app) -> Array:
	var result := []
	for i in app.chapter_choice.item_count: result.append(int(app.chapter_choice.get_item_metadata(i)))
	return result

func select_chapter(app, chapter: int) -> void:
	for i in app.chapter_choice.item_count:
		if int(app.chapter_choice.get_item_metadata(i))==chapter:
			app.chapter_choice.select(i)
			return
	assert(false,"Requested chapter exists in the normal menu")

func capture(name: String) -> void:
	if output.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Native main entry capture")

func leave_battle(app) -> void:
	app._leave_to_menu()
	check(app.menu_screen=="confirm","Leaving an active battle keeps the save confirmation")
	app.menu_pages.confirm.get_node("Confirm").pressed.emit()
	check(not app.active and app.menu_screen=="main","Confirmed return saves and leaves the battle")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	if not output.is_empty():
		assert(DisplayServer.get_name()!="headless")
		assert(DirAccess.make_dir_recursive_absolute(output)==OK)
		root.size=Vector2i(1280,720)
		root.gui_embed_subwindows=true
	var profile_dir := "user://stage0710-main-flow-%d"%Time.get_ticks_usec()
	var app = load("res://main.tscn").instantiate()
	root.add_child(app);app.set_physics_process(false)
	app.profiles=Profiles.new(profile_dir,"user://no-stage0710-legacy.json")
	check(app.profiles.save()==OK,"Persist an isolated, fresh normal roster")
	var before: Dictionary=app.profiles.data.duplicate(true)
	check(app.menu_screen=="title" and not app.testing,"Real main scene starts at its normal title")
	app.menu_pages.title.get_node("Start").pressed.emit()
	app.players_continue.pressed.emit()
	app.menu_pages.roster.get_node("Continue").pressed.emit()
	check(app.menu_screen=="select","Normal title and player/hero menus reach the production sortie page")
	check(ids(app)==[1,7,8,9,10],"Fresh roster can choose seven to ten while chapters two to five keep progression")
	check(app.profiles.data==before,"Opening the choices never changes gear, scores or completion")
	if not output.is_empty():
		app.chapter_choice.show_popup()
		await capture("01-normal-chapter-menu")
		app.chapter_choice.get_popup().hide()
	for chapter in [7,8,9,10]:
		app._open_selection(false);select_chapter(app,chapter)
		app.character_panel.begin_requested.emit()
		check(app.active and app.session=="solo" and app.sim.state.stage.id==chapter,"Normal sortie starts each new chapter")
		for tick in 12: app._physics_process(1.0/60)
		check(app.sim.state.tick>=12 and Wire.valid_snapshot(app.sim.state),"Normal physics and snapshots validate")
		await capture("solo-stage-%02d"%chapter)
		leave_battle(app)
	check(app.profiles.data.completed_chapter==0,"Choosing later chapters never fabricates earlier victories")
	app._open_selection(false);select_chapter(app,7);app.character_panel.begin_requested.emit()
	for chapter in [7,8,9,10]:
		check(app.sim.state.stage.id==chapter,"Campaign continuation follows seven through ten")
		check(app._next_chapter_id()==(chapter+1 if chapter<10 else 0),"Only available adjacent chapters can follow")
		if chapter==10: break
		# Combat has a playthrough; this fixture exercises real victory saving and continuation.
		app.sim.state.phase="won";app.ending_confirmed=true
		app._continue_campaign();app.set_physics_process(false)
		check(app.profiles.data.completed_chapter==chapter,"Continue saves completed chapters")
	app.queue_free();await process_frame
	var restored := Profiles.new(profile_dir,"user://no-stage0710-legacy.json")
	check(restored.data.completed_chapter==9 and restored.data.chapter==10,"Normal progress survives restarting the roster")
	app=load("res://main.tscn").instantiate();root.add_child(app);app.set_physics_process(false)
	app.profiles=restored;app._open_selection(false)
	check(int(app.chapter_choice.get_item_metadata(app.chapter_choice.selected))==10,"Restarted main entry selects the saved chapter")
	app.character_panel.begin_requested.emit()
	check(app.sim.state.stage.id==10,"Saved roster enters ten from the production menu")
	app.queue_free();await process_frame
	var coop := CoopApp.new();root.add_child(coop);coop.set_physics_process(false)
	coop.profiles=Profiles.new("user://stage0710-coop-flow-%d"%Time.get_ticks_usec(),"user://no-stage0710-legacy.json")
	for chapter in [7,8,9,10]:
		coop._open_selection(true);select_chapter(coop,chapter);coop.character_panel.begin_requested.emit()
		check(coop.active and coop.session=="local" and coop.sim.state.stage.id==chapter,"Normal two-player sortie starts each new chapter")
		check(coop.sim.state.fighters.filter(func(f):return f.team==0).size()==2,"Both selected players join")
		for tick in 12: coop._physics_process(1.0/60)
		check(coop.sim.state.tick>=12 and Wire.valid_snapshot(coop.sim.state),"Two-player physics advances")
		leave_battle(coop)
	coop.queue_free();await process_frame
	print("STAGE07_10_FLOW_PASS %d checks"%checks)
	quit()
