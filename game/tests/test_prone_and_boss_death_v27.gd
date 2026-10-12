extends SceneTree

const Battle = preload("res://core/battle.gd")
const Audio = preload("res://render/combat_audio.gd")
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
		audio.stop_speech()
		var battle := Battle.new()
		battle.reset_training("tadakatsu","boss")
		var boss: Dictionary = battle.state.fighters[1]
		boss.stage_boss = final
		battle._damage(boss,10000,battle.state.fighters[0].id,true,true,true)
		var deaths: Array = battle.state.events.filter(func(e):return e.type == "defeat" and e.target_kind == "boss")
		check(deaths.size() == 1,"Boss death emits exactly one death event")
		if deaths.is_empty(): continue
		audio.play_event(deaths[0])
		check(audio._speech_players.boss.playing,"Small/final boss plays its death wail")
		check(audio._speech_players.hero0.playing and audio.speech_manifest.actors.tadakatsu.boss_defeat.has(audio.last_spoken),"Hero keeps the enemy-general victory cry on a separate channel")
		var wail: AudioStream = audio._speech_players.boss.stream
		audio.play_character("soldier","hurt",0,true)
		check(audio._speech_players.boss.playing and audio._speech_players.boss.stream == wail,"Ordinary enemy chatter cannot interrupt the boss wail")
		check(audio.speech_playing(),"Victory timing includes the extended death voice")
	audio.stop_speech()
	audio.queue_free()
	await process_frame
