extends Node
## One controller owns all effect SFX. No voice playback or user-volume changes.
const MAX_PLAYERS := 12
const MAX_PER_INSTANCE := 5
var assets: Dictionary = {}
var root_path := ""
var players: Array[AudioStreamPlayer] = []
var loops: Dictionary = {}
var instances: Dictionary = {}
var paused := false
var voice_duck := false
var serial := 0
var finishing: Dictionary = {}

func configure(asset_root: String) -> bool:
	root_path = asset_root.trim_suffix("/") + "/"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(root_path + "manifest.json"))
	if not parsed is Dictionary: return false
	assets = parsed.get("assets", {})
	return not assets.is_empty()

func handle_cue(instance_id: String, cue_key: String, operation: String, context: Dictionary = {}) -> bool:
	if operation == "finish":
		finish_instance(instance_id)
		return true
	if operation == "stop_all":
		stop_instance(instance_id)
		return true
	if operation == "loop_stop":
		var loop_id := instance_id + ":" + cue_key
		if loops.has(loop_id): _fade_out(loops[loop_id])
		return true
	if operation not in ["start", "loop_start"] or not assets.has(cue_key): return false
	var is_loop := operation == "loop_start"
	if is_loop and not bool(assets[cue_key].get("loop", false)): return false
	var composite := instance_id + ":" + cue_key
	if is_loop and loops.has(composite):
		update_instance(instance_id, float(context.get("intensity", 1.0)), float(context.get("phase_progress", context.get("progress", 0.0))))
		return true
	if not instances.has(instance_id): instances[instance_id] = {"intensity": 1.0, "progress": 0.0}
	update_instance(instance_id, float(context.get("intensity", instances[instance_id].intensity)), float(context.get("phase_progress", context.get("progress", instances[instance_id].progress))))
	instances[instance_id]["distance"] = clampf(float(context.get("distance", instances[instance_id].get("distance", 0.0))), 0.0, 1.0)
	instances[instance_id]["layered"] = bool(context.get("layered", instances[instance_id].get("layered", false)))
	_enforce_cap(instance_id)
	var path := str(assets[cue_key].wav)
	var stream := AudioStreamWAV.load_from_file(path if path.begins_with("res://") else root_path + path)
	if stream == null: return false
	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	serial += 1
	p.set_meta("instance", instance_id)
	p.set_meta("cue", cue_key)
	p.set_meta("loop", is_loop)
	p.set_meta("serial", serial)
	p.set_meta("fade",0.0 if is_loop else 1.0)
	add_child(p)
	players.append(p)
	if is_loop: loops[composite] = p
	_apply_gain(p)
	p.finished.connect(_dispose.bind(p))
	p.play()
	p.stream_paused = paused
	return true

func update_instance(instance_id: String, intensity: float, progress: float) -> void:
	var distance: float = float(instances.get(instance_id, {}).get("distance", 0.0))
	var layered: bool = bool(instances.get(instance_id, {}).get("layered", false))
	instances[instance_id] = {"intensity": clampf(intensity, 0.0, 1.0), "progress": clampf(progress, 0.0, 1.0), "distance": distance, "layered": layered}
	for p in players:
		if str(p.get_meta("instance")) == instance_id: _apply_gain(p)

func _apply_gain(p: AudioStreamPlayer) -> void:
	if p.get_meta("stopping",false):
		p.volume_db = float(p.get_meta("fade_base_db")) + linear_to_db(maxf(.0001,float(p.get_meta("fade"))))
		return
	var state: Dictionary = instances.get(str(p.get_meta("instance")), {"intensity": 1.0, "progress": 0.0})
	var is_loop: bool = bool(p.get_meta("loop"))
	# Quiet startup, increasing charge energy, limited pitch lift for expanding rings.
	var base := -24.0 if is_loop else -18.0
	var grow := lerpf(-8.0, 0.0, float(state.progress)) if is_loop else lerpf(-2.0, 0.0, float(state.progress))
	var cue: String = str(p.get_meta("cue", ""))
	var gun_extra := -3.0 if cue.begins_with("enemy_matchlock") else 0.0
	var distance_gain := -12.0 * float(state.get("distance", 0.0))
	var layer_gain := -6.0 if bool(state.get("layered", false)) else 0.0
	p.volume_db = base + grow + gun_extra + distance_gain + layer_gain + linear_to_db(maxf(0.001, float(state.intensity))) + (-6.0 if voice_duck else 0.0) + linear_to_db(maxf(.0001,float(p.get_meta("fade",1.0))))
	p.pitch_scale = lerpf(0.98, 1.06, float(state.progress))

func set_voice_duck(active: bool) -> void:
	voice_duck = active
	for p in players: _apply_gain(p)

func set_paused(value: bool) -> void:
	paused = value
	for p in players: p.stream_paused = paused

func stop_instance(instance_id: String) -> void:
	for p in players.duplicate():
		if str(p.get_meta("instance")) == instance_id:
			if p.get_meta("loop",false): _fade_out(p)
			else: _dispose(p)
	instances.erase(instance_id)
	finishing.erase(instance_id)

func finish_instance(instance_id: String) -> void:
	finishing[instance_id] = true
	for p in players.duplicate():
		if str(p.get_meta("instance")) == instance_id and bool(p.get_meta("loop")): _fade_out(p)
	_cleanup_finished(instance_id)

func _cleanup_finished(instance_id: String) -> void:
	if not finishing.has(instance_id): return
	for p in players:
		if str(p.get_meta("instance")) == instance_id: return
	instances.erase(instance_id)
	finishing.erase(instance_id)

func stop_all() -> void:
	for p in players.duplicate(): _dispose(p)
	loops.clear()
	instances.clear()
	finishing.clear()

func _fade_out(p: AudioStreamPlayer) -> void:
	if p.get_meta("stopping",false): return
	var key := str(p.get_meta("instance"))+":"+str(p.get_meta("cue"))
	if loops.get(key) == p: loops.erase(key)
	p.set_meta("fade_base_db",p.volume_db-linear_to_db(maxf(.0001,float(p.get_meta("fade",1.0)))))
	p.set_meta("stopping",true)

func _process(delta: float) -> void:
	if paused: return
	for p in players.duplicate():
		if not p.get_meta("loop",false): continue
		var stopping: bool = p.get_meta("stopping",false)
		var fade := move_toward(float(p.get_meta("fade",1.0)),0.0 if stopping else 1.0,delta/.06)
		p.set_meta("fade",fade)
		if stopping and fade <= 0: _dispose(p)
		else: _apply_gain(p)

func _enforce_cap(instance_id: String) -> void:
	var owned: Array[AudioStreamPlayer] = []
	for p in players:
		if str(p.get_meta("instance")) == instance_id: owned.append(p)
	if owned.size() >= MAX_PER_INSTANCE: _dispose(_oldest_prefer_one_shot(owned))
	if players.size() >= MAX_PLAYERS: _dispose(_oldest_prefer_one_shot(players))

func _oldest_prefer_one_shot(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not bool(p.get_meta("loop")): return p
	return pool[0]

func _dispose(p: AudioStreamPlayer) -> void:
	if not is_instance_valid(p) or not players.has(p): return
	players.erase(p)
	var key := str(p.get_meta("instance")) + ":" + str(p.get_meta("cue"))
	if loops.get(key) == p: loops.erase(key)
	p.stop()
	p.queue_free()
	_cleanup_finished(str(p.get_meta("instance")))
