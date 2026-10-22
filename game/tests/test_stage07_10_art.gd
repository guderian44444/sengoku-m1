extends SceneTree
const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Art = preload("res://render/stage07_10_art.gd")
const Encounter = preload("res://core/stage07_10_encounter.gd")
var checks := 0
var inspected_images := {}
func verify(ok: bool, message: String) -> void:
	checks+=1
	assert(ok,message)

func source_image(path: String) -> Image:
	if not inspected_images.has(path):
		verify(not path.is_absolute_path() and ".." not in path,"Runtime artwork path stays inside its package: "+path)
		verify(FileAccess.file_exists(Art.ROOT+path),"Referenced artwork exists: "+path)
		inspected_images[path]=Image.load_from_file(Art.ROOT+path)
	return inspected_images[path]

func metadata(view) -> void:
	var actors: Dictionary=view._stage0710_art.actors()
	verify(actors.size()==8,"All eight historical officers have artwork metadata")
	var total_frames := 0
	var unique_sources := {}
	var provenance := ""
	for directory in [Art.ROOT,Art.ROOT+"actors/"]:
		for name in DirAccess.get_files_at(directory):
			if not name.ends_with(".json") or not "generation" in name: continue
			var text := FileAccess.get_file_as_string(directory+name)
			verify(JSON.parse_string(text) is Dictionary,"Generation provenance remains readable: "+name)
			verify("prompt" in text,"Generation provenance preserves prompts: "+name)
			provenance+=text
	for role in Art.Data.BOSSES:
		verify(actors.has(role),"Metadata covers "+role)
		verify(role in provenance,"Generation provenance identifies "+role)
		var actor: Dictionary=actors[role]
		verify(actor.frames is Array and not actor.frames.is_empty(),role+" has frame data")
		total_frames+=actor.frames.size()
		var referenced_frames := {}
		for clip in ["idle","walk","attack_a","attack_b","attack_c","hurt","guard","down","recover"]:
			verify(actor.clips.has(clip) and actor.clips[clip] is Array,role+" has "+clip)
			var authored: Array=actor.clips[clip]
			verify(authored.size()==8 if clip in ["walk","attack_a","attack_b","attack_c"] else authored.size()>=2,role+" authored pose count: "+clip)
			var used := {}
			var clip_sources := {}
			for id in authored:
				verify(int(id)>=0 and int(id)<actor.frames.size() and not used.has(int(id)),role+" distinct valid pose index: "+clip)
				used[int(id)]=true
				referenced_frames[int(id)]=true
				var row: Dictionary=actor.frames[int(id)]
				var path := str(row.get("path",actor.path))
				var source_key := path+":"+JSON.stringify(row.region)
				verify(not clip_sources.has(source_key),role+" clip contains distinct source poses: "+clip)
				clip_sources[source_key]=true
				unique_sources[source_key]=true
				var image := source_image(path)
				var bounds := Rect2(row.region[0],row.region[1],row.region[2],row.region[3])
				verify(bounds.size.x>0 and bounds.size.y>0 and Rect2(Vector2.ZERO,image.get_size()).encloses(bounds),role+" pose fits image: "+clip)
				verify(float(row.anchor[0])>=0 and float(row.anchor[0])<=bounds.size.x and float(row.anchor[1])>=0 and float(row.anchor[1])<=bounds.size.y,role+" body anchor stays inside one pose: "+clip)
				var body := float(row.get("body_height",actor.body_height))
				verify(body>0 and bounds.size.x/body<2.3,role+" crop does not combine neighboring full bodies: "+clip)
				verify(bounds.size.y/body<1.8,role+" crop does not combine vertically adjacent bodies: "+clip)
				verify(row.polygon.size()>=3,role+" uses an authored silhouette polygon: "+clip)
				for point in row.polygon:
					verify(float(point[0])>=-.1 and float(point[0])<=bounds.size.x+.1 and float(point[1])>=-.1 and float(point[1])<=bounds.size.y+.1,role+" silhouette remains in crop")
				if clip in ["walk","attack_a","attack_b","attack_c"]:
					verify(path!=str(actor.path),role+" uses expanded motion artwork: "+clip)
					verify(image.detect_alpha()!=Image.ALPHA_NONE and image.get_pixel(0,0).a<.01,role+" motion sheet has real transparent alpha: "+clip)
		verify(referenced_frames.size()==actor.frames.size(),role+" frame table contains only referenced poses")
		for action in Art.Data.BOSSES[role].actions:
			var spec: Dictionary=Art.Data.ACTIONS[action]
			var indices: Array=actor.impact_indices[spec.art_clip]
			verify(indices.size()==spec.hits.size(),action+" maps every actual hit to a visible pose")
			for index in indices: verify(int(index)>=0 and int(index)<8,action+" impact pose is in the eight-cel clip")
	verify(unique_sources.size()==total_frames,"Frame table keeps one entry per unique image region")
	print("STAGE07_10_ART_METADATA_PASS actors=",actors.size()," images=",inspected_images.size()," frames=",total_frames," unique_sources=",unique_sources.size())

func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var view = View.new()
	metadata(view)
	var role_number := 0
	var tested_hits := 0
	for role in Art.Data.BOSSES:
		role_number+=1
		var sim = Battle.new()
		sim.reset_campaign("normal",1,["nobunaga"],int(Art.Data.BOSSES[role].stage))
		var boss: Dictionary = Encounter.spawn(sim,role,700,480)
		boss.entering=false
		sim.state.fighters.append(boss)
		sim.state.tick=1000*role_number
		view.state=sim.state
		view._stage_key=""
		view._update_motion()
		var cells := []
		var last_sample := {}
		for tick in 70:
			sim.state.tick+=1
			boss.x+=3
			view._update_motion()
			last_sample=view._fighter_animation(boss)
			verify(last_sample.clip=="walk",role+" movement chooses walk clip")
			if int(last_sample.cell) not in cells: cells.append(int(last_sample.cell))
		verify(cells.size()==8,role+" walks through all eight authored cels")
		verify(int(view._walk_ticks.get(boss.id,0))>0,role+" walk clock advances")
		var held_cell := int(last_sample.cell)
		var held_region: Rect2=last_sample.frame_data.region
		boss.freeze=12
		for tick in 12:
			sim.state.tick+=1
			view._update_motion()
			var frozen: Dictionary=view._fighter_animation(boss)
			verify(int(frozen.cell)==held_cell and frozen.frame_data.region==held_region,role+" freezes exact sampled pose")
		boss.freeze=0
		var resumed := []
		for tick in 18:
			sim.state.tick+=1
			boss.x+=3
			view._update_motion()
			var sample: Dictionary=view._fighter_animation(boss)
			if int(sample.cell) not in resumed: resumed.append(int(sample.cell))
		verify(resumed.size()>=3,role+" walk resumes after thaw")
		print("REVIEW_WALK_FIXED role=",role," faction=",boss.faction," cells=",cells," freeze_hold=PASS thaw=PASS")
		var actor: Dictionary=view._stage0710_art.actors()[role]
		for action in Art.Data.BOSSES[role].actions:
			var spec: Dictionary=Art.Data.ACTIONS[action]
			for hit in spec.hits.size():
				boss.action=action
				boss.action_tick=int(spec.hits[hit])
				var sampled: Dictionary=view._fighter_animation(boss)
				var impact := int(actor.impact_indices[spec.art_clip][hit])
				var row: Dictionary=actor.frames[int(actor.clips[spec.art_clip][impact])]
				var expected_region := Rect2(row.region[0],row.region[1],row.region[2],row.region[3])
				verify(sampled.clip==spec.art_clip and int(sampled.cell)==impact,action+" hit samples the authored impact pose")
				verify(sampled.frame_data.region==expected_region and sampled.frame_data.texture==view._stage0710_art.texture(Art.ROOT+str(row.get("path",actor.path))),action+" hit samples the exact source image and region")
				verify(sampled.released,action+" sampled release agrees with hit timing")
				tested_hits+=1
	print("STAGE07_10_ART_IMPACTS_PASS bosses=",role_number," actions=",Art.Data.ACTIONS.size()," hits=",tested_hits)
	var sim = Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],10)
	var kagetsune: Dictionary=Encounter.spawn(sim,"kagetsune",700,480)
	sim.state.fighters.append(kagetsune)
	sim.state.tick=10000
	view.state=sim.state
	view._stage_key=""
	view._update_motion()
	for action in ["s10_kagetsune_charge","s10_kagetsune_turn","s10_kagetsune_brace"]:
		var spec: Dictionary=Art.Data.ACTIONS[action]
		kagetsune.action=action
		kagetsune.action_tick=int(spec.hits[0])
		var sampled: Dictionary=view._fighter_animation(kagetsune)
		verify(sampled.clip==spec.art_clip and int(sampled.cell)==5,action+" real renderer samples authored full-thrust cel at damage tick")
		verify(sampled.released,action+" release flag agrees with hit")
		print("REVIEW_HIT_FIXED action=",action," tick=",spec.hits[0]," cel=",sampled.cell)
	var world := {"tick":0,"expedition":{"civilians":[{"safe":false,"walking":false,"x":100.0,"y":390.0},{"safe":false,"walking":false,"x":120.0,"y":480.0},{"safe":false,"walking":false,"x":140.0,"y":570.0}]}}
	var before: Array=Art.civilian_samples(world)
	world.expedition.civilians[0].safe=true
	var after: Array=Art.civilian_samples(world)
	verify(after.size()==2,"Safe civilian is hidden")
	verify(after[0].x==before[1].x and after[0].kind==before[1].kind and after[0].height==before[1].height,"Elder keeps identity after woman leaves")
	verify(after[1].x==before[2].x and after[1].kind==before[2].kind and after[1].height==before[2].height,"Child keeps identity after woman leaves")
	world.expedition.civilians[1].safe=true
	var last: Array=Art.civilian_samples(world)
	verify(last.size()==1 and last[0].kind=="child" and last[0].height==before[2].height,"Child keeps identity after both other civilians leave")
	print("REVIEW_CIVILIANS_FIXED elder=",after[0].kind," child=",after[1].kind," final=",last[0].kind)
	view.free()
	print("STAGE07_10_ART_PASS checks=",checks)
	quit()
