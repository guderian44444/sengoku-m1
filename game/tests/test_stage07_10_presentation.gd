extends SceneTree
const Main=preload("res://main.gd")
const Stage=preload("res://core/stage07_10_encounter.gd")
const Wire=preload("res://core/wire.gd")
const Art=preload("res://render/stage07_10_art.gd")
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	assert(ok,label)
class App extends Main:
	func _save_characters(_manual: bool=false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: _has_focus=true
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app := App.new();root.add_child(app);app.set_physics_process(false)
	check(not app.testing,"Exercise the production event/audio route")
	var capture := AudioEffectCapture.new();capture.buffer_length=1.0
	var voice_bus := AudioServer.get_bus_index("Voice")
	AudioServer.add_bus_effect(voice_bus,capture)
	for chapter in [7,8,9,10]:
		app.sim.reset_campaign("normal",1,["nobunaga"],chapter);app._activate()
		var paths := {}
		for region in 5:
			var path := Art.landscape_path(chapter,region)
			check(FileAccess.file_exists(path) and not paths.has(path),"Each of the twenty regions has its own location artwork")
			paths[path]=true
		for role in Stage.Data.BOSSES:
			if Stage.Data.BOSSES[role].stage!=chapter: continue
			app.audio.stop_speech()
			app.sim._enter_segment(4 if role in ["inaba","tatsuoki","iwanari","yoshikage"] else 2)
			app.sim._start_checkpoint(1)
			app._physics_process(1.0/60)
			check(app.audio.intro_playing() and app.audio.last_spoken=="s%02d_%s_intro"%[chapter,role],"Every entrance plays through the real main loop")
			app.audio.stop_speech();capture.clear_buffer();app._update_view()
			check(app.audio.intro_playing(),"The authoritative introduction recovers a missed audio event")
			app.audio._process(.1)
			var music_bus := AudioServer.get_bus_index("Music")
			check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)),app.audio.get_category_volume("music")*.2),"Entrance music ducks without altering saved preferences")
			await create_timer(.65).timeout
			var frames := capture.get_buffer(capture.get_frames_available())
			var peak := 0.0
			for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
			check(frames.size()>128 and peak>.001,"Entrance produces non-silent samples through the actual voice mixer")
			print("INTRO_MIX_PASS ",role," frames=",frames.size()," peak=",peak)
			app.audio.stop_speech();app.audio._process(.1)
			check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)),app.audio.get_category_volume("music")),"Music mix restores after the voice finishes")
		check(Wire.valid_snapshot(app.sim.state),"Presentation leaves a valid network state")
	var sim := Main.Battle.new();sim.reset_campaign("normal",1,["nobunaga"],8)
	sim.state.intro={};sim.state.expedition.pending=[]
	var hero: Dictionary=sim.state.fighters[0];hero.invuln=0;hero.x=80;hero.y=480
	var boss := Stage.spawn(sim,"nagai",1320,480);boss.entering=false;sim.state.fighters.append(boss)
	Stage.start(sim,boss,"s08_nagai_burst",hero)
	Stage.release(sim,boss,Stage.Data.ACTIONS.s08_nagai_burst,1)
	hero.x=45;var hp: int=hero.hp
	for tick in 10: Stage.tick_hazards(sim)
	check(hero.hp<hp,"Full-lane matchlock fire reaches a player beyond the original aim point")
	check(Wire.valid_snapshot(sim.state),"Unbounded aiming uses a finite full-corridor network shape")
	sim.state.expedition.hazards=[];hero.invuln=0;hero.hp=hero.max_hp
	Stage.release(sim,boss,Stage.Data.ACTIONS.s08_nagai_powder,0)
	check(sim.state.expedition.hazards[0].warning==26,"Grenade flight lasts under half a second")
	var first := []
	for chapter in [7,8,9,10]:
		sim.reset_campaign("normal",1,["nobunaga"],chapter);sim.state.expedition.hazards=[];sim.state.props=[]
		var target: Dictionary=sim.state.fighters[0];target.x=60;target.y=480;target.invuln=0
		var gunner := Stage.spawn(sim,"gunner",1320,480);gunner.entering=false;gunner.cooldown=0;sim.state.fighters.append(gunner)
		sim._enemy_input(gunner)
		check(gunner.action=="gun_shot","Every map's ordinary matchlock troops aim beyond the old 900-unit limit")
		gunner.action_tick=int(Main.Battle.enemy_timing(gunner)[0]);sim._tick_enemy_attack(gunner)
		check(sim.state.expedition.hazards.size()==1 and sim.state.expedition.hazards[0].kind=="fireline","Ordinary matchlocks use the same full-corridor rendered gunfire")
		var before: int=target.hp
		for tick in 8: Stage.tick_hazards(sim)
		check(target.hp<before,"Ordinary matchlock fire reaches the far edge")
		sim.state.expedition.hazards=[]
		Stage.arrow_rain(sim,Vector2(700,480),16)
		var points := {};var ys := {};var delays := {}
		for h in sim.state.expedition.hazards:
			points[Vector2(h.x,h.y)]=true;ys[h.y]=true;delays[h.warning]=true
			check(h.radius==23 and h.depth==14,"Only each visible sparse arrow point inflicts damage")
		check(points.size()==8 and ys.size()>=6 and delays.size()>=4,"Rain scatters in two dimensions and time, never fixed rows")
		check(Wire.valid_snapshot(sim.state),"Every chapter uses serializable scattered arrow hit points")
		if chapter==7: first=sim.state.expedition.hazards.duplicate(true)
		sim.state.expedition.hazards=[];sim.state.tick+=60;Stage.arrow_rain(sim,Vector2(700,480),16)
		check(sim.state.expedition.hazards!=first,"New volleys change their pattern")
	sim.reset_campaign("normal",1,["nobunaga"],9);sim._start_checkpoint(1);sim.state.expedition.hazards=[]
	Stage.fire_line(sim,16,480,1,10,18)
	check(sim.state.expedition.hazards[0].radius>1300 and Wire.valid_snapshot(sim.state),"Full-width gunfire validates while a player retreats into an earlier checkpoint")
	sim.state.expedition.hazards=[];Stage.fire_line(sim,2750,480,-1,10,18)
	var line: Dictionary=sim.state.expedition.hazards[0]
	check(line.x-line.radius<40 and Wire.valid_snapshot(sim.state),"Backward gunfire covers the whole traversable road")
	AudioServer.remove_bus_effect(voice_bus,AudioServer.get_bus_effect_count(voice_bus)-1)
	app.audio.stop_speech();app.queue_free();await process_frame
	print("STAGE07_10_PRESENTATION_PASS ",checks," checks");quit()
