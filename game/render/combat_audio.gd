extends Node

const SAMPLE_RATE := 22050
const VOICE_COUNT := 6
const IMPACT_VARIANTS := 5
const SFX_VARIANTS := 3
const EVENT_SOUNDS := {
	"hit": "hit", "heavy_hit": "heavy_hit", "special": "special",
	"pickup": "pickup", "defeat": "defeat", "shield_hit": "shield_hit", "grab": "grab", "bow_release": "bow_release",
	"gunshot": "gunshot", "shatter": "shatter", "sword_whoosh":"sword_whoosh", "spear_wind":"spear_wind",
	"landing":"landing", "splash":"splash", "guard":"guard", "guard_break":"guard_break", "prop_break":"prop_break",
	"arrow_hit":"arrow_hit", "bullet_hit":"bullet_hit", "needle_hit":"needle_hit", "blunt_hit":"blunt_hit",
	"kick_whoosh":"kick_whoosh", "needle_whoosh":"needle_whoosh", "chain_swing":"chain_swing"
}

var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _impact_sounds: Dictionary = {}
var _sound_variants: Dictionary = {}
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
var last_spoken := ""
var _intro_token := ""

func _ready() -> void:
	_rng.randomize()
	for kind in EVENT_SOUNDS:
		_sound_variants[kind] = []
		for variant in range(IMPACT_VARIANTS if kind in ["hit", "heavy_hit"] else SFX_VARIANTS):
			_sound_variants[kind].append(_synthesize(kind, variant))
		_sounds[kind] = _sound_variants[kind][0]
		if kind in ["hit", "heavy_hit"]: _impact_sounds[kind] = _sound_variants[kind]
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.volume_db = -17.0
		add_child(player)
		_voices.append(player)
	assert(_sounds.size() == EVENT_SOUNDS.size() and _voices.size() == VOICE_COUNT)
	var voice_root := "res://audio/v15/" if FileAccess.file_exists("res://audio/v15/manifest.json") else ("res://audio/v14/" if FileAccess.file_exists("res://audio/v14/manifest.json") else ("res://audio/v11/" if FileAccess.file_exists("res://audio/v11/manifest.json") else "res://audio/v10/"))
	var manifest_path := voice_root + "manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: speech_manifest = parsed
	for key in speech_manifest.get("clips", {}):
		var clip: Dictionary = speech_manifest.clips[key]
		var stream := AudioStreamWAV.load_from_file(voice_root + str(clip.file))
		if stream != null: _speech_streams[key] = stream
	for channel in ["hero0", "hero1", "enemy", "boss"]:
		var speaker := AudioStreamPlayer.new()
		speaker.volume_db = -5.0 if channel.begins_with("hero") else -9.0
		add_child(speaker)
		_speech_players[channel] = speaker
	_intro_player = AudioStreamPlayer.new()
	_intro_player.volume_db = -3.0
	add_child(_intro_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -19.0
	add_child(_music_player)
	var music := AudioStreamWAV.load_from_file("res://audio/v14/sengoku-battle-loop.wav") if FileAccess.file_exists("res://audio/v14/sengoku-battle-loop.wav") else null
	if music != null:
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		music.loop_end = music.data.size() / (4 if music.stereo else 2)
		_music_player.stream = music

func play_music() -> void:
	if _music_player == null or _music_player.stream == null: return
	if not _music_player.playing: _music_player.play()
	_music_player.stream_paused = false

func stop_music() -> void:
	if _music_player != null: _music_player.stop()

func set_music_paused(paused: bool) -> void:
	if _music_player != null: _music_player.stream_paused = paused

func play_event(event: Dictionary) -> void:
	_play_character_event(event)
	var kind := sound_for_event(event)
	if not _sound_variants.has(kind) or _voices.is_empty():
		return
	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	last_sound = kind
	last_sound_variant = _choose_variant("sfx:" + kind, _sound_variants[kind].size())
	player.stream = _sound_variants[kind][last_sound_variant]
	if _impact_sounds.has(kind): last_impact_variant = last_sound_variant
	player.volume_db = -13.0 if kind in ["heavy_hit", "bullet_hit", "gunshot"] else -17.0
	player.play()

static func sound_for_event(event: Dictionary) -> String:
	var kind := str(event.get("type", event.get("kind", "")))
	var weapon := str(event.get("weapon", ""))
	if kind == "swing": return "" # Voice onset; wind belongs to the actual weapon release.
	if kind == "weapon_swing":
		return {"needle":"needle_whoosh", "spear":"spear_wind", "blunt":"spear_wind", "kick":"kick_whoosh", "chain":"chain_swing"}.get(weapon,"sword_whoosh")
	if kind in ["hit", "heavy_hit", "shield_hit"]:
		return {"arrow":"arrow_hit", "special_arrow":"arrow_hit", "bullet":"bullet_hit", "needle":"needle_hit", "blunt":"blunt_hit", "kick":"blunt_hit"}.get(weapon,kind)
	if kind == "run_bump": return "blunt_hit"
	if kind == "landing" and event.get("wet",false): return "splash"
	return kind

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
	player.pitch_scale = 0.88 if actor == "tadakatsu" else 1.0
	player.play()

func _play_character_event(event: Dictionary) -> void:
	var type := str(event.get("type", ""))
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
