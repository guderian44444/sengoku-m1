extends Node

const Data = preload("res://core/stage05_data.gd")
var streams: Dictionary = {}
var last_choices: Dictionary = {}
var players: Array[AudioStreamPlayer] = []

func stream(path: String) -> AudioStreamWAV:
	if not streams.has(path):
		var audio := AudioStreamWAV.load_from_file(Data.ROOT+path)
		assert(audio != null,"Missing stage-five sound: "+path)
		audio.loop_mode=AudioStreamWAV.LOOP_DISABLED
		streams[path]=audio
	return streams[path]

static func music(key: String) -> AudioStreamWAV:
	if key in ["s05_kusei_intro","s05_kusei_loop"]:
		var base := "music/05_kusei_approved/"
		var meta: Dictionary=Data.read(base+"loop_manifest.json")
		var loop := AudioStreamWAV.load_from_file(Data.ROOT+base+"kusei_loop.wav")
		assert(loop != null)
		loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin=0; loop.loop_end=int(meta.loop.loopend_sample)
		if key=="s05_kusei_loop": return loop
		var intro := AudioStreamWAV.load_from_file(Data.ROOT+base+"kusei_intro.wav")
		assert(intro != null and intro.mix_rate==loop.mix_rate and intro.stereo==loop.stereo and intro.format==loop.format)
		# One PCM stream crosses the intro boundary at the exact sample. Only the
		# appended loop repeats; no frame-timed callback or overlapping drums.
		var pcm := intro.data
		pcm.append_array(loop.data); intro.data=pcm
		intro.loop_mode=AudioStreamWAV.LOOP_FORWARD
		intro.loop_begin=int(meta.intro.samples)
		intro.loop_end=int(meta.intro.samples)+int(meta.loop.loopend_sample)
		return intro
	for row in Data.read("music/music_map.json").tracks:
		if "s05_"+str(row.id)!=key: continue
		var audio := AudioStreamWAV.load_from_file(Data.ROOT+"music/"+str(row.wav))
		assert(audio != null)
		audio.loop_mode=AudioStreamWAV.LOOP_FORWARD
		audio.loop_begin=int(row.loopstart_sample); audio.loop_end=int(row.loopend_sample)
		return audio
	return null

func play(event: Dictionary) -> void:
	var cue: String=event.cue
	var path := ""
	var voice := false
	if cue=="kusei_stomp_full": path="audio/tracks/kusei_stomp_v2_voiceA_full_5p65s.wav"; voice=true
	if cue=="kusei_roar": path="../stage5-runtime/kusei-roar.wav"
	for row in Data.read("audio/voice-event-map.json"):
		if row.id==cue: path="audio/"+str(row.wav); voice=true; break
	if path.is_empty():
		for row in Data.read("audio/event-map.json"):
			if row.event_id!=cue: continue
			var choices: Array=row.variants
			var choice := int(event.id)%choices.size()
			if choice==int(last_choices.get(cue,-1)): choice=(choice+1)%choices.size()
			last_choices[cue]=choice
			path="audio/wav/"+str(choices[choice])+".wav"
			break
	assert(not path.is_empty(),"Unbound stage-five sound: "+cue)
	players=players.filter(func(p):return is_instance_valid(p))
	if voice and players.any(func(p):return p.playing and p.bus=="Voice" and int(p.get_meta("actor",0))==int(event.actor)): return
	if players.size()>=48: return
	var player := AudioStreamPlayer.new()
	player.bus="Voice" if voice else "SFX"
	player.set_meta("actor",int(event.actor)); player.stream=stream(path)
	player.volume_linear=.85 if voice else .7
	add_child(player); players.append(player)
	player.finished.connect(func(): players.erase(player); player.queue_free())
	player.play()

func set_paused(paused: bool) -> void:
	for player in players:
		if is_instance_valid(player): player.stream_paused=paused

func speech_playing() -> bool:
	return players.any(func(p):return is_instance_valid(p) and p.bus=="Voice" and p.playing)

func stop_speech() -> void:
	for player in players:
		if is_instance_valid(player) and player.bus=="Voice": player.stop(); player.queue_free()
	players=players.filter(func(p):return is_instance_valid(p) and not p.is_queued_for_deletion())
