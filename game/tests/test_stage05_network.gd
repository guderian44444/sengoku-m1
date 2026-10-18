extends SceneTree
const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")
const S5 = preload("res://core/stage05_encounter.gd")

class App extends Main:
	var verified := false
	func _save_characters(_manual: bool = false) -> Error: return OK
	func _choices() -> void:
		super._choices();selected_chapter=5
	func _input_frame() -> Dictionary: return {"dx":0,"dy":0,"buttons":0}
	@rpc("any_peer","call_remote","reliable",0)
	func report_verified() -> void:
		if session=="host" and multiplayer.get_remote_sender_id()==remote_id: verified=true
	@rpc("authority","call_remote","reliable",0)
	func finish_verified() -> void:
		print("STAGE05_NETWORK_CLIENT_PASS snapshots=",received_snapshots)
		get_tree().quit()

var app: App
var host := false
var started := 0
var node := 0
var changed_at := 0
var seen := []
var thresholds_seen := false
var effects_seen := false
var summon_seen := false
var sent := false

func _initialize() -> void: run.call_deferred()
func run() -> void:
	host="--host" in OS.get_cmdline_user_args()
	app=App.new();app.name="NetworkMain";root.add_child(app)
	await process_frame
	app.testing=true;app.port.value=27865;app.address.text="127.0.0.1"
	if host:
		# Use the normal handshake and snapshot RPC handlers; bind loopback only.
		app._choices()
		var peer := ENetMultiplayerPeer.new();peer.set_bind_ip("127.0.0.1")
		assert(peer.create_server(27865,1,3)==OK)
		app.multiplayer.multiplayer_peer=peer;app.session="host"
		print("STAGE05_NETWORK_HOST_READY")
	else: app._join()
	started=Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if started==0: return false
	assert(Time.get_ticks_msec()-started<45000,"loopback timeout")
	if not app.active: return false
	assert(Wire.valid_snapshot(app.sim.state),"network snapshot validates")
	if host:
		for f in app.sim.state.fighters:
			if f.team==0: f.invuln=10000;f.hp=f.max_hp
		if node<12 and (node==0 or app.sim.state.tick-changed_at>=36):
			node+=1
			for section in 5:
				for index in app.sim._campaign.segments[section].encounters.size():
					if int(app.sim._campaign.segments[section].encounters[index].node)==node:
						app.sim._enter_segment(section);app.sim._start_checkpoint(index)
			changed_at=app.sim.state.tick
			if node==10:
				var boss: Dictionary=app.sim._fighter(app.sim.state.ikki.boss)
				S5.start(app.sim,boss,"s05_natsume_diagonal",app.sim.state.fighters[0]);boss.action_tick=32;S5.attack(app.sim,boss)
			if node==12:
				var boss: Dictionary=app.sim._fighter(app.sim.state.ikki.boss)
				boss.hp=roundi(boss.max_hp*.09);S5.thresholds(app.sim,boss)
				S5.start(app.sim,boss,"s05_kusei_summon");boss.action_tick=98
		if app.verified and not sent:
			sent=true
			assert(app.remote_frame>0,"client input reached authoritative host")
			app.finish_verified.rpc_id(app.remote_id)
			print("STAGE05_NETWORK_HOST_PASS nodes=12 remote_input=",app.remote_frame)
			await create_timer(.2).timeout
			quit()
	else:
		var current: int=app.sim.state.ikki.node
		if current not in seen: seen.append(current)
		thresholds_seen=thresholds_seen or app.sim.state.ikki.thresholds==[70,40,10]
		effects_seen=effects_seen or app.sim.state.effects.any(func(e):return e.type=="s05_wave")
		summon_seen=summon_seen or app.sim.state.ikki.summon_count>0
		if seen==range(1,13) and thresholds_seen and effects_seen and summon_seen and not sent:
			sent=true;app.report_verified.rpc_id(1)
	return false
