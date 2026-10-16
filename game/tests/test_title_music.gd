extends SceneTree
const Audio = preload("res://render/combat_audio.gd")
const Main = preload("res://main.gd")
var checks := 0
var failures := 0
var natural := false

class App extends "res://main.gd":
	func _confirm_end(_action: Callable, _message: String) -> bool: return false
	func _set_game_focus(_focused: bool) -> void: pass

class MissingAudio extends "res://render/combat_audio.gd":
	var unavailable: Array = []
	func _load_music(key: String) -> AudioStream:
		if key in unavailable: return null
		return super._load_music(key)

func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run():
	natural = "--natural" in OS.get_cmdline_user_args()
	var timing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Audio.TITLE_ROOT+"title_music_handoff.json"))
	for line in FileAccess.get_file_as_string(Audio.TITLE_ROOT+"SHA256SUMS.txt").split("\n",false):
		var parts := line.split("  ",false)
		check(FileAccess.get_sha256(Audio.TITLE_ROOT+parts[1].strip_edges()) == parts[0],"Supplied source hash: "+parts[1])
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	var intro = audio._load_music("title_intro")
	var loop = audio._load_music("title_loop")
	check(intro is AudioStreamOggVorbis and loop is AudioStreamOggVorbis,"Both title cues use native OGG decoding")
	check(absf(intro.get_length()-float(timing.intro_seconds))<.002 and absf(loop.get_length()-float(timing.loop_seconds))<.002,"Both exact supplied durations are retained")
	check(not intro.loop and loop.loop and is_zero_approx(loop.loop_offset) and loop.beat_count==0,"Intro is one-shot, full-length loop is native")
	audio.play_title_music()
	check(audio._music_key=="title_intro" and audio._music_player.playing,"First title visit starts the intro")
	check(is_equal_approx(audio._music_target_gain,1.0) and is_equal_approx(audio._music_player.volume_linear,1.0),"Supplied gain and intro fade are not applied twice")
	var current: AudioStreamPlayer = audio._music_player
	var playback = current.get_stream_playback()
	for iteration in range(30): audio.play_title_music()
	check(audio._music_player==current and current.get_stream_playback()==playback,"Repeated menu entry keeps the intro cursor")
	current.seek(float(timing.loop_first_start_seconds)-.04)
	audio._process(0)
	check(audio._music_key=="title_intro","Intro remains before the handoff threshold")
	current.seek(float(timing.loop_first_start_seconds)+.01)
	audio._process(0)
	check(audio._music_key=="title_loop" and audio._music_player.playing and audio._music_tail==current and current.playing,"Loop starts before intro ends with two active players")
	check(audio._title_linear_crossfade and is_equal_approx(audio._music_fade_seconds,.1),"Intro handoff uses the supplied 100 ms linear fade")
	audio._process(.05)
	check(absf(audio._music_player.volume_linear-.5)<.002 and absf(audio._music_tail.volume_linear-.5)<.002,"Midpoint is linear half gain on both supplied files")
	audio._process(.05)
	check(not audio._music_tail.playing and audio._music_tail.stream==null and audio._music_player.playing,"Completed crossfade clears intro without restarting loop")
	current=audio._music_player
	for crossing in range(2):
		current.seek(loop.get_length()-.08)
		playback=current.get_stream_playback()
		await create_timer(.75).timeout
		check(current.playing and current.get_playback_position()<2 and current.get_stream_playback()==playback and audio._music_key=="title_loop","Native loop boundary preserves playback: "+str(crossing))
	audio.stop_music()
	audio._music_finished(current)
	check(not audio._music_active,"Late intro completion cannot restart stopped music")
	audio.play_title_music()
	check(audio._music_key=="title_loop","Returning after a stop skips the intro for this app session")
	audio.stop_music()
	audio.queue_free()
	await process_frame
	for missing in [["title_intro"],["title_loop"],["title_intro","title_loop"]]:
		var faulty := MissingAudio.new()
		faulty.unavailable=missing
		root.add_child(faulty)
		faulty.set_process(false)
		faulty.play_title_music()
		if missing==["title_intro"]:
			check(faulty._music_key=="title_loop" and faulty._music_player.playing,"Missing intro starts the supplied loop")
		elif missing==["title_loop"]:
			faulty._music_finished(faulty._music_player)
			check(faulty._music_key=="legacy" and faulty._music_player.playing,"Missing loop falls back when intro hands off")
		else:
			check(faulty._music_key=="legacy" and faulty._music_player.stream is AudioStreamWAV and faulty._music_player.playing,"Both title files missing safely use the registered legacy WAV")
		faulty.stop_music()
		faulty.queue_free()
		await process_frame
	var app := App.new()
	root.size=Vector2i(1280,720)
	root.add_child(app)
	app.testing=true
	app.set_physics_process(false)
	await process_frame
	check(app.menu_screen=="title" and app.audio._music_key=="title_intro","Actual Main boots into title intro")
	current=app.audio._music_player
	playback=current.get_stream_playback()
	for page in ["main","options","players","roster","main","title"]:
		app._show_menu_page(page)
		check(app.audio._music_player==current and current.get_stream_playback()==playback,"Actual menu preserves intro: "+page)
	app.audio.set_music_paused(true)
	var position: float = current.get_playback_position()
	await create_timer(.15).timeout
	check(current.stream_paused and absf(current.get_playback_position()-position)<.08,"Pausing retains the intro cursor")
	app.audio.set_music_paused(false)
	if natural:
		# No seek: this is the actual first intro, across the menu changes above.
		await create_timer(float(timing.intro_seconds)+.35).timeout
		check(app.audio._music_key=="title_loop" and app.audio._music_player.playing and app.audio._music_player.get_playback_position()>.15 and app.audio._music_player.get_playback_position()<1.2,"Actual Main naturally reaches the title loop near the supplied transition time without seeking")
		print("TITLE MUSIC NATIVE: natural intro handoff completed; loop position=%.4f seconds; no listening claim" % app.audio._music_player.get_playback_position())
	var outgoing_title: AudioStream = app.audio._music_player.stream
	app._start_solo()
	check(app.active and not app.menu.visible and app.audio._music_key.begins_with("s01_"),"Starting actual solo selects chapter music")
	check(app.audio._music_tail.playing and app.audio._music_tail.stream == outgoing_title,"Chapter crossfade retains the outgoing title stream")
	app.audio._process(2)
	check(not app.audio._music_tail.playing,"Chapter transition clears its outgoing title")
	app._leave_to_menu()
	check(not app.active and app.menu_screen=="main" and app.audio._music_key=="title_loop" and app.audio._music_player.playing,"Leaving actual battle returns to loop, never replays intro")
	check(app.audio._music_tail.playing,"Returning to menu fades the outgoing chapter stream")
	app.audio._process(1)
	current=app.audio._music_player
	playback=current.get_stream_playback()
	app._open_options()
	app._menu_back()
	check(app.audio._music_player==current and current.get_stream_playback()==playback,"Options roundtrip preserves returned loop")
	app._fail("title music test")
	check(app.audio._music_key=="title_loop" and app.audio._music_player.playing,"Network failure restores title loop")
	app.audio.stop_music()
	app.queue_free()
	await process_frame
	print("TITLE MUSIC: %d checks, %d failures; subjective listening pending" % [checks,failures])
	quit(0 if failures==0 else 1)
