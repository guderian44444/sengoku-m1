extends SceneTree
const Battle = preload("res://core/battle.gd")
const Data = preload("res://core/stage05_data.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Art = preload("res://render/stage05_art.gd")
const View = preload("res://render/battle_view.gd")

func _initialize() -> void:
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],5)
	var art := Art.new();art.profiling=true
	var peak := 0
	for section in 5:
		for checkpoint in sim._campaign.segments[section].encounters.size():
			sim._enter_segment(section);sim._start_checkpoint(checkpoint)
			art.prepare_scene(sim.state)
			var misses: int=art.metrics.misses
			var roles := ["militia","monk","sickle_farmer","hunting_bow_farmer"]
			for f in sim.state.fighters:
				if f.has("s05_role") and f.s05_role not in roles: roles.append(f.s05_role)
			for role in roles:
				for spec in Data.actors()[role].values():
					for row in spec.frames:
						for part in [row]+row.get("layers_before",[])+row.get("layers_after",[]):
							var drawing := art.frame(part)
							var entry: Dictionary=art.atlas_manifest().entries[part.path]
							assert(drawing.anchor+Vector2(entry.crop[0],entry.crop[1])==Vector2(part.anchor[0],part.anchor[1]),"Cropping preserves the original anatomical anchor")
							assert(drawing.body_height==part.body_height and drawing.source_size==Vector2(entry.crop[2],entry.crop[3]),"World size uses source pixels, never the reduced atlas rectangle")
			assert(art.metrics.misses==misses and art.metrics.evictions==0,"Every body/FX pose stays resident for a whole encounter")
			peak=maxi(peak,art.cached_bytes)
	var view := View.new();view.state=sim.state
	view._stage05_art=art
	var hero: Dictionary=sim.state.fighters[0]
	for cycle in 100:
		var f := S5.spawn(sim,"monk",500,480)
		sim.state.fighters=[hero,f];sim.state.tick+=1
		view._update_motion();view._fighter_animation(f)
		assert(view._frozen_samples.size()==1)
		sim.state.fighters=[hero];sim.state.tick+=1;view._update_motion()
		assert(view._frozen_samples.is_empty(),"Removed reinforcements release their texture references")
	view.free()
	print("STAGE05_STREAMING_PASS 12 encounters; all source poses; zero draw-time misses/evictions; 100 retired actors; peak bytes=",peak)
	quit()
