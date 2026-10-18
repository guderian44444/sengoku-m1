extends SceneTree
const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const FX = preload("res://render/officer_weapon_fx.gd")
var checks := 0
var view: View
var captures := []

func check(ok: bool, label: String) -> void:
	checks+=1
	assert(ok,label)

func fixture(move: Dictionary) -> Dictionary:
	var sim := Battle.new()
	var stage := int(move.actor_appearances[0].stage)
	sim.reset_campaign("normal",1,["nobunaga"],stage)
	var id: String = move.id
	var f: Dictionary = sim._make_fighter(1,"commander" if id.contains("commander") else "boss",640,510,1000)
	f.faction = "imagawa"
	if id.begins_with("stage4-"):
		f.mikawa_role = id.trim_prefix("stage4-").split("_")[0]
		f.action = id.trim_prefix("stage4-")
	elif id.begins_with("stage3-"):
		var role: String = id.split("-")[1]
		f.faction="imagawa";f.encounter_epoch=sim.state.encounter.epoch
		if role=="yoshimoto": f.is_yoshimoto=true
		else: f.lieutenant_slot=1 if role=="ii_naomori" else 2
		f.action={"bow_shot":"boss_arrow","sword_energy":"boss_sword_wave","thrust":"boss_thrust"}.get(id.split("-")[2],"boss_sweep")
	elif id.begins_with("v31-"):
		f.faction="oda";f.boss_variant=id.split("-")[1];f.action=id.split("-")[2]
	else:
		f.action=id.split("-")[2]
		if id.contains("matsui"): f.faction="imagawa";f.stage_boss=true
	view.state=sim.state;view._frozen_samples.clear()
	return f

func _initialize() -> void: run.call_deferred()

func run() -> void:
	view=View.new();root.add_child(view)
	await process_frame
	var fx := FX.new()
	check(fx.moves.size()==39,"all 39 authored moves retained")
	var enabled := 0
	for move in fx.moves.values():
		var f := fixture(move)
		var original := f.duplicate(true)
		var visible := false
		for tick in int(move.duration_ticks):
			f.action_tick=tick
			var sample := view._fighter_animation(f)
			check(FX.move_id(f,sample)==move.id,"live source binds "+str(move.id))
			var a := fx.attachment(f,sample,view.enemy_display_height(f),1,0)
			if not move.new_fx_enabled:
				check(a.is_empty(),"existing effect is not duplicated")
				continue
			if a.is_empty(): continue
			visible=true
			var frame: Dictionary = sample.frame_data if sample.source in ["stage3","stage4"] else view._art.enemy_frame(f.kind,sample.cell,view.enemy_art_faction(f),sample.sheet)
			var row: Dictionary = move.frames[a.pose]
			# Atlas isolation adds the same transparent two-pixel padding to the
			# anchor and the pixels. Their relative vector is unchanged.
			var unpadded: Vector2 = frame.anchor-frame.get("frame_padding",Vector2.ZERO)
			if row.region_xywh != null:
				var source_region: Rect2 = frame.get("source_region",frame.region)
				unpadded += source_region.position-Vector2(row.region_xywh[0],row.region_xywh[1])
			check(unpadded.distance_to(Vector2(row.root_px[0],row.root_px[1]))<.01,"unchanged foot anchor "+str(move.id))
			check(is_equal_approx(frame.body_height,row.body_height_source_px),"unchanged body ruler "+str(move.id))
			var mirrored := fx.attachment(f,sample,view.enemy_display_height(f),-1,0)
			check(mirrored.offset.is_equal_approx(a.offset*Vector2(-1,1)) and is_equal_approx(mirrored.rotation,-a.rotation),"mirror position and orientation together")
			check(FileAccess.file_exists(FX.ROOT+a.path),"authored pose FX exists")
			if move.id=="stage4-tominaga_sweep" and tick>=36: check(a.is_empty(),"600ms onward intentionally clear")
		if move.new_fx_enabled: check(visible,"enabled move has visible window");enabled+=1
		f.action_tick=original.action_tick
		check(f==original,"attachment sampling never mutates gameplay")
	check(enabled==32,"32 attachments; seven original FX retained")
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	if not output.is_empty():
		assert(DirAccess.make_dir_recursive_absolute(output)==OK)
		root.size=Vector2i(1280,720)
		for move in fx.moves.values():
			if not move.new_fx_enabled: continue
			var f := fixture(move)
			f.action_tick=int(move.events[0].peak_tick)
			f.face=-1 if captures.size()%2 else 1
			view.state.fighters=[f];view.state.props=[];view.state.effects=[];view.state.drops=[]
			view.state.erase("challenge")
			view.state.civilian_spawn_enabled=false;view.camera_x=0
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output.path_join(str(move.id)+".png"))==OK)
			captures.append(move.id)
	print("OFFICER_WEAPON_FX_PASS %d checks"%checks)
	view.queue_free()
	await process_frame
	quit()
