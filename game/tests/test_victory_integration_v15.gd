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
	for fighter in app.sim.state.fighters:
		var sample: Dictionary = app.view._fighter_animation(fighter)
		var source := "v22" if app.view._art.animations[fighter.kind].has("v22_victory") else "v15"
		var count := 6 if source == "v22" else 12
		check(sample.source == source and sample.frame == count - 1 and sample.count == count, "Actual registered victory stays on its last authored drawing")
		check(app.view._art.animation_frame(fighter.kind, sample).source == source, "Renderer retrieves the same PNG selected by animation")
	app.audio.stop_speech()
	for tick in range(30): app._physics_process(1.0 / 60)
	check(not app.audio.speech_playing(), "Held terminal state never repeats either victory line")
	check(app.sim.state.victory_looting and app.sim.state.fighters.all(func(f): return f.action == "idle"), "After both voices finish, winners can move to collect remaining loot")
	app.sim.state.props.clear()
	for slot in range(2): app.sim.state.fighters[slot].x = 600.0 + slot*300.0
	app.view.state = app.sim.state
	app.view._update_motion()
	var walk_frames := [{},{}]
	for tick in range(24):
		app.sim.step([{"dx":-1,"stick_full":false},{"dx":1,"stick_full":false}])
		app.view._update_motion()
		for slot in range(2):
			var sample: Dictionary = app.view._fighter_animation(app.sim.state.fighters[slot])
			check(sample.clip == "walk","Post-victory movement selects walking instead of a frozen standing pose")
			walk_frames[slot][sample.frame] = true
	check(walk_frames.all(func(frames): return frames.size() > 1),"Both winners visibly animate their walking stride")
	for tick in range(12):
		app.sim.step([{"dx":-1,"stick_full":true},{"dx":1,"stick_full":true}])
		app.view._update_motion()
	for fighter in app.sim.state.fighters:
		check(fighter.sprinting and app.view._fighter_animation(fighter).clip == "run","Full stick still triggers running after victory")
	app.sim.step([{"buttons":app.Battle.JUMP|app.Battle.HEAVY|app.Battle.LIGHT},{"buttons":app.Battle.JUMP}])
	app.view._update_motion()
	for fighter in app.sim.state.fighters:
		check(fighter.z > 0 and fighter.action == "idle" and app.view._fighter_animation(fighter).clip == "jump","Post-victory jump animates while combat attacks remain disabled")
	for tick in range(60):
		app.sim.step([{},{}])
		app.view._update_motion()
	for fighter in app.sim.state.fighters:
		check(fighter.z == 0 and app.view._fighter_animation(fighter).clip == "idle","Stopping after victory returns to a grounded idle pose")
	var looter: Dictionary = app.sim.state.fighters[0]
	looter.hp = looter.max_hp-20
	app.sim._add_drop("food",looter.x,looter.y)
	app.sim.step([{"buttons":app.Battle.INTERACT},{}])
	check(looter.hp == looter.max_hp,"Victory movement still allows collecting remaining loot")
	app._leave_to_menu()
	app._accept_confirmation()
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
	app._accept_confirmation()
	check(not app.audio.speech_playing(), "Leaving the result stops queued speech")
	app.queue_free()
	await process_frame
	print("V15 VICTORY INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
