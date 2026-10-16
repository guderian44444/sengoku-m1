extends SceneTree

const Main = preload("res://main.gd")
const Scroll = preload("res://ui/objective_scroll.gd")
const HUD = preload("res://render/combat_hud.gd")
const Players = preload("res://core/player_store.gd")
var checks := 0
var captures := false
var output := ""

class App extends Main:
	func _connected_pads() -> Array[int]: return [3, 7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	assert(value, label)

func capture(name: String) -> void:
	if not captures: return
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Screenshot: " + name)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	captures = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	output = OS.get_environment("TEST_ARTIFACT_DIR")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../artifacts/ui-v34-objective")
	DirAccess.make_dir_recursive_absolute(output)
	var app := App.new()
	root.add_child(app)
	app.testing = true
	app.set_physics_process(false)
	app.profiles = Players.new("user://objective-%d" % Time.get_ticks_usec(), "user://objective-no-legacy.json")
	app._start_local_coop()
	app.audio.stop_speech()
	app._update_view()
	var scroll = app.objective_scroll
	check(app.active and scroll.visible, "Campaign starts with visible order")
	check(scroll.order_state == "battle" and scroll.order == "殲滅守軍", "Living guards determine the order")
	check(scroll.chapter == app.sim.state.stage.title and scroll.place.begins_with(app.sim.state.stage.name), "Chapter and place come from stage state")
	check(not app.hud.visible and app.hud.text == "", "Campaign uses only scroll for objective")
	check(scroll.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Order never captures input")
	for slot in [0, 1]: check(not Scroll.BOUNDS.intersects(HUD.player_rect(slot)), "Order leaves player %d HUD clear" % slot)
	check(Scroll.BOUNDS.end.y < 125, "Order remains above achievement banner")
	await capture("objective-battle")
	var initial: Dictionary = app.sim.get_state()
	var fixture: Dictionary = initial.duplicate(true)
	fixture.fighters.append({"team": 1, "kind": "boss", "hp": 1})
	check(Scroll.objective(fixture).order == "擊破敵將", "Living enemy commander takes priority")
	fixture.fighters[-1].hp = 0
	check(Scroll.objective(fixture).state == "battle", "Dead commander does not retain order")
	fixture.fighters = fixture.fighters.filter(func(f): return f.team == 0)
	fixture.props = [{"mandatory": true, "broken": false, "x": fixture.stage.encounter_end - 30}]
	check(Scroll.objective(fixture).state == "ready", "Waiting for scheduled wave does not falsely declare the encounter clear")
	fixture.wave = fixture.stage.wave_total
	check(Scroll.objective(fixture).order == "掃除路障　打通去路", "Cleared enemies reveal blocking obstacle")
	fixture.props[0].x = fixture.stage.encounter_end + 30
	check(Scroll.objective(fixture).state == "ready", "Future checkpoint obstacle does not misdirect party")
	fixture.props[0].x = fixture.stage.encounter_end - 30
	fixture.props[0].broken = true
	check(Scroll.objective(fixture).state == "ready", "Broken obstacle no longer blocks order")
	fixture.props[0].broken = false
	fixture.props[0].mandatory = false
	check(Scroll.objective(fixture).state == "ready", "Optional destructibles do not prevent advance instructions")
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	for prop in app.sim.state.props:
		if prop.get("mandatory", false) and prop.x < app.sim.state.stage.encounter_end: prop.broken = true
	app.sim.state.stage.go = true
	app.sim.state.stage.phase = "exit"
	app._update_view()
	check(scroll.order_state == "advance" and scroll.order == "全軍會合　向右進軍 →", "Authority GO state determines advance order")
	await capture("objective-advance")
	app.sim.state = initial.duplicate(true)
	app.sim._start_checkpoint(1)
	app._update_view()
	check(scroll.place.ends_with("2／%d 陣" % app.sim.state.stage.checkpoint_total) and scroll.order_state == "battle", "Checkpoint transition refreshes order and location")
	app.sim._enter_segment(1)
	app._update_view()
	check(scroll.place.begins_with(app.sim.state.stage.name) and scroll.place != Scroll.objective(initial).place, "Scene transition replaces old location")
	app.paused = true
	app._show_menu_page("pause")
	check(not scroll.visible, "Pause hides order immediately without physics tick")
	app._update_view()
	check(not scroll.visible, "Paused view update keeps order hidden")
	app._resume()
	app._update_view()
	check(scroll.visible, "Resuming restores current order")
	app._show_controls()
	check(not scroll.visible, "Instructions hide order immediately")
	app._update_view()
	check(not scroll.visible, "Instructions stay unobstructed")
	app._close_controls()
	app._update_view()
	check(scroll.visible, "Closing instructions restores current order")
	app.sim.state.intro = {"remaining_ticks": 60, "name": "敵將", "line": "此路不通", "line_key": ""}
	app._update_view()
	check(not scroll.visible and app.end_label.text.contains("此路不通"), "Commander dialogue hides order and retains subtitle")
	app.sim.state.intro = {}
	app._update_view()
	check(scroll.visible and app.end_label.text.is_empty(), "Dialogue ending restores order")
	for phase in ["won", "lost"]:
		app.sim.state.phase = phase
		app._update_view()
		check(not scroll.visible, "Terminal phase %s leaves victory or defeat subtitle clear" % phase)
	app.sim.state.phase = "playing"
	app.training_active = true
	app.sim.reset_training("nobunaga", "dummy", "mori")
	app._update_view()
	check(not scroll.visible and app.hud.visible and app.hud.text.contains("演武"), "Training retains its existing statistics HUD")
	app._close_network()
	check(not scroll.visible and scroll.order.is_empty(), "Leaving a session clears prior order")
	app._start_art_demo()
	check(not scroll.visible and app.hud.visible, "Move exhibition retains its own HUD")
	app.queue_free()
	await process_frame
	print("OBJECTIVE SCROLL V34 PASS: %d checks" % checks)
	quit()
