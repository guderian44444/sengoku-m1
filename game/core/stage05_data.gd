extends RefCounted

const ROOT := "res://assets/stage5/"
const ROLES := ["hachiya","natsume","kusei","militia","monk","sickle_farmer","hunting_bow_farmer"]
const FARMERS := ["militia","sickle_farmer","hunting_bow_farmer"]
const MUSIC := ["s05_01_outdoor","s05_02_advance","s05_03_temple","s05_04_natsume","s05_kusei_intro","s05_kusei_loop"]
const BACKGROUNDS := ["01_temple_town","02_granary_court","03_sanmon_gallery","04_ginkgo_bell_court","05_lamplit_main_hall"]
const HITS := {
	"s05_hachiya_rapid":[410,590,750], "s05_hachiya_return":[660], "s05_hachiya_sweep":[510],
	"s05_natsume_sweep":[300], "s05_natsume_ground":[300], "s05_natsume_diagonal":[300],
	"s05_kusei_stomp":[650,1550,2450,3350,4250], "s05_kusei_slash":[450,800,1050],
	"s05_kusei_guard":[], "s05_kusei_summon":[1000,1650], "s05_kusei_roar":[450],
	"s05_militia_attack":[260], "s05_monk_quick_attack":[140], "s05_monk_heavy_attack":[300],
	"s05_sickle_farmer_attack":[260], "s05_hunting_bow_farmer_shot":[480]
}
static var _json: Dictionary = {}
static var _actors: Dictionary = {}
const NATSUME_FRAME_MS := {
	"s05_natsume_sweep":[20,60,90,60,35,35,80,160,260,80],
	"s05_natsume_ground":[20,45,45,60,40,30,30,30,80,80,100,120,60],
	"s05_natsume_diagonal":[20,45,45,60,40,30,30,30,80,80,100,120,60]
}

static func read(path: String) -> Variant:
	if not _json.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+path))
		assert(parsed is Dictionary or parsed is Array,"Invalid stage-five data: "+path)
		_json[path] = parsed
	return _json[path]

static func actors() -> Dictionary:
	if _actors.is_empty():
		_actors=read("actors.json").duplicate(true)
		_actors.merge(read("../stage5-farmers/actors.json"))
		# shortcut: Reuse guard poses for the roar; replace when dedicated roar art is available.
		var roar: Dictionary = _actors.kusei.s05_kusei_guard.duplicate(true)
		roar.duration_ms = 1200
		for frame in roar.frames: frame.duration_ms = float(frame.duration_ms) * .5
		_actors.kusei.s05_kusei_roar = roar
		for clip in NATSUME_FRAME_MS:
			var spec: Dictionary=_actors.natsume[clip]
			var old: Array=spec.frames.map(func(f):return float(f.duration_ms))
			var changed: Array=NATSUME_FRAME_MS[clip]
			assert(old.size()==changed.size(),"Natsume retiming retains every source pose")
			for event in spec.events:
				for key in ["time_ms","t_ms","at_ms"]:
					if event.has(key): event[key]=retime(float(event[key]),old,changed)
			spec.duration_ms=0
			for i in changed.size():
				spec.frames[i].duration_ms=changed[i];spec.duration_ms+=changed[i]
	return _actors

static func retime(ms: float, old: Array, changed: Array) -> float:
	var elapsed := 0.0
	for i in old.size():
		if ms<=float(old[i]): return elapsed+ms/float(old[i])*float(changed[i])
		ms-=float(old[i]);elapsed+=float(changed[i])
	return elapsed

static func audio_cues() -> Array:
	var result := ["kusei_stomp_full","kusei_roar"]
	for row in read("audio/event-map.json"): result.append(str(row.event_id))
	for row in read("audio/voice-event-map.json"): result.append(str(row.id))
	return result

static func height(role: String) -> float:
	return 146.0 if role in ["sickle_farmer","hunting_bow_farmer"] else float(read("display.json").height[role])

static func speed(fighter: Dictionary) -> float:
	return 1.5 if fighter.get("s05_elite",false) else 1.0

static func duration(role: String, clip: String) -> float:
	return float(actors()[role][clip].duration_ms)

static func crossed(tick: int, ms: float, multiplier: float = 1.0) -> bool:
	return tick == maxi(1,ceili(ms*.06/multiplier-.000001))

static func timing(fighter: Dictionary) -> Array:
	var hits: Array = HITS.get(fighter.action,[])
	return [ceili(float(hits[0])*.06/speed(fighter)) if not hits.is_empty() else 0,ceili(duration(fighter.s05_role,fighter.action)*.06/speed(fighter))]

static func frame_index(spec: Dictionary, ms: float) -> int:
	if spec.loop: ms = fposmod(ms,float(spec.duration_ms))
	var index := 0
	while index < spec.frames.size()-1 and ms >= float(spec.frames[index].duration_ms)-.000001:
		ms -= float(spec.frames[index].duration_ms)
		index += 1
	return index

static func row(role: String, clip: String, ms: float) -> Dictionary:
	var spec: Dictionary = actors()[role][clip]
	return spec.frames[frame_index(spec,ms)]

static func music(world: Dictionary) -> String:
	if world.phase == "lost": return "silence"
	if world.phase == "won": return "victory_jingle"
	var node := int(world.get("ikki",{}).get("node",1))
	if node == 12: return "s05_kusei_intro"
	if node == 10: return "s05_04_natsume"
	if node >= 6: return "s05_03_temple"
	return "s05_01_outdoor" if node <= 2 else "s05_02_advance"
