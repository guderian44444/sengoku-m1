extends SceneTree

const Battle = preload("res://core/battle.gd")
const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func axis(device: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device=device; event.axis=JOY_AXIS_TRIGGER_LEFT; event.axis_value=value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.player_devices=[3,7]
	check("guard" in Main.CONTROL_ACTIONS,"Focus cancellation releases the guard action")
	check(InputMap.action_get_events("guard").any(func(e):return e is InputEventJoypadMotion and e.axis==JOY_AXIS_TRIGGER_LEFT),"L2/LT mapping exists")
	for slot in [0,1]:
		axis(app.player_devices[slot],0.2)
		check(app._player_frame(slot).buttons==0,"Trigger noise below deadzone")
		axis(app.player_devices[slot],0.9)
		check(app._player_frame(slot).buttons==Battle.GUARD and app._player_frame(1-slot).buttons==0,"L2 isolated per player")
		check(Wire.valid_input(app._player_frame(slot)),"Guard input accepted over network")
		axis(app.player_devices[slot],0)
		check(app._player_frame(slot).buttons==0,"Trigger release clears guard")
	axis(11,0.9)
	check(app._player_frame(0).buttons==0 and app._player_frame(1).buttons==0,"Unassigned controller ignored")
	axis(11,0)
	var key := InputEventKey.new()
	key.physical_keycode=KEY_I;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	check(app._player_frame(0).buttons==Battle.GUARD and app._player_frame(1).buttons==0,"Keyboard I guards local player only")
	key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	for hero in Battle.PLAYABLE_HEROES:
		for face in [-1,1]:
			var sim := Battle.new()
			sim.reset_training(hero,"dummy")
			var f: Dictionary=sim.state.fighters[0]
			var enemy: Dictionary=sim.state.fighters[1]
			f.face=face;f.x=500;f.y=500
			enemy.x=f.x+face*50;enemy.y=f.y
			var origin := Vector2(f.x,f.y)
			for tick in 35:
				sim.step([{"buttons":Battle.GUARD,"dx":face,"dy":0,"stick_full":true}])
				check(f.action=="guard" and Vector2(f.x,f.y)==origin and not f.sprinting,"Held guard stays planted: "+hero)
				check(Wire.valid_snapshot(sim.get_state()),"Guard snapshots remain valid")
			app.view.state=sim.state
			app.view._moving[f.id]=true
			var sample: Dictionary=app.view._fighter_animation(f)
			var guard_frame: Dictionary=app.view._art.animation_frame(hero,sample)
			check(sample.clip=="guard" and sample.frame==sample.count-1 and sample.count>1,"Guard raises weapon then holds final pose: "+hero)
			var idle: Dictionary=f.duplicate(true)
			idle.action="idle";app.view._moving[f.id]=false
			var idle_frame: Dictionary=app.view._art.animation_frame(hero,app.view._fighter_animation(idle))
			check(guard_frame.texture!=idle_frame.texture or guard_frame.region!=idle_frame.region,"Guard body pose differs from idle: "+hero)
			f.action_tick=0
			check(app.view._fighter_animation(f).frame==0,"Guard has an entry animation")
			f.invuln=0;f.armor=0;f.treasure_uid=0;f.hp=5000;f.max_hp=5000
			check(sim._damage(f,50,enemy.id,false) and f.hp==4990 and f.action=="hurt","Front light hit reduces damage 80% and retains hit reaction")
			check(sim.state.events.any(func(e):return e.type=="guard"),"Block emits existing sound and impact event")
			sim._begin(f,"guard");f.invuln=0;enemy.x=f.x-face*50
			check(sim._damage(f,50,enemy.id,false) and f.hp==4940,"Rear attack bypasses guard")
			sim._begin(f,"guard");f.invuln=0;enemy.x=f.x+face*50
			check(sim._damage(f,50,enemy.id,true) and f.hp==4930 and f.action=="down","Heavy hit also reduces damage 80% but still knocks down")
			sim._begin(f,"guard");f.invuln=0;enemy.face=-face
			sim._enemy_melee(enemy,100,60,50,"push")
			check(f.hp==4920 and f.knockback==-face*12.0,"Guard preserves enemy push distance")
			sim._begin(f,"guard");f.invuln=0
			sim._enemy_melee(enemy,100,60,50,"down")
			check(f.hp==4910 and f.airborne_lock and f.action=="launched","Guard preserves enemy launching attacks")
			f.airborne_lock=false;f.z=0;f.vz=0;f.knockback=0
			sim._begin(f,"guard");f.invuln=0;f.armor=5
			check(sim._damage(f,50,0,false,true,false,false,f.x+face*100,f.y,"bow_shot") and f.hp==4903,"Projectile source position guards, after armor mitigation")
			f.armor=0
			sim._begin(enemy,"guard");enemy.invuln=0
			var enemy_hp: int=enemy.hp
			check(not sim._damage(enemy,50,f.id,false) and enemy.hp==enemy_hp,"Enemy guard still blocks ordinary attacks")
			sim._begin(f,"guard");f.invuln=0
			sim._queued_buttons[0]=Battle.LIGHT
			sim.step([{"buttons":Battle.GUARD}])
			sim.step([{}])
			check(f.action=="idle" and sim._queued_buttons[0]==0,"Release exits guard without a stale queued attack")
			sim.step([{"buttons":Battle.GUARD}])
			sim.cancel_input(0)
			check(f.action=="idle","Pause/focus loss cancels guard")
			sim.step([{"buttons":Battle.JUMP|Battle.GUARD}])
			check(f.action=="guard" and f.z==0,"Held guard takes precedence over jump")
			sim.step([{}]);sim.step([{"buttons":Battle.JUMP}]);sim.step([{"buttons":Battle.GUARD}])
			check(f.z>0 and f.action!="guard","No airborne guard")
			sim._begin(f,"charged");f.z=0;f.vz=0
			sim.step([{"buttons":Battle.GUARD}])
			check(f.action=="charged","Guard does not cancel an ongoing ultimate")
	app.queue_free()
	await process_frame
	print("GUARD RESTORE PASS: %d checks"%checks)
	quit()
