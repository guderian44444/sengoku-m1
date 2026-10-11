extends SceneTree

class VictoryPeer:
	extends "res://main.gd"
	var final_ack := false
	func _ready() -> void:
		testing = true
		super._ready()
	func _input_frame() -> Dictionary: return _neutral()
	@rpc("any_peer", "call_remote", "reliable", 0)
	func victory_complete() -> void:
		if session == "host" and multiplayer.get_remote_sender_id() == remote_id:
			final_ack = true

var app: VictoryPeer
var host := false
var injected := false
var started := 0
var first_held := false
var stopped_tick := -1
var same_tick_frames := 0
var released := false
var finishing := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	host = "--victory-host" in OS.get_cmdline_user_args()
	app = VictoryPeer.new()
	app.name = "NetworkMain"
	root.add_child(app)
	await process_frame
	app.port.value = 27864
	if host: app._host()
	else:
		app.heroes.selected = 1
		app.address.text = "127.0.0.1"
		app._join()
	started = Time.get_ticks_msec()

func fail(message: String) -> void:
	push_error(message)
	finishing = true
	quit(1)

func _process(_delta: float) -> bool:
	if app == null or started == 0 or finishing: return false
	if Time.get_ticks_msec() - started > 30000:
		fail("Victory ENet test timed out")
		return false
	if host:
		if app.active and app.remote_id != 0 and not injected and app.sim.state.tick >= 8:
			injected = true
			app.sim.state.wave = 3
			app.sim.state.intro = {}
			for fighter in app.sim.state.fighters:
				if fighter.team == 1: app.sim._damage(fighter,10000,app.sim.state.fighters[0].id,false)
		if app.final_ack:
			finishing = true
			print("VICTORY NETWORK PASS ",JSON.stringify({"host":true,"client_acknowledged_both_lines":true,"phase":app.sim.state.phase,"tick":app.sim.state.tick}))
			finish.call_deferred()
		return false
	if app.sim.state.get("phase","") != "won": return false
	if app._victory_spoken.size() == 1 and not first_held:
		first_held = true
		# Loop the real first speech channel across the final snapshot deliberately.
		# This tests the queue independently of the selected line's natural duration.
		var first_stream: AudioStreamWAV = app.audio._speech_players.hero0.stream
		first_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		first_stream.loop_begin = 0
		first_stream.loop_end = first_stream.data.size() / 2
	var players: Array = app.sim.state.fighters.filter(func(f): return f.team == 0)
	var settled: bool = players.size() == 2 and players.all(func(f): return f.action == "victory" and f.action_tick == 120)
	if settled and not released:
		if stopped_tick == app.sim.state.tick: same_tick_frames += 1
		else:
			stopped_tick = app.sim.state.tick
			same_tick_frames = 0
		if same_tick_frames >= 20:
			if not first_held or app._victory_spoken.size() != 1 or app.received_snapshots < 2:
				fail("Client must receive genuine victory snapshots and keep the second line queued: held=%s spoken=%d snapshots=%d playing=%s" % [first_held,app._victory_spoken.size(),app.received_snapshots,app.audio.speech_playing()])
				return false
			app.audio._speech_players.hero0.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
			app.audio.stop_speech()
			released = true
	if released and app._victory_spoken.size() == 2:
		if app.sim.state.tick != stopped_tick or not app.audio.speech_playing() or not app._victory_subtitle.begins_with("阿市：「"):
			fail("Client must start Oichi's second line after the host world tick has stopped")
			return false
		finishing = true
		print("VICTORY NETWORK PASS ",JSON.stringify({"host":false,"snapshots":app.received_snapshots,"phase":app.sim.state.phase,"held_tick":stopped_tick,"spoken":app._victory_spoken.size(),"second_line_after_tick_stopped":true}))
		app.victory_complete.rpc_id(1)
		finish.call_deferred()
	return false

func finish() -> void:
	await create_timer(.3).timeout
	app.audio.stop_speech()
	app._close_network()
	app.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit()
