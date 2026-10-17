extends Node

const CampaignMusic = preload("res://core/campaign_music.gd")
const TITLE_ROOT := "res://audio/title-amenoshita-v1/"
const TITLE_KEYS := ["title_intro", "title_loop"]

const SAMPLE_RATE := 22050
const VOICE_COUNT := 6
const IMPACT_VARIANTS := 5
const SFX_VARIANTS := 3
const SAMPLED_CUES := ["sword_whoosh","sword_heavy_whoosh","hit","heavy_hit","spear_wind","spear_hit","spear_heavy_hit","blunt_whoosh","blunt_hit","blunt_heavy_hit","bow_release","bow_heavy_release","arrow_hit","shield_hit","guard_break","guard","kick_whoosh"]
const WEAPON_AUDIO_ROOT := "res://audio/v38/weapons/"
const WEAPONS_V3_ROOT := "res://audio/weapons-v3/"
const V3_ALIASES := {
	"sword_whoosh":"sword_swing", "sword_heavy_whoosh":"sword_swing", "hit":"sword_hit_flesh", "heavy_hit":"sword_hit_flesh",
	"spear_wind":"spear_thrust", "spear_hit":"spear_hit_flesh", "spear_heavy_hit":"spear_hit_flesh",
	"blunt_whoosh":"staff_swing", "blunt_hit":"staff_hit", "blunt_heavy_hit":"staff_hit",
	"bow_heavy_release":"bow_release", "arrow_hit":"arrow_hit_body", "guard":"shield_block", "shield_hit":"shield_block",
	"needle_whoosh":"knife_throw", "needle_hit":"knife_hit_flesh", "bullet_hit":"musket_hit_body", "grab":"grab_contact"
}
static var _v3_banks: Dictionary = {}
const MUSIC_VOLUME_DB := -19.0
const MUSIC_FADE_SECONDS := 1.4
const CATEGORY_BUSES := {"music": "Music", "sfx": "SFX", "voice": "Voice"}
const STAGE_MUSIC := {
	"legacy": "res://audio/v35/legacy-loop.wav",
	"bamboo": "res://audio/v35/bamboo-loop.wav",
	"siege": "res://audio/v35/siege-loop.wav",
	"town": "res://audio/v35/town-loop.wav",
	"castle": "res://audio/v35/castle-loop.wav",
	"camp": "res://audio/v35/camp-loop.wav",
	"courtyard": "res://audio/v35/courtyard-loop.wav",
	"river": "res://audio/v35/river-loop.wav",
	"miniboss": "res://audio/v35/miniboss-loop.wav",
	"boss": "res://audio/v35/boss-loop.wav"
}
const SCENE_MUSIC := {"camp":"camp", "courtyard":"courtyard", "riverbank":"river"}
const EVENT_SOUNDS := {
	"hit": "hit", "heavy_hit": "heavy_hit", "special": "special",
	"pickup": "pickup", "food_pickup": "food_pickup", "defeat": "defeat", "shield_hit": "shield_hit", "grab": "grab", "bow_release": "bow_release",
	"gunshot": "gunshot", "shatter": "shatter", "sword_whoosh":"sword_whoosh", "spear_wind":"spear_wind",
	"landing":"landing", "splash":"splash", "guard":"guard", "guard_break":"guard_break", "prop_break":"prop_break",
	"arrow_hit":"arrow_hit", "bullet_hit":"bullet_hit", "needle_hit":"needle_hit", "blunt_hit":"blunt_hit",
	"kick_whoosh":"kick_whoosh", "needle_whoosh":"needle_whoosh", "chain_swing":"chain_swing",
	"ceramic_hit":"ceramic_hit", "ceramic_break":"ceramic_break", "box_hit":"box_hit", "box_break":"box_break",
	"wood_hit":"wood_hit", "wood_break":"wood_break", "stone_hit":"stone_hit", "stone_break":"stone_break", "wicker_hit":"wicker_hit", "wicker_break":"wicker_break"
}

var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _food_player: AudioStreamPlayer
var _prop_players: Array[AudioStreamPlayer] = []
var _bell_player: AudioStreamPlayer
var _next_prop := 0
var _next_voice: int = 0
var _impact_sounds: Dictionary = {}
var _sound_variants: Dictionary = {}
var _sample_gains: Dictionary = {}
var _choice_bags: Dictionary = {}
var _last_choices: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var last_impact_variant := -1
var last_sound := ""
var last_sound_variant := -1
var speech_manifest: Dictionary = {}
var _speech_streams: Dictionary = {}
var _speech_players: Dictionary = {}
var _intro_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_tail: AudioStreamPlayer
var _music_streams: Dictionary = {}
var _campaign_scores: Dictionary = {}
var _music_target_gain := db_to_linear(MUSIC_VOLUME_DB)
var _music_fade_seconds := MUSIC_FADE_SECONDS
var _music_key := "legacy"
var _title_intro_seen := false
var _title_switch_at := -1.0
var _title_crossfade_seconds := 0.1
var _title_linear_crossfade := false
var _alarm_player: AudioStreamPlayer
var _music_active := false
var _music_paused := false
var _music_fade := 1.0
var _music_tail_gain := 0.0
var last_spoken := ""
var _intro_token := ""
var settings_path := "user://audio-settings.cfg"
var _category_volumes := {"music": 1.0, "sfx": 1.0, "voice": 1.0}

func _ready() -> void:
	_restore_volumes()
	_rng.randomize()
	for kind in EVENT_SOUNDS:
		_sound_variants[kind] = []
		for variant in range(IMPACT_VARIANTS if kind in ["hit", "heavy_hit"] else SFX_VARIANTS):
			_sound_variants[kind].append(_synthesize(kind, variant))
		_sounds[kind] = _sound_variants[kind][0]
		if kind in ["hit", "heavy_hit"]: _impact_sounds[kind] = _sound_variants[kind]
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = CATEGORY_BUSES.sfx
		player.volume_db = -17.0
		add_child(player)
		_voices.append(player)
	assert(_sounds.size() == EVENT_SOUNDS.size() and _voices.size() == VOICE_COUNT)
	var weapons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WEAPON_AUDIO_ROOT + "manifest.json"))
	for cue in SAMPLED_CUES:
		var bank := []
		for take in weapons.cues[cue].variants:
			var sample := AudioStreamWAV.load_from_file(WEAPON_AUDIO_ROOT + str(take.file))
			assert(sample != null, "Missing weapon sound: " + str(take.file))
			bank.append(sample)
		assert(bank.size() == IMPACT_VARIANTS)
		_sound_variants[cue] = bank
		_sounds[cue] = bank[0]
		_sample_gains[cue] = float(weapons.cues[cue].gain_db)
		if cue in ["hit","heavy_hit"]: _impact_sounds[cue] = bank
	for cue in weapon_banks():
		var bank := []
		for take in weapon_banks()[cue].variants:
			var sample := AudioStreamWAV.load_from_file(WEAPONS_V3_ROOT + str(take.file))
			assert(sample != null, "Missing v3 weapon sound: " + str(take.file))
			bank.append(sample)
		assert(not bank.is_empty())
		_sound_variants[cue] = bank
		_sample_gains[cue] = -17.0
	for cue in V3_ALIASES:
		_sound_variants[cue] = _sound_variants[V3_ALIASES[cue]]
		if cue in ["hit","heavy_hit"]: _impact_sounds[cue] = _sound_variants[cue]
	for cue in ["musket_player_shot","charge_release","spin_finish"]: _sample_gains[cue] = -13.0
	_sample_gains.musket_enemy_shot = -16.0
	for element in ["fire","ice","wind","lightning"]: _sample_gains["element_"+element+"_hit"] = -24.0
	_food_player = AudioStreamPlayer.new()
	_food_player.bus = CATEGORY_BUSES.sfx
	_food_player.volume_db = -10.0
	add_child(_food_player)
	var voice_root := "res://audio/v31/"
	var manifest_path := voice_root + "manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: speech_manifest = parsed
	var repairs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v38/voices/manifest.json"))
	for field in ["clips","actors","named_calls","stage_boss_intros","hero_voice_profiles"]:
		speech_manifest[field].merge(repairs.get(field, {}), true)
	for key in speech_manifest.get("clips", {}):
		var clip: Dictionary = speech_manifest.clips[key]
		var path := str(clip.file)
		var stream := AudioStreamWAV.load_from_file(path if path.begins_with("res://") else voice_root + path)
		if stream != null: _speech_streams[key] = stream
	for channel in ["hero0", "hero1", "enemy", "boss"]:
		var speaker := AudioStreamPlayer.new()
		speaker.bus = CATEGORY_BUSES.voice
		speaker.volume_db = -5.0 if channel.begins_with("hero") else -9.0
		add_child(speaker)
		_speech_players[channel] = speaker
	_intro_player = AudioStreamPlayer.new()
	_intro_player.bus = CATEGORY_BUSES.voice
	_intro_player.volume_db = -3.0
	add_child(_intro_player)
	var score_path := CampaignMusic.ROOT + "manifest.json"
	if FileAccess.file_exists(score_path):
		var scores: Variant = JSON.parse_string(FileAccess.get_file_as_string(score_path))
		if scores is Dictionary:
			for row in scores.get("assets", []): _campaign_scores[str(row.id)] = row
	var title_path := TITLE_ROOT + "title_music_handoff.json"
	if FileAccess.file_exists(title_path):
		var title: Variant = JSON.parse_string(FileAccess.get_file_as_string(title_path))
		if title is Dictionary:
			_title_switch_at = float(title.get("loop_first_start_seconds", -1.0))
			_title_crossfade_seconds = float(title.get("intro_to_loop_crossfade_seconds", 0.1))
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = CATEGORY_BUSES.music
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	_music_tail = AudioStreamPlayer.new()
	_music_tail.bus = CATEGORY_BUSES.music
	add_child(_music_tail)
	_music_player.finished.connect(_music_finished.bind(_music_player))
	_music_tail.finished.connect(_music_finished.bind(_music_tail))
	_music_player.stream = _load_music("legacy")
	_alarm_player = AudioStreamPlayer.new()
	_alarm_player.bus = CATEGORY_BUSES.sfx
	_alarm_player.volume_db = -24.0
	_alarm_player.stream = AudioStreamWAV.load_from_file("res://audio/stage3/alarm.wav")
	_alarm_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_alarm_player.stream.loop_end = _alarm_player.stream.data.size() / 2
	for cue in ["bell_fall","sword_air"]:
		_sound_variants[cue] = [AudioStreamWAV.load_from_file("res://audio/stage3/"+cue+".wav")]
	add_child(_alarm_player)
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/props-v41/manifest.json"))
	for cue in props.cues:
		var bank := []
		for file in props.cues[cue]: bank.append(AudioStreamWAV.load_from_file("res://audio/props-v41/" + file))
		_sound_variants[cue] = bank
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = CATEGORY_BUSES.sfx
		add_child(player)
		_prop_players.append(player)
	_bell_player = AudioStreamPlayer.new()
	_bell_player.bus = CATEGORY_BUSES.sfx
	add_child(_bell_player)

func _restore_volumes() -> void:
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error not in [OK, ERR_FILE_NOT_FOUND]: push_warning("Audio settings could not be read; using the default mix.")
	for category in CATEGORY_BUSES:
		var value: Variant = config.get_value("audio", category, 1.0) if error == OK else 1.0
		if (value is float or value is int) and is_finite(float(value)):
			_category_volumes[category] = clampf(float(value), 0.0, 1.0)
		var bus_name: String = CATEGORY_BUSES[category]
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		_apply_volume(category)

func get_category_volume(category: String) -> float:
	return float(_category_volumes.get(category, 1.0))

func set_category_volume(category: String, value: float) -> Error:
	if not CATEGORY_BUSES.has(category) or not is_finite(value): return ERR_INVALID_PARAMETER
	_category_volumes[category] = clampf(value, 0.0, 1.0)
	_apply_volume(category)
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error not in [OK, ERR_FILE_NOT_FOUND]: return error
	for key in _category_volumes: config.set_value("audio", key, _category_volumes[key])
	return config.save(settings_path)

func _apply_volume(category: String) -> void:
	var bus := AudioServer.get_bus_index(CATEGORY_BUSES[category])
	if bus < 0: return
	var level := get_category_volume(category)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(bus, is_zero_approx(level))

func _load_music(key: String) -> AudioStream:
	if _music_streams.has(key): return _music_streams[key]
	if key in TITLE_KEYS:
		var title_path := TITLE_ROOT + key + ".ogg"
		if not FileAccess.file_exists(title_path): return null
		var title := AudioStreamOggVorbis.load_from_file(title_path)
		if title == null: return null
		title.loop = key == "title_loop"
		title.loop_offset = 0.0
		title.beat_count = 0
		if key == "title_intro" and _title_switch_at < 0: _title_switch_at = maxf(0.0, title.get_length() - _title_crossfade_seconds)
		_music_streams[key] = title
		return title
	if _campaign_scores.has(key):
		var row: Dictionary = _campaign_scores[key]
		var ogg_path := CampaignMusic.ROOT + str(row.file).get_file()
		if not FileAccess.file_exists(ogg_path): return null
		var ogg := AudioStreamOggVorbis.load_from_file(ogg_path)
		if ogg == null: return null
		ogg.loop = bool(row.loop)
		ogg.loop_offset = float(row.loop_start_seconds) if row.loop else 0.0
		ogg.beat_count = 0
		_music_streams[key] = ogg
		return ogg
	var path: String = STAGE_MUSIC[key]
	if not FileAccess.file_exists(path): return null
	var music := AudioStreamWAV.load_from_file(path)
	if music == null: return null
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = music.data.size() / (4 if music.stereo else 2)
	_music_streams[key] = music
	return music

static func alarm_should_ring(world: Dictionary) -> bool:
	return world.get("phase", "") == "playing" and world.get("encounter", {}).get("ringing", false)

func sync_encounter(world: Dictionary) -> void:
	if _alarm_player == null: return
	if alarm_should_ring(world):
		if not _alarm_player.playing: _alarm_player.play()
		_alarm_player.stream_paused = _music_paused
	else:
		_alarm_player.stop()

func sync_stage_music(world: Dictionary) -> void:
	var key := CampaignMusic.select(world,_music_key)
	if key == "silence":
		if _music_active: stop_music()
		return
	if key.is_empty():
		var stage: Variant = world.get("stage", {})
		key = str(stage.get("music", "legacy")) if stage is Dictionary else "legacy"
		if stage is Dictionary: key = str(SCENE_MUSIC.get(str(stage.get("theme","")),key))
		for fighter in world.get("fighters", []):
			if fighter.get("team", 1) != 1 or fighter.get("kind", "") != "boss" or fighter.get("hp", 0) <= 0: continue
			key = "boss" if fighter.get("stage_boss", false) else "miniboss"
			if key == "boss": break
	if not STAGE_MUSIC.has(key) and not _campaign_scores.has(key):
		if key in ["victory_jingle", "victory_loop"]:
			stop_music()
			return
		key = "legacy"
	var gain: float = CampaignMusic.gain(world,key) if _campaign_scores.has(key) else db_to_linear(-14.0 if key == "boss" else (-17.0 if key == "miniboss" else MUSIC_VOLUME_DB))
	var fade: float = CampaignMusic.fade_seconds(key) if _campaign_scores.has(key) else (0.55 if key == "boss" else MUSIC_FADE_SECONDS)
	_change_music(key,gain,fade)

func _change_music(key: String, gain: float, fade: float) -> void:
	_music_target_gain = gain
	if key == _music_key: return
	var stream := _load_music(key)
	if stream == null:
		if key in ["victory_jingle", "victory_loop"]:
			stop_music()
			return
		key = "legacy"
		stream = _load_music(key)
		gain = db_to_linear(MUSIC_VOLUME_DB)
		fade = MUSIC_FADE_SECONDS
		_music_target_gain = gain
		if stream == null or key == _music_key: return
	_title_linear_crossfade = _music_active and _music_key == "title_intro" and key == "title_loop"
	_music_key = key
	_music_fade_seconds = fade
	if key == "victory_jingle":
		# No battle score may survive under the victory cue, including a fade tail.
		_music_player.stop()
		_music_tail.stop()
		_music_tail.stream = null
	if not _music_active:
		_music_player.stream = stream
		_music_player.volume_linear = gain
		return
	_music_tail.stop()
	var outgoing := _music_player
	_music_player = _music_tail
	_music_tail = outgoing
	_music_tail_gain = _music_tail.volume_linear
	_music_player.stream = stream
	_music_player.volume_linear = 0.0
	_music_player.play()
	_music_player.stream_paused = _music_paused
	_music_fade = 0.0

func _music_finished(player: AudioStreamPlayer) -> void:
	if player != _music_player or not _music_active: return
	if _music_key == "victory_jingle": _change_music("victory_loop",.65,.25)
	elif _music_key == "title_intro": _change_music("title_loop",1.0,_title_crossfade_seconds)

func _process(delta: float) -> void:
	if not _music_active or _music_paused: return
	if _music_key == "title_intro" and _music_player.playing and _music_player.get_playback_position() >= _title_switch_at:
		_change_music("title_loop",1.0,_title_crossfade_seconds)
	# Recover an interrupted stream without restarting healthy loops or same-score areas.
	if not _music_player.playing and _music_player.stream != null and _music_key not in ["victory_jingle", "title_intro"]: _music_player.play()
	if _music_fade >= 1.0:
		_music_player.volume_linear = move_toward(_music_player.volume_linear,_music_target_gain,delta * 2.0)
		return
	_music_fade = minf(1.0, _music_fade + delta / _music_fade_seconds)
	_music_player.volume_linear = _music_target_gain * (_music_fade if _title_linear_crossfade else sin(_music_fade * PI * 0.5))
	_music_tail.volume_linear = _music_tail_gain * (1.0 - _music_fade if _title_linear_crossfade else cos(_music_fade * PI * 0.5))
	if _music_fade >= 1.0:
		_music_tail.stop()
		_music_tail.stream = null

func is_title_music() -> bool:
	return _music_active and _music_key in TITLE_KEYS

func play_title_music() -> void:
	if is_title_music(): return
	var key := "title_loop" if _title_intro_seen else "title_intro"
	if key == "title_intro" and _load_music(key) == null: key = "title_loop"
	_title_intro_seen = true
	# The supplied OGG files already contain gain 0.65 and the intro fade-in.
	_change_music(key,1.0,0.6)
	play_music()

func play_music() -> void:
	if _music_player == null or _music_player.stream == null: return
	_music_active = true
	if not _music_player.playing:
		_music_player.volume_linear = 0.0 if _campaign_scores.has(_music_key) else _music_target_gain
		if _campaign_scores.has(_music_key): _music_fade = 0.0
		_music_player.play()
	set_music_paused(false)

func stop_music() -> void:
	if _alarm_player != null: _alarm_player.stop()
	if _music_player != null: _music_player.stop()
	if _music_tail != null:
		_music_tail.stop()
		_music_tail.stream = null
	_music_active = false
	_music_fade = 1.0
	_title_linear_crossfade = false
	_music_key = "legacy"
	_music_target_gain = db_to_linear(MUSIC_VOLUME_DB)
	_music_fade_seconds = MUSIC_FADE_SECONDS
	if _music_player != null:
		_music_player.stream = _load_music("legacy")
		_music_player.volume_db = MUSIC_VOLUME_DB
	set_music_paused(false)

func set_music_paused(paused: bool) -> void:
	_music_paused = paused
	if _alarm_player != null: _alarm_player.stream_paused = paused
	if _music_player != null: _music_player.stream_paused = paused
	if _music_tail != null: _music_tail.stream_paused = paused

func play_event(event: Dictionary) -> void:
	_play_character_event(event)
	if event.get("shared_sfx",false): return
	var kind := sound_for_event(event)
	if not _sound_variants.has(kind) or _voices.is_empty():
		return
	# A crowded impact burst must not steal the healing confirmation.
	var player := _food_player if kind == "food_pickup" else _voices[_next_voice]
	if kind == "bell_fall": player = _bell_player
	elif event.get("type","") in ["prop_hit","prop_break"]:
		player = _prop_players[_next_prop]
		_next_prop = (_next_prop + 1) % _prop_players.size()
	elif kind != "food_pickup": _next_voice = (_next_voice + 1) % VOICE_COUNT
	last_sound = kind
	last_sound_variant = _choose_variant("sfx:" + kind, _sound_variants[kind].size())
	player.stream = _sound_variants[kind][last_sound_variant]
	if _impact_sounds.has(kind): last_impact_variant = last_sound_variant
	player.volume_db = -13.0 if kind in ["heavy_hit", "bullet_hit", "gunshot"] else -17.0
	if _sample_gains.has(kind): player.volume_db = _sample_gains[kind]
	if event.get("type","") in ["prop_hit","prop_break"]: player.volume_db = -5.0 if event.type == "prop_break" else -6.0
	if kind == "bell_fall": player.volume_db = -4.0
	if kind == "food_pickup": player.volume_db = -10.0
	player.play()

static func sound_for_event(event: Dictionary) -> String:
	if event.get("sound_suppressed",false): return ""
	if event.get("type","") == "weapon_swing" and event.get("action","") == "boss_sword_wave": return "sword_air"
	var kind := str(event.get("type", event.get("kind", "")))
	var weapon := str(event.get("weapon", ""))
	var action := str(event.get("action", ""))
	var polearm := str(event.get("weapon_id", "")).contains("naginata")
	if kind == "gunshot": return "musket_player_shot" if int(event.get("actor_team",1)) == 0 else "musket_enemy_shot"
	if kind == "element_hit": return "element_" + str(event.get("element","")) + "_hit"
	if kind == "prop_hit" and weapon in ["arrow","special_arrow","needle"] and event.get("material","") in ["wood","box"]: return "arrow_hit_wood"
	if kind in ["prop_hit","prop_break"]: return str(event.get("material","wood")) + ("_break" if kind == "prop_break" else "_hit")
	if kind == "swing": return "" # Voice onset; wind belongs to the actual weapon release.
	if kind == "weapon_swing":
		if action.begins_with("charged"):
			return "sword_draw" if event.get("actor_kind","") == "ieyasu" and action == "charged" else "charge_release"
		if weapon == "blade" or polearm: return "polearm_sweep"
		var sword := "sword_heavy_whoosh" if action.begins_with("charged") or action in ["heavy","air_heavy","dash_heavy"] else "sword_whoosh"
		return {"needle":"needle_whoosh", "spear":"spear_wind", "blunt":"blunt_whoosh", "kick":"kick_whoosh", "chain":"chain_swing"}.get(weapon,sword)
	if kind == "bow_release": return "bow_heavy_release" if weapon == "special_arrow" or event.get("action", "") in ["charged","charge_rain","special"] else "bow_release"
	if kind in ["hit", "heavy_hit", "shield_hit"]:
		if event.get("contact","") == "armor_absorb": return "shield_block"
		if action == "throw": return "" # Release has a whoosh; the body impact belongs to landing.
		if action == "body_collision": return "body_collision"
		if action.begins_with("grab_hit"):
			return "headbutt_hit" if event.get("actor_kind","") in ["nobunaga","ieyasu","mitsuhide"] else "knee_hit"
		if event.get("spin_finish",false): return "spin_finish"
		if event.get("material","") == "armor":
			return {"bullet":"musket_hit_armor", "needle":"knife_hit_armor", "arrow":"knife_hit_armor", "special_arrow":"knife_hit_armor", "blunt":"staff_hit_armor", "kick":"body_collision"}.get(weapon,"sword_hit_armor")
		if polearm: return "polearm_hit_flesh"
		if kind == "shield_hit" and event.get("contact","") != "held_body": return "shield_hit"
		var heavy := kind == "heavy_hit"
		return {"arrow":"arrow_hit", "special_arrow":"arrow_hit", "bullet":"bullet_hit", "needle":"needle_hit", "spear":"spear_heavy_hit" if heavy else "spear_hit", "blunt":"blunt_heavy_hit" if heavy else "blunt_hit", "kick":"body_collision"}.get(weapon,"hit" if kind == "shield_hit" else kind)
	if kind == "run_bump": return "body_collision"
	if kind in ["extra_life", "revive", "armor_pickup"]: return "pickup"
	if kind == "armor_break": return "guard_break"
	if kind == "landing" and event.get("wet",false): return "splash"
	if kind == "landing" and event.get("body",false): return "body_land"
	return kind

static func weapon_banks() -> Dictionary:
	if _v3_banks.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_V3_ROOT+"manifest.json"))
		_v3_banks = data.cues
	return _v3_banks

static func owns_physical_sound(event: Dictionary) -> bool:
	var cue := sound_for_event(event)
	return cue.is_empty() or cue in SAMPLED_CUES or V3_ALIASES.has(cue) or weapon_banks().has(cue)

func _choose_variant(selector: String, count: int) -> int:
	# Random bags visit every distinct take; a refill never repeats its boundary take.
	var bag: Array = _choice_bags.get(selector,[])
	if bag.is_empty():
		bag = range(count)
		for i in range(count - 1,0,-1):
			var swap := _rng.randi_range(0,i)
			var value: int = bag[i]
			bag[i] = bag[swap]
			bag[swap] = value
		if count > 1 and bag[0] == _last_choices.get(selector,-1):
			var swap := _rng.randi_range(1,count-1)
			var value: int = bag[0]
			bag[0] = bag[swap]
			bag[swap] = value
	var index: int = bag.pop_front()
	_choice_bags[selector] = bag
	_last_choices[selector] = index
	return index

func intro_playing() -> bool:
	return _intro_player != null and _intro_player.playing

func speech_playing() -> bool:
	if intro_playing(): return true
	for player in _speech_players.values():
		if player.playing: return true
	return false

func stop_speech() -> void:
	_intro_token = ""
	if _intro_player != null: _intro_player.stop()
	for player in _speech_players.values(): player.stop()

func play_character(actor: String, event: String, slot: int = 0, force: bool = false) -> void:
	if intro_playing(): return
	var choices: Array = speech_manifest.get("actors", {}).get(actor, {}).get(event, [])
	if choices.is_empty(): return
	var channel := "boss" if actor.begins_with("boss_") else ("hero%d" % clampi(slot, 0, 1) if actor in ["nobunaga","oichi","hideyoshi","ieyasu","mitsuhide","tadakatsu"] else "enemy")
	var player: AudioStreamPlayer = _speech_players[channel]
	if player.playing and not force: return
	# Events/actors sharing the same short-voice pool also share its no-repeat history.
	var index := _choose_variant("voice:" + ",".join(choices), choices.size())
	var key: String = choices[index]
	if not _speech_streams.has(key): return
	last_spoken = key
	player.stream = _speech_streams[key]
	player.pitch_scale = 0.88 if actor == "tadakatsu" and not speech_manifest.has("hero_voice_profiles") else 1.0
	player.play()

func _play_character_event(event: Dictionary) -> void:
	var type := str(event.get("type", ""))
	if type == "defeat" and event.get("target_kind","") == "boss":
		_intro_player.stop()
		_intro_token = ""
		var actor := "boss_fallen" if event.get("target_stage_boss",false) else "boss_minor_fallen"
		var key := str(event.get("line_key",""))
		if key in speech_manifest.get("actors",{}).get(actor,{}).get("defeat",[]) and _speech_streams.has(key):
			_speech_players.boss.stream = _speech_streams[key]
			_speech_players.boss.pitch_scale = 1.0
			_speech_players.boss.play()
		else: play_character(actor,"defeat",0,true)
		play_character(str(event.get("actor_kind","nobunaga")),"boss_defeat",int(event.get("actor_slot",0)),true)
		return
	if type == "boss_intro":
		var key := str(event.get("line_key", ""))
		var token := "%s:%d" % [key, int(event.get("actor", 0))]
		if token == _intro_token: return
		if _speech_streams.has(key):
			stop_speech()
			_intro_token = token
			_intro_player.stream = _speech_streams[key]
			_intro_player.play()
			last_spoken = key
		return
	var speech_event: String = {"swing":"attack", "special":"special", "hit":"hurt", "heavy_hit":"hurt", "shield_hit":"hurt", "guard":"guard", "guard_break":"hurt", "defeat":"defeat"}.get(type, "")
	if speech_event == "": return
	var target: bool = type in ["hit", "heavy_hit", "shield_hit", "guard", "guard_break", "defeat"]
	var actor := str(event.get("target_kind" if target else "actor_kind", "soldier"))
	if actor == "dummy": return
	if actor == "boss": actor = "boss_" + str(event.get("target_faction" if target else "actor_faction", "mori"))
	elif not speech_manifest.get("actors",{}).has(actor): actor = "soldier"
	if type == "swing":
		var action := str(event.get("action", ""))
		if actor.begins_with("boss_"):
			var basic := action in ["boss_thrust", "boss_double"] or (actor == "boss_mori" and action in ["boss_sweep","boss_smash"])
			speech_event = "attack" if basic else "special"
		elif actor in ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]:
			if (action == "heavy" and int(event.get("heavy_combo",0)) == 2) or action in ["charged", "charged_upper", "charged_slam", "mixed_finisher", "mixed_rising"]:
				speech_event = "heavy"
			elif action == "light" and int(event.get("combo", 0)) == 3:
				speech_event = "attack"
			else:
				return
	var slot := int(event.get("target_slot" if target else "actor_slot", 0))
	play_character(actor, speech_event, slot, speech_event in ["special", "hurt", "defeat"])

func _synthesize(kind: String, variant: int = 0) -> AudioStreamWAV:
	var duration := 0.10
	variant = posmod(variant, IMPACT_VARIANTS if kind in ["hit", "heavy_hit"] else SFX_VARIANTS)
	if kind == "hit": duration = 0.105 + variant * 0.012
	if kind == "heavy_hit":
		duration = 0.205 + variant * 0.018
	elif kind == "special":
		duration = 0.72
	elif kind == "shield_hit":
		duration = 0.42
	elif kind == "bow_release":
		duration = 0.22
	elif kind == "pickup":
		duration = 0.24
	elif kind == "food_pickup":
		duration = 0.34
	elif kind == "defeat":
		duration = 0.23
	elif kind in ["gunshot", "shatter"]:
		duration = 0.38
	elif kind in ["sword_whoosh","spear_wind","guard"]:
		duration = 0.18 if kind == "sword_whoosh" else 0.25
	elif kind in ["landing","splash","guard_break","prop_break"]:
		duration = 0.32
	elif kind in ["arrow_hit","bullet_hit","blunt_hit"]: duration = 0.24
	elif kind == "needle_hit": duration = 0.12
	elif kind in ["kick_whoosh","needle_whoosh"]: duration = 0.16
	elif kind == "chain_swing": duration = 0.36
	if kind.get_slice("_",0) in ["ceramic","wood","box","stone","wicker"]:
		duration = 0.55 if kind.ends_with("_break") else 0.16
	if kind == "bow_release": duration = 0.34
	if kind not in ["hit", "heavy_hit"]: duration *= [1.0,0.89,1.13][variant]
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 41006 + variant * 7919 + kind.hash()
	var low_noise := 0.0
	for index in range(samples):
		var t := float(index) / SAMPLE_RATE
		var progress := float(index) / samples
		var attack := minf(t / 0.003, 1.0)
		var envelope := attack * pow(1.0 - progress, 2.4)
		var value := 0.0
		var raw := noise.randf_range(-1,1)
		low_noise = lerpf(low_noise,raw,[0.09,0.16,0.23][variant % 3])
		var high_noise := raw - low_noise
		var bite := minf(t / 0.0007,1.0) * exp(-t * [100.0,150.0,75.0][variant % 3])
		var metal := sin(TAU*(1367.0+variant*193.0)*t)*0.47 + sin(TAU*(2213.0+variant*311.0)*t)*0.32 + sin(TAU*(3719.0-variant*127.0)*t)*0.21
		if kind in ["sword_whoosh","spear_wind","kick_whoosh","needle_whoosh"]:
			var rush := pow(sin(progress * PI),[1.3,2.1,1.6][variant])
			var thin: bool = kind == "needle_whoosh"
			value = (low_noise*(1.4 if thin else 2.4)+high_noise*(0.30 if thin else 0.14))*rush*0.78
			if kind == "sword_whoosh": value += metal*exp(-absf(progress-.64)*20.0)*.09
		elif kind == "chain_swing":
			var rush := sin(progress*PI)
			value = (low_noise*1.8+high_noise*.2)*rush*.6
			for tap in range(3):
				var delay: float = .014+tap*(.05+variant*.006)
				if t>=delay: value += metal*exp(-(t-delay)*62.0)*(.17-tap*.025)
		elif kind == "landing":
			value = (sin(TAU*((64+variant*13)*t-37*t*t))*.56+low_noise*(.65+variant*.12))*envelope + high_noise*bite*.16
		elif kind == "splash":
			value = (low_noise*1.6+raw*.24+sin(TAU*((800+variant*180)*t-1700*t*t))*sin(TAU*(38+variant*7)*t)*.1)*attack*pow(1.0-progress,1.3+variant*.2)
		elif kind in ["guard","guard_break"]:
			value = metal*.57*attack*exp(-t*(19.0+variant*4.0)) + high_noise*bite*.55 + low_noise*(1.0 if kind=="guard_break" else .3)*envelope
		elif kind == "prop_break":
			value = (low_noise*1.3+sin(TAU*(164+variant*41)*t)*.27+raw*.4*maxf(0,sin(TAU*(37+variant*11)*t)))*envelope+high_noise*bite*.28
		elif kind.get_slice("_",0) in ["ceramic","wood","box","stone","wicker"]:
			var material := kind.get_slice("_",0)
			var broken := kind.ends_with("_break")
			var tail := attack * exp(-t * (9.0 if broken else 32.0))
			var chips := pow(maxf(0.0,sin(TAU * (33 + variant * 7) * t)),8.0) * tail if broken else bite
			match material:
				"ceramic": value = (sin(TAU*(1810+variant*137)*t)*.27 + sin(TAU*(3147+variant*193)*t)*.17)*tail + high_noise*(chips*.85+bite*.4)
				"box": value = (sin(TAU*(143+variant*19)*t)*.56 + sin(TAU*(319+variant*23)*t)*.28)*tail + raw*(chips*.32+bite*.38)
				"wood": value = sin(TAU*(530+variant*53)*t)*tail*.16 + high_noise*(chips*.65+bite*.7) + low_noise*tail*.45
				"stone": value = sin(TAU*(97+variant*17)*t)*tail*.5 + low_noise*tail*1.2 + raw*chips*.25
				"wicker": value = high_noise*(chips*.6+bite*.2) + sin(TAU*(2140+variant*149)*t)*tail*.07
		elif kind == "hit":
			var edge := float([1250, 1680, 2120, 1460, 2460][variant])
			var body := float([205, 255, 175, 290, 225][variant])
			var cut := noise.randf_range(-1, 1) * (0.44 + variant * 0.035)
			value = (cut + sin(TAU * (body * t - 420 * t * t)) * 0.30 + sin(TAU * edge * t) * exp(-t * 55.0) * 0.18) * envelope
		elif kind == "heavy_hit":
			var body := float([72, 91, 60, 108, 82][variant])
			var edge := float([780, 1130, 1460, 940, 1810][variant])
			var crack := noise.randf_range(-1, 1) * exp(-t * (38.0 + variant * 3.0))
			value = (sin(TAU * (body * t - 85 * t * t)) * 0.62 + low_noise * 0.85 + crack * 0.34 + sin(TAU * edge * t) * exp(-t * 34.0) * 0.14) * envelope
		elif kind == "special":
			value = (sin(TAU*((105+variant*17)*t-45*t*t))*.33+low_noise*1.4+high_noise*.18)*attack*pow(1.0-progress,1.8+variant*.3)
		elif kind == "shield_hit":
			# Pain now comes from the target's Japanese voice; this layer supplies only the impact.
			value = (sin(TAU*((118+variant*26)*t-90*t*t))*.57+low_noise*.9)*envelope+high_noise*bite*.28
		elif kind == "bow_release":
			var string_hz: float = [238.0,287.0,213.0][variant]
			var string_wave := sin(TAU*string_hz*t)*.53 + sin(TAU*string_hz*2.02*t)*.27 + sin(TAU*string_hz*4.07*t)*.13
			var flight := maxf(0,t-(.022+variant*.009))
			value = string_wave*attack*exp(-t*(27.0+variant*6.0)) + raw*bite*.35
			value += (low_noise*1.9+high_noise*.17)*minf(flight/.018,1.0)*exp(-flight*13.0)*pow(1.0-progress,.5)
		elif kind == "gunshot":
			var bang := minf(t/.0004,1.0)
			value = raw*bang*exp(-t*(30.0+variant*6.0))*.85 + sin(TAU*((73+variant*16)*t-45*t*t))*.42*bang*exp(-t*15.0)
			value += low_noise*1.1*bang*exp(-t*9.0)*pow(1.0-progress,1.5) + metal*.09*bite
		elif kind == "shatter":
			var fragments := sin(TAU*(1700+variant*277)*t)*sin(TAU*(13+variant*7)*t)+sin(TAU*(2630-variant*293)*t)*.4
			value = (fragments*.3+raw*.43)*envelope + high_noise*bite*.28
		elif kind == "grab":
			value = (sin(TAU*(120+variant*29)*t)*.43+low_noise*1.1+high_noise*.16)*envelope
		elif kind == "pickup":
			value = metal*attack*exp(-t*(22.0+variant*7.0))*.62 + high_noise*bite*.16
		elif kind == "food_pickup":
			# Three short ascending bell notes distinguish healing from gear and weapon impacts.
			var roots := [659.25, 739.99, 587.33]
			for note in range(3):
				var note_t := t - note * 0.06
				if note_t < 0: continue
				var hz: float = roots[variant] * [1.0, 1.25, 1.5][note]
				var note_envelope := minf(note_t / 0.003, 1.0) * exp(-note_t * 24.0) * pow(1.0 - progress, 0.7)
				value += (sin(TAU * hz * note_t) * 0.46 + sin(TAU * hz * 2.0 * note_t) * 0.13) * note_envelope
		elif kind in ["arrow_hit","bullet_hit","needle_hit","blunt_hit"]:
			var body_hz: float = (185.0 if kind=="arrow_hit" else (92.0 if kind=="bullet_hit" else (330.0 if kind=="needle_hit" else 115.0))) + variant*21.0
			var body := sin(TAU*(body_hz*t-150*t*t))*attack*exp(-t*(27.0+variant*5.0))
			value = body*.52 + low_noise*1.1*envelope + high_noise*bite*(.75 if kind=="bullet_hit" else .38)
			if kind=="arrow_hit": value += sin(TAU*(718+variant*139)*t)*exp(-t*38.0)*attack*.19
			elif kind=="bullet_hit": value += metal*bite*.22
			elif kind=="needle_hit": value += metal*exp(-t*65.0)*attack*.23
		else:
			value = (sin(TAU*((140+variant*22)*t-190*t*t))*.5+raw*.38+low_noise*.55)*envelope
		# Round only the loudest transient peaks instead of flattening their waveform.
		if absf(value) > .6: value = signf(value) * (.6 + .25 * tanh((absf(value)-.6)/.25))
		data.encode_s16(index * 2, int(value * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.stereo = false
	sound.data = data
	assert(sound.data.size() == samples * 2 and sound.mix_rate == SAMPLE_RATE)
	return sound
