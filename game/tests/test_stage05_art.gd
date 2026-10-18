extends SceneTree

const Data = preload("res://core/stage05_data.gd")
const Art = preload("res://render/stage05_art.gd")

func _initialize() -> void:
	var count := 0
	var frames := 0
	var art := Art.new()
	for role in Data.ROLES:
		for clip in Data.actors()[role]:
			var spec: Dictionary=Data.actors()[role][clip]
			var elapsed:=0.0
			var ruler: float=spec.frames[0].body_height
			for i in spec.frames.size():
				var row: Dictionary=spec.frames[i]
				assert(row.body_height==ruler and row.duration_ms>0)
				assert(FileAccess.file_exists(Data.ROOT+row.path))
				assert(Data.frame_index(spec,elapsed+.001)==i,"Frame boundary "+role+"/"+clip)
				elapsed+=float(row.duration_ms); frames+=1
			assert(is_equal_approx(elapsed,Data.duration(role,clip)))
			var f:={"s05_role":role,"action":clip,"action_tick":elapsed*.03,"hp":100}
			var sample:=art.sample({"tick":0},f,elapsed*.03,elapsed*.03)
			assert(sample.frame_data.texture != null)
			count+=1
	assert(count==75)
	assert(Data.duration("kusei","s05_kusei_stomp")==5000)
	assert(Data.actors().hachiya.run.native_face == -1)
	assert(Data.actors().militia.walk.frames.size()==6 and Data.actors().monk.walk.frames.size()==6)
	assert(Data.timing({"s05_role":"monk","action":"s05_monk_quick_attack","s05_elite":true})==[6,16])
	print("STAGE05_ART_PASS actions=%d frames=%d"%[count,frames])
	quit(0)
