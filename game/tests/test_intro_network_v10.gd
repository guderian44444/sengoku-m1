extends SceneTree

class IntroClient:
	extends "res://main.gd"
	var dropped_intro_events := 0
	var client_checked := false

	func _input_frame() -> Dictionary:
		return {"dx": -1 if audio != null and audio.intro_playing() else 0, "dy": 0, "buttons": 0}

	@rpc("any_peer", "call_remote", "reliable")
	func confirm_intro_checks() -> void:
		if session == "host" and multiplayer.get_remote_sender_id() == remote_id:
			client_checked = true

	@rpc("authority", "call_remote", "reliable")
	func receive_boss_voice(actor: int, line_key: String) -> void:
		await get_tree().create_timer(0.7).timeout
		super.receive_boss_voice(actor, line_key)

	@rpc("authority", "call_remote", "unreliable_ordered")
	func receive_state(world: Dictionary) -> void:
		# Simulate losing every unreliable intro event while reliable speech delivery remains intact.
		var retained := []
		for event in world.get("events", []):
			if event.get("type", "") == "boss_intro": dropped_intro_events += 1
			else: retained.append(event)
		world.events = retained
		super.receive_state(world)

var app: IntroClient
var host := false
var injected := false
var heard := false
var advanced_during_voice := false
var moved_during_voice := false
var advanced_before_remote_ack := false
var voice_start_tick := -1
var voice_start_x := 0.0
var pending_voice_tick := -1
var started := 0
var finishing := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	host = "--intro-host" in OS.get_cmdline_user_args()
	app = IntroClient.new()
	app.name = "NetworkMain"
	root.add_child(app)
	await process_frame
	app.port.value = 27863
	if host: app._host()
	else:
		app.heroes.selected = 1
		app._join()
	started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if app == null or started == 0 or finishing: return false
	if Time.get_ticks_msec() - started > 25000:
		push_error("Intro network test timeout: " + JSON.stringify({"host":host,"heard":heard,"advanced_during_voice":advanced_during_voice,"moved_during_voice":moved_during_voice,"advanced_before_remote_ack":advanced_before_remote_ack,"dropped_unreliable_intro_events":app.dropped_intro_events}))
		quit(1)
		return false
	if host and app.active and not injected and app.remote_id != 0 and app.sim.state.tick >= 15:
		injected = true
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f):return f.team==0)
		var boss: Dictionary = app.sim._make_fighter(1,"boss",850.0,480.0,600)
		boss.cooldown = 9999
		app.sim.state.fighters.append(boss)
		app.sim._start_boss_intro(boss)
	if app.audio.intro_playing():
		heard = true
		var players: Array = app.sim.state.fighters.filter(func(f): return f.team == 0 and f.player_index == app.local_slot)
		if not players.is_empty():
			if voice_start_tick < 0:
				voice_start_tick = app.sim.state.tick
				voice_start_x = float(players[0].x)
			advanced_during_voice = advanced_during_voice or int(app.sim.state.tick) > voice_start_tick + 6
			moved_during_voice = moved_during_voice or float(players[0].x) < voice_start_x - 5.0
		assert(not app.sim.state.get("intro",{}).get("blocking",true), "Reliable boss speech must never suspend gameplay")
	if host and app.pending_intro_actor > 0 and heard and not app.audio.intro_playing():
		if pending_voice_tick < 0: pending_voice_tick = app.sim.state.tick
		advanced_before_remote_ack = advanced_before_remote_ack or int(app.sim.state.tick) > pending_voice_tick + 6
	if heard and advanced_during_voice and moved_during_voice and not app.audio.intro_playing() and ((host and app.client_checked and advanced_before_remote_ack) or (not host and app.dropped_intro_events > 0)):
		finishing = true
		print("INTRO NETWORK PASS ",JSON.stringify({"host":host,"heard":heard,"advanced_during_voice":advanced_during_voice,"moved_during_voice":moved_during_voice,"advanced_before_remote_ack":advanced_before_remote_ack,"dropped_unreliable_intro_events":app.dropped_intro_events}))
		if not host: app.confirm_intro_checks.rpc_id(1)
		finish.call_deferred()
	return false

func finish() -> void:
	app.set_physics_process(false)
	app.audio.stop_speech()
	app.audio.stop_music()
	for player in app.audio._voices: player.stop()
	# Deliver the completion acknowledgement and let active audio playback detach.
	await create_timer(0.2).timeout
	app._close_network()
	await process_frame
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
