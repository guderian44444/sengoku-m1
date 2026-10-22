extends SceneTree

const Main = preload("res://main.gd")
const Expedition = preload("res://core/stage07_10_encounter.gd")
const Wire = preload("res://core/wire.gd")

class App extends Main:
	func _save_characters(_manual: bool=false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: _has_focus=true

var app: App
var output := ""
var records := []

func _initialize() -> void: run.call_deferred()

func capture(name: String) -> void:
	app._camera_scene=-1;app.view._frozen_samples.clear();app._update_view()
	app.view.queue_redraw()
	check_snapshot()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
	records.append({"file":name+".png","stage":app.sim.state.stage.id,"scene":app.sim.state.stage.index+1,"tick":app.sim.state.tick})

func check_snapshot() -> void:
	assert(Wire.valid_snapshot(app.sim.state),"Captured world remains a valid multiplayer snapshot")

func arrange() -> void:
	app.sim.state.intro.clear()
	var left := float(app.sim.state.stage.encounter_start)
	for hero in app.sim.state.fighters:
		if hero.team==0: hero.x=left+430+hero.player_index*100;hero.y=530
	for enemy in app.sim.state.fighters:
		if enemy.kind=="boss": enemy.x=left+800;enemy.y=495;enemy.face=-1;enemy.entering=false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(not output.is_empty() and DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	root.size=Vector2i(1280,720)
	app=App.new();root.add_child(app);app.testing=true;app.set_physics_process(false)
	for chapter in [7,8,9,10]:
		app.sim.reset_campaign("normal",2,["nobunaga","oichi"],chapter)
		app.session="local";app._activate();app.set_physics_process(false)
		for section in 5:
			app.sim._enter_segment(section);app.sim._start_checkpoint(1);arrange()
			app.sim.state.tick=1200+section*300
			Expedition.hazard(app.sim,["rock","arrows","fireline","arrows"][chapter-7],Vector2(app.sim.state.fighters[0].x+200,420),150,32,85,12)
			await capture("stage-%02d-scene-%02d"%[chapter,section+1])
			if section==0:
				for hazard in app.sim.state.expedition.hazards: hazard.age=int(hazard.warning)+5
				await capture("stage-%02d-environment-impact"%chapter)
			for boss in app.sim.state.fighters.filter(func(f):return f.kind=="boss"):
				for action in Expedition.Data.BOSSES[boss.expedition_role].actions:
					app.sim.state.effects.clear();app.sim.state.expedition.hazards.clear()
					Expedition.start(app.sim,boss,action,app.sim.state.fighters[0])
					var hits: Array=Expedition.Data.ACTIONS[action].hits
					for hit_index in hits.size():
						app.sim.state.effects.clear();app.sim.state.expedition.hazards.clear()
						boss.action_tick=int(hits[hit_index])
						Expedition.attack(app.sim,boss)
						await capture(action+("-impact" if hit_index==0 else "-hit-%02d-impact"%(hit_index+1)))
						if hit_index==0 and not app.sim.state.expedition.hazards.is_empty():
							for hazard in app.sim.state.expedition.hazards: hazard.age=int(hazard.warning)+5
							await capture(action+"-hazard")
				for reaction in ["down","recovering","defeated"]:
					boss.action=reaction;boss.action_tick=48 if reaction!="recovering" else 18
					await capture("%s-%s"%[boss.expedition_role,reaction])
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("STAGE0710_CAPTURE_PASS %d native frames"%records.size())
	app.queue_free();await process_frame;quit()
