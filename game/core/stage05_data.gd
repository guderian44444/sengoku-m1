extends RefCounted

const ROOT := "res://assets/stage5/"
const ROLES := ["hachiya","natsume","kusei","militia","monk"]
const MUSIC := ["s05_01_outdoor","s05_02_advance","s05_03_temple","s05_04_natsume","s05_kusei_intro","s05_kusei_loop"]
const BACKGROUNDS := ["01_temple_town","02_granary_court","03_sanmon_gallery","04_ginkgo_bell_court","05_lamplit_main_hall"]
const HITS := {
	"s05_hachiya_rapid":[410,590,750], "s05_hachiya_return":[660], "s05_hachiya_sweep":[510],
	"s05_natsume_sweep":[740], "s05_natsume_ground":[520], "s05_natsume_diagonal":[520],
	"s05_kusei_stomp":[650,1550,2450,3350,4250], "s05_kusei_slash":[450,800,1050],
	"s05_kusei_guard":[], "s05_kusei_summon":[1000,1650],
	"s05_militia_attack":[260], "s05_monk_quick_attack":[140], "s05_monk_heavy_attack":[300]
}
static var _json: Dictionary = {}

static func read(path: String) -> Variant:
	if not _json.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+path))
		assert(parsed is Dictionary or parsed is Array,"Invalid stage-five data: "+path)
		_json[path] = parsed
	return _json[path]

static func actors() -> Dictionary: return read("actors.json")

static func audio_cues() -> Array:
	var result := ["kusei_stomp_full"]
	for row in read("audio/event-map.json"): result.append(str(row.event_id))
	for row in read("audio/voice-event-map.json"): result.append(str(row.id))
	return result

static func height(role: String) -> float: return float(read("display.json").height[role])

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
