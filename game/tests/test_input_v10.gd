extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode=code
	e.keycode=code
	e.pressed=down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func tick(app, count: int=1) -> void:
	for i in range(count): app._physics_process(1.0/60.0)

func run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.sim.boss_intros={}
	check(app.heroes.item_count==6 and app.factions.item_count==12,"All heroes and factions selectable")
	app._start_training()
	for hero in Main.HEROES:
		app.selected_hero=hero
		app._reset_training()
		tick(app,2)
		key(KEY_I,true)
		tick(app,2)
		check(app.sim.state.fighters[0].action=="guard",hero+" keyboard guard")
		key(KEY_I,false)
		tick(app,2)
		key(KEY_D,true)
		tick(app,2)
		key(KEY_D,false)
		tick(app,2)
		key(KEY_D,true)
		tick(app,2)
		check(app.sim.state.fighters[0].sprinting,hero+" directional double tap sprint")
		key(KEY_D,false)
		tick(app,2)
		check(not app.sim.state.fighters[0].sprinting,"Release ends sprint")
	var mappings={"light":JOY_BUTTON_X,"heavy":JOY_BUTTON_B,"jump":JOY_BUTTON_A,"grab":JOY_BUTTON_Y,"special":JOY_BUTTON_RIGHT_SHOULDER,"pickup":JOY_BUTTON_LEFT_SHOULDER}
	for action in mappings:
		check(InputMap.action_get_events(action).any(func(e):return e is InputEventJoypadButton and e.button_index==mappings[action]),"DualSense logical mapping: "+action)
		var button := InputEventJoypadButton.new()
		button.button_index=mappings[action]
		button.pressed=true
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		check(Input.is_action_pressed(action),"Synthetic PS5 button enters real InputMap: "+action)
		var released: InputEventJoypadButton=button.duplicate()
		released.pressed=false
		Input.parse_input_event(released)
		Input.flush_buffered_events()
	check(not app.paused and not app.menu.visible,"Circle heavy does not trigger Godot's default cancel/menu action")
	check(InputMap.action_get_events("guard").any(func(e):return e is InputEventJoypadMotion and e.axis==JOY_AXIS_TRIGGER_LEFT and e.axis_value==1.0),"DualSense L2 guard")
	app.audio.stop_speech()
	app.sim.boss_intros=app.audio.speech_manifest.boss_intros.duplicate(true)
	app.training_drill="boss"
	app._reset_training()
	var snapshot: Dictionary=app.sim.get_state()
	snapshot.tick+=1
	snapshot.intro.remaining_ticks-=1
	check(app._newer_snapshot(snapshot),"Advancing world ticks carry the nonblocking introduction to clients")
	var old: Dictionary=snapshot.duplicate(true)
	app.sim.state=snapshot
	old.tick-=1
	old.intro.remaining_ticks+=1
	check(not app._newer_snapshot(old),"Reordered intro packet cannot rewind countdown")
	app._reset_training()
	app.sim.state.fighters[1].x=1800.0
	app.sim.state.fighters[1].cooldown=9999
	tick(app,2)
	check(app.audio.intro_playing(),"Native app starts the selected boss speech")
	check(not app.sim.state.intro.get("blocking",true),"Training introductions use the same nonblocking rules as stage bosses")
	var voice_tick: int=app.sim.state.tick
	var voice_x: float=app.sim.state.fighters[0].x
	key(KEY_A,true)
	tick(app,6)
	key(KEY_A,false)
	check(app.audio.intro_playing() and app.sim.state.tick==voice_tick+6 and app.sim.state.fighters[0].x<voice_x,"Movement and world time continue while the introduction is spoken")
	key(KEY_J,true)
	tick(app)
	key(KEY_J,false)
	check(app.audio.intro_playing() and app.sim.state.fighters[0].action=="light","Attack input remains live during boss speech")
	tick(app,400)
	check(app.sim.state.tick==voice_tick+407 and app.sim.state.intro.remaining_ticks==0 and app.audio.intro_playing(),"Simulation continues even when the display countdown ends before real-time audio")
	var clip_seconds: float=app.audio._intro_player.stream.get_length()
	await create_timer(clip_seconds+0.15).timeout
	if app.audio.intro_playing(): await app.audio._intro_player.finished
	tick(app,3)
	check(not app.audio.intro_playing() and app.sim.state.tick==voice_tick+410,"Speech completion does not reset or interrupt continued combat")
	var connected=[]
	for id in Input.get_connected_joypads(): connected.append({"id":id,"name":Input.get_joy_name(id),"guid":Input.get_joy_guid(id)})
	print("CONNECTED JOYPADS: ",JSON.stringify(connected))
	app.audio.stop_speech()
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("V10 INPUT: %d checks, %d failures; physical controller playtest remains separate"%[checks,failures])
	quit(0 if failures == 0 else 1)
