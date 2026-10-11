extends SceneTree

class IntroClient:
	extends "res://main.gd"
	var dropped_intro_events := 0
	var client_checked := false

	func _input_frame() -> Dictionary:
		return _neutral()

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
var frozen := false
var resumed := false
var waited_for_remote_voice := false
var start_tick := -1
var last_intro_tick := -1
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
		push_error("Intro network test timeout")
		quit(1)
		return false
	if host and app.active and not injected and app.remote_id != 0 and app.sim.state.tick >= 15:
		injected = true
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f):return f.team==0)
		var boss: Dictionary = app.sim._make_fighter(1,"boss",850.0,480.0,600)
		app.sim.state.fighters.append(boss)
		app.sim._start_boss_intro(boss)
	if app.audio.intro_playing(): heard = true
	if host and app.pending_intro_actor > 0 and not app.audio.intro_playing() and int(app.sim.state.get("intro",{}).get("remaining_ticks",0)) <= 1:
		waited_for_remote_voice = true
	if int(app.sim.state.get("intro",{}).get("remaining_ticks",0)) > 0:
		if start_tick < 0: start_tick = app.sim.state.tick
		if app.sim.state.tick == last_intro_tick: frozen = true
		last_intro_tick = app.sim.state.tick
	if start_tick >= 0 and int(app.sim.state.get("intro",{}).get("remaining_ticks",0)) == 0 and int(app.sim.state.tick)>start_tick:
		assert(not app.audio.intro_playing(), "Combat must not resume before this peer finishes the introduction")
		resumed = true
	if heard and frozen and resumed and ((host and app.client_checked and (app.sim.state.tick > start_tick + 6 or not app.active)) or (not host and app.dropped_intro_events > 0)):
		finishing = true
		assert(not host or waited_for_remote_voice, "Host must wait for the delayed client's voice acknowledgement")
		print("INTRO NETWORK PASS ",JSON.stringify({"host":host,"heard":heard,"frozen":frozen,"resumed":resumed,"waited_for_remote_voice":waited_for_remote_voice,"dropped_unreliable_intro_events":app.dropped_intro_events}))
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
