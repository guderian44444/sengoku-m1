extends SceneTree
const Art = preload("res://render/art_assets.gd")
const Frames = preload("res://render/frame_animation.gd")
const Battle = preload("res://core/battle.gd")
const ATTACKS := {
	"soldier":["spear_thrust","spear_sweep","spear_butt"],
	"flag":["flag_poke","flag_sweep","flag_slam"],
	"commander":["commander_cut","commander_rise","commander_dash"],
	"archer":["bow_shot"],"gunner":["gun_shot"],
	"boss":["boss_sweep","boss_thrust","boss_counter","boss_dash"],
	"matsui":["boss_sweep","boss_thrust","boss_counter","boss_earth"]}
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	assert(ok,label)

func _initialize() -> void:
	var art := Art.new()
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v19/enemies/registration.json"))
	check(registration.missing.is_empty(),"Every runtime Imagawa move must have a formal sprite clip")
	for role in ATTACKS:
		var all_clips: Array = ["idle","walk","hurt","struggle","death"]+ATTACKS[role]
		for clip in all_clips:
			var key: String = "imagawa:"+role+":"+clip
			check(art.enemy_clips.has(key),key+" is registered")
			var frames: Array = art.enemy_clips[key]
			var expected: int = 1 if clip=="idle" else (3 if clip in ["hurt","struggle"] else 6)
			if role == "soldier" and clip == "walk": expected = 12
			check(frames.size()==expected,key+" genuine source count")
			var regions := []
			for frame in frames:
				check(frame.source=="v19",key+" cannot silently use old low-resolution fallback")
				check(frame.body_height >= (201.5 if role=="matsui" else 146.0),key+" native anatomical pixels cover runtime body height")
				check(frame.has("clip_polygon") and frame.has("frame_padding"),key+" isolated alpha contour and texture padding")
				check(frame.frame_padding==Vector2(2,2),key+" two transparent filter guard pixels")
				var signature := str(frame.source_region)
				check(not regions.has(signature),key+" no repeated source rectangle posing as extra drawings")
				regions.append(signature)
				check(is_equal_approx(frame.body_height,frames[0].body_height),key+" crouch/death never enlarge to bbox height")
		var fighter := {"kind":"boss" if role=="matsui" else role,"stage_boss":role=="matsui","faction":"imagawa","action":"idle","action_tick":0,"moving":false,"face":1}
		for action in ["idle","walk","run","retreat","hurt","frozen","stunned","guard","grabbed","down","dead","defeated","launched","thrown","recovering"]+ATTACKS[role]:
			fighter.action=action
			fighter.moving=action in ["walk","run","retreat"]
			for tick in [0,10,30,59,90]:
				fighter.action_tick=tick
				var sample := Frames.enemy_v14_sample(fighter,tick,tick,art.enemy_clips)
				check(not sample.is_empty() and sample.source=="v19",role+"/"+action+" resolves v19 on every state phase")
		for ranged in ["bow_shot","gun_shot"]:
			if ranged not in ATTACKS[role]: continue
			for frame in art.enemy_clips["imagawa:"+role+":"+ranged]:
				check(frame.has("hand_offset"),role+" release origin follows source weapon")
		var death: Array = art.enemy_clips["imagawa:"+role+":death"]
		check(death[-1].source_region.size.x>death[-1].source_region.size.y*1.8,role+" final corpse is horizontally prone")
	print("PASS: ",checks," formal Imagawa asset and state-coverage checks")
	quit()
