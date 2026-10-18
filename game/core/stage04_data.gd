extends RefCounted

const UDONO_SPEED := 1.1
const ROOT := "res://assets/stage4/"
const MUSIC := ["s04_intro","s04_hot","s04_rescue","s04_boss","s04_victory"]
const SHIELD_ROLES := ["shield_kira","shield_udono"]
const ROLES := ["spear_kira","shield_kira","archer_kira","spear_udono","shield_udono","gunner","tominaga","kira","udono"]
const HITS := {
	"udono_upthrust":[720], "udono_charge":[780], "udono_sweep":[740],
	"udono_groundsmash":[560], "udono_triplequake":[620,1300,1980],
	"udono_melee_spin_counter":[792], "udono_ranged_rock_volley":[800,2000,3200],
	"tominaga_sweep":[420], "tominaga_pursuit":[360], "tominaga_heavy_chop":[780],
	"kira_arrow":[620,760,900], "kira_counter":[240], "kira_command":[900,1100,1300,1500],
	"kira_volley":[]
}
const BACKGROUNDS := ["01_smoke_return_road","02_reed_riverbank","03_bridgehead_rescue","04_riverbank_pursuit","05_camp_clean_background"]
static var _json: Dictionary = {}

static func read(path: String) -> Dictionary:
	if not _json.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+path))
		assert(parsed is Dictionary, "Invalid Mikawa data: " + path)
		_json[path] = parsed
	return _json[path]

static func actors() -> Dictionary:
	return read("actors.json")

static func audio_cues() -> Array:
	var cues := ["wood_guard","quake","stone_hit","stone_release","spin","spear_motion","sword_motion","bow_motion","flag_snap","flag_land"]
	for event in read("audio/voice_animation_map_v3.json").events: cues.append(str(event.clip_id))
	return cues

static func tuning() -> Dictionary:
	return read("settings/udono_combat.json").integration_initial_values_unmeasured

static func crossed(tick: int, milliseconds: float, speed: float = 1.0) -> bool:
	return tick == maxi(1,ceili(milliseconds * 60.0 / 1000.0 / speed - .000001))

static func duration(role: String, clip: String) -> float:
	var result := 0.0
	for frame in actors()[role][clip].frames: result += float(frame.duration_ms)
	return result

static func attack_timing(fighter: Dictionary) -> Array:
	var role: String = fighter.mikawa_role
	var action: String = fighter.action
	if action == "kira_volley": return [54,100]
	if HITS.has(action):
		var speed := UDONO_SPEED if role == "udono" else 1.0
		return [ceili(float(HITS[action][0])*.06/speed),ceili((2500.0 if action == "kira_command" else duration(role,action))*.06/speed)]
	var clip := attack_clip(role,action)
	var data: Dictionary = actors()[role][clip]
	var release := float(data.get("release_ms",510 if clip == "shield_bash" else 280))
	return [ceili(release*.06),ceili(duration(role,clip)*.06)]

static func attack_clip(role: String, action: String) -> String:
	if role == "gunner": return "gun_shot"
	if role.begins_with("shield_"): return "sword_cut" if action == "commander_cut" else "shield_bash"
	return "sweep" if action == "spear_sweep" else "attack"

static func charged(action: String) -> bool:
	return action in ["charged","charge_rain"]

static func music(world: Dictionary) -> String:
	if world.phase == "lost": return "silence"
	if world.phase == "won": return "s04_victory"
	var index := int(world.stage.index)
	if index == 4 and int(world.get("mikawa",{}).get("node",0)) == 13: return "s04_boss"
	if index >= 2: return "s04_rescue"
	if index == 0 and int(world.tick)-int(world.stage.entered_tick) < 1200: return "s04_intro"
	return "s04_hot"
