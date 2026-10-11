extends "res://render/battle_view.gd"

# Earlier suites lock the retained v12-v17 fallback contracts. The production
# renderer now selects v22; test_hero_layers_v22 verifies that default separately.
# Remove only the new registration from this test instance, never the assets.
func _init() -> void:
	for hero in _art.animations:
		for sheet in _art.animations[hero].keys():
			if str(sheet).begins_with("v22_"): _art.animations[hero].erase(sheet)
