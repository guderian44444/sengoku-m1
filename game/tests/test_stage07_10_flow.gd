extends SceneTree

const Profiles = preload("res://core/player_store.gd")
const Stages = preload("res://core/stage_data.gd")
const Wire = preload("res://core/wire.gd")
const Playtest = preload("res://tests/play_stage07_10.gd")
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	assert(ok,message)

func ids(app) -> Array:
	var result := []
	for i in app.chapter_choice.item_count: result.append(int(app.chapter_choice.get_item_metadata(i)))
	return result

func run() -> void:
	var profile_dir := "user://stage0710-flow-%d"%Time.get_ticks_usec()
	var app = load("res://main.tscn").instantiate()
	root.add_child(app);app.set_physics_process(false)
	app.profiles=Profiles.new(profile_dir,"user://no-stage0710-legacy.json")
	app._refresh_chapters()
	check(ids(app)==[1],"New normal campaign keeps its unlock rules")
	# Isolated fixture for the allied chapter-six handoff, never a real player save.
	app.profiles.capture_chapter(6,true)
	check(app.profiles.save()==OK,"Persist the isolated chapter-six completion fixture")
	app._refresh_chapters()
	check(7 in ids(app) and 8 not in ids(app),"Completing six unlocks seven only")
	check(int(app.chapter_choice.get_item_metadata(app.chapter_choice.selected))==7,"Next sortie selects chapter seven")
	app.character_panel.begin_requested.emit()
	check(app.active and app.session=="solo" and app.sim.state.stage.id==7,"Normal sortie starts seven")
	for chapter in [7,8,9,10]:
		check(app.sim.state.stage.id==chapter and Wire.valid_snapshot(app.sim.state),"Normal stage state validates")
		check(app._next_chapter_id()==(chapter+1 if chapter<10 else 0),"Campaign advances only to an available adjacent chapter")
		for tick in 12: app._physics_process(1.0/60)
		check(app.sim.state.tick>=12,"Normal main physics advances the new chapter")
		if chapter==10: break
		# The combat tests cover actual victory; this fixture exercises its save/menu continuation.
		app.sim.state.phase="won";app.ending_confirmed=true
		app._continue_campaign();app.set_physics_process(false)
		check(app.profiles.data.completed_chapter==chapter,"Continue persists chapter victory")
	app.queue_free();await process_frame
	var playtest := Playtest.App.new()
	root.add_child(playtest);playtest.set_physics_process(false)
	check(playtest.profiles.directory=="user://stages07-10-profiles","Direct script use also isolates the playtest roster")
	playtest.profiles=Profiles.new("user://stage0710-new-playtest-%d"%Time.get_ticks_usec(),"user://no-stage0710-legacy.json")
	playtest._refresh_chapters()
	check(ids(playtest)==[7,8,9,10],"Dedicated launcher offers all four chapters without rewriting normal unlocks")
	check(playtest.profiles.data.completed_chapter==0,"Independent chapter selection does not fabricate completion")
	playtest.profiles.capture_chapter(10,true)
	check(playtest.profiles.save()==OK,"Playtest progress can be saved independently")
	var normal := Profiles.new(profile_dir,"user://no-stage0710-legacy.json")
	check(normal.data.completed_chapter==9 and normal.data.chapter==10,"Playtest saving leaves the normal roster unchanged")
	playtest.queue_free();await process_frame
	print("STAGE07_10_FLOW_PASS %d checks"%checks)
	quit()
