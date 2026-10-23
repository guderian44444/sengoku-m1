extends SceneTree

const Builder = preload("res://tests/build_stage07_10_art_manifest.gd")
const ROOT := "res://assets/stages07-10/"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var result := {"format":"expedition-troops-v1","actors":{},"civilians":{}}
	for faction in ["saito","miyoshi","asakura"]:
		for role in ["spear","archer","gunner","shield","raider"]:
			var key: String=faction+"-"+role
			var path: String="troops/"+key+".png"
			var source := Image.load_from_file(ROOT+path)
			var rows := Builder.groups(source,6,path)
			var body := float(rows[0][0].bounds.size.y)
			var actor := {"path":path,"body_height":body,"frames":[],"clips":{}}
			for section in 3:
				var clip_path: String="troops/"+key+("-attack.png" if section==1 else "-reactions.png")
				var image: Image=source
				var clip_rows: Array=[rows[section*2],rows[section*2+1]]
				var clip_body := body
				if section>0 and FileAccess.file_exists(ROOT+clip_path):
					image=Image.load_from_file(ROOT+clip_path);clip_rows=Builder.groups(image,2,clip_path)
					clip_body=float(clip_rows[1][-1].bounds.size.y)
				else: clip_path=path
				print(key," section=",section," rows=",clip_rows.map(func(r):return r.size()))
				if not clip_rows.all(func(r):return r.size()==4):
					push_error("Expected eight isolated people: "+clip_path);quit(1);return
				Builder.append_group(actor,image,clip_rows[0]+clip_rows[1],clip_path,clip_body)
			actor.clips={"idle":[0,7],"walk":[0,1,2,3,4,5,6,7],"attack":[8,9,10,11,12,13,14,15],"hurt":[16,17],"guard":[18,19],"down":[20,21],"recover":[20,22,23]}
			result.actors[key]=actor
	var npc_path := "props/civilians.png"
	var npcs := Image.load_from_file(ROOT+npc_path)
	var npc_rows := Builder.groups(npcs,3,npc_path)
	for i in 3:
		assert(npc_rows[i].size()==4,"Each civilian has four distinct fleeing poses")
		var actor := {"path":npc_path,"body_height":float(npc_rows[i][0].bounds.size.y),"frames":[]}
		Builder.append_group(actor,npcs,npc_rows[i],npc_path,actor.body_height)
		result.civilians[["woman","elder","child"][i]]=actor
	var file := FileAccess.open(ROOT+"troops.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	var runtime: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"runtime-files.json"))
	for path in ["troops.json","props/civilians.png","props/rockfall.png","props/rock-support.png","generation-troops-revision.json","generation-troop-repairs.json"]:
		runtime.runtime_files[path]=FileAccess.get_sha256(ROOT+path)
	for actor in result.actors.values():
		for row in actor.frames: runtime.runtime_files[row.path]=FileAccess.get_sha256(ROOT+row.path)
	for folder in ["backgrounds","props"]:
		for name in DirAccess.get_files_at(ROOT+folder):
			if name.ends_with(".png"): runtime.runtime_files[folder+"/"+name]=FileAccess.get_sha256(ROOT+folder+"/"+name)
	file=FileAccess.open(ROOT+"runtime-files.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(runtime,"\t"));file.close()
	print("EXPEDITION_TROOPS_BUILD_PASS 15 troop sets, 360 troop poses, 12 civilian poses")
	quit()
