extends SceneTree

const Battle = preload("res://core/battle.gd")

class VirtualPads:
	extends "res://main.gd"
	var pads: Array[int] = []
	var vibrations: Array = []
	var stopped := 0
	func _connected_pads() -> Array[int]: return pads
	func _vibrate_device(device: int, weak: float, strong: float, seconds: float) -> void:
		vibrations.append({"device": device, "weak": weak, "strong": strong, "seconds": seconds})
	func _stop_rumble() -> void: stopped += 1

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func button(device: int, code: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func axis(device: int, code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tick(app, count: int = 1) -> void:
	for i in range(count): app._physics_process(1.0 / 60.0)

func run() -> void:
	var app := VirtualPads.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.sim.boss_intros = {}
	app._start_local_coop()
	check(not app.active and app.menu.visible, "co-op cannot start without two connected controllers")
	app.pads = [3, 7]
	app.heroes.selected = 0
	app.partner_heroes.selected = 1
	app._start_local_coop()
	app.audio.stop_speech()
	check(app.session == "local" and app.sim.state.fighters[0].kind == "nobunaga" and app.sim.state.fighters[1].kind == "oichi", "co-op creates both chosen heroes without ENet")
	check(app.player_devices == [3, 7], "distinct controller IDs are assigned to 1P and 2P")
	for fighter in app.sim.state.fighters:
		if fighter.team == 1:
			fighter.kind = "dummy"
			fighter.x = 2100.0
	tick(app, 2)
	axis(3, JOY_AXIS_LEFT_X, 0.15)
	check(app._input_frame().dx == 0, "analog deadzone prevents idle drift")
	axis(3, JOY_AXIS_LEFT_X, 0.8)
	axis(7, JOY_AXIS_LEFT_X, -0.8)
	var first_x: float = app.sim.state.fighters[0].x
	var second_x: float = app.sim.state.fighters[1].x
	tick(app, 4)
	check(app.sim.state.fighters[0].x > first_x and app.sim.state.fighters[1].x < second_x, "opposite controller sticks move their own fighter simultaneously")
	axis(3, JOY_AXIS_LEFT_X, 0)
	axis(7, JOY_AXIS_LEFT_X, 0)
	button(3, JOY_BUTTON_X, true)
	button(7, JOY_BUTTON_B, true)
	check(app._input_frame().buttons == Battle.LIGHT and app._partner_frame().buttons == Battle.HEAVY, "light and heavy buttons do not leak between players")
	button(3, JOY_BUTTON_X, false)
	button(7, JOY_BUTTON_B, false)
	button(11, JOY_BUTTON_Y, true)
	check(app._input_frame().buttons == 0 and app._partner_frame().buttons == 0, "unassigned third controller cannot control either hero")
	button(11, JOY_BUTTON_Y, false)
	key(KEY_I, true)
	check(app._input_frame().buttons == Battle.GUARD and app._partner_frame().buttons == 0, "keyboard fallback controls only 1P")
	key(KEY_I, false)
	axis(7, JOY_AXIS_TRIGGER_LEFT, 0.9)
	check(app._input_frame().buttons == 0 and app._partner_frame().buttons == Battle.GUARD, "2P L2 guard stays isolated")
	axis(7, JOY_AXIS_TRIGGER_LEFT, 0)
	button(7, JOY_BUTTON_START, true)
	button(7, JOY_BUTTON_START, false)
	check(app.paused and app.menu.visible, "2P Options/Start pauses the shared game")
	app._resume()
	tick(app, 2)
	var player: Dictionary = app.sim.state.fighters[1]
	var target: Dictionary = app.sim.state.fighters[2]
	player.face = 1
	target.x = player.x + 45.0
	target.y = player.y
	button(7, JOY_BUTTON_Y, true)
	tick(app, 12)
	check(player.grab_target == target.id and target.held_by == player.id, "2P Triangle/Y holds a real enemy without moving 1P")
	button(7, JOY_BUTTON_Y, false)
	tick(app, 6)
	check(target.thrown_by == player.id and target.z > 0, "releasing 2P Triangle/Y throws the held enemy")
	tick(app, 40)
	button(3, JOY_BUTTON_B, true)
	button(7, JOY_BUTTON_B, true)
	tick(app, 45)
	check(app.sim.state.fighters[0].action == "charge" and player.action == "charge", "both players can hold charge independently")
	var stop_count: int = app.stopped
	app._set_game_focus(false)
	check(app.paused and app.menu.visible and app.stopped > stop_count and app.sim.state.fighters[0].action == "idle" and player.action == "idle", "focus loss cancels both charges and stops haptics")
	app._set_game_focus(true)
	app._resume()
	tick(app, 3)
	check(player.action == "idle" and app.sim.state.fighters[0].action == "idle", "held buttons cannot fire when focus returns")
	button(3, JOY_BUTTON_B, false)
	button(7, JOY_BUTTON_B, false)
	tick(app, 3)
	button(7, JOY_BUTTON_B, true)
	tick(app, 3)
	check(player.action == "charge" and app.sim.state.fighters[0].action == "idle", "2P rearms only after release and a fresh press")
	app.pads = [3]
	app._joy_changed(7, false)
	check(app.paused and app.player_devices == [3, -1] and player.action == "idle", "assigned disconnect pauses and preserves the remaining player's slot")
	app._resume()
	check(app.paused and app.menu.visible, "cannot resume co-op with a missing controller")
	app.pads = [3, 12]
	app._joy_changed(12, true)
	check(app.player_devices == [3, 12] and app.paused, "reconnected controller fills the missing slot without auto-resuming")
	button(7, JOY_BUTTON_B, false)
	button(12, JOY_BUTTON_Y, true)
	app._resume()
	tick(app, 2)
	check(app._partner_frame().buttons == 0, "reconnected held button stays disarmed")
	button(12, JOY_BUTTON_Y, false)
	tick(app, 2)
	button(12, JOY_BUTTON_Y, true)
	check(app._partner_frame().buttons == Battle.GRAB, "new controller controls the original 2P after rearming")
	button(12, JOY_BUTTON_Y, false)
	app._show_controls()
	app.pads = [3]
	app._joy_changed(12, false)
	app._close_controls()
	check(app.paused, "closing F1 after disconnect cannot accidentally resume")
	app.pads = [3, 12]
	app._joy_changed(12, true)
	app._resume()
	tick(app, 2)
	app.sim.state.fighters[0].x = 100.0
	player.x = 2200.0
	player.knockback = 20.0
	app._keep_local_party_in_view()
	app._update_view()
	check(absf(player.x - app.sim.state.fighters[0].x) <= 860.0 and player.knockback == 0, "shared screen limits party separation and outward knockback")
	for fighter in [app.sim.state.fighters[0], player]:
		check(fighter.x - app.view.camera_x >= 80 and fighter.x - app.view.camera_x <= 1200, "shared camera keeps each living hero inside the viewport")
	app.testing = true
	app.vibrations.clear()
	app._events([{"id": 1000, "type": "heavy_hit", "actor": player.id, "target": target.id}, {"id": 1001, "type": "hit", "actor": player.id, "target": target.id}])
	check(app.vibrations.size() == 1 and app.vibrations[0].device == 12 and app.vibrations[0].strong == 0.7, "successful hit vibrates only the attacker and preserves the stronger pulse")
	app._events([{"id": 1001, "type": "hit", "actor": player.id, "target": target.id}])
	check(app.vibrations.size() == 1, "duplicate event does not repeat vibration")
	app._events([{"id": 1002, "type": "guard", "actor": target.id, "target": app.sim.state.fighters[0].id}])
	check(app.vibrations[-1].device == 3, "enemy hit or block vibrates the defending player's controller")
	app.paused = true
	var pulse_count: int = app.vibrations.size()
	app._events([{"id": 1003, "type": "special", "actor": player.id}])
	check(app.vibrations.size() == pulse_count, "paused game never dispatches vibration")
	app.paused = false
	app.session = "client"
	app.local_slot = 1
	app.player_devices = [-1, 12]
	app._events([{"id": 1004, "type": "hit", "actor": app.sim.state.fighters[0].id, "target": target.id}])
	check(app.vibrations.size() == pulse_count, "network teammate does not rumble the local player's controller")
	app._events([{"id": 1005, "type": "heavy_hit", "actor": target.id, "target": player.id}])
	check(app.vibrations.size() == pulse_count + 1 and app.vibrations[-1].device == 12, "network 2P damage rumbles the assigned local controller")
	app._leave_to_menu()
	check(app.player_devices == [-1, -1] and not app.active, "leaving clears controller ownership")
	app.testing = false
	app.pads = []
	app._start_training()
	tick(app, 2)
	key(KEY_K, true)
	tick(app, 40)
	app.pads = [5]
	app._joy_changed(5, true)
	key(KEY_K, false)
	tick(app, 30)
	check(app.sim.state.training.hit_count == 0 and app.sim.state.fighters[0].action == "idle", "connecting a controller cancels a held keyboard charge instead of releasing it")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("V11 INPUT: %d checks, %d failures; synthetic controllers only, physical rumble remains a hardware check" % [checks, failures])
	quit(0 if failures == 0 else 1)
