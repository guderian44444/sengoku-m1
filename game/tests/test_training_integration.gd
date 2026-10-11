extends SceneTree

const Main = preload("res://main.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return event

func _run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_training()
	_check(app.training_active and app.active and app.session == "solo" and not app.menu.visible, "training starts without network")
	app._physics_process(1.0 / 60.0)
	_key(KEY_J, true)
	_check(Input.is_action_pressed("light"), "physical J maps to the light attack action")
	app._physics_process(1.0 / 60.0)
	_key(KEY_J, false)
	for tick in range(10): app._physics_process(1.0 / 60.0)
	_check(app.sim.state.training.hit_count == 1, "physical keyboard J produces a real dummy hit")
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(app.sim.state.training.hit_count == 0 and app.sim.state.fighters[1].hp == 1000, "R resets practice stats and dummy")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	_check(app.selected_hero == "oichi" and app.sim.state.fighters[0].kind == "oichi", "Tab switches the actual playable hero")
	app._physics_process(1.0 / 60.0)
	_key(KEY_K, true)
	for tick in range(8): app._physics_process(1.0 / 60.0)
	app._set_game_focus(false)
	var saved_tick: int = app.sim.state.tick
	for tick in range(30): app._physics_process(1.0 / 60.0)
	_check(app.paused and app.menu.visible and app.sim.state.tick == saved_tick, "losing focus stops practice simulation")
	_check(app.sim.state.fighters[0].action == "idle" and app._input_frame().buttons == 0, "focus loss clears held charge and input")
	app._set_game_focus(true)
	app._resume()
	_key(KEY_K, false)
	_key(KEY_J, true)
	app._physics_process(1.0 / 60.0)
	_check(app.sim.state.fighters[0].action == "idle", "a held key cannot immediately attack after focus returns")
	_key(KEY_J, false)
	app._physics_process(1.0 / 60.0)
	_key(KEY_J, true)
	app._physics_process(1.0 / 60.0)
	_key(KEY_J, false)
	for tick in range(10): app._physics_process(1.0 / 60.0)
	_check(app.sim.state.training.hit_count == 1, "a fresh press after releasing keys resumes attacks")
	app._reset_training()
	app._physics_process(1.0 / 60.0)
	_key(KEY_K, true)
	for tick in range(40): app._physics_process(1.0 / 60.0)
	_check(app.sim.state.fighters[0].action == "charge" and app.sim.state.fighters[0].charge >= 35, "disconnect scenario begins with a fully held charge")
	app._joy_changed(0, false)
	_key(KEY_K, false)
	_check(app.paused and app.menu.visible and app.sim.state.fighters[0].action == "idle", "controller disconnect cancels the charge and pauses")
	app._resume()
	for tick in range(60): app._physics_process(1.0 / 60.0)
	_check(app.sim.state.training.hit_count == 0 and app.sim.state.fighters[0].action == "idle", "resuming after controller disconnect never releases an unintended attack")
	_key(KEY_2, true)
	_key(KEY_2, false)
	_check(app.training_drill == "shield" and app.sim.state.fighters.size() > 2, "2 starts the shield drill with real attackers")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	_check(app.training_drill == "shield" and app.sim.state.training.drill == "shield", "switching heroes preserves the selected drill")
	_key(KEY_1, true)
	_key(KEY_1, false)
	_check(app.training_drill == "dummy" and app.sim.state.fighters.size() == 2, "1 restores the passive dummy drill")
	app._physics_process(1.0 / 60.0)
	app.sim.state.fighters[1].x = app.sim.state.fighters[0].x + 45.0
	_key(KEY_L, true)
	for tick in range(25): app._physics_process(1.0 / 60.0)
	_check(app.sim.state.fighters[0].action == "holding" and app.sim.state.fighters[1].action == "grabbed", "holding physical L keeps the dummy grabbed")
	_key(KEY_L, false)
	for tick in range(18): app._physics_process(1.0 / 60.0)
	_check(app.sim.state.fighters[1].z > 0, "releasing physical L throws the grabbed dummy")
	app._reset_training()
	app._physics_process(1.0 / 60.0)
	app.sim.state.fighters[1].x = app.sim.state.fighters[0].x + 45.0
	_key(KEY_L, true)
	for tick in range(10): app._physics_process(1.0 / 60.0)
	app._set_game_focus(false)
	_key(KEY_L, false)
	_check(app.sim.state.fighters[0].action == "idle" and app.sim.state.fighters[1].z == 0 and app.sim.state.fighters[1].held_by == 0, "focus loss safely puts down a held target without throwing")
	app._set_game_focus(true)
	app._resume()
	app.session = "client"
	app._set_game_focus(false)
	_check(app._input_frame().buttons == 64, "network focus loss transmits cancellation instead of a throw release")
	app._set_game_focus(true)
	app._joy_changed(0, false)
	_check(app._input_frame().buttons == 64, "network controller loss transmits cancellation")
	app._cancel_sequence = 42
	app._input_armed = false
	for frame in range(8):
		_check(app._input_frame().buttons == 64, "client never sends neutral release before a cancellation acknowledgement")
	app.controls_cancelled(41)
	_check(app._cancel_sequence == 42, "stale acknowledgements cannot unlock cancelled input")
	app.controls_cancelled(42)
	_check(app._cancel_sequence == -1, "matching reliable acknowledgement allows input to rearm")
	app.session = "solo"
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(app.menu.visible and app.paused, "Escape opens the practice pause menu")
	app._start_solo()
	_check(not app.training_active and app.sim.state.fighters[1].kind == "soldier" and not app.sim.state.has("training"), "normal encounter remains independent")
	app.queue_free()
	await process_frame
	print("TRAINING INPUT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
