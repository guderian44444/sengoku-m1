extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
const Stage = preload("res://core/stage_data.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	audio.play_music()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v21/music.json"))
	check(manifest.tracks.size() == 4, "Four newly composed v21 scores are installed")
	var expected_keys := ["s01_bamboo_approach", "s01_outpost_battle", "s01_outpost_battle", "s01_outpost_battle", "s01_outpost_battle", "s01_outpost_battle", "s01_outpost_battle"]
	var campaign := Stage.first()
	for index in range(campaign.segments.size()):
		var segment: Dictionary = campaign.segments[index]
		audio.sync_stage_music({"stage":segment, "fighters":[]})
		check(audio._music_key == expected_keys[index], "Actual region %d selects its intended arrangement" % (index + 1))
		audio._process(Audio.MUSIC_FADE_SECONDS)
		check(audio._music_player.playing and not audio._music_tail.playing, "Region %d completes its continuous transition" % (index + 1))
	var world := {"stage":{"music":"bamboo"}, "fighters":[]}
	audio.sync_stage_music(world)
	audio._process(Audio.MUSIC_FADE_SECONDS)
	var area: AudioStreamPlayer = audio._music_player
	var minor := {"team":1, "kind":"boss", "hp":240, "stage_boss":false}
	world.fighters = [minor]
	audio.sync_stage_music(world)
	check(audio._music_key == "miniboss" and audio._music_tail == area and area.playing, "A live midboss immediately overlaps the ambient region score")
	var battle_player: AudioStreamPlayer = audio._music_player
	var playback := battle_player.get_stream_playback()
	for frame in range(120): audio.sync_stage_music(world)
	check(audio._music_player == battle_player and battle_player.get_stream_playback() == playback, "The boss theme does not restart during repeated simulation snapshots")
	minor.action = "down"
	audio.sync_stage_music(world)
	check(audio._music_key == "miniboss", "Knocking a living boss down does not revert the music")
	var final_boss := {"team":1, "kind":"boss", "hp":360, "stage_boss":true}
	for fighters in [[minor,final_boss],[final_boss,minor]]:
		world.fighters = fighters
		audio.sync_stage_music(world)
		check(audio._music_key == "boss", "The final commander has priority regardless of fighter order")
	final_boss.hp = 0
	audio.sync_stage_music(world)
	check(audio._music_key == "miniboss", "A remaining living midboss resumes after the final commander falls")
	minor.hp = 0
	audio.sync_stage_music(world)
	check(audio._music_key == "bamboo" and audio._music_tail.playing, "Defeated bosses restore the actual region score through a crossfade")
	world.fighters = [{"team":0,"kind":"boss","hp":100,"stage_boss":true}, {"team":1,"kind":"commander","hp":125}]
	audio.sync_stage_music(world)
	check(audio._music_key == "bamboo", "Allies and ordinary commanders do not claim the boss score")
	for key in ["bamboo", "town", "miniboss", "boss"]:
		check(Audio.STAGE_MUSIC[key].begins_with("res://audio/v27/" if key == "boss" else "res://audio/v21/"), key + " retains the registered legacy PCM source")
		audio.sync_stage_music({"stage":{"music":key}})
		audio._process(Audio.MUSIC_FADE_SECONDS)
		var player: AudioStreamPlayer = audio._music_player
		var stream: AudioStreamWAV = player.stream
		check(stream.stereo and stream.mix_rate == 44100 and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, key + " is a native full-resolution stereo loop")
		player.seek(stream.get_length() - .15)
		var loop_playback := player.get_stream_playback()
		await create_timer(.75).timeout
		check(player.playing and player.get_playback_position() < 2.0 and player.get_stream_playback() == loop_playback, key + " crosses its actual loop boundary without replacing playback")
	for event in ["extra_life", "revive", "armor_pickup", "armor_break"]:
		var expected := "guard_break" if event == "armor_break" else "pickup"
		var variants := []
		for i in range(3):
			audio.play_event({"type":event})
			check(audio.last_sound == expected, event + " reaches its short existing effect")
			variants.append(audio.last_sound_variant)
		check(variants.size() == 3 and variants.has(0) and variants.has(1) and variants.has(2), event + " cycles all three sound variants")
	audio.stop_music()
	for player in audio._voices: player.stop()
	audio.queue_free()
	await process_frame
	await create_timer(.2).timeout
	print("MUSIC V21: %d checks, %d failures; real native loop boundaries and routing, subjective listening remains pending" % [checks, failures])
	quit(0 if failures == 0 else 1)
