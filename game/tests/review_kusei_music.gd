extends SceneTree
const Main = preload("res://main.gd")

class App extends Main:
	func _save_characters(_manual: bool = false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: _has_focus=true
	func _input_frame() -> Dictionary: return {"dx":0,"dy":0,"buttons":0}
	func _physics_process(delta: float) -> void:
		if active:
			for f in sim.state.fighters:
				if f.team==0: f.hp=f.max_hp;f.invuln=1000000
		super._physics_process(delta)

func _initialize(): run.call_deferred()
func run():
	var output := ProjectSettings.globalize_path("res://../artifacts/kusei-music-repair-20261019/native-before")
	var seconds := 80.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="): seconds=float(arg.trim_prefix("--seconds="))
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var app:=App.new();root.add_child(app);await process_frame
	app.session="solo";app.selected_chapter=5;app.local_slot=0
	app.sim.reset_campaign("normal",1,["nobunaga"],5)
	app._activate()
	await create_timer(1).timeout
	app.sim._enter_segment(4);app.sim._start_checkpoint(0)
	app.sim.state.intro.clear()
	var left: float=app.sim.state.stage.encounter_start
	for f in app.sim.state.fighters:
		f.entering=false;f.y=500;f.x=app.sim.state.stage.encounter_end-100 if f.team==0 else left+850
		if f.team==1: f.hp=0;f.damage_tick=app.sim.state.tick
	for p in app.sim.state.props: p.broken=true;p.hp=0
	app._camera_scene=-1;app._update_view()
	# Record the actual master mix while isolating music from combat SFX and voices.
	for bus in ["SFX","Voice"]: AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),true)
	var recording:=AudioEffectRecord.new();recording.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recording)
	recording.set_recording_active(true)
	var samples:=[]
	var start:=Time.get_ticks_msec()
	var captured:={}
	var last_print:=-1
	while float(Time.get_ticks_msec()-start)/1000.0<seconds:
		await create_timer(.25).timeout
		var elapsed:=float(Time.get_ticks_msec()-start)/1000.0
		var p: AudioStreamPlayer=app.audio._music_player
		var row:={"elapsed":elapsed,"key":app.audio._music_key,"playing":p.playing,"paused":p.stream_paused,"position":p.get_playback_position(),"gain":p.volume_linear,"music_db":AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Music"),0),"master_db":AudioServer.get_bus_peak_volume_left_db(0,0),"phase":app.sim.state.phase,"node":app.sim.state.ikki.node}
		samples.append(row)
		if int(elapsed)/5!=last_print:
			last_print=int(elapsed)/5;print("KUSEI_MUSIC_SAMPLE ",JSON.stringify(row))
		for mark in [2,28,72]:
			if elapsed>=mark and not captured.has(mark):
				captured[mark]=true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("battle-%02ds.png"%mark))
	recording.set_recording_active(false)
	var wav:=recording.get_recording()
	assert(wav!=null and wav.save_to_wav(output.path_join("master-output.wav"))==OK)
	var report:=FileAccess.open(output.path_join("playback.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"audio_driver":AudioServer.get_driver_name(),"music_volume":app.audio.get_category_volume("music"),"samples":samples},"  "));report.close()
	print("KUSEI_MUSIC_REVIEW_COMPLETE ",output)
	app.queue_free();await process_frame;quit()
