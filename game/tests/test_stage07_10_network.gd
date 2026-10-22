extends SceneTree

const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")
const Expedition = preload("res://core/stage07_10_encounter.gd")

class App extends Main:
	var verified := false
	func _save_characters(_manual: bool=false) -> Error: return OK
	func _choices() -> void:
		super._choices();selected_chapter=7
	func _input_frame() -> Dictionary: return {"dx":0,"dy":0,"buttons":0}
	@rpc("any_peer","call_remote","reliable",0)
	func report_verified() -> void:
		if session=="host" and multiplayer.get_remote_sender_id()==remote_id: verified=true
	@rpc("authority","call_remote","reliable",0)
	func finish_verified() -> void:
		print("STAGE0710_NETWORK_CLIENT_PASS snapshots=",received_snapshots)
		get_tree().quit()

var app: App
var host := false
var started := 0
var section := -1
var changed_at := 0
var seen := []
var hazards_seen := []
var bosses_seen := []
var civilians_seen := false
var sent := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	host="--host" in OS.get_cmdline_user_args()
	app=App.new();app.name="NetworkMain";root.add_child(app)
	await process_frame
	app.testing=true;app.port.value=27871;app.address.text="127.0.0.1"
	if host:
		app._choices()
		var peer := ENetMultiplayerPeer.new();peer.set_bind_ip("127.0.0.1")
		assert(peer.create_server(27871,1,3)==OK)
		app.multiplayer.multiplayer_peer=peer;app.session="host"
		print("STAGE0710_NETWORK_HOST_READY")
	else: app._join()
	started=Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if started==0: return false
	assert(Time.get_ticks_msec()-started<75000,"Loopback must finish or report a failure")
	if not app.active: return false
	assert(Wire.valid_snapshot(app.sim.state),"Live snapshots pass boundary validation")
	if host:
		for f in app.sim.state.fighters:
			if f.team==0: f.invuln=10000;f.hp=f.max_hp
		if section<19 and (section<0 or app.sim.state.tick-changed_at>=100):
			section+=1
			var chapter := 7+section/5
			if app.sim.state.stage.id!=chapter:
				app.sim.state.phase="won";app.ending_confirmed=true
				app._continue_campaign()
			app.sim._enter_segment(section%5);app.sim._start_checkpoint(1)
			app.sim.state.intro.clear();changed_at=app.sim.state.tick
			Expedition.hazard(app.sim,["rock","arrows","fireline","arrows"][chapter-7],Vector2(620,450),120,36,85,12)
			for f in app.sim.state.fighters:
				if f.kind=="boss":
					Expedition.start(app.sim,f,str(Expedition.Data.BOSSES[f.expedition_role].actions[1]),app.sim.state.fighters[0])
		if app.verified and not sent:
			sent=true
			assert(app.remote_frame>0,"Remote input reached authoritative host")
			app.finish_verified.rpc_id(app.remote_id)
			print("STAGE0710_NETWORK_HOST_PASS scenes=20 remote_input=",app.remote_frame)
			await create_timer(.2).timeout
			quit()
	else:
		var stage: int=app.sim.state.stage.id
		var key: int=(stage-7)*5+app.sim.state.stage.index
		if key not in seen: seen.append(key)
		if not app.sim.state.expedition.hazards.is_empty() and stage not in hazards_seen: hazards_seen.append(stage)
		civilians_seen=civilians_seen or not app.sim.state.expedition.civilians.is_empty()
		for f in app.sim.state.fighters:
			if f.kind=="boss" and f.expedition_role not in bosses_seen: bosses_seen.append(f.expedition_role)
		if seen.size()==20 and hazards_seen.size()==4 and bosses_seen.size()==8 and civilians_seen and not sent:
			sent=true;app.report_verified.rpc_id(1)
	return false
