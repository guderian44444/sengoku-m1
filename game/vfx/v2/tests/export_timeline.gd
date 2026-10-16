extends SceneTree
const Emitter=preload("res://vfx/v2/effect_emitter.gd")
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var output:="user://vfx2-timeline.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var fx=Emitter.new();root.add_child(fx);assert(fx.configure())
	var frames:=[];var cues:=[]
	fx.audio_cue.connect(func(id,key,operation,context):cues.append({"instance":id,"key":key,"operation":operation,"context":context}))
	for family: String in ["blade","fire","ice","wind","lightning"]:
		fx.reset_scene()
		fx.trigger("charge",family+"_charged_wave")
		fx.trigger("spin",family+"_growing_spin")
		for tick in range(216):
			if tick==60:fx.release("charge",tick)
			if tick==72:fx.confirmed_hit("charge","demo-hit",tick)
			fx.advance("charge",tick);fx.advance("spin",tick)
			if tick%2==0:frames.append({"family":family,"tick":tick,"instances":fx.instances.duplicate(true)})
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":30,"frames":frames,"audio_cues":cues},"  "))
	fx.queue_free();await process_frame
	print("PASS: 540 frames exported from actual deterministic VFX controller")
	quit()
