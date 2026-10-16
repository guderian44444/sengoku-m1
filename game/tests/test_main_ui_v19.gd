extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

class App extends Main:
	var requested_fullscreen := false
	func _ready() -> void:
		testing = true
		super._ready()
	func _set_fullscreen(enabled: bool) -> void:
		# Exercise the real input/menu route without changing the user's desktop mode.
		requested_fullscreen = enabled

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	check(Main.should_start_fullscreen([], "windows", false), "Normal desktop launches request fullscreen")
	for args in [["--headless"],["--script","res://tests/fixture.gd"],["-s","res://tests/fixture.gd"],["--windowed"],["-w"],["--capture=frame.png"],["--capture-menu"],["--art-capture-dir=frames"],["--smoke-host"]]:
		check(not Main.should_start_fullscreen(PackedStringArray(args), "windows", false), "Automation remains windowed: " + str(args))
	check(not Main.should_start_fullscreen([], "headless", false) and not Main.should_start_fullscreen([], "windows", true), "Headless and testing flags independently suppress fullscreen")
	var app := App.new()
	var original_mode := root.mode
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	check(not app.requested_fullscreen and root.mode == original_mode, "Constructing a test app preserves the runner's display mode (including the headless dummy window)")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F11
	event.pressed = true
	app._input(event)
	check(app.requested_fullscreen, "F11 reaches the native fullscreen setter")
	app.requested_fullscreen = false
	app.fullscreen_button.pressed.emit()
	check(app.requested_fullscreen, "Menu fullscreen control reaches the same setter")
	app._update_view()
	check(not app.hint.visible, "Battle does not reserve the old bottom operation strip")
	check(app.objective_scroll.chapter == app.sim.state.stage.title and app.objective_scroll.place == "%s　1／2 陣" % app.sim.state.stage.name, "Campaign order names the region and its checkpoint")
	var player: Dictionary = app.sim.state.fighters[0]
	app.sim.state.stage.encounter_end = 2400.0 # Ensure this camera fixture permits scrolling even when the first checkpoint fits one screen.
	player.x = 900.0
	var camera_before: float = app.view.camera_x
	app._update_view()
	check(app.view.camera_x > camera_before and app.view.camera_x <= camera_before + 10.0 and app.view.camera_x <= Battle.camera_left(app.sim.state), "Main smoothly approaches the authoritative camera without revealing a locked checkpoint: before=%.1f after=%.1f target=%.1f party=%s" % [camera_before,app.view.camera_x,Battle.camera_left(app.sim.state),app.sim.state.fighters.filter(func(f): return f.team == 0).map(func(f): return f.x)])
	app.session = "local"
	app.sim.reset_campaign("normal", 2, ["nobunaga", "oichi"])
	app._update_view()
	check(app.combat_hud.players.size() == 2, "Co-op has both portraits and HP/rage records")
	check(app.combat_hud.players[0].kind == "nobunaga" and app.combat_hud.players[1].kind == "oichi", "HUD matches the selected co-op heroes")
	app.sim.state.stage.go = true
	app.sim.state.stage.phase = "exit"
	app._update_view()
	check(app.objective_scroll.order == "全軍會合　向右進軍 →", "Cleared checkpoint gives the shared advance order")
	app.sim.reset_training("oichi", "boss", "imagawa")
	app.sim.state.intro = {"remaining_ticks":180,"name":"今川軍小王","line":"來戰！"}
	app._update_view()
	check(app.end_label.text.contains("來戰") and app.end_label.position.y == 100 and not app.paused, "Boss dialogue stays above action and never pauses play")
	check(not app.combat_hud.boss.is_empty(), "Boss encounter exposes its compact HP bar")
	app._show_controls()
	check(app.controls_dialog.visible, "Complete operation help is reachable from the options dialog")
	app.requested_fullscreen = false
	app.controls_dialog.window_input.emit(event)
	check(app.requested_fullscreen, "F11 remains available while the F1 dialog owns keyboard focus")
	app._close_controls()
	app.sim.reset_training("nobunaga")
	app.sim.state.drops.clear()
	player = app.sim.state.fighters[0]
	player.hp = player.max_hp - 50
	var before_hp: int = player.hp
	app.sim._add_drop("food", player.x, player.y)
	app.sim.step([{"dx":0, "dy":0, "buttons":Battle.INTERACT}])
	var pickups: Array = app.sim.state.events.filter(func(e): return e.type == "food_pickup")
	check(pickups.size() == 1 and app.sim.state.drops.is_empty(), "An actual pickup input consumes one food and emits one healing event")
	if not pickups.is_empty():
		check(pickups[0].actor == player.id and pickups[0].heal == player.hp - before_hp, "Healing event identifies its player and the actual restored HP")
		check(player.pickup_flash_tick == app.sim.state.tick, "Healing flash and sound share the authoritative pickup tick")
		app.audio.play_event(pickups[0])
		check(app.audio.last_sound == "food_pickup" and app.audio._food_player.playing, "Real battle event reaches the dedicated healing audio channel")
	app._close_network()
	check(app.combat_hud.players.is_empty() and app.combat_hud.boss.is_empty(), "Returning to menu clears stale combat status")
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("MAIN UI v19: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
