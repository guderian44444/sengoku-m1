extends SceneTree

const Art = preload("res://render/art_assets.gd")
const FrameAnimation = preload("res://render/frame_animation.gd")
const Sources = preload("res://render/layered_hero_source.gd")
const HUD = preload("res://render/combat_hud.gd")
const WeaponRenderer = preload("res://render/weapon_renderer.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const CLIPS := ["idle","walk","run","light1","light2","light3","heavy1","heavy2","charged_upper","charged_slam","air_heavy","air_light","rising","low_sweep","dash_heavy","dash_strike","jump","hurt","down","recovering","launched","stunned","guard","throw","special","victory"]
const ROOT := "res://assets/v27/oichi/"
const PRODUCTION_ID := "oichi-original-approved-20261013"
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	check(FileAccess.file_exists(ROOT + "registration.json"),"Complete accepted v27 registration required")
	if failures:
		quit(1)
		return
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "registration.json"))
	check(registration.version == "v27" and registration.clips.size() == 26,"26 new authored v27 motions")
	check(registration.get("production_id") == PRODUCTION_ID,"Original-approved production identity is explicit")
	check(registration.get("provenance") is Dictionary and not registration.get("provenance",{}).is_empty(),"Final grading provenance is recorded")
	if failures:
		quit(1)
		return
	check(Sources.folder("oichi") == ROOT,"Only Oichi selects the new v27 asset folder")
	check(Sources.folder("nobunaga") == "res://assets/v22/nobunaga/","Nobunaga source unchanged")
	check(Sources.folder("tadakatsu") == "res://assets/v22/tadakatsu/","Tadakatsu source unchanged")
	check(str(HUD.portrait_spec("oichi").file).begins_with(ROOT),"HUD portrait uses the accepted new source")
	var art := Art.new()
	var weapons := WeaponRenderer.new()
	var sheets: Dictionary = art.animations.oichi
	var sources := {}
	var drawn_poses := {}
	var count := 0
	for clip in CLIPS:
		var key: String = "v22_" + str(clip)
		check(sheets.has(key) and sheets[key].size() == 6,clip + " retains the six-frame runtime contract")
		var clip_hashes := {}
		for index in range(6):
			count += 1
			var frame: Dictionary = sheets[key][index]
			var spec: Dictionary = registration.clips[clip].frames[index]
			check(frame.source_version == "v27" and str(frame.source_file).begins_with(ROOT),clip + " never falls back to old artwork")
			check(frame.body_height == float(spec.body_height),clip + " uses authored anatomical ruler")
			check(frame.weapon_hand == Vector2(spec.hand[0]-spec.foot[0],spec.hand[1]-spec.foot[1]),clip + " preserves measured grip offset")
			if not sources.has(frame.source_file):
				check(FileAccess.get_sha256(frame.source_file) == spec.source_sha256,clip + " final source PNG hash matches registration")
				sources[frame.source_file] = Image.load_from_file(frame.source_file)
			var source: Image = sources[frame.source_file]
			var texture_image: Image = frame.texture.get_image()
			var actual: Image = texture_image.get_region(Rect2i(2,2,frame.source_rect.size.x,frame.source_rect.size.y))
			check(actual.get_data() == source.get_region(frame.source_rect).get_data(),clip + " crop preserves final registered RGBA bytes")
			var hasher := HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(actual.get_data())
			var digest := hasher.finish().hex_encode()
			check(digest == str(spec.rgba_sha256),clip + " runtime crop hash matches registration")
			clip_hashes[digest] = true
			if not drawn_poses.has(digest): drawn_poses[digest] = []
			drawn_poses[digest].append(clip + "/" + str(index+1))
			check(frame.region.encloses(Rect2(frame.anchor,Vector2.ONE)),clip + " support stays within texture")
			for face in [-1,1]:
				var actor := {"kind":"oichi","weapon_id":Weapons.default_for("oichi"),"face":face}
				var pose: Dictionary = weapons.geometry(actor,frame,148)
				check(not pose.is_empty() if frame.weapon_visible else pose.is_empty(),clip + " resolves selected bow for both facings")
		check(clip_hashes.size() == 6,clip + " has six distinct drawn frames")
	check(count == 156 and registration.get("registered_frame_count") == count,"All 156 registered frames reached")
	check(drawn_poses.size() == 155 and registration.get("unique_drawn_pose_count") == drawn_poses.size(),"Actual crop hashes confirm 155 unique poses")
	var shared: Array = registration.get("shared_drawn_poses",[])
	check(shared.size() == 1,"Exactly one intentional shared transition boundary")
	var down_spec: Dictionary = registration.clips.down.frames[5]
	var recovery_spec: Dictionary = registration.clips.recovering.frames[0]
	if shared.size() == 1:
		var expected_frames := ["down/6","recovering/1"]
		check(shared[0].get("frames") == expected_frames and drawn_poses.get(str(shared[0].get("rgba_sha256"))) == expected_frames,"Recorded shared group matches actual down/recovery crop hashes")
		check(shared[0].get("source_file") == down_spec.file and down_spec.file == recovery_spec.file,"Shared group names its actual source without a fixed filename")
		check(shared[0].get("rgba_sha256") == down_spec.rgba_sha256 and down_spec.rgba_sha256 == recovery_spec.rgba_sha256,"Shared group records identical registered pixels")
	var down_end: Dictionary=sheets.v22_down[5]
	var recovery_start: Dictionary=sheets.v22_recovering[0]
	check(down_end.source_file==recovery_start.source_file and down_end.source_rect==recovery_start.source_rect,"Recovery starts from the exact accepted final down drawing")
	check(down_end.anchor==recovery_start.anchor and down_end.body_height==recovery_start.body_height and down_end.weapon_hand==recovery_start.weapon_hand and down_end.weapon_angle==recovery_start.weapon_angle,"Shared prone boundary preserves world root, anatomical size and back-bow pose")
	for field in ["weapon_behind","weapon_visible","second_hand","hand_occluders","clip_polygon"]:
		check(down_spec.get(field) == recovery_spec.get(field),"Shared prone boundary preserves " + field)
	for alias in registration.aliases:
		check(sheets["v22_"+str(alias)][0].texture == sheets["v22_"+str(registration.aliases[alias])][0].texture,"Alias keeps its intended pose: " + alias)
	var cases := {"idle":"idle","charged":"charged","charge":"charge","guard":"guard","holding":"holding","grab":"grab","throw":"throw","hurt":"hurt","down":"down","dead":"down","defeated":"down","recovering":"recovering","launched":"launched","thrown":"launched","stunned":"stunned","frozen":"hurt","pulled":"hurt","grabbed":"hurt","rising":"rising","low_sweep":"low_sweep","air_light":"air_light","air_heavy":"air_heavy","dash_strike":"dash_strike","dash_heavy":"dash_heavy","charged_upper":"charged_upper","charged_slam":"charged_slam","upper_heavy":"charged_upper","ground_slam":"charged_slam","counter_cut":"light2","special":"special","victory":"victory"}
	for action in cases:
		var sample := FrameAnimation.hero_v22_sample({"kind":"oichi","action":action,"action_tick":12},sheets)
		check(sample.get("source_version") == "v27" and sample.get("clip") == cases[action],"Gameplay state routes to new source: " + action)
	for combo in [1,2,3]:
		var sample := FrameAnimation.hero_v22_sample({"kind":"oichi","action":"light","combo":combo,"action_tick":8},sheets)
		check(sample.clip == "light%d" % combo and sample.source_version == "v27","Three distinct light-combo actions retained")
	for combo in [1,2]:
		var sample := FrameAnimation.hero_v22_sample({"kind":"oichi","action":"heavy","heavy_combo":combo,"action_tick":15},sheets)
		check(sample.clip == "heavy%d" % combo and sample.source_version == "v27","Both archery-heavy actions retained")
	for moving in [false,true]:
		for sprinting in [false,true]:
			var sample := FrameAnimation.hero_v22_sample({"kind":"oichi","action":"idle","moving":moving,"sprinting":sprinting,"locomotion_tick":20},sheets)
			check(sample.clip == (("run" if sprinting else "walk") if moving else "idle") and sample.source_version == "v27","Locomotion routing retained")
	print("OICHI LAYERS V27 %s: %d checks, %d failures; %s / 26 clips / 156 registered frames / 155 unique poses" % ["PASS" if failures == 0 else "FAILED",checks,failures,PRODUCTION_ID])
	quit(1 if failures else 0)
