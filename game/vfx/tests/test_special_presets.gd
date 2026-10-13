extends SceneTree
const Battle = preload("res://core/battle.gd")
const Adapter = preload("res://vfx/special_preset_adapter.gd")
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://vfx/special_presets.json"))
	assert(data.heroes.size() == Battle.HEROES.size())
	for hero in Battle.HEROES:
		assert(data.heroes.has(hero))
		assert(int(data.heroes[hero].duration_ticks) == Battle.SPECIAL_TICKS)
		assert(data.heroes[hero].hit_ticks_snapshot.size() == Battle.SPECIAL_HIT_TICKS[hero].size())
		for i in range(Battle.SPECIAL_HIT_TICKS[hero].size()):
			assert(int(data.heroes[hero].hit_ticks_snapshot[i]) == Battle.SPECIAL_HIT_TICKS[hero][i])
	print("PASS: all 6 special presets match authoritative duration/hit ticks; adapter parses")
	quit()
