extends RefCounted

const Profile = preload("res://core/save_profile.gd")
const Equipment = preload("res://core/equipment.gd")
const DEFAULT_DIRECTORY := "user://players"
var directory: String
var records: Dictionary = {}
var dirty: Dictionary = {}
var migration_pending := false
var selected: Array[String] = []
var warning := ""
var blocked := false
var data: Dictionary:
	get:
		var snapshot := {"players":{},"selected":selected.duplicate(),"chapter":1,"completed_chapter":0}
		for id in records: snapshot.players[id] = records[id].data
		if not selected.is_empty() and records.has(selected[0]):
			snapshot.chapter = records[selected[0]].data.get("chapter",1)
			snapshot.completed_chapter = records[selected[0]].data.get("completed_chapter",0)
		return snapshot

func _init(folder: String = DEFAULT_DIRECTORY, legacy_path: String = Profile.DEFAULT_PATH) -> void:
	directory = folder
	var dir := DirAccess.open(directory)
	if dir != null:
		var files := dir.get_files()
		files.sort()
		for file in files:
			if file.ends_with(".json.bak"): file = file.trim_suffix(".bak")
			if not file.ends_with(".json") or not file.begins_with("player-"): continue
			if records.has(file.trim_suffix(".json")): continue
			var profile := Profile.new(directory.path_join(file),"玩家")
			records[file.trim_suffix(".json")] = profile
			if profile.warning != "": warning += profile.warning + "\n"
	if records.is_empty():
		migration_pending = true
		var legacy := Profile.new(legacy_path)
		if legacy.blocked:
			blocked = true
			warning = legacy.warning
		for slot in range(2):
			var profile := Profile.new(directory.path_join("player-%d.json" % (slot + 1)),"玩家 %d" % (slot + 1))
			if not legacy.blocked:
				profile.data.chapter = legacy.data.get("chapter",1)
				profile.data.completed_chapter = legacy.data.get("completed_chapter",0)
				for hero in Profile.HEROES:
					var row := legacy.character(slot,hero)
					row.slot = 0
					Equipment.ensure(row)
					profile.data.characters["0:" + hero] = row
			records["player-%d" % (slot + 1)] = profile
			dirty["player-%d" % (slot + 1)] = true
	selected.assign(records.keys().slice(0,2))
	if selected.size() == 1: selected.append(selected[0])
	var preferences := ConfigFile.new()
	if preferences.load(directory.path_join("selection.cfg")) == OK:
		for slot in range(2):
			var id := str(preferences.get_value("players",str(slot),selected[slot]))
			if records.has(id): selected[slot] = id

func name_for(slot: int) -> String:
	return str(records[selected[slot]].data.get("name","玩家"))

func select_player(slot: int, id: String) -> Error:
	if slot not in [0,1] or not records.has(id): return ERR_INVALID_PARAMETER
	if migration_pending:
		var err := save()
		if err != OK: return err
	var previous := selected[slot]
	selected[slot] = id
	var err := _save_selection()
	if err != OK: selected[slot] = previous
	return err

func _save_selection() -> Error:
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if err != OK: return err
	var config := ConfigFile.new()
	for slot in range(2): config.set_value("players",str(slot),selected[slot])
	return config.save(directory.path_join("selection.cfg"))

func add_player(value: String) -> String:
	var player_name := value.strip_edges()
	if blocked or player_name == "" or player_name.length() > 20 or records.size() >= 64: return ""
	if migration_pending and save() != OK: return ""
	for profile in records.values():
		if str(profile.data.name) == player_name: return ""
	var id := "player-%d" % Time.get_ticks_usec()
	while records.has(id) or FileAccess.file_exists(directory.path_join(id + ".json")): id += "1"
	var profile := Profile.new(directory.path_join(id + ".json"),player_name)
	if profile.save() != OK: return ""
	records[id] = profile
	return id

func character(slot: int, hero: String) -> Dictionary:
	return records[selected[slot]].character(0,hero)

func apply_to(fighter: Dictionary) -> void:
	var slot := int(fighter.player_index)
	var index: int = fighter.player_index
	fighter.player_index = 0
	records[selected[slot]].apply_to(fighter)
	fighter.player_index = index

func capture(fighter: Dictionary) -> void:
	if fighter.get("team",1) != 0: return
	var copy := fighter.duplicate(true)
	copy.player_index = 0
	records[selected[int(fighter.player_index)]].capture(copy)
	dirty[selected[int(fighter.player_index)]] = true

func equip(slot: int, hero: String, id: String) -> bool:
	var equipped: bool = records[selected[slot]].equip(0,hero,id)
	if equipped: dirty[selected[slot]] = true
	return equipped

func equip_instance(slot: int, hero: String, uid: int) -> bool:
	var profile = records[selected[slot]]
	var row: Dictionary = profile.character(0,hero)
	if not Equipment.equip(row,uid): return false
	profile.data.characters["0:" + hero] = row
	dirty[selected[slot]] = true
	return true

func unequip_treasure(slot: int, hero: String) -> void:
	var profile = records[selected[slot]]
	var row: Dictionary = profile.character(0,hero)
	row.treasure_uid = 0
	Equipment.sync(row)
	profile.data.characters["0:" + hero] = row
	dirty[selected[slot]] = true

func pack(slot: int, hero: String, uid: int, carry: bool) -> bool:
	var profile = records[selected[slot]]
	var row: Dictionary = profile.character(0,hero)
	if not Equipment.pack(row,uid,carry): return false
	profile.data.characters["0:" + hero] = row
	dirty[selected[slot]] = true
	return true

func discard(slot: int, hero: String, uid: int) -> bool:
	var profile = records[selected[slot]]
	var row: Dictionary = profile.character(0,hero)
	if Equipment.instance(row,uid).is_empty(): return false
	Equipment.remove(row,uid)
	profile.data.characters["0:" + hero] = row
	dirty[selected[slot]] = true
	return true

func sell(slot: int, hero: String, uid: int) -> int:
	var profile = records[selected[slot]]
	var row: Dictionary = profile.character(0,hero)
	var price := Equipment.sell(row,uid)
	if price > 0:
		profile.data.characters["0:" + hero] = row
		dirty[selected[slot]] = true
	return price

func capture_chapter(chapter: int, completed: bool, player_count: int = 1) -> void:
	for id in selected.slice(0,player_count):
		records[id].capture_chapter(chapter,completed)
		dirty[id] = true

func save_player(slot: int) -> Error:
	if blocked: return ERR_INVALID_DATA
	var profile = records[selected[slot]]
	var err: Error = profile.save()
	if err == OK: dirty.erase(selected[slot])
	else: warning = profile.warning if profile.warning != "" else "玩家存檔寫入失敗 (%d)。" % err
	return err

func save() -> Error:
	if blocked: return ERR_INVALID_DATA
	for id in dirty.keys():
		var profile = records[id]
		var err: Error = profile.save()
		if err != OK:
			warning = profile.warning if profile.warning != "" else "玩家存檔寫入失敗 (%d)。" % err
			return err
		dirty.erase(id)
	migration_pending = false
	warning = ""
	return _save_selection()
