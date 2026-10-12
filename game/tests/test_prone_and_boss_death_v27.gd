extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const Audio = preload("res://render/combat_audio.gd")
const FrameAnimation = preload("res://render/frame_animation.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	for kind in ["soldier","boss"]:
		for face in [-1,1]:
			for shove in [false,true]:
				var battle := Battle.new()
				battle.reset_training("tadakatsu")
				battle.state.props.clear()
				var player: Dictionary = battle.state.fighters[0]
				var enemy: Dictionary = battle._make_fighter(1,kind,700,480,200)
				battle.state.fighters = [player,enemy]
				player.y = 480
				player.sprinting = shove
				for action in ["down","recovering"]:
					enemy.action = action
					player.x = 700.0 - face * 100.0
					battle._move_fighter(player,face * 200.0,0,shove)
					check(is_equal_approx(player.x,700.0 + face * 100.0),kind+" can be crossed while "+action)
					check(enemy.hp == 200 and not battle.state.events.any(func(e):return e.type == "run_bump"),"Crossing a prone enemy does not cause a sprint collision")
				enemy.action_tick = Battle.RECOVER_TICKS - 1
				player.x = 700.0 - face * 200.0
				battle._tick_fighter(enemy)
				check(enemy.action == "idle","Enemy completes recovery before becoming solid")
				player.x = 700.0 - face * 100.0
				battle._move_fighter(player,face * 200.0)
				check(is_equal_approx(player.x,700.0 - face * 45.0),"Standing enemy blocks movement again")
	if "--collision-only" not in OS.get_cmdline_user_args(): await _test_death_audio()
	_test_death_motion()
	print("V27 PRONE / BOSS DEATH %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _test_death_audio() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	await process_frame
	var pool: Array = audio.speech_manifest.get("actors",{}).get("boss_fallen",{}).get("defeat",[])
	check(pool.size() == 2,"Two distinct extended boss death wails are installed")
	for key in pool:
		check(audio._speech_streams.has(key),"Death wail decodes into a playable stream")
		if audio._speech_streams.has(key):
			var seconds: float = audio._speech_streams[key].get_length()
			check(seconds >= 2.5 and seconds < 7,"Death wail retains a long ending")
	for final in [false,true]:
		var actor := "boss_fallen" if final else "boss_minor_fallen"
		var choices: Array = audio.speech_manifest.actors.get(actor,{}).get("defeat",[])
		check(choices.size() == 2,"Both boss sizes retain two death variants")
		for key in choices:
			var seconds: float = audio._speech_streams[key].get_length()
			check(seconds >= 2.5 if final else seconds > 0 and seconds <= 1.5,"Only miniboss wails are capped at 1.5 seconds")
		audio.stop_speech()
		var battle := Battle.new()
		battle.reset_training("tadakatsu","boss")
		var boss: Dictionary = battle.state.fighters[1]
		boss.stage_boss = final
		battle._damage(boss,10000,battle.state.fighters[0].id,true,true,true)
		var deaths: Array = battle.state.events.filter(func(e):return e.type == "defeat" and e.target_kind == "boss")
		check(deaths.size() == 1,"Boss death emits exactly one death event")
		if deaths.is_empty(): continue
		check(deaths[0].get("target_stage_boss") == final,"Death event distinguishes small and final boss")
		check(Wire.valid_snapshot(battle.get_state()),"Death classification passes network validation")
		var invalid: Dictionary = battle.get_state()
		invalid.events[-1].target_stage_boss = "false"
		check(not Wire.valid_snapshot(invalid),"Network rejects a non-boolean death classification")
		audio.play_event(deaths[0])
		check(audio._speech_players.boss.playing,"Small/final boss plays its death wail")
		check(choices.any(func(key):return audio._speech_streams[key] == audio._speech_players.boss.stream),"Death event selects the correct duration pool")
		check(audio._speech_players.hero0.playing and audio.speech_manifest.actors.tadakatsu.boss_defeat.has(audio.last_spoken),"Hero keeps the enemy-general victory cry on a separate channel")
		var wail: AudioStream = audio._speech_players.boss.stream
		check(wail == audio._speech_streams[boss.death_voice] and absf(float(boss.death_ticks)/60.0 - wail.get_length()) < 1.0/60.0,"Death animation matches the exact selected cry within one simulation tick")
		audio.play_character("soldier","hurt",0,true)
		check(audio._speech_players.boss.playing and audio._speech_players.boss.stream == wail,"Ordinary enemy chatter cannot interrupt the boss wail")
		check(audio.speech_playing(),"Victory timing includes the extended death voice")
	audio.stop_speech()
	audio.queue_free()
	await process_frame

func _test_death_motion() -> void:
	for final in [false,true]:
		var battle := Battle.new()
		battle.reset_campaign()
		battle._enter_segment(6 if final else 1)
		battle._start_checkpoint(1)
		battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
		for prop in battle.state.props:
			prop.broken = true
			prop.hp = 0
		battle.state.wave = battle.state.stage.wave_total
		var boss: Dictionary = battle._make_fighter(1,"boss",700,480,200)
		boss.stage_boss = final
		boss.faction = "imagawa"
		battle.state.fighters.append(boss)
		battle._damage(boss,10000,battle.state.fighters[0].id,true,true,true)
		battle._launch(boss,1)
		check(not boss.airborne_lock,"Fatal blows use the grounded collapse instead of relaunching the corpse")
		var clips := {"imagawa:%s:death" % ("matsui" if final else "boss"): [{"source":"v19"},{},{},{},{},{}]}
		var previous_frame := -1
		var seen := []
		var valid := true
		for tick in range(boss.death_ticks+1):
			var sample := FrameAnimation.enemy_v14_sample(boss,0,0,clips)
			valid = valid and sample.frame >= previous_frame and sample.duration == boss.death_ticks and Wire.valid_snapshot(battle.get_state())
			previous_frame = sample.frame
			if sample.frame not in seen: seen.append(sample.frame)
			if tick == roundi(boss.death_ticks * .45): check(sample.frame == 2,"Boss holds the kneeling pose during the cry")
			if tick < boss.death_ticks:
				valid = valid and battle.state.phase == "playing" and not battle.state.stage.go
				battle.step([])
		check(valid and seen == [0,1,2,3,4,5],"All six death poses run forward with valid snapshots and no early stage exit")
		check(battle.state.fighters.has(boss) and boss.action_tick == boss.death_ticks,"Corpse survives through the complete long cry")
		for tick in range(46): battle.step([])
		check(battle.state.phase == "won" if final else battle.state.stage.go,"Stage can finish once collapse completes")
