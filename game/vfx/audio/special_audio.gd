extends Node
## Standalone cue player. Copies belong under res://vfx/audio/.
## Runtime sends begin_cast once, then advance_cast on simulation ticks.
## Does not change combat timing, user volume settings or legacy audio maps.
signal voice_duck_requested(active: bool)
var asset_root := "res://vfx/audio/"
var manifest: Dictionary = {}
var casts: Dictionary = {}
var speakers: Array[AudioStreamPlayer] = []
var active_voice_count := 0
var _audio_paused := false
var _seen_casts: Dictionary = {}

func configure(root: String) -> bool:
	asset_root = root.trim_suffix("/") + "/"
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(asset_root + "manifest.json"))
	if not value is Dictionary: return false
	manifest = value
	return true

func begin_cast(cast_id: String, actor: String, allow_legacy_voice := true) -> void:
	if _seen_casts.has(cast_id): return
	if not manifest.get("actors", {}).has(actor): return
	_seen_casts[cast_id] = true
	var spec: Dictionary = manifest.actors[actor]
	casts[cast_id] = {"actor": actor, "tick": -1}
	if allow_legacy_voice: _play(cast_id, str(spec.voice), "Voice", -2.0, true)
	if spec.has("charge"): _play(cast_id, str(spec.charge), "SFX", -7.0)
	advance_cast(cast_id, 0)

func advance_cast(cast_id: String, tick: int) -> void:
	if not casts.has(cast_id): return
	var state: Dictionary = casts[cast_id]
	if tick <= int(state.tick): return
	var spec: Dictionary = manifest.actors[state.actor]
	var hits: Array = spec.get("hit_ticks", [])
	for i in range(hits.size()):
		if int(hits[i]) > int(state.tick) and int(hits[i]) <= tick:
			var cue: String = str(spec.final if i == hits.size() - 1 else spec.release)
			_play(cast_id, cue, "SFX", -4.0)
	state.tick = tick
	if tick >= int(spec.get("duration_ticks", 210)): casts.erase(cast_id)

func cancel_cast(cast_id: String) -> void:
	casts.erase(cast_id)
	for player in speakers.duplicate():
		if is_instance_valid(player) and str(player.get_meta("cast", "")) == cast_id:
			player.stop()
			_finish(player)

func cancel_all() -> void:
	casts.clear()
	_seen_casts.clear()
	for player in speakers.duplicate():
		if is_instance_valid(player):
			player.stop()
			_finish(player)

func _play(cast_id: String, key: String, bus_name: String, gain: float, voice := false) -> void:
	if not manifest.get("assets", {}).has(key): return
	var stream := AudioStreamWAV.load_from_file(asset_root + str(manifest.assets[key].wav))
	if stream == null: return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else "Master"
	player.volume_db = gain
	player.set_meta("cast", cast_id)
	player.set_meta("voice", voice)
	add_child(player)
	speakers.append(player)
	if voice:
		active_voice_count += 1
		if active_voice_count == 1: voice_duck_requested.emit(true)
	player.finished.connect(_finish.bind(player))
	player.play()
	player.stream_paused = _audio_paused

func _finish(player: AudioStreamPlayer) -> void:
	if not speakers.has(player): return
	speakers.erase(player)
	if bool(player.get_meta("voice", false)):
		active_voice_count = maxi(0, active_voice_count - 1)
		if active_voice_count == 0: voice_duck_requested.emit(false)
	player.queue_free()

func set_audio_paused(paused: bool) -> void:
	_audio_paused = paused
	for player in speakers:
		if is_instance_valid(player): player.stream_paused = paused

## New authored voice slots stay silent when missing. Does not trigger legacy cues.
func play_authored_voice(cast_id: String, slot: Dictionary) -> bool:
	var key: Variant = slot.get("new_asset")
	if key == null or str(key).is_empty(): return false
	if not manifest.get("assets", {}).has(str(key)): return false
	_play(cast_id, str(key), "Voice", -2.0, true)
	return true
