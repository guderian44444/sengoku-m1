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
var variants_seen := false
var arrow_seen := false
var reinforcements_seen := false
var broken_seen := false
var changed_flags := false
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
	assert(Time.get_ticks_msec()-started<75000,"loopback timeout")
	if not app.active: return false
	assert(Wire.valid_snapshot(app.sim.state),"network snapshot validates")
	if host:
		for f in app.sim.state.fighters:
			if f.team==0: f.invuln=10000;f.hp=f.max_hp
		var age: int=app.sim.state.tick-changed_at
		if node==1:
			if age>=100 and not variants_seen:
				var bows: Array=app.sim.state.fighters.filter(func(f):return f.get("s05_role","")=="hunting_bow_farmer")
				if not bows.is_empty():
					var bow: Dictionary=bows[0];var hero: Dictionary=app.sim.state.fighters[0]
					bow.entering=false;bow.x=hero.x+360;bow.y=hero.y
					S5.start(app.sim,bow,"s05_hunting_bow_farmer_shot",hero);bow.action_tick=28;variants_seen=true
			if age>=160 and not reinforcements_seen:
				for f in app.sim.state.fighters:
					if f.team==1: f.hp=0;f.damage_tick=app.sim.state.tick;break
				reinforcements_seen=true
			if age>=230 and not changed_flags:
				for prop in app.sim.state.props:
					if prop.get("s05_banner",false):prop.hp=0;prop.broken=true;prop.broken_tick=app.sim.state.tick
				changed_flags=true
		if node<12 and (node==0 or age>=(300 if node==1 else 60)):
			node+=1
			for section in 5:
				for index in app.sim._campaign.segments[section].encounters.size():
					if int(app.sim._campaign.segments[section].encounters[index].node)==node:
						app.sim._enter_segment(section);app.sim._start_checkpoint(index)
			changed_at=app.sim.state.tick
			if node==10:
				var boss: Dictionary=app.sim._fighter(app.sim.state.ikki.boss)
				S5.start(app.sim,boss,"s05_natsume_diagonal",app.sim.state.fighters[0]);boss.action_tick=18;S5.attack(app.sim,boss)
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
		var roles: Array=app.sim.state.fighters.map(func(f):return f.get("s05_role",""))
		variants_seen=variants_seen or ("sickle_farmer" in roles and "hunting_bow_farmer" in roles)
		arrow_seen=arrow_seen or app.sim.state.effects.any(func(e):return e.get("s05_arrow",false))
		reinforcements_seen=reinforcements_seen or (current==1 and app.sim.state.ikki.entry_seq>=6 and not app.sim.state.ikki.pending.is_empty())
		broken_seen=broken_seen or (current==1 and S5.banners(app.sim)==0 and app.sim.state.ikki.pending.is_empty() and app.sim.state.ikki.phase=="combat")
		if seen==range(1,13) and thresholds_seen and effects_seen and summon_seen and variants_seen and arrow_seen and reinforcements_seen and broken_seen and not sent:
			sent=true;app.report_verified.rpc_id(1)
	return false
