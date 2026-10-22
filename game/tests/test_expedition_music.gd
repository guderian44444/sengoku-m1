extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
const Music = preload("res://core/campaign_music.gd")
var checks := 0
var failures := 0

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func run():
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	check(Music.EXPEDITION.values().size()==4 and Music.EXPEDITION.values().all(func(k):return Music.EXPEDITION.values().count(k)==1),"Four distinct chapter battle melodies")
	for id in [7,8,9,10]:
		audio.stop_music()
		var world := {"stage":{"id":id,"index":0},"phase":"playing","fighters":[],"props":[]}
		audio.sync_stage_music(world)
		audio.play_music()
		check(audio._music_key==("s07_mountain_approach" if id==7 else Music.EXPEDITION[id]),"Chapter opening cue %d"%id)
		world.fighters=[{"team":0,"hp":100,"x":300,"y":450},{"team":1,"hp":100,"x":400,"y":450,"stage_boss":false}]
		audio.sync_stage_music(world)
		audio._process(2)
		check(audio._music_key==Music.EXPEDITION[id],"Contact enters chapter combat score %d"%id)
		var current: AudioStreamPlayer=audio._music_player
		var playback=current.get_stream_playback()
		var gain: float=audio._music_target_gain
		world.fighters[1].stage_boss=true
		audio.sync_stage_music(world)
		check(audio._music_target_gain>gain and audio._music_player==current and current.get_stream_playback()==playback,"Commander raises intensity without restarting music %d"%id)
		world.fighters=[]
		audio.sync_stage_music(world)
		check(audio._music_key==Music.EXPEDITION[id] and current==audio._music_player,"Clear waves preserve combat playback %d"%id)
		world.phase="won"
		audio.sync_stage_music(world)
		audio._process(1)
		check(audio._music_key=="s07_mountain_approach" and not audio._music_tail.playing,"Victory uses Japanese Oboro2 and retires battle tail %d"%id)
		current=audio._music_player
		playback=current.get_stream_playback()
		for n in 60: audio.sync_stage_music(world)
		check(current==audio._music_player and playback==current.get_stream_playback(),"Victory snapshots preserve the loop %d"%id)
		world.phase="lost"
		audio.sync_stage_music(world)
		check(not audio._music_active and not audio._music_player.playing and not audio._music_tail.playing,"Loss silences both streams %d"%id)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Music.ROOT+"manifest.json"))
	for row in manifest.assets:
		if row.id not in ["s07_mountain_approach","s08_castle_battle"]: continue
		check(FileAccess.get_sha256(Music.ROOT+str(row.file))==row.sha256,"Pinned imported bytes "+str(row.id))
		var stream: AudioStream=audio._load_music(row.id)
		check(stream is AudioStreamOggVorbis and absf(stream.get_length()-float(row.duration_seconds))<.05,"Native OGG decode and duration "+str(row.id))
		audio._change_music(row.id,.4,.25)
		audio.play_music()
		var current: AudioStreamPlayer=audio._music_player
		for crossing in 2:
			current.seek(current.stream.get_length()-.08)
			var playback=current.get_stream_playback()
			await create_timer(.75).timeout
			check(current.playing and current.get_playback_position()<2 and current.get_stream_playback()==playback,"Native repeat boundary %d: %s"%[crossing+1,row.id])
		audio.stop_music()
	# Expedition selections do not alter old chapter choices.
	check(Music.select({"stage":{"id":1},"phase":"won"},"")=="victory_jingle","Original chapter victory routing retained")
	audio.queue_free()
	await process_frame
	print("EXPEDITION MUSIC: %d checks, %d failures; human listening remains pending"%[checks,failures])
	quit(0 if failures==0 else 1)
