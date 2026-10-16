extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func stick(device: int, position: Vector2) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = axis
		event.axis_value = position.x if axis == JOY_AXIS_LEFT_X else position.y
		Input.parse_input_event(event)
	Input.flush_buffered_events()

func _initialize() -> void:
	var app := Main.new()
	app.player_devices = [3,7]
	app.local_slot = 0
	var battle := Battle.new()
	for hero in Battle.PLAYABLE_HEROES:
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
			battle.reset_training(hero)
			battle.state.props.clear()
			battle.state.fighters[1].x = 2000
			var player: Dictionary = battle.state.fighters[0]
			stick(3,direction)
			var walk_step := 0.0
			for tick in range(1,13):
				var frame: Dictionary = app._player_frame(0)
				check(frame.get("stick_full",false) and Wire.valid_input(frame),"Full stick including diagonals survives input validation")
				var before := Vector2(player.x,player.y)
				battle.step([frame])
				check(player.sprinting == (tick == 12),"Full stick runs on tick 12, never before: "+hero)
				var stride := before.distance_to(Vector2(player.x,player.y))
				if tick == 11: walk_step = stride
				if tick == 12: check(absf(stride-walk_step*2) < .001,"Running doubles movement speed within subpixel precision: "+hero+"/"+str(direction)+"/"+str(stride)+"/"+str(walk_step))
			stick(3,direction*.89)
			battle.step([app._player_frame(0)])
			check(not player.sprinting and player.sprint_ticks == 0,"Relaxing the stick returns to walking immediately")
			for tick in range(30): battle.step([app._player_frame(0)])
			check(not player.sprinting,"Partial stick never becomes a run by waiting")
			for tick in range(2):
				stick(3,Vector2.ZERO)
				battle.step([app._player_frame(0)])
				stick(3,direction*.6)
				battle.step([app._player_frame(0)])
			check(not player.sprinting,"Double tapping a partial analog stick cannot bypass full-push timing")
			stick(3,direction)
			for tick in range(11): battle.step([app._player_frame(0)])
			check(not player.sprinting,"A relaxed stick starts a fresh 0.2-second interval")
			battle.step([app._player_frame(0)])
			check(player.sprinting and Wire.valid_snapshot(battle.state),"Full-push run resumes with a valid snapshot")
			var heavy: Dictionary = app._player_frame(0)
			heavy.buttons = Battle.HEAVY
			battle.step([heavy])
			check(player.action == "dash_heavy" and player.sprint_ticks == 0,"Analog running still connects to sprint-heavy")
			battle.cancel_input()
			check(not player.sprinting and player.sprint_ticks == 0,"Pause or focus cancellation clears running progress")
			stick(3,Vector2.ZERO)
	battle.reset("normal",2)
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.props.clear()
	stick(3,Vector2.RIGHT)
	stick(7,Vector2.LEFT*.6)
	for tick in range(12): battle.step([app._player_frame(0),app._player_frame(1)])
	check(battle.state.fighters[0].sprinting and not battle.state.fighters[1].sprinting,"Each controller has independent full-push timing")
	stick(3,Vector2.ZERO)
	stick(7,Vector2.LEFT)
	for tick in range(12): battle.step([app._player_frame(0),app._player_frame(1)])
	check(not battle.state.fighters[0].sprinting and battle.state.fighters[1].sprinting,"Releasing one controller does not stop the other")
	stick(7,Vector2.ZERO)
	battle.reset_training("nobunaga")
	stick(3,Vector2.RIGHT)
	for tick in range(11): battle.step([app._player_frame(0)])
	battle.cancel_input()
	battle.step([app._player_frame(0)])
	check(not battle.state.fighters[0].sprinting and battle.state.fighters[0].sprint_ticks == 1,"Cancelled pre-run progress cannot resume at the old threshold")
	stick(3,Vector2.ZERO)
	battle.reset_training("nobunaga")
	for frame in [{"dx":1},{},{"dx":1}]: battle.step([frame])
	check(battle.state.fighters[0].sprinting,"Keyboard and D-pad retain double-tap running")
	for value in [true,false]:
		var frame := {"dx":1,"dy":0,"buttons":0,"stick_full":value}
		check(Wire.valid_input(bytes_to_var(var_to_bytes(frame))),"Network round trip preserves analog sprint intent")
	for value in [null,1,"true",{}]:
		check(not Wire.valid_input({"dx":1,"dy":0,"buttons":0,"stick_full":value}),"Malformed analog input is rejected")
	check(not Wire.valid_input({"dx":1,"dy":0,"buttons":0,"extra":true}),"Unknown input fields remain rejected")
	app.free()
	print("STICK SPRINT V35 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
