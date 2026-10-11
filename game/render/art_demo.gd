extends RefCounted
const FrameAnimation = preload("res://render/frame_animation.gd")

const POSE_SECONDS := 2.4
const POSES := ["穩定待機／衣物飄動", "刀擊／飛針", "下劈／長弓放箭", "刀勢／長弓蓄力", "跳躍攻擊", "抓住／拋出", "受擊", "烈焰衝擊／貫穿光箭", "勝利收勢", "行走步態"]
const ACTIONS := ["idle", "light", "heavy", "charge", "jump_attack", "throw", "hurt", "special", "victory", "idle"]
var elapsed := 0.0
var running := true
var facing := 1
var weather_override := -1
var speed := 1.0

func step(delta: float) -> void:
	if running: elapsed += delta * speed

func pose() -> int:
	return int(elapsed / POSE_SECONDS) % POSES.size()

func progress() -> float:
	return fmod(elapsed, POSE_SECONDS) / POSE_SECONDS

func weather() -> int:
	return weather_override if weather_override >= 0 else int(elapsed / (POSE_SECONDS * 3.0)) % 3

func seek(index: int) -> void:
	var selected := posmod(index, POSES.size())
	var sample_seconds := [0.2, 0.49, 0.66, 0.4, 0.70, 0.54, 0.48, 0.91, 0.4, 0.5]
	elapsed = selected * POSE_SECONDS + float(sample_seconds[selected])

func world() -> Dictionary:
	var fighters: Array = []
	var index := pose()
	var sample: Dictionary = FrameAnimation.demo_sample(index, progress(), elapsed)
	var jump_tick := float(sample.get("tick", 0))
	var jump_z := maxf(0.0, 1.0 + 9.0 * jump_tick - 0.275 * jump_tick * jump_tick) if sample.clip == "jump" else 0.0
	for slot in range(2):
		var x := 330.0 + slot * 540.0
		if index == 9: x += (progress() - 0.5) * 220.0 * facing
		fighters.append({"id": 1001 + slot, "player_index": slot, "team": 0, "kind": "nobunaga" if slot == 0 else "oichi", "x": x, "y": 585.0, "z": jump_z, "vz": 9.0 - 0.55 * jump_tick if sample.clip == "jump" else 0.0, "face": facing, "hp": 120, "max_hp": 120, "rage": 100, "weapon": 0, "armor": 0, "action": ACTIONS[index], "action_tick": int(sample.get("tick", 0)), "charge": 40 if index == 3 else 0, "poison": 0, "invuln": 0})
		fighters[-1]["moving"] = index == 9
	return {"tick": int(elapsed * 60.0), "phase": "playing", "wave": 1, "fighters": fighters, "drops": [], "effects": [], "events": []}
