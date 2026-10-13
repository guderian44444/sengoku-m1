extends SceneTree

const Sources = preload("res://render/layered_hero_source.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	check(not Sources.complete_registration(null),"Missing manifest is not an activation marker")
	check(not Sources.complete_registration({}),"Blank manifest is not an activation marker")
	var manifest := {"version":"v27","complete":false,"clips":{}}
	for index in range(26):manifest.clips[str(index)]={"frames":[{},{},{},{},{},{}]}
	check(not Sources.complete_registration(manifest),"Even 156 draft entries stay inactive")
	manifest.complete=true
	check(Sources.complete_registration(manifest),"Complete 26-by-6 manifest passes structural activation gate")
	manifest.clips["0"].frames.pop_back()
	check(not Sources.complete_registration(manifest),"Incomplete individual clip blocks activation")
	manifest.clips["0"].frames.append({})
	manifest.clips.erase("0")
	check(not Sources.complete_registration(manifest),"Partial 25-clip manifest blocks activation")
	check(Sources.folder("nobunaga")=="res://assets/v22/nobunaga/","Nobunaga remains unchanged")
	check(Sources.folder("tadakatsu")=="res://assets/v22/tadakatsu/","Tadakatsu remains unchanged")
	if not FileAccess.file_exists("res://assets/v27/oichi/registration.json"):
		check(Sources.folder("oichi")=="res://assets/v22/oichi/","Oichi retains v22 until final registration exists")
	print("OICHI PIPELINE V27 %s: %d checks, %d failures" % ["PASS" if failures==0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
