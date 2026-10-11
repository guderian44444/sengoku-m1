extends SceneTree
const View = preload("res://render/battle_view.gd")

func _initialize() -> void:
	var prop := {"x":400.0,"y":500.0,"broken":false}
	var player := {"team":0,"hp":120,"x":400.0,"y":450.0}
	var checks := [
		View.prop_opacity(prop,[player],155,140) == 0.42,
		View.prop_opacity(prop,[player],75,140) == 1.0,
		View.prop_opacity(prop,[{"team":1,"hp":100,"x":400,"y":450}],155,140) == 1.0,
		View.prop_opacity(prop,[{"team":0,"hp":120,"x":400,"y":520}],155,140) == 1.0,
		View.prop_opacity(prop,[{"team":0,"hp":0,"x":400,"y":450}],155,140) == 1.0,
		View.prop_opacity(prop,[{"team":0,"hp":120,"x":700,"y":450}],155,140) == 1.0,
		View.prop_opacity({"x":400,"y":500,"broken":true},[player],155,140) == 1.0,
	]
	if checks.has(false):
		push_error("Tall scenery must reveal only living players directly behind it")
		quit(1)
		return
	print("STAGE OCCLUSION V19 PASS: 7 checks, 0 failures")
	quit()
