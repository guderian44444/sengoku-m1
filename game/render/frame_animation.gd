extends RefCounted

const Battle = preload("res://core/battle.gd")

const POSE_CLIPS := ["idle", "light", "heavy", "charge", "jump", "throw", "hurt", "special", "victory", "walk"]
const CLIPS := {
	"idle": {"sheet": "motion", "start": 0, "count": 4, "duration": 60, "fps": 6, "pingpong": true},
	"walk": {"sheet": "motion", "start": 4, "count": 4, "duration": 30, "fps": 8},
	"hurt": {"sheet": "motion", "start": 8, "count": 4, "duration": 18},
	"heavy": {"sheet": "attacks", "start": 0, "count": 8, "duration": 36, "hit": 14},
	"light": {"sheet": "attacks", "start": 8, "count": 4, "duration": 19, "hit": 6},
	"special": {"sheet": "special", "start": 0, "count": 8, "duration": 56, "hit": 26},
	"charge": {"sheet": "special", "start": 8, "count": 4, "duration": 60, "fps": 6, "pingpong": true},
	"jump": {"sheet": "physical", "start": 0, "count": 4, "duration": 34},
	"throw": {"sheet": "physical", "start": 4, "count": 4, "duration": 24},
	"victory": {"sheet": "physical", "start": 8, "count": 4, "duration": 40, "fps": 6}
}
const DEMO_SECONDS := 2.4
const DEMO_HOLD := 0.35
const DEMO_SPEED := 0.8

static func sample(clip: String, tick: float) -> Dictionary:
	if not CLIPS.has(clip):
		clip = "idle"
	var spec: Dictionary = CLIPS[clip]
	var count := int(spec.count)
	var frame := 0
	var elapsed := maxf(tick, 0.0)
	var hit := int(spec.get("hit", -1))
	if spec.has("fps"):
		var step := floori(elapsed * float(spec.fps) / 60.0)
		if spec.get("pingpong", false):
			var cycle := posmod(step, count * 2 - 2)
			frame = mini(cycle, count * 2 - 2 - cycle)
		else:
			frame = posmod(step, count)
	elif hit > 0:
		var half := count / 2
		if elapsed < hit:
			frame = mini(half - 1, floori(elapsed * half / hit))
		else:
			frame = half + mini(half - 1, floori((elapsed - hit) * half / (int(spec.duration) - hit)))
	else:
		frame = mini(count - 1, floori(elapsed * count / float(spec.duration)))
	return {"clip": clip, "sheet": spec.sheet, "frame": frame, "count": count, "cell": int(spec.start) + frame, "tick": elapsed, "duration": int(spec.duration), "released": hit >= 0 and elapsed >= hit}

static func jump_sample(z: float, vz: float) -> Dictionary:
	var result := sample("jump", 0)
	var frame := 0
	if z > 1.0:
		frame = 1 if vz > 0.0 else 2
		if vz > 6.0:
			frame = 0
		elif vz < -6.0 or (vz < 0.0 and z < 15.0):
			frame = 3
	result.frame = frame
	result.cell = frame
	return result

static func combo_sample(stage: int, tick: float) -> Dictionary:
	var result := sample("light", tick)
	var combo := clampi(stage, 1, 3)
	result["combo_stage"] = combo
	result.sheet = "combo"
	result.cell = (combo - 1) * 4 + int(result.frame)
	return result

static func heavy_chain_sample(stage: int, tick: float, hero: String = "nobunaga") -> Dictionary:
	var result := sample("heavy", tick)
	result["heavy_combo"] = clampi(stage, 1, 2)
	if stage != 2:
		return result
	if hero == "nobunaga":
		result.sheet = "special"
		return result
	var elapsed := maxf(tick, 0.0)
	result.frame = mini(1, floori(elapsed * 2.0 / 14.0)) if elapsed < 14.0 else 2 + mini(1, floori((elapsed - 14.0) * 2.0 / 22.0))
	result.count = 4
	result.sheet = "combo"
	result.cell = (8 if hero == "oichi" else 4) + int(result.frame)
	return result

static func bow_sample(action: String, tick: float, stage: int = 1) -> Dictionary:
	if action == "charge":
		var charge := sample("charge", tick)
		charge.sheet = "attacks"
		# Draw the bow once, then keep the string at the cheek until release.
		charge.frame = mini(3, floori(maxf(tick, 0.0) / 6.0))
		charge.cell = 8 + int(charge.frame)
		return charge
	var result := sample("heavy", tick)
	if action == "charged":
		if tick < 14.0:
			result.sheet = "attacks"
			result.cell = 11
			result.frame = 3
		else:
			result.sheet = "special"
		return result
	var elapsed := maxf(tick, 0.0)
	result.frame = mini(1, floori(elapsed * 2.0 / 14.0)) if elapsed < 14.0 else 2 + mini(1, floori((elapsed - 14.0) * 2.0 / 22.0))
	result.count = 4
	result.cell = (4 if stage == 2 else 0) + int(result.frame)
	result["heavy_combo"] = clampi(stage, 1, 2)
	return result

static func walk_sample(distance: float, stride: float) -> Dictionary:
	var result := sample("walk", 0)
	result.frame = posmod(floori(maxf(distance, 0.0) / maxf(stride, 1.0) * 4.0 + 0.00001), 4)
	result.cell = 4 + int(result.frame)
	result["distance"] = maxf(distance, 0.0)
	return result

static func directional_sample(action: String, tick: float) -> Dictionary:
	var result := combo_sample(2, tick) if action == "rising" else sample("heavy", tick)
	result.clip = action
	result.duration = 24 if action == "rising" else 42
	var count := int(result.count)
	var hit := 6.0 if action == "rising" else 14.0
	var half := count / 2
	result.frame = mini(half - 1, floori(maxf(tick, 0.0) * half / hit)) if tick < hit else half + mini(half - 1, floori((tick - hit) * half / (float(result.duration) - hit)))
	result.cell = (4 if action == "rising" else 0) + int(result.frame)
	result.released = tick >= hit
	return result

static func restraint_sample(action: String, tick: float) -> Dictionary:
	var result := sample("throw" if action == "holding" else "hurt", tick)
	if action == "holding":
		result.frame = 1
		result.cell = 5
	elif action in ["down", "defeated", "dead", "thrown"]:
		result.frame = 3
		result.cell = 11
	else:
		result.frame = 1
		result.cell = 9
	result["restraint"] = action
	return result

static func primary_enemy_action(fighter: Dictionary) -> String:
	var kind := str(fighter.get("kind","soldier"))
	if kind == "archer": return "bow_shot"
	if kind == "gunner": return "gun_shot"
	if kind == "boss":
		var variant: String = fighter.get("boss_variant",Battle.FACTIONS.get(fighter.get("faction","mori"),Battle.FACTIONS.mori).boss)
		return Battle.BOSS_PROFILES.get(variant,Battle.BOSS_PROFILES.kusarigama).actions[0]
	return Battle.ENEMY_ATTACKS.get(kind,Battle.ENEMY_ATTACKS.soldier)[0]

static func primary_enemy_sample(fighter: Dictionary, count: int) -> Dictionary:
	var tick := float(fighter.get("action_tick",0))
	var timing: Array = Battle.enemy_timing(fighter)
	var hit := float(timing[0])
	var duration := float(timing[1])
	var local_tick := tick
	if fighter.action == "boss_double":
		if tick < hit + 9:
			duration = hit + 9
		else:
			local_tick -= hit + 9
			duration -= hit + 9
			hit = 9
	var frame := _attack_frame(local_tick,hit,duration,count)
	if fighter.action in ["boss_chain","boss_hook","boss_grab_throw"] and tick >= hit:
		frame = count / 2 if tick < hit + 12 else (count - 3 if tick < hit + 28 else (count - 2 if tick < hit + 40 else count - 1))
		if count == 12:
			frame = 6 if tick < hit + 12 else (7 if tick < hit + 20 else (8 if tick < hit + 28 else (9 if tick < hit + 40 else (10 if tick < hit + 46 else 11))))
	if local_tick >= duration - 2: frame = count - 1
	return {"clip":fighter.action,"sheet":"enemy_attack","frame":frame,"cell":frame,"count":count,"tick":tick,"duration":timing[1],"released":local_tick >= hit,"source":"v11","hero":fighter.kind}

static func enemy_v14_sample(fighter: Dictionary, locomotion_tick: float, idle_tick: float, clips: Dictionary) -> Dictionary:
	var faction := str(fighter.get("faction","mori"))
	if faction not in ["mori", "imagawa", "oda"]: return {}
	var action := str(fighter.get("action","idle"))
	var clip := action
	var tick := float(fighter.get("action_tick",0))
	var moving: bool = fighter.get("moving",false)
	if action in ["idle","walk","run","move","retreat"]: clip = "walk" if moving else "idle"
	elif action in ["down","dead","defeated","recovering","launched","thrown"]: clip = "death"
	elif action == "grabbed": clip = "struggle"
	elif action in ["hurt","pulled","stunned","frozen","guard"]: clip = "hurt"
	var role := str(fighter.get("kind","soldier"))
	if faction == "imagawa" and fighter.get("stage_boss",false): role = "matsui"
	var key := faction + ":" + role + ":" + clip
	if not clips.has(key): return {}
	var count: int = clips[key].size()
	if count <= 0: return {}
	var source := str(clips[key][0].get("source", "v14"))
	var frame := 0
	var duration := 0.0
	var released := false
	if clip in ["walk","idle","struggle"]:
		tick = locomotion_tick if clip == "walk" else (idle_tick if clip == "idle" else tick)
		var fps := 12.0 if clip == "walk" else 6.0
		# Six v19 key poses keep a natural one-second gait; fewer drawings do not speed up walking.
		if clip == "walk" and source == "v19": fps = float(count)
		frame = posmod(floori(maxf(tick,0) * fps / 60.0),count)
		if action == "retreat" and float(fighter.get("move_dx",-float(fighter.get("face",1)))) * float(fighter.get("face",1)) < 0: frame = posmod(-frame,count)
		duration = count * 60.0 / fps
	elif clip == "death":
		duration = 24.0
		if fighter.get("airborne_lock",false) or action in ["launched","thrown"]: frame = maxi(0,count / 2 - 1)
		elif action == "recovering":
			duration = float(Battle.RECOVER_TICKS)
			frame = count - 1 - mini(count - 1,floori(tick * count / duration))
		elif action == "defeated" and fighter.has("death_ticks"):
			duration = float(fighter.death_ticks)
			if count == 6:
				var poses := [0.0,0.12,0.30,0.64,0.83,1.0]
				for index in range(count):
					if tick >= duration * poses[index]: frame = index
			else: frame = mini(count - 1,floori(tick * (count - 1) / duration))
		elif action in ["down","dead"] or fighter.get("down_from_air",false): frame = count - 1
		else: frame = mini(count - 1,floori(tick * count / duration))
	elif Battle.ENEMY_TIMING.has(action):
		var attack := primary_enemy_sample(fighter,count)
		frame = attack.frame
		duration = attack.duration
		released = attack.released
		if clips[key][0].has("frame_tick"):
			frame = 0
			for index in range(count):
				if tick >= clips[key][index].frame_tick: frame = index
	else:
		duration = 18.0
		frame = mini(count - 1,floori(tick * count / duration))
	return {"clip":clip,"sheet":"enemy_clip:" + key,"frame":frame,"cell":frame,"count":count,"tick":tick,"duration":duration,"released":released,"source":source,"hero":fighter.get("kind","soldier")}

static func enemy_sample(kind: String, action: String, tick: float, distance: float, walking: bool, expanded: bool = false) -> Dictionary:
	var cell := 0
	var frame := 0
	var duration := 60
	var released := false
	var count := 6 if expanded else 4
	if Battle.ENEMY_TIMING.has(action):
		var timing: Array = Battle.ENEMY_TIMING[action]
		var attacks: Array = Battle.ENEMY_ATTACKS.get(kind, [action])
		var row := maxi(0, attacks.find(action)) + 1
		if kind == "boss": row = {"boss_chain":1,"boss_sweep":2,"boss_smash":3,"boss_grab_throw":1}.get(action,row)
		duration = int(timing[1])
		frame = _attack_frame(tick, float(timing[0]), float(duration),count)
		if action in ["bow_shot", "gun_shot"]:
			frame = mini(2,floori(tick * 3.0 / float(timing[0]))) if tick < float(timing[0]) else (3 if tick < float(timing[0]) + (7 if action == "gun_shot" else 15) else 0)
		cell = row * count + frame
		released = tick >= float(timing[0])
		if action in ["boss_chain","boss_grab_throw"] and tick >= 48.0:
			cell = 9 if tick < 54.0 else (10 if tick < 70.0 else 7)
	elif action in ["hurt", "stunned", "grabbed", "pulled", "thrown", "down", "dead", "defeated"]:
		frame = mini(3, floori(tick / 5.0))
		# shortcut: melee reactions retain the walk drawing until dedicated pain/down atlases are approved.
		cell = 12 + frame if kind in ["archer", "gunner"] else 3
	elif walking:
		frame = posmod(floori(distance / 105.0 * count), count)
		cell = frame
	return {"clip": action, "sheet": "enemy", "frame": frame, "cell": cell, "count": count, "tick": tick, "duration": duration, "released": released, "source": "v10" if expanded else "v09", "hero": kind}

static func planted_idle_sample(tick: float) -> Dictionary:
	var phase := posmod(floori(tick / 12.0),10)
	var frame := mini(phase,10 - phase)
	return {"clip":"idle","sheet":"idle","frame":frame,"cell":frame,"count":6,"tick":tick,"duration":120,"released":false}

static func hero_v10_sample(fighter: Dictionary, distance: float = 0.0, height: float = 155.0) -> Dictionary:
	var expanded := str(fighter.get("kind","")) in ["hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
	var action := str(fighter.get("action","idle"))
	var tick := float(fighter.get("action_tick",0))
	var frame := 0
	var row := 0
	var sheet := "reactions"
	var duration := 36
	var released := false
	match action:
		"guard":
			frame = mini(3,floori(tick / 3.0))
			if int(fighter.get("guard_hit_tick",0)) > 0: frame = 4 if int(fighter.guard_hit_tick) > 5 else 5
		"hurt", "grabbed", "pulled":
			row = 1
			duration = 18
			frame = mini(5,floori(tick / 3.0))
		"launched", "thrown":
			row = 2
			var vz := float(fighter.get("vz",0))
			frame = 0 if vz > 7 else (1 if vz > 2 else (2 if vz > -2 else (3 if vz > -6 else (4 if float(fighter.get("z",0)) > 10 else 5))))
		"down", "dead", "defeated":
			row = 3
			duration = 60
			frame = 4 if action != "down" else mini(4,floori(tick / 10.0))
			if expanded and action != "down":
				row = 5
				frame = 0
		"stunned":
			row = 4
			var sway := posmod(floori(tick / 6.0),10)
			frame = mini(sway,10 - sway)
		"recovering":
			row = 5
			frame = mini(5,floori(tick / 6.0))
		"light":
			sheet = "combat"
			row = clampi(int(fighter.get("combo",1)),1,3)
			duration = 19
			frame = _attack_frame(tick,6,19,6)
			released = tick >= 6
		"heavy", "charged", "throw", "holding":
			sheet = "combat"
			row = 5 if action in ["charged", "throw", "holding"] or int(fighter.get("heavy_combo",1)) == 2 else 4
			duration = 36
			frame = 1 if action == "holding" else _attack_frame(tick,14,36,6)
			released = tick >= 14
		"charge":
			sheet = "skills" if int(fighter.get("charge_direction",0)) != 0 else "combat"
			row = (2 if int(fighter.get("charge_direction",0)) < 0 else 3) if sheet == "skills" else 5
			frame = mini(2,floori(tick / 6))
		"rising", "upper_heavy", "low_sweep", "ground_slam", "charged_upper", "charged_slam", "air_light", "air_heavy", "special", "dash_strike", "mixed_finisher", "mixed_rising", "counter_cut":
			sheet = "skills"
			row = {"rising":0,"upper_heavy":0,"low_sweep":1,"ground_slam":1,"charged_upper":2,"charged_slam":3,"air_light":4,"air_heavy":4,"special":5,"dash_strike":0,"mixed_finisher":0,"mixed_rising":0}.get(action,0)
			var timing: Array = {"rising":[6,24],"upper_heavy":[12,36],"low_sweep":[9,28],"ground_slam":[14,42],"charged_upper":[22,56],"charged_slam":[28,72],"air_light":[6,20],"air_heavy":[12,38],"special":[26,210],"dash_strike":[10,30],"mixed_finisher":[9,48],"mixed_rising":[9,48],"counter_cut":[5,24]}[action]
			duration = timing[1]
			frame = _attack_frame(tick,timing[0],duration,6)
			released = tick >= timing[0]
			if action in ["air_light","air_heavy"]: frame = (0 if action == "air_light" else 3) + mini(2,floori(tick * 3 / duration))
			elif action == "special": frame = posmod(floori(maxf(0,tick - 8) / 6),6)
			elif action == "dash_strike":
				sheet = "combat"
				row = 4 if tick < 10 else 1
				frame = mini(1,floori(tick / 5)) if tick < 10 else 3 + mini(2,floori((tick - 10) / 7))
			elif action in ["mixed_finisher","mixed_rising"]:
				sheet = "combat" if tick < 22 else "skills"
				row = 3 if tick < 22 else (0 if action == "mixed_rising" else 3)
				frame = mini(5,floori(fposmod(tick,24) / 4))
		_:
			sheet = "combat"
			row = 4 if fighter.get("sprinting",false) and not expanded else 0
			var stride := height * (1.25 if fighter.get("sprinting",false) else 0.82)
			frame = posmod(floori(maxf(distance,0) / stride * 6.0),6)
	return {"clip":action,"sheet":sheet,"frame":frame,"cell":row * 6 + frame,"count":6,"tick":tick,"duration":duration,"released":released}

static func tadakatsu_v17_sample(fighter: Dictionary, action: String, tick: float, sheets: Dictionary) -> Dictionary:
	var clip: String = {
		"charged":"dash", "dash_heavy":"dash", "dash_strike":"dash", "rising":"upper", "upper_heavy":"upper", "charged_upper":"upper",
		"ground_slam":"charged_slam", "dead":"death", "defeated":"death", "down":"death", "recovering":"recover",
		"stunned":"hurt", "grabbed":"hurt", "pulled":"hurt", "frozen":"hurt", "thrown":"launched"
	}.get(action,action)
	if action == "charge": clip = "slam_charge" if int(fighter.get("charge_direction",0)) > 0 else ("upper" if int(fighter.get("charge_direction",0)) < 0 else "charge_forward")
	if action in ["mixed_finisher","mixed_rising"]:
		if tick < 22: return {}
		clip = "upper" if action == "mixed_rising" else "charged_slam"
	var sheet := "v17_" + clip
	if not sheets.has(sheet): return {}
	var count: int = sheets[sheet].size()
	var frame := 0
	var duration := 0.0
	var released := false
	if action == "charge":
		frame = mini(count / 2 - 1 if clip == "upper" else count - 1,floori(float(fighter.get("charge",0)) / 35.0 * (count / 2 if clip == "upper" else count)))
	elif action == "guard":
		frame = mini(5,floori(tick / 3.0)) if tick < 18 else 6 + posmod(floori((tick - 18) / 5.0),6)
		if int(fighter.get("guard_hit_tick",0)) > 0: frame = 10 if int(fighter.guard_hit_tick) > 5 else 11
	elif action == "holding":
		frame = mini(5,floori(tick / 3.0)) if tick < 18 else 6 + posmod(floori((tick - 18) / 5.0),6)
	elif action == "throw":
		duration = 24
		frame = mini(count - 1,floori(tick * count / duration))
		released = true
	elif clip == "hurt":
		frame = mini(count - 1,floori(tick * count / 18.0))
		if action == "frozen": frame = count / 2
		elif action == "stunned": frame = 6 + posmod(floori(tick / 5.0),6)
	elif clip == "death":
		frame = mini(count - 1,floori(tick * count / 24.0))
		if fighter.get("airborne_lock",false): return {}
		if fighter.get("down_from_air",false): frame = count / 2 + mini(count / 2 - 1,floori(tick * count / 24.0))
	elif clip == "recover":
		frame = mini(count - 1,floori(tick * count / float(Battle.RECOVER_TICKS)))
	elif clip == "launched":
		frame = clampi(floori((9.0 - float(fighter.get("vz",0))) / 18.0 * count),0,count - 1)
	elif action == "special":
		var pulses: Array = Battle.SPECIAL_HIT_TICKS.tadakatsu
		var pulse := 0
		for index in range(1,pulses.size()):
			if tick >= (float(pulses[index - 1]) + float(pulses[index])) * .5: pulse = index
		var hit := float(pulses[pulse])
		var start := 0.0 if pulse == 0 else (float(pulses[pulse - 1]) + hit) * .5
		var finish := float(Battle.SPECIAL_TICKS) if pulse == pulses.size() - 1 else (hit + float(pulses[pulse + 1])) * .5
		frame = _attack_frame(tick - start,hit - start,finish - start,count)
		duration = Battle.SPECIAL_TICKS
		released = tick >= hit
	else:
		var timing: Array = {"charged":[5,36],"dash_heavy":[12,34],"dash_strike":[10,30],"rising":[6,24],"low_sweep":[9,28],"upper_heavy":[12,36],"charged_upper":[22,56],"ground_slam":[14,42],"charged_slam":[28,72],"air_light":[6,20],"air_heavy":[12,38],"mixed_finisher":[5,26],"mixed_rising":[5,26]}.get(action,[])
		if timing.is_empty(): return {}
		var local_tick := tick - 22.0 if action in ["mixed_finisher","mixed_rising"] else tick
		frame = _attack_frame(local_tick,timing[0],timing[1],count)
		duration = 48 if action in ["mixed_finisher","mixed_rising"] else timing[1]
		released = local_tick >= timing[0]
	return {"clip":action,"sheet":sheet,"frame":frame,"cell":frame,"count":count,"tick":tick,"duration":duration,"released":released,"source":"v17","hero":"tadakatsu"}

static func hero_v12_sample(fighter: Dictionary, distance: float, height: float, sheets: Dictionary) -> Dictionary:
	if sheets.has("v22_idle"):
		return hero_v22_sample(fighter,sheets)
	if fighter.get("action","") in ["dead","defeated"] and fighter.get("airborne_lock",false):
		fighter = fighter.duplicate()
		fighter.action = "launched"
	if fighter.get("action","") == "frozen":
		fighter = fighter.duplicate()
		fighter.action = "hurt"
		fighter.action_tick = 6
	var action := str(fighter.get("action", "idle"))
	var clip := action
	if action == "idle":
		clip = "jump" if float(fighter.get("z",0)) > 0 else ("walk" if fighter.get("moving",false) else "idle")
	elif action == "light": clip = "light%d" % clampi(int(fighter.get("combo",1)),1,3)
	elif action == "heavy": clip = "heavy%d" % clampi(int(fighter.get("heavy_combo",1)),1,2)
	elif action in ["charged","charge"] and int(fighter.get("charge_direction",0)) == 0: clip = "heavy2"
	elif action in ["grabbed","pulled"]: clip = "hurt"
	elif action in ["dead","defeated"]: clip = "down"
	elif action == "thrown": clip = "launched"
	elif action == "holding": clip = "throw"
	elif action == "upper_heavy": clip = "charged_upper"
	elif action == "ground_slam": clip = "charged_slam"
	elif action == "dash_strike" and not sheets.has("v12_dash_strike") and not sheets.has("v13_dash_strike"): clip = "light1"
	elif action == "dash_heavy" and fighter.get("kind","") == "nobunaga": clip = "light3" if sheets.has("v13_light3") else "heavy2"
	elif action == "counter_cut": clip = "light2"
	if action == "idle" and fighter.get("sprinting",false) and fighter.get("moving",false) and float(fighter.get("z",0)) <= 0: clip = "run"
	if action == "charge" and int(fighter.get("charge_direction",0)) != 0:
		clip = "charged_upper" if int(fighter.charge_direction) < 0 else "charged_slam"
	if action in ["mixed_finisher","mixed_rising"]:
		clip = ("light2" if fighter.get("kind","") == "oichi" else "light3") if float(fighter.get("action_tick",0)) < 22 else ("charged_upper" if action == "mixed_rising" else "charged_slam")
	var sheet := ("v15_" if sheets.has("v15_" + clip) else ("v14_" if sheets.has("v14_" + clip) else ("v13_" if sheets.has("v13_" + clip) else "v12_"))) + clip
	if not sheets.has(sheet): return {}
	var count: int = sheets[sheet].size()
	var row_counts := []
	row_counts.resize(6)
	row_counts.fill(count)
	# Keep the established hit, charge, jump and special timing; only the drawing source changes.
	var counts := {"combat":row_counts,"skills":row_counts,"reactions":row_counts,"movement":row_counts,"needles":row_counts}
	var sample := hero_v11_sample(fighter,distance,height,counts)
	if clip == "victory" and sheet.begins_with("v15_"):
		sample.frame = mini(count - 1, floori(maxf(0, float(fighter.get("action_tick", 0))) / 10.0))
		sample.tick = float(fighter.get("action_tick", 0))
		sample.duration = Battle.VICTORY_TICKS
		sample.clip = "victory"
	if clip in ["walk","run"] and fighter.get("kind","") in ["nobunaga","oichi"]:
		var active_tick := maxf(0,float(fighter.get("locomotion_tick",0)))
		var fps := 16.0 if clip == "run" else 12.0
		sample.frame = posmod(floori(active_tick * fps / 60.0 + .0001),count)
		sample.tick = active_tick
		sample.duration = count * 60.0 / fps
		sample.clip = clip
	if sheet.begins_with("v13_") and fighter.get("kind","") == "nobunaga" and action == "light":
		sample.frame = clampi(floori(float(fighter.get("action_tick",0))),0,count - 1)
	if action == "dash_heavy":
		var tick := float(fighter.get("action_tick",0))
		sample.frame = _attack_frame(tick,12,34,count)
		sample.duration = 34
		sample.released = tick >= 12
	if action == "throw":
		# Releasing the grab already launches the target; the holder only follows through.
		sample.frame = count / 2 + mini(count / 2 - 1,floori(float(fighter.get("action_tick",0)) * (count / 2) / 24.0))
		sample.duration = 24
		sample.released = true
	if action in ["down","dead","defeated"] and fighter.get("down_from_air",false):
		# Landing continues the prone half; the standing fall was already shown in flight.
		sample.frame = count / 2 + mini(count / 2 - 1,floori(float(fighter.get("action_tick",0)) * count / 24.0))
	if action in ["mixed_finisher","mixed_rising"]:
		var tick := float(fighter.get("action_tick",0))
		sample.frame = _attack_frame(tick,9,22,count) if tick < 22 else _attack_frame(tick - 22,5,26,count)
		sample.released = tick >= (9 if tick < 22 else 27)
	if action == "charged_slam" and fighter.get("kind","") == "oichi":
		# The charged pose stays drawn until both the ice fan and its arrows leave at 28.
		var tick := float(fighter.get("action_tick",0))
		sample.frame = count / 2 - 1 if tick < 28 else _attack_frame(tick,28,72,count)
	sample.merge({"source":sheet.get_slice("_",0),"sheet":sheet,"cell":sample.frame},true)
	if clip == "walk": sample.clip = "walk"
	return sample


static func hero_v22_sample(fighter: Dictionary, sheets: Dictionary) -> Dictionary:
	var action := str(fighter.get("action","idle"))
	var tick := float(fighter.get("action_tick",0))
	var clip := action
	if fighter.get("hp",1) <= 0: clip = "launched" if fighter.get("airborne_lock",false) else "down"
	elif action == "idle": clip = "jump" if float(fighter.get("z",0)) > 0 else (("run" if fighter.get("sprinting",false) else "walk") if fighter.get("moving",false) else "idle")
	elif action == "light": clip = "light%d" % clampi(int(fighter.get("combo",1)),1,3)
	elif action == "heavy": clip = "heavy%d" % clampi(int(fighter.get("heavy_combo",1)),1,2)
	elif action in ["defeated","dead"]: clip = "down"
	elif action == "dash_heavy" and fighter.get("kind","") == "hideyoshi": clip = "heavy1"
	elif action == "charged" and fighter.get("kind","") == "hideyoshi": clip = ["light1","light2","heavy1"][mini(2,floori(tick/22.0))]
	elif action in ["frozen","pulled","grabbed"]: clip = action if fighter.get("kind","") == "hideyoshi" and sheets.has("v22_"+action) else "hurt"
	elif action == "thrown": clip = "launched"
	elif action == "counter_cut": clip = "light2"
	elif action == "upper_heavy": clip = "upper_heavy" if fighter.get("kind","") == "hideyoshi" and sheets.has("v22_upper_heavy") else "charged_upper"
	elif action == "ground_slam": clip = "ground_slam" if fighter.get("kind","") == "hideyoshi" and sheets.has("v22_ground_slam") else "charged_slam"
	elif action == "holding": clip = "holding" if sheets.has("v22_holding") else "throw"
	elif action == "charge":
		clip = "charge_slam" if int(fighter.get("charge_direction",0)) > 0 else ("charge_upper" if int(fighter.get("charge_direction",0)) < 0 else "charge")
		if not sheets.has("v22_"+clip): clip = "charged_slam" if int(fighter.get("charge_direction",0)) > 0 else ("charged_upper" if int(fighter.get("charge_direction",0)) < 0 else "heavy2")
	elif action == "charged" and not sheets.has("v22_charged"): clip = "heavy2"
	if action == "special" and fighter.get("kind","") == "hideyoshi": clip = "special_%d" % mini(3,1+floori(tick/70.0))
	if action in ["mixed_finisher","mixed_rising"] and not sheets.has("v22_"+action):
		clip = ("light2" if fighter.get("kind","") == "oichi" else "light3") if tick < 22 else ("charged_upper" if action == "mixed_rising" else "charged_slam")
	var sheet := "v22_" + clip
	if not sheets.has(sheet): return {}
	var count: int = sheets[sheet].size()
	var frame := 0
	var duration := 0.0
	var released := false
	if clip in ["walk","run"]:
		tick = float(fighter.get("locomotion_tick",0))
		duration = 45.0 if clip == "run" else 60.0
		frame = posmod(floori(tick * count / duration),count)
	elif clip == "idle": frame = posmod(floori(tick / 12.0),count)
	elif clip in ["jump","launched"]: frame = clampi(floori((10.0-float(fighter.get("vz",0))) / 20.0 * count),0,count-1)
	elif clip == "down":
		frame = mini(count-1,floori(tick*count/24.0))
		if fighter.get("down_from_air",false): frame = count/2 + mini(count/2-1,floori(tick*count/24.0))
	elif clip == "recovering": frame = mini(count-1,floori(tick*count/float(Battle.RECOVER_TICKS)))
	elif clip == "hurt": frame = count/2 if action == "frozen" else mini(count-1,floori(tick*count/18.0))
	elif clip == "stunned": frame = posmod(floori(tick/8.0),count)
	elif clip == "victory":
		duration = Battle.VICTORY_TICKS
		frame = mini(count-1,floori(tick*count/duration))
	elif action in ["charge","holding"]: frame = mini(count-1 if fighter.get("kind","") == "hideyoshi" else count/2-1,floori(tick/6.0))
	elif action == "guard": frame = 4 if fighter.get("guard_hit_tick",0)>0 else mini(count-1 if fighter.get("kind","") == "hideyoshi" else 2,floori(tick/4.0))
	elif action == "special" and fighter.get("kind","") == "hideyoshi":
		frame = _attack_frame(fposmod(tick,70),35,70,count)
		duration = Battle.SPECIAL_TICKS
		released = fposmod(tick,70) >= 35
	elif action == "special":
		var pulses: Array = Battle.SPECIAL_HIT_TICKS.get(str(fighter.get("kind","nobunaga")),Battle.SPECIAL_HIT_TICKS.nobunaga)
		var pulse := 0
		for index in range(1,pulses.size()):
			if tick >= (float(pulses[index-1])+float(pulses[index]))*.5: pulse=index
		var hit := float(pulses[pulse])
		var start := 0.0 if pulse == 0 else (float(pulses[pulse-1])+hit)*.5
		var finish := float(Battle.SPECIAL_TICKS) if pulse == pulses.size()-1 else (hit+float(pulses[pulse+1]))*.5
		frame = _attack_frame(tick-start,hit-start,finish-start,count)
		duration = Battle.SPECIAL_TICKS
		released = tick >= hit
	else:
		var timing: Array = {"light":[6,19],"heavy":[14,36],"charged":[14,36],"throw":[0,24],"rising":[6,24],"upper_heavy":[12,36],"low_sweep":[9,28],"ground_slam":[14,42],"charged_upper":[22,56],"charged_slam":[28,72],"air_light":[6,20],"air_heavy":[12,38],"dash_strike":[10,30],"dash_heavy":[12,34],"counter_cut":[5,24],"mixed_finisher":[5,26],"mixed_rising":[5,26]}.get(action,[14,36])
		if fighter.get("kind","") == "hideyoshi":
			if action == "throw": timing = [12,36]
			elif action in ["mixed_finisher","mixed_rising"]: timing = [14,48]
		var local_tick := tick
		if fighter.get("kind","") == "hideyoshi" and action == "charged":
			local_tick = fposmod(tick,22)
			timing = [12,22]
		if action in ["mixed_finisher","mixed_rising"] and fighter.get("kind","") != "hideyoshi":
			if tick < 22: timing = [9,22]
			else: local_tick -= 22
		if action == "charged" and fighter.get("kind","") == "tadakatsu": timing = [5,36]
		frame = _attack_frame(local_tick,timing[0],timing[1],count) if timing[0] > 0 else mini(count-1,floori(local_tick*count/timing[1]))
		duration = timing[1]
		if fighter.get("kind","") == "hideyoshi" and action == "charged": duration = 66
		released = local_tick >= timing[0]
	return {"source":"v22","source_version":sheets[sheet][frame].get("source_version","v22"),"hero":fighter.get("kind",""),"clip":clip,"sheet":sheet,"frame":frame,"cell":frame,"count":count,"tick":tick,"duration":duration,"released":released}

static func hero_v11_sample(fighter: Dictionary, distance: float, height: float, counts: Dictionary) -> Dictionary:
	var sample := hero_v10_sample(fighter, distance, height)
	var action := str(fighter.get("action", "idle"))
	var tick := float(fighter.get("action_tick", 0))
	var sheet := str(sample.sheet)
	var row := int(sample.cell) / 6
	if counts.has("reactions") and action in ["dead","defeated","down"]: row = 3
	if action == "idle":
		sheet = "combat"
		row = 0
		if float(fighter.get("z", 0)) > 0:
			sheet = "skills"
			row = 4
	if counts.has("movement"):
		if action == "idle" and float(fighter.get("z",0)) > 0:
			sheet = "movement"
			row = 2
		elif action == "idle" and (not fighter.get("moving",false) or fighter.get("sprinting",false)):
			sheet = "movement"
			row = 1 if fighter.get("moving",false) else 0
		elif action in ["holding","throw","guard","victory"]:
			sheet = "movement"
			row = {"holding":3,"throw":3,"guard":4,"victory":5}[action]
	if counts.has("needles"):
		if action in ["rising","low_sweep","air_light"]:
			sheet = "needles"
			row = {"rising":0,"low_sweep":1,"air_light":2}[action]
		elif action == "dash_strike":
			sheet = "combat"
			row = 1
	if not counts.has(sheet): return {}
	var count := int(counts[sheet][row])
	var frame := 0
	if action == "idle" and float(fighter.get("z",0)) > 0:
		frame = clampi(floori((10.0 - float(fighter.get("vz",0))) / 20.0 * count),0,count - 1)
	elif action == "idle":
		frame = posmod(floori(distance / (height * (1.25 if fighter.get("sprinting",false) else .82)) * count + .0001),count)
		if sheet == "movement" and row == 0: frame = posmod(floori(tick / 12),count)
	elif action == "victory":
		frame = mini(count - 1,floori(tick / 6))
	elif action in ["dead","defeated","down"]:
		frame = mini(count - 1,floori(tick * count / 24.0))
	elif action == "recovering":
		frame = mini(count - 1,floori(tick * count / 36.0))
	elif action in ["hurt","grabbed","pulled"]:
		frame = mini(count - 1,floori(tick * count / 18.0))
	elif action in ["launched","thrown"]:
		frame = clampi(floori((10.0 - float(fighter.get("vz",0))) / 20.0 * count),0,count - 1)
	elif action == "stunned":
		frame = posmod(floori(tick / 5.0),count)
	elif action == "guard":
		frame = mini(count - 3,floori(tick / 3.0))
		if int(fighter.get("guard_hit_tick",0)) > 0: frame = count - (2 if int(fighter.guard_hit_tick) > 5 else 1)
	elif action in ["charge","holding"]:
		frame = mini(count / 2 - 1,floori(tick / 5.0))
	elif action == "special":
		var pulses: Array = Battle.SPECIAL_HIT_TICKS.get(str(fighter.get("kind","nobunaga")),Battle.SPECIAL_HIT_TICKS.nobunaga)
		var pulse := 0
		# Split the gap between hits into recovery for one strike and windup for the next.
		for index in range(1,pulses.size()):
			if tick >= (float(pulses[index - 1]) + float(pulses[index])) * .5: pulse = index
		var hit := float(pulses[pulse])
		var start := 0.0 if pulse == 0 else (float(pulses[pulse - 1]) + hit) * .5
		var end := float(Battle.SPECIAL_TICKS) if pulse == pulses.size() - 1 else (hit + float(pulses[pulse + 1])) * .5
		var strike := count / 2
		if tick < hit:
			frame = mini(strike - 1,floori(maxf(0,tick - start) * strike / (hit - start)))
		else:
			frame = strike + mini(count - strike - 1,floori((tick - hit) * (count - strike) / (end - hit)))
		sample.released = tick >= hit
		sample.duration = Battle.SPECIAL_TICKS
	else:
		var hit: float = {"light":6,"heavy":14,"charged":14,"throw":12,"rising":6,"upper_heavy":12,"low_sweep":9,"ground_slam":14,"charged_upper":22,"charged_slam":28,"air_light":6,"air_heavy":12,"dash_strike":10,"mixed_finisher":9,"mixed_rising":9,"counter_cut":5}.get(action,14)
		frame = _attack_frame(tick,hit,float(sample.duration),count)
		sample.released = tick >= hit
		if fighter.get("kind","") == "oichi" and action in ["charged","charged_upper","charged_slam"] and tick < hit:
			frame = count / 2 - 1
		# Odd source counts still include the true recovery drawing at the end.
		if tick >= float(sample.duration) - 2: frame = count - 1
	sample.merge({"source":"v11","sheet":"v11_" + sheet,"frame":frame,"cell":row * 8 + frame,"count":count},true)
	return sample

static func enemy_reaction_sample(action: String, tick: float, count: int = 8, airborne: bool = false) -> Dictionary:
	var frame := 0
	if action in ["dead","defeated","down"]:
		frame = mini(count - 1,4 + floori(tick * (count - 4) / 24.0))
		if airborne: frame = 4
	elif action == "recovering":
		frame = maxi(0,count - 1 - floori(tick * count / 36.0))
	elif action in ["launched","thrown"]:
		frame = mini(count - 2,4)
	elif action == "stunned":
		frame = posmod(floori(tick / 7.0),4)
	else:
		frame = mini(3,floori(tick * 4.0 / 18.0))
	return {"clip":action,"sheet":"enemy_reaction","frame":frame,"cell":frame,"count":count,"tick":tick,"duration":24,"released":false,"source":"v11"}

static func technique_sample(action: String, tick: float) -> Dictionary:
	# Each row is a separately drawn technique; charge release has its own low-attack row.
	var rows := {"rising":0, "low_sweep":1, "ground_slam":2, "charged_slam":3, "air_light":0, "air_heavy":1, "upper_heavy":0, "charged_upper":1, "dash_strike":2, "mixed_finisher":3, "mixed_rising":3}
	var row := int(rows.get(action, 2))
	var timing: Array = {"rising":[6,24],"low_sweep":[9,28],"dash_strike":[10,30],"air_light":[6,20],"air_heavy":[12,38],"upper_heavy":[12,36],"charged_upper":[22,56],"mixed_finisher":[9,48],"mixed_rising":[9,48],"ground_slam":[14,42],"charged_slam":[28,72]}.get(action,[14,42])
	var hit := float(timing[0])
	var duration := float(timing[1])
	var frame := _attack_frame(tick, hit, duration)
	if action in ["mixed_finisher", "mixed_rising"]:
		frame = 0 if tick < 9 else (1 if tick < 20 else (2 if tick < 27 else 3))
	var sheet := "air" if action in ["air_light", "air_heavy"] else ("advanced" if action in ["upper_heavy", "charged_upper", "dash_strike", "mixed_finisher", "mixed_rising"] else "techniques")
	var cell := row * 4 + frame
	if action == "mixed_rising":
		sheet = "techniques"
		cell = [4,6,1,2][frame] if tick < 38 else 3
	return {"clip":action,"sheet":sheet,"frame":frame,"cell":cell,"count":4,"tick":tick,"duration":int(duration),"released":tick >= hit}

static func battle_special_sample(tick: float) -> Dictionary:
	var result := sample("special", 0)
	var pulse := 26.0
	for hit in [26.0, 68.0, 110.0, 152.0, 192.0]:
		if tick >= hit - 18.0: pulse = hit
	var local_tick := maxf(0.0, tick - pulse + 18.0)
	result.frame = mini(7, floori(local_tick * 8.0 / 36.0))
	result.cell = int(result.frame)
	result.tick = tick
	result.duration = Battle.SPECIAL_TICKS
	result.released = tick >= 26.0
	return result

static func _attack_frame(tick: float, hit: float, duration: float, count: int = 4) -> int:
	var half := count / 2
	return mini(half - 1, floori(maxf(tick, 0.0) * half / hit)) if tick < hit else half + mini(half - 1, floori((tick - hit) * half / maxf(1, duration - hit)))

static func demo_sample(pose: int, progress: float, clock: float = 0.0) -> Dictionary:
	var clip: String = POSE_CLIPS[clampi(pose, 0, POSE_CLIPS.size() - 1)]
	var seconds := clampf(progress, 0.0, 1.0) * DEMO_SECONDS
	if clip in ["idle", "walk"]:
		return sample(clip, clock * 60.0)
	var tick := (seconds - DEMO_HOLD) * 60.0 * DEMO_SPEED
	if tick < 0.0 or seconds > DEMO_SECONDS - 0.1:
		return sample("idle", clock * 60.0)
	var spec: Dictionary = CLIPS[clip]
	if not spec.has("fps") and tick >= float(spec.duration):
		return sample("idle", clock * 60.0)
	var result := sample(clip, tick)
	if clip == "jump":
		var z := maxf(0.0, 1.0 + 9.0 * tick - 0.275 * tick * tick)
		var jump := jump_sample(z, 9.0 - tick * 0.55)
		result.frame = jump.frame
		result.cell = jump.cell
	return result
