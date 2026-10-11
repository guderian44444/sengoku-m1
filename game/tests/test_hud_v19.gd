extends SceneTree

const HUD = preload("res://render/combat_hud.gd")
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
	var hud := HUD.new()
	root.add_child(hud)
	check(hud.portraits.size() == 6, "All selectable heroes retain their own existing-art portrait")
	var hashes := []
	for hero in HUD.PORTRAITS:
		var image := Image.load_from_file(HUD.PORTRAITS[hero][0])
		var region: Rect2i = HUD.PORTRAITS[hero][1]
		check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), hero + " crop stays inside source atlas")
		var portrait: Image = hud.portraits[hero].get_image()
		check(portrait.get_width() >= 110 and portrait.get_height() >= 110, hero + " source exceeds displayed portrait resolution")
		var hash := portrait.get_data().hex_encode().sha256_text()
		check(not hashes.has(hash), hero + " does not accidentally use another character's face")
		hashes.append(hash)
		check(portrait.get_data() == image.get_region(region).get_data(), hero + " portrait is native pixel crop of accepted art")
	var p1 := {"id":1,"team":0,"kind":"nobunaga","player_index":0,"hp":0,"max_hp":500,"rage":100}
	var p2 := {"id":2,"team":0,"kind":"oichi","player_index":1,"hp":240,"max_hp":400,"rage":35}
	var minor := {"id":3,"team":1,"kind":"boss","hp":300,"max_hp":350}
	var final := {"id":4,"team":1,"kind":"boss","hp":900,"max_hp":1000,"stage_boss":true}
	hud.sync({"fighters":[p2,minor,p1,final]})
	check(hud.players.size() == 2 and hud.players.has(p1), "A defeated partner remains visible with zero HP")
	check(hud.boss.id == final.id, "Final boss has priority when smaller officers share the battlefield")
	final.hp = 0
	hud.sync({"fighters":[p1,final]})
	check(hud.boss.is_empty() and hud.players.size() == 1, "Dead boss bar and stale 2P card disappear on the next snapshot")
	check(not HUD.player_rect(0).intersects(HUD.player_rect(1)) and HUD.player_rect(0).end.y <= 94, "Player HUD remains in two compact top corners")
	check(HUD.BOSS_RECT.size.y <= 36 and HUD.BOSS_RECT.end.y <= 720, "Boss bar is narrow and inside the visible viewport")
	var audio := Audio.new()
	root.add_child(audio)
	check(Audio.sound_for_event({"type":"food_pickup","food_id":"onigiri","heal":45}) == "food_pickup", "Eating routes to the dedicated healing cue")
	check(Audio.sound_for_event({"type":"pickup"}) == "pickup", "Gear pickups keep their distinct metal cue")
	var sounds: Array = audio._sound_variants.food_pickup
	check(sounds.size() >= 3, "Healing has at least three random variants")
	hashes.clear()
	for sound: AudioStreamWAV in sounds:
		var data := sound.data
		var hash := data.hex_encode().sha256_text()
		check(not hashes.has(hash), "Each healing variant has a distinct waveform")
		hashes.append(hash)
		check(sound.get_length() >= 0.25 and sound.get_length() <= 0.5, "Healing cue remains a clear short chime")
		check(abs(data.decode_s16(0)) < 20 and abs(data.decode_s16(data.size() - 2)) < 20, "Healing cue starts and ends without a waveform discontinuity")
		var peak := 0
		for offset in range(0, data.size(), 2): peak = maxi(peak, abs(data.decode_s16(offset)))
		check(peak > 8000 and peak < 32767, "Healing waveform is audible and does not clip")
		check(data != audio._sounds.pickup.data and data != audio._sounds.hit.data, "Healing never reuses an impact or gear waveform")
	var choices := []
	audio.play_music()
	var music: AudioStreamPlayer = audio._music_player
	for index in range(3):
		audio.play_event({"type":"food_pickup", "actor":1,"food_id":"onigiri","heal":45})
		choices.append(audio.last_sound_variant)
	check(choices[0] != choices[1] and choices[1] != choices[2] and choices[0] != choices[2], "One random bag plays all three healing takes without repetition")
	check(audio.last_spoken.is_empty() and audio._music_player == music and music.playing, "Healing cue leaves speech and background music independent")
	var healing: AudioStream = audio._food_player.stream
	for index in range(10): audio.play_event({"type":"heavy_hit"})
	check(audio._food_player.playing and audio._food_player.stream == healing, "Ten overlapping impacts cannot steal the dedicated healing confirmation")
	audio.stop_music()
	hud.queue_free()
	audio.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("HUD/AUDIO v19: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
