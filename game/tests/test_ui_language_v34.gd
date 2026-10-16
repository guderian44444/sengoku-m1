extends SceneTree

const Weapons = preload("res://core/weapon_catalog.gd")
const Charms = preload("res://core/talisman_catalog.gd")
const Achievements = preload("res://core/achievements.gd")
const Archive = preload("res://core/weapon_encyclopedia.gd")

func _initialize() -> void:
	for item in Weapons.ITEMS.values():
		_check_visible(str(item.name) + " " + str(item.special))
	for hero in ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]:
		assert(Weapons.item(Weapons.default_for(hero)).name.contains("常備"))
	for item in Charms.ITEMS.values():
		_check_visible(str(item.name) + " " + str(item.description))
		assert(not str(item.history).is_empty() and str(item.source).begins_with("https://"), "Historical notes and sources remain available.")
		assert(str(item.description).contains("護力耗盡") if item.mode == "fixed" else str(item.description).contains("耐久降至兩成"), "Durability limits must stay explicit.")
	for rule in Achievements.RULES:
		_check_visible(str(rule[1]) + " " + str(rule[2]))
		assert(not str(rule[2]).contains("小王") and not str(rule[2]).contains("大王"))
	_check_visible(Archive.stats("unknown_weapon"))
	var archive := Archive.new()
	assert(archive.entries.size() > 0)
	for id in archive.entries:
		for phrase in ["catalog", "_cm", "null", "本次", "此次", "不應全部搬"]:
			assert(not archive.history(id).contains(phrase), "Production notes must not appear in the weapon archive: " + str(id))
	assert(not archive.entry("spear_otegine").sources.is_empty())
	assert(archive.history("spear_otegine").contains("燒失"), "Immersive wording must not erase historical uncertainty or destruction.")
	print("UI LANGUAGE V34 PASS: weapon/charm/feat text, explicit limits, historical sources")
	quit()

func _check_visible(value: String) -> void:
	# Review action-facing text; archival notes may legitimately identify an adaptation.
	for phrase in ["白板", "新版", "製作中", "草稿", "測試", "遊戲創作", "題材：", "保留原本", "既有的", "創作款"]:
		assert(not value.contains(phrase), "Development narration in visible text: " + value)
