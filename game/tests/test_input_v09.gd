extends SceneTree

const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


func _tick(app, count: int = 1) -> void:
	for tick in range(count): app._physics_process(1.0 / 60.0)


func _run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.sim.boss_intros = {}
	app._start_training()
	_tick(app, 2)
	for spec in [[KEY_3, "enemies", 5], [KEY_4, "ranged", 3], [KEY_5, "boss", 2]]:
		_tap(spec[0])
		_check(app.training_drill == spec[1] and app.sim.state.training.drill == spec[1] and app.sim.state.fighters.size() == spec[2], "physical drill key selects " + spec[1])
		_check(Wire.valid_snapshot(app.sim.get_state()), spec[1] + " drill initializes a valid multiplayer snapshot")
	_tap(KEY_TAB)
	_check(app.selected_hero == "oichi" and app.training_drill == "boss", "switching hero preserves new drill")
	_tap(KEY_1)
	for hero in ["nobunaga", "oichi"]:
		app.selected_hero = hero
		for held in [false, true]:
			app._reset_training()
			_tick(app, 2)
			_key(KEY_S, true)
			_key(KEY_K, true)
			_tick(app, 40 if held else 1)
			_check(app.sim.state.fighters[0].action == "charge" and app.sim.state.fighters[0].charge_direction == 1, hero + " physical S+K captures down direction without sliding")
			_key(KEY_S, false)
			_key(KEY_K, false)
			_tick(app)
			_check(app.sim.state.fighters[0].action == ("charged_slam" if held else "ground_slam"), hero + " physical S+K release distinguishes tap from hold")
			_tick(app, 85)
			_check(app.sim.state.training.hit_count > 0, hero + " physical down-heavy reaches an actual target")
		app._reset_training()
		_tick(app, 2)
		_key(KEY_K, true)
		_tick(app)
		_key(KEY_K, false)
		_tick(app)
		_key(KEY_J, true)
		_tick(app)
		_key(KEY_J, false)
		_tick(app, 35)
		_check(app.sim.state.fighters[0].action == "mixed_rising", hero + " physical K→J buffers rising mixed combo")
		_tick(app, 30)
		_check(app.sim.state.training.hit_count >= 2, hero + " physical mixed combo produces multiple impacts")
	app.selected_hero = "nobunaga"
	app._reset_training()
	_tick(app, 2)
	_key(KEY_K, true)
	_tick(app, 40)
	_check(app.sim.state.fighters[0].action == "charge", "F1 cancellation test starts with held full charge")
	_tap(KEY_F1)
	await process_frame
	_check(app.controls_dialog.visible and app.paused and app.sim.state.fighters[0].action == "idle", "F1 opens guide, pauses, cancels full charge")
	var paused_tick: int = app.sim.state.tick
	_tick(app, 60)
	_check(app.sim.state.tick == paused_tick, "guide freezes solo simulation")
	_tap(KEY_F1)
	await process_frame
	_check(not app.controls_dialog.visible and not app.paused, "second F1 closes guide and restores play")
	if app.controls_dialog.visible: app._close_controls()
	_tick(app, 5)
	_check(app.sim.state.fighters[0].action == "idle", "held K cannot restart charge after guide closes")
	_key(KEY_K, false)
	_tick(app, 60)
	_check(app.sim.state.training.hit_count == 0, "releasing cancelled full charge cannot attack after F1")
	app._reset_training()
	_tick(app, 2)
	_key(KEY_L, true)
	_tick(app, 8)
	_check(app.sim.state.fighters[0].grab_target != 0, "F1 grab cancellation starts with held target")
	_tap(KEY_F1)
	await process_frame
	_check(app.sim.state.fighters[0].grab_target == 0 and app.sim.state.fighters[1].held_by == 0 and app.sim.state.fighters[1].throw_ticks == 0, "opening guide puts down grabbed enemy without throwing")
	_key(KEY_L, false)
	app.controls_dialog.confirmed.emit()
	_tick(app, 60)
	_check(not app.controls_dialog.visible and not app.paused and app.sim.state.training.hit_count == 0, "guide confirmation resumes without accidental throw")
	_tap(KEY_ESCAPE)
	_check(app.menu.visible and app.paused, "Escape pauses before guide preservation check")
	_tap(KEY_F1)
	app.controls_dialog.confirmed.emit()
	_check(app.paused and app.menu.visible, "guide opened from pause menu restores paused state")
	app.queue_free()
	await process_frame
	# Headless input loops outpace the audio mixer; let queued playback releases drain.
	await create_timer(0.1).timeout
	print("V09 PHYSICAL INPUT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
