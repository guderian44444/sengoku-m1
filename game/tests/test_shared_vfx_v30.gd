extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Audio = preload("res://render/combat_audio.gd")
var checks := 0
var failures := 0

class ReviewView extends View:
	var title := ""
	func _draw() -> void:
		_fx.shared_player.begin_draw(self)
		draw_rect(Rect2(0,0,1920,1080),Color("303c39"))
		Typography.draw_label(self,Vector2(24,36),title,25,Typography.PAPER)
		for effect in state.get("effects",[]):
			if effect.type == "shockwave": _draw_ground_effect(effect)
		for fighter in state.get("fighters",[]):
			_shadow_pass = true
			if fighter.team == 0: _draw_art_fighter(fighter,Vector2(fighter.x,fighter.y))
			else: _draw_enemy_art(fighter,Vector2(fighter.x,fighter.y))
			_shadow_pass = false
			if fighter.team == 0: _draw_art_fighter(fighter,Vector2(fighter.x,fighter.y))
			else: _draw_enemy_art(fighter,Vector2(fighter.x,fighter.y))
			_fx.draw_bound(self,int(fighter.id),camera_x)
			Typography.draw_label(self,Vector2(fighter.x-180,fighter.y+50),{"nobunaga":"信長","oichi":"阿市","hideyoshi":"秀吉","ieyasu":"家康","mitsuhide":"光秀","tadakatsu":"忠勝"}.get(fighter.kind,"火槍兵"),22,Typography.PAPER,360,HORIZONTAL_ALIGNMENT_CENTER)
		for effect in state.get("effects",[]):
			if effect.type != "shockwave": _draw_effect(effect)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func arena(hero: String) -> Battle:
	var battle := Battle.new()
	battle.reset("normal",1,[hero])
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.props.clear()
	battle.state.drops.clear()
	battle.state.fighters[0].x = 600
	battle.state.fighters[0].y = 500
	return battle

func tick(battle: Battle, view: View) -> void:
	battle.state.tick += 1
	battle.state.events.clear()
	for fighter in battle.state.fighters: battle._tick_fighter(fighter)
	battle._tick_effects()
	view.state = battle.state
	var before := var_to_bytes(battle.state)
	view._fx.sync(battle.state,view)
	check(var_to_bytes(battle.state) == before,"VFX/audio leave combat, equipment, damage and events unchanged")

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	var view := ReviewView.new()
	root.add_child(view)
	view._fx.muted = true
	check(view._fx.configured and view._fx.shared_player.catalog.size() == 28,"All twenty-eight reviewed base textures load once")
	var expected := ["fire","ice","wind","neutral","blade","fire"]
	for i in range(Battle.HEROES.size()):
		var hero: String = Battle.HEROES[i]
		var battle := arena(hero)
		var actor: Dictionary = battle.state.fighters[0]
		check(view._fx.family(actor) == expected[i],hero+" uses its appropriate default family")
		for cue in ["charge","release","final"]:
			var spec: Dictionary = view._fx.sound.assets[hero+":"+cue]
			check(AudioStreamWAV.load_from_file(view._fx.sound.root_path+str(spec.wav)) != null,hero+" special sound decodes without replacing its voice")
		for action in ["light","heavy","charged","charged_slam","special"]:
			view._fx.reset_scene()
			battle = arena(hero)
			actor = battle.state.fighters[0]
			battle._begin(actor,action)
			if action == "special": battle._event("special",actor.x,actor.y,actor.id,0)
			view.state = battle.state
			view._fx.sync(battle.state,view)
			for _frame in range(210 if action == "special" else 80): tick(battle,view)
			check(view._fx.emitter.diagnostics.is_empty(),hero+" "+action+" stays within lifecycle budget")
	var battle := arena("hideyoshi")
	var actor: Dictionary = battle.state.fighters[0]
	view._fx.reset_scene()
	battle._begin(actor,"charge")
	actor.charge = 40
	tick(battle,view)
	var charge: String = view._fx.charges[actor.id]
	view._fx.set_paused(true)
	var charge_before := var_to_bytes(view._fx.emitter.instances[charge])
	view._fx.emitter.advance(charge,100)
	check(var_to_bytes(view._fx.emitter.instances[charge]) == charge_before,"Paused VFX do not advance simulation or audio")
	view._fx.set_paused(false)
	battle._release_heavy(actor)
	for _frame in range(12): tick(battle,view)
	check(not view._fx.charges.has(actor.id) and view._fx.emitter.instances[charge].phase == "release","Charge loop ends and release starts at the actual first cut")
	check(Battle.SPECIAL_HIT_TICKS.hideyoshi == [35,105,175],"Shared art preserves Hideyoshi's authored three special pulses")
	view._fx.reset_scene()
	battle = arena("ieyasu")
	actor = battle.state.fighters[0]
	actor.action = "heavy"
	actor.action_tick = 14
	battle._projectile(actor,20,0,false,"bullet",800)
	var old: Dictionary = battle.state.effects[0]
	old.life -= 8
	old.x += 272
	battle.state.events.clear()
	battle._projectile(actor,20,0,false,"bullet",800)
	view.state = battle.state
	var event: Dictionary = battle.state.events[0]
	check(view._fx.accept_event(event,battle.state,view),"Confirmed matchlock shot activates the new pack")
	var id := "%d:event:%d" % [view._fx.generation,event.id]
	var origin: Vector2 = view._fx.origins[id]
	var fresh: Dictionary = battle.state.effects[-1]
	check(origin.is_equal_approx(Vector2(fresh.x,fresh.y-fresh.z-96)+view._projectile_release_offset(fresh)),"Muzzle binds to the fresh shot rather than an older bullet")
	var count: int = view._fx.emitter.instances.size()
	check(view._fx.accept_event(event,battle.state,view) and view._fx.emitter.instances.size() == count,"Repeated snapshots never replay a confirmed shot")
	actor.x += 90
	actor.face = -1
	view.camera_x = 210
	check(view._fx.origins[id] == origin and view._fx.emitter.instances[id].context.face == 1,"Released muzzle keeps its world origin and facing when the shooter moves or camera scrolls")
	var point_blank: Dictionary = event.duplicate(true)
	point_blank.id += 1
	battle.state.effects.clear()
	check(view._fx.accept_event(point_blank,battle.state,view) and view._fx.origins.size() == 2,"Confirmed point-blank shots keep a release-anchored flash after their bullet is destroyed")
	battle.state.fighters.clear()
	battle.state.tick += 1
	battle.state.events.clear()
	view._fx.sync(battle.state,view)
	check(view._fx.origins.is_empty() and view._fx.emitter.instances.is_empty(),"Removing a bound actor cancels its pending effects and sound")
	battle.state.tick = 0
	view._fx.sync(battle.state,view)
	check(view._fx.events.is_empty() and view._fx.emitter.retired.is_empty(),"Rollback resets deduplication and sound lifetimes")
	view._fx.muted = false
	check(view._fx.sound.handle_cue("mix","fire_charge_loop","loop_start"),"Selected v2 charge SFX actually starts in the native audio controller")
	var player: AudioStreamPlayer = view._fx.sound.players[0]
	var gain := player.volume_db
	view._fx.sound.set_voice_duck(true)
	check(player.bus == "SFX" and is_equal_approx(player.volume_db,gain-6),"New sounds respect the existing SFX bus and yield six dB to individual voices")
	view._fx.set_paused(true)
	check(player.stream_paused,"Pause freezes ongoing native sound")
	view._fx.reset_scene()
	check(view._fx.sound.players.is_empty() and view._fx.sound.loops.is_empty(),"Leaving or resetting stops all charge loops")
	for hero in Battle.HEROES:
		audio.stop_speech()
		audio.play_event({"type":"special","actor_kind":hero,"actor":1,"actor_slot":0,"shared_sfx":true})
		check(audio.speech_manifest.clips.get(audio.last_spoken,{}).get("actor","") == hero,"Shared SFX preserve "+hero+" independent special voice")
	view._fx.set_paused(false)
	view._fx.muted = true
	if "--capture" in OS.get_cmdline_user_args(): await capture(view)
	view.free()
	audio.free()
	print("SHARED VFX V30 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)

func capture(view: ReviewView) -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	var output := ProjectSettings.globalize_path("res://../artifacts/shared-vfx-tests-v30/native")
	DirAccess.make_dir_recursive_absolute(output)
	for action in ["light","heavy","charge","charged","charged_slam","special_first","special_final","status"]:
		for face in [-1,1]:
			view._fx.reset_scene()
			view.camera_x = 0
			var world := {"tick":1000,"fighters":[],"effects":[],"events":[]}
			for i in range(Battle.HEROES.size()):
				var battle := arena(Battle.HEROES[i])
				var actor: Dictionary = battle.state.fighters[0]
				actor.id = 100+i
				actor.face = face
				battle._begin(actor,"special" if action.begins_with("special") else ("idle" if action == "status" else action))
				if action == "status": actor.burn = 60 if i%2 == 0 else 0; actor.freeze = 60 if i%2 else 0
				if action == "charge": actor.charge = 45
				var contact := 6 if action == "light" else (12 if action == "charged" and actor.kind == "hideyoshi" else 14)
				if action == "charged_slam": contact = 28
				if action.begins_with("special"): contact = int(Battle.SPECIAL_HIT_TICKS[actor.kind][0 if action == "special_first" else -1])
				for frame in range(contact+1 if action != "charge" else 0):
					battle.state.tick += 1
					battle.state.events.clear()
					battle._tick_fighter(actor)
					battle._tick_effects()
				var offset := Vector2(320+(i%3)*640-600,410+(i/3)*490-500)
				actor.x += offset.x
				actor.y += offset.y
				for effect in battle.state.effects:
					for field in ["x","previous_x","origin_x","target_x"]:
						if effect.has(field): effect[field] += offset.x
					for field in ["y","previous_y","origin_y","target_y"]:
						if effect.has(field): effect[field] += offset.y
				world.fighters.append(actor)
				world.effects.append_array(battle.state.effects)
				for event in battle.state.events:
					event.x += offset.x
					event.y += offset.y
					event.id = 1000+i*100+world.events.size()
					world.events.append(event)
			view.state = world
			view._fx.sync(world,view)
			view.title = "共用效果 / "+action+" / "+("左向" if face < 0 else "右向")
			var before := var_to_bytes(world)
			var sound_serial: int = view._fx.sound.serial
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(var_to_bytes(world) == before and view._fx.sound.serial == sound_serial,"Native draw emits neither extra damage nor sound")
			check(not view.get_meta("shared_vfx_meshes",[]).is_empty(),"Native procedural meshes stay alive for the canvas commands")
			check(root.get_texture().get_image().save_png(output.path_join(action+("-left.png" if face < 0 else "-right.png"))) == OK,"Native six-hero effect review saved")
	for face in [-1,1]:
		view._fx.reset_scene()
		var battle := arena("nobunaga")
		battle.state.fighters.clear()
		for i in range(4):
			var gunner: Dictionary = battle._make_fighter(1,"gunner",360+i*300,530,100)
			gunner.faction = "oda"
			gunner.face = face
			battle.state.fighters.append(gunner)
			battle._begin(gunner,"gun_shot")
			gunner.action_tick = Battle.ENEMY_TIMING.gun_shot[0]-1
			battle._tick_fighter(gunner)
		view.state = battle.state
		view._fx.sync(battle.state,view)
		check(view._fx.origins.size() == 4,"Four actual enemy shot events bind four measured muzzle origins")
		view.title = "共用效果 / 火槍兵同時射擊 / "+("左向" if face < 0 else "右向")
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("gunshots"+("-left.png" if face < 0 else "-right.png"))) == OK,"Native simultaneous matchlock review saved")
