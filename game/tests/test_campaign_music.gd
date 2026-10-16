extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run():
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Audio.CampaignMusic.ROOT + "manifest.json"))
	check(manifest.assets.size() == 12,"Twelve supplied OGG cues are installed")
	for row in manifest.assets:
		var path: String = Audio.CampaignMusic.ROOT + str(row.file).get_file()
		check(FileAccess.get_sha256(path) == row.sha256,"Unmodified supplied bytes: " + str(row.id))
		var stream = audio._load_music(row.id)
		check(stream is AudioStreamOggVorbis,"Native OGG decoder: " + str(row.id))
		check(absf(stream.get_length()-float(row.duration_seconds)) < .05,"Decoded duration: " + str(row.id))
		check(stream.loop == row.loop and is_zero_approx(stream.loop_offset),"Manifest loop mode and offset: " + str(row.id))
	var sim := Battle.new()
	for chapter in [1,2,3]:
		sim.reset_campaign("normal",2,["nobunaga","oichi"],chapter)
		for index in range(sim._campaign.segments.size()):
			sim._enter_segment(index)
			check(Wire.valid_snapshot(sim.get_state()),"New scene cue remains valid over Wire: %d/%d" % [chapter,index])
			check(sim.state.stage.music in Audio.CampaignMusic.KEYS,"Actual scene has supplied cue: %d/%d" % [chapter,index])
	# First contact changes the quiet opening, and kills must not return to it.
	audio.stop_music()
	sim.reset_campaign("normal",1,["nobunaga"],3)
	audio.sync_stage_music(sim.state)
	audio.play_music()
	check(audio._music_key == "s03_rain_approach","Rainy camp opens with Shizima4")
	var enemy: Dictionary = sim.state.fighters.filter(func(f):return f.team == 1)[0]
	enemy.entering = false
	enemy.x = sim.state.fighters[0].x + 200
	enemy.y = sim.state.fighters[0].y
	audio.sync_stage_music(sim.state)
	audio._process(2)
	check(audio._music_key == "s03_camp_battle","Actual first contact selects Amenoshita3")
	var current: AudioStreamPlayer = audio._music_player
	var playback = current.get_stream_playback()
	for f in sim.state.fighters:
		if f.team == 1: f.hp = 0
	for tick in range(120): audio.sync_stage_music(sim.state)
	check(audio._music_key == "s03_camp_battle" and audio._music_player == current and current.get_stream_playback() == playback,"Repeated snapshots and kills preserve the combat cursor")
	for index in [1,2]:
		sim._enter_segment(index)
		audio.sync_stage_music(sim.state)
		check(audio._music_player == current and current.get_stream_playback() == playback,"Barriers and formation continue the same cue")
	for chapter in [1,2,3]:
		audio.stop_music()
		sim.reset_campaign("normal",1,["nobunaga"],chapter)
		sim._enter_segment(3 if chapter == 3 else sim._campaign.segments.size()-1)
		var world := sim.get_state()
		world.fighters = [{"id":800,"team":1,"kind":"boss","hp":200,"stage_boss":chapter!=3}]
		audio.sync_stage_music(world)
		audio.play_music()
		var expected: String = "s03_dual_miniboss" if chapter == 3 else Audio.CampaignMusic.BOSSES[chapter]
		check(audio._music_key == expected,"Distinct chapter boss music: " + str(chapter))
		if chapter == 3:
			world.encounter.phase = "awaiting_yoshimoto"
			audio.sync_stage_music(world)
			check(audio._music_key == "s03_yoshimoto_boss","Yoshimoto introduction overrides twin-boss score")
		world.phase = "won" # Remaining enemies cannot override the victory cue.
		var battle_player: AudioStreamPlayer = audio._music_player
		audio.sync_stage_music(world)
		check(audio._music_key == "victory_jingle" and not battle_player.playing and not audio._music_tail.playing,"Victory cuts both battle players: " + str(chapter))
		current = audio._music_player
		playback = current.get_stream_playback()
		for tick in range(120): audio.sync_stage_music(world)
		check(current == audio._music_player and playback == current.get_stream_playback(),"Victory stinger starts only once: " + str(chapter))
		current.seek(current.stream.get_length()-.08)
		await create_timer(.75).timeout
		check(audio._music_key == "victory_loop" and audio._music_player.playing,"Natural stinger completion starts the bright loop: " + str(chapter))
		current = audio._music_player
		playback = current.get_stream_playback()
		for tick in range(20): audio.sync_stage_music(world)
		check(audio._music_player == current and current.get_stream_playback() == playback,"Won snapshots do not restart the completed stinger")
		world.phase = "lost"
		audio.sync_stage_music(world)
		check(not audio._music_active and not audio._music_player.playing and not audio._music_tail.playing,"Loss clears celebration and tails")
	# Exercise real decoder loop boundaries while keeping the same playback instance.
	for row in manifest.assets:
		if not row.loop: continue
		var key: String = row.id
		audio._change_music(key,.65,.25)
		audio.play_music()
		current = audio._music_player
		for crossing in range(2):
			current.seek(current.stream.get_length()-.08)
			playback = current.get_stream_playback()
			await create_timer(.75).timeout
			check(current.playing and current.get_playback_position() < 2 and current.get_stream_playback() == playback,"Actual OGG boundary %d preserves playback: %s" % [crossing+1,key])
		audio.stop_music()
	audio.sync_stage_music({"stage":{"id":1,"music":"s01_bamboo_approach"},"phase":"playing","fighters":[]})
	audio.play_music()
	check(audio._music_key == "s01_bamboo_approach","Restart clears the prior victory/combat selection")
	audio.sync_stage_music({"stage":{"id":1,"music":"s01_outpost_battle"},"phase":"playing","fighters":[]})
	audio._process(.1)
	var fade: float = audio._music_fade
	audio.set_music_paused(true)
	audio._process(1)
	check(audio._music_player.stream_paused and audio._music_tail.stream_paused and audio._music_fade == fade,"Pause preserves both cursors and fade state")
	audio.set_music_paused(false)
	audio.stop_music()
	audio._music_finished(audio._music_player)
	check(not audio._music_active and audio._music_key == "legacy","Stale completion cannot restart celebration after exit")
	audio.sync_stage_music({"stage":{"music":"siege"}})
	audio.play_music()
	audio._process(2)
	check(audio._music_key == "siege" and audio._music_player.stream is AudioStreamWAV,"Non-campaign legacy PCM routing remains supported")
	# A missing supplied file falls back safely; missing victory must silence battle.
	audio._campaign_scores["missing_test"] = {"file":"absent.ogg"}
	audio.sync_stage_music({"stage":{"music":"missing_test"}})
	check(audio._music_key == "legacy" and audio._music_player.stream is AudioStreamWAV and audio._music_player.playing,"Missing supplied OGG uses the legacy fallback")
	audio._campaign_scores.erase("missing_test")
	var victory_row: Dictionary = audio._campaign_scores.victory_jingle
	audio._campaign_scores.victory_jingle = {"file":"absent-victory.ogg"}
	audio._music_streams.erase("victory_jingle")
	audio.sync_stage_music({"stage":{"id":1},"phase":"won"})
	check(not audio._music_active and not audio._music_player.playing and not audio._music_tail.playing,"Missing victory file stops battle and its fade tail")
	audio._campaign_scores.erase("victory_jingle")
	audio.sync_stage_music({"stage":{"music":"siege"}})
	audio.play_music()
	audio.sync_stage_music({"stage":{"id":1},"phase":"won"})
	check(not audio._music_active and not audio._music_player.playing and not audio._music_tail.playing,"Missing victory manifest entry also silences battle")
	audio._campaign_scores.victory_jingle = victory_row
	audio.stop_music()
	audio.queue_free()
	await process_frame
	print("CAMPAIGN MUSIC: %d checks, %d failures; listening and hardware mix remain pending" % [checks,failures])
	quit(0 if failures == 0 else 1)
