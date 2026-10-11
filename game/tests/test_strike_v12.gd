extends SceneTree
const View = preload("res://render/battle_view.gd")

func _initialize() -> void:
	var fighter := {"kind":"nobunaga","action":"light","combo":1}
	assert(View.strike_accent(fighter,{"tick":5}).is_empty(),"No strike arc before the damage frame")
	var down := View.strike_accent(fighter,{"tick":6})
	fighter.combo = 2
	var up := View.strike_accent(fighter,{"tick":6})
	fighter.combo = 3
	var sweep := View.strike_accent(fighter,{"tick":6})
	assert(down.path[3] > 0 and up.path[3] < 0,"Rising and falling cuts trace opposite arcs")
	assert(sweep.path[4] < down.path[4],"Third cut follows a horizontal waist-level sweep")
	fighter.action = "heavy"
	fighter.heavy_combo = 1
	var heavy := View.strike_accent(fighter,{"tick":14})
	fighter.heavy_combo = 2
	var finisher := View.strike_accent(fighter,{"tick":14})
	assert(heavy.path[0] > down.path[0] and heavy.path[1] > down.path[1],"Heavy cuts have larger, thicker arcs")
	assert(not heavy.shock and finisher.shock and finisher.path[4] < heavy.path[4],"Heavy finish differs by sweep and ground pressure")
	fighter.action = "charged_slam"
	var charged := View.strike_accent(fighter,{"tick":28})
	assert(charged.power > heavy.power and charged.shock and charged.low,"Charged ground strike gains grounded impact")
	assert(View.strike_accent(fighter,{"tick":42}).is_empty(),"Strike accents fade before recovery ends")
	fighter.kind = "oichi"
	fighter.action = "heavy"
	assert(View.strike_accent(fighter,{"tick":14}).bow,"Arrows emit from hands rather than a sword arc")
	fighter.action = "light"
	assert(not View.strike_accent(fighter,{"tick":6}).bow,"The turning kick receives its own arc")
	fighter.action = "special"
	for hit in [26,68,110,152,192]:
		assert(View.strike_accent(fighter,{"tick":hit}).age == 0,"Every actual special pulse restarts its accent")
	print("PASS: distinct cut paths, heavy/charged weight, kick/arrow separation and special pulse effects")
	quit()
