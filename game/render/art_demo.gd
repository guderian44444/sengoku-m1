extends RefCounted
const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const Weapons = preload("res://core/weapon_catalog.gd")

const POSE_SECONDS := 2.4
const POSES := ["待機", "輕手一", "輕手二", "輕手三", "普通重手", "集氣", "滿蓄施放", "空中輕手", "空中重手", "抓取", "抓中第一擊", "抓中第二擊", "正向摔", "反向摔", "跑步重手", "行走", "受傷", "勝利"]
const ACTIONS := ["idle","light","light","light","heavy","charge","charged","air_light","air_heavy","grab_start","grab_hit_1","grab_hit_2","throw","throw","dash_heavy","idle","hurt","victory"]
var elapsed := 0.0
var running := true
var facing := 1
var weather_override := -1
var speed := 1.0

func step(delta: float) -> void:
	if running: elapsed += delta * speed

func pose() -> int: return int(elapsed / POSE_SECONDS) % POSES.size()
func progress() -> float: return fmod(elapsed, POSE_SECONDS) / POSE_SECONDS
func weather() -> int: return weather_override if weather_override >= 0 else int(elapsed / (POSE_SECONDS * 3.0)) % 3
func seek(index: int) -> void: elapsed = posmod(index,POSES.size()) * POSE_SECONDS + POSE_SECONDS * .5

func world() -> Dictionary:
	var fighters: Array = []
	var index := pose()
	for slot in range(2):
		var hero := "nobunaga" if slot == 0 else "oichi"
		var fighter := {"id":1001+slot,"player_index":slot,"team":0,"kind":hero,"x":330.0+slot*540.0,"y":585.0,"z":50.0 if index in [7,8] else 0.0,"vz":0.0,"face":facing,"hp":120,"max_hp":120,"rage":0,"weapon":0,"weapon_id":Weapons.default_for(hero),"armor":0,"action":ACTIONS[index],"action_tick":0,"charge":0,"combo":index if index in [1,2,3] else 1,"throw_clip":"throw_reverse" if index==13 else "throw_forward","poison":0,"invuln":0,"moving":index==15}
		var spec := Moves.spec(fighter)
		fighter.action_tick = int(progress()*float(spec.get("duration_ms",1000))*.06)
		if fighter.action == "light": fighter.action_tick = int(progress()*roundi(Battle.fighter_tick(fighter,19)*Battle.LIGHT_TIME_SCALE))
		if hero == "oichi" and fighter.action == "air_heavy": fighter.action_tick = int(progress()*Battle.fighter_tick(fighter,27))
		if hero == "oichi" and fighter.action == "heavy": fighter.action_tick = progress()*float(spec.duration_ms)*.06/Battle.OICHI_HEAVY_SPEED
		if fighter.action == "throw": fighter.action_tick = int(progress()*float(spec.duration_ms)*.06*Battle.THROW_TIME_SCALE)
		if index == 5: fighter.charge = fighter.action_tick
		fighters.append(fighter)
	return {"tick":int(elapsed*60),"phase":"playing","wave":1,"fighters":fighters,"drops":[],"effects":[],"events":[]}
