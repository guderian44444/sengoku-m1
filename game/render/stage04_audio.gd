extends Node

const Data = preload("res://core/stage04_data.gd")
const CUES := {
	"wood_guard":"audio/shield/ogg/wood_shield_block_01.ogg",
	"quake":"audio/stone_quake_v1/ogg/ground_quake_thump_01.ogg",
	"stone_hit":"audio/stone_quake_v1/ogg/rock_impact_crumble_01.ogg",
	"stone_release":"audio/weapons/processed/ogg/throw_swing_01.ogg",
	"spin":"audio/weapons/processed/ogg/polearm_sweep_01.ogg",
	"spear_motion":"audio/weapons/processed/ogg/spear_thrust_01.ogg",
	"sword_motion":"audio/weapons/processed/ogg/sword_swing_01.ogg",
	"bow_motion":"audio/weapons/processed/ogg/bow_release_01.ogg",
	"flag_snap":"props/flags/sfx/wood_break_01.ogg",
	"flag_land":"props/flags/sfx/wood_heavy_hit_01.ogg"
}
var voices: Dictionary = {}
var streams: Dictionary = {}
var sounds: Array[AudioStreamPlayer] = []
var crowd: AudioStreamPlayer
var last_crowd := -120
var scene := -1

func _ready() -> void:
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sounds.append(player)
	crowd = AudioStreamPlayer.new()
	crowd.bus = "Voice"
	add_child(crowd)

static func voice_cues() -> Array:
	var result := []
	for row in Data.read("audio/voice_animation_map_v3.json").events:
		if row.clip_id not in result: result.append(row.clip_id)
	return result

func stream(path: String) -> AudioStream:
	if not streams.has(path):
		var audio := AudioStreamOggVorbis.load_from_file(Data.ROOT+path)
		assert(audio != null,"Missing Mikawa audio: "+path)
		audio.loop = false
		streams[path] = audio
	return streams[path]

func play(event: Dictionary) -> void:
	var cue: String = event.cue
	var player: AudioStreamPlayer
	var path := ""
	if event.voice:
		if cue not in voice_cues(): return
		play_voice(int(event.actor),stream("audio/voices/processed/ogg/"+cue+".ogg"))
		return
	else:
		if not CUES.has(cue): return
		player = sounds[int(event.id)%sounds.size()]
		path = CUES[cue]
		if path.ends_with("_01.ogg") and cue not in ["flag_land"]:
			path = path.replace("_01.ogg","_%02d.ogg"%[1+int(event.id)%3])
	player.stream = stream(path)
	player.pitch_scale = 1.0
	player.volume_linear = 1.0 if event.voice else .65
	player.play()

func play_voice(actor: int, audio: AudioStream, defeated: bool = false) -> void:
	if not voices.has(actor):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Voice"
		add_child(voice)
		voices[actor] = voice
	var player: AudioStreamPlayer = voices[actor]
	if player.playing and not defeated: return
	player.set_meta("defeated",defeated)
	player.stream = audio
	player.pitch_scale = 1.0
	player.volume_linear = 1.0
	player.play()

func set_paused(paused: bool) -> void:
	for player in voices.values()+sounds+[crowd]:
		if player != null: player.stream_paused = paused

func sync(world: Dictionary, paused: bool) -> void:
	for id in voices.keys():
		var live: bool = world.get("fighters",[]).any(func(f): return f.id == id and (f.hp > 0 or voices[id].get_meta("defeated",false)))
		if not live: voices[id].queue_free(); voices.erase(id)
	set_paused(paused)
	var current := int(world.get("stage",{}).get("index",-1)) if world.has("mikawa") else -1
	if current != scene: scene = current; last_crowd = int(world.get("tick",0))-120; crowd.stop()
	if current != 4 or world.get("phase","") != "playing" or world.mikawa.phase == "retreat": crowd.stop(); return
	if paused or int(world.tick)-last_crowd < 120 or crowd.playing: return
	var group := "a" if int(world.tick)/120%2 == 0 else "b"
	crowd.stream = stream("audio/crowd/groups/tent_support_group_%s.ogg"%group)
	crowd.volume_linear = .65
	crowd.pitch_scale = 1.0
	crowd.play()
	last_crowd = int(world.tick)
