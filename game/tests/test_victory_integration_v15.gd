extends SceneTree

class VirtualPads:
	extends "res://main.gd"
	func _connected_pads() -> Array[int]: return [3, 7]
	func _stop_rumble() -> void: pass
	func _input_frame() -> Dictionary: return _neutral()
	func _partner_frame() -> Dictionary: return _neutral()

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var app := VirtualPads.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_local_coop()
	app.audio.stop_speech()
	app.sim.state.intro = {}
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0)
	app.sim.state.phase = "won"
	for tick in range(60): app._physics_process(1.0 / 60)
	check(app._victory_spoken.is_empty(), "No line before the authored victory cue")
	app._physics_process(1.0 / 60)
	check(app._victory_spoken.size() == 1 and app._victory_spoken.has(app.sim.state.fighters[0].id), "First living partner speaks at tick sixty")
	check(app.audio.speech_playing(), "A real character channel occupies the speech queue")
	check(app._victory_subtitle.begins_with("信長：「") and app._victory_subtitle.length() > 7, "The spoken victory take supplies its localized subtitle")
	check(app.audio._music_player.playing and not app.audio._music_player.stream_paused, "Victory speech plays over the continuously looping battle score")
	for tick in range(160): app._physics_process(1.0 / 60)
	check(app._victory_spoken.size() == 1, "Second partner cannot interrupt the first victory line")
	var victory_tick: int = app.sim.state.fighters[0].action_tick
	app._set_game_focus(false)
	app._physics_process(1.0 / 60)
	check(app.paused and app.sim.state.fighters[0].action == "victory" and app.sim.state.fighters[0].action_tick == victory_tick, "Focus loss freezes the celebration without cancelling its pose")
	app._set_game_focus(true)
	app._resume()
	check(not app.paused, "Focus return can resume a won encounter and its pending second line")
	app.audio.stop_speech()
	app._physics_process(1.0 / 60)
	check(app._victory_spoken.size() == 2 and app._victory_subtitle.begins_with("阿市：「"), "Second partner speaks after the first channel finishes even when animation has held")
	app.audio.stop_speech()
	for tick in range(30): app._physics_process(1.0 / 60)
	check(not app.audio.speech_playing(), "Held terminal state never repeats either victory line")
	for fighter in app.sim.state.fighters:
		var sample: Dictionary = app.view._fighter_animation(fighter)
		check(sample.source == "v15" and sample.frame == 11 and sample.count == 12, "Actual registered victory stays on drawing twelve")
		check(app.view._art.animation_frame(fighter.kind, sample).source == "v15", "Renderer retrieves the same new PNG selected by animation")
	app._leave_to_menu()
	app._start_local_coop()
	check(app._victory_spoken.is_empty() and app._victory_subtitle.is_empty(), "New encounter clears both speech queue and old subtitle")
	app.audio.stop_speech()
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0)
	app.sim.state.fighters[0].hp = 0
	app.sim.state.fighters[0].action = "defeated"
	app.sim.state.phase = "won"
	for tick in range(65): app._physics_process(1.0 / 60)
	check(app._victory_spoken.size() == 1 and app._victory_subtitle.begins_with("阿市：「"), "Defeated partner does not speak or block the living winner")
	app._leave_to_menu()
	check(not app.audio.speech_playing(), "Leaving the result stops queued speech")
	app.queue_free()
	await process_frame
	print("V15 VICTORY INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
