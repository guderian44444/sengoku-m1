extends RefCounted

const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
const Achievements = preload("res://core/achievements.gd")
const HEROES := ["nobunaga","oichi","hideyoshi","ieyasu","mitsuhide","tadakatsu"]
const DEFAULT_PATH := "user://characters-v1.json"
var path: String
var data := {"version":1,"characters":{},"chapter":1,"completed_chapter":0}
var warning := ""
var blocked := false

func _init(save_path: String = DEFAULT_PATH, player_name: String = "") -> void:
	path = save_path
	if player_name != "": data = {"version":2,"name":player_name,"characters":{},"chapter":1,"completed_chapter":0}
	load_profile()

static func _int_range(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func valid(payload: Variant) -> bool:
	if not payload is Dictionary or (payload.get("version") != 1 and payload.get("version") != 2) or not payload.get("characters") is Dictionary or payload.characters.size() > 12: return false
	if payload.version == 2 and (not payload.get("name") is String or payload.name.strip_edges() == "" or payload.name.length() > 20): return false
	if not _int_range(payload.get("chapter",1),1,24) or not _int_range(payload.get("completed_chapter",0),0,24): return false
	for key in payload.characters:
		var row: Variant = payload.characters[key]
		if not key is String or not row is Dictionary or row.get("hero") not in HEROES or not _int_range(row.get("slot"),0,1): return false
		if key != "%d:%s" % [int(row.slot),row.hero]: return false
		if not _int_range(row.get("score"),0,1000000000) or not _int_range(row.get("max_hp_bonus"),0,10000): return false
		if payload.version == 2:
			if row.slot != 0 or not Equipment.valid(row) or not Achievements.valid(row.get("achievements")): return false
		elif not Weapons.valid_inventory(row.hero,row.get("weapon_id"),row.get("owned_weapons")): return false
	return true

func _read(file_path: String, validate: bool = true) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null or file.get_length() > 1048576: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary and (not validate or valid(parsed)) else {}

func _protect_unknown_version(payload: Dictionary) -> bool:
	if not payload.has("version") or payload.version == data.version: return false
	blocked = true
	warning = "不支援此角色存檔版本，已保留原檔與備份；本次不覆寫存檔。"
	return true

func load_profile() -> void:
	var primary := _read(path,false)
	if _protect_unknown_version(primary): return
	if valid(primary):
		data = primary
		return
	var backup := _read(path + ".bak")
	if not backup.is_empty() and backup.version == data.version:
		data = backup
		warning = "角色存檔已從備份復原。"
		return
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		blocked = true
		warning = "角色存檔與備份無法讀取，已保留原檔；本次不覆寫存檔。"

func character(slot: int, hero: String) -> Dictionary:
	var key := "%d:%s" % [slot,hero]
	var row: Dictionary = data.characters.get(key,{"slot":slot,"hero":hero,"score":0,"max_hp_bonus":0,"weapon_id":Weapons.default_for(hero),"owned_weapons":[Weapons.default_for(hero)]}).duplicate(true)
	if data.version == 2: Equipment.ensure(row)
	elif hero == "hideyoshi" and not Weapons.compatible(hero,str(row.weapon_id)):
		row.weapon_id = Weapons.default_for(hero)
		if row.weapon_id not in row.owned_weapons: row.owned_weapons.append(row.weapon_id)
	return row

func apply_to(fighter: Dictionary) -> void:
	var row := character(int(fighter.player_index),str(fighter.kind))
	for field in ["score","max_hp_bonus","weapon_id","owned_weapons"]: fighter[field] = row[field]
	for field in ["score","max_hp_bonus"]: fighter[field] = int(row[field])
	if data.version == 2:
		for field in ["next_item_uid","weapon_uid","treasure_uid","gold","achievements","bag_uids"]: fighter[field] = row[field].duplicate(true) if row[field] is Array else row[field]
		fighter.inventory = row.inventory.duplicate(true)
		fighter.bag_only = false
		fighter.storage_reserve = 0
		Equipment.sync(fighter)
	fighter.max_hp += roundi(int(row.max_hp_bonus) * 1.5)
	fighter.hp = fighter.max_hp
	fighter.next_life_score = (int(fighter.score) / 10000 + 1) * 10000

func capture(fighter: Dictionary) -> void:
	if fighter.get("team",1) != 0: return
	var row := character(int(fighter.player_index),str(fighter.kind))
	for field in ["score","max_hp_bonus","weapon_id","owned_weapons"]: row[field] = fighter[field].duplicate() if fighter[field] is Array else fighter[field]
	if data.version == 2:
		# Preserve reserved stock from legacy carried-only snapshots; new battles use the whole warehouse.
		if fighter.get("bag_only",false):
			row.inventory = row.inventory.filter(func(item): return int(item.uid) not in row.bag_uids)
			row.inventory.append_array(fighter.inventory.duplicate(true))
		else: row.inventory = fighter.inventory.duplicate(true)
		for field in ["next_item_uid","weapon_uid","treasure_uid","gold","achievements","bag_uids"]: row[field] = fighter[field].duplicate(true) if fighter[field] is Array else fighter[field]
		Equipment.sync(row)
	data.characters["%d:%s" % [fighter.player_index,fighter.kind]] = row

func equip(slot: int, hero: String, id: String) -> bool:
	var row := character(slot,hero)
	if id not in row.owned_weapons or not Weapons.compatible(hero,id): return false
	if data.version == 2:
		for item in row.inventory:
			if item.item_id == id:
				Equipment.equip(row,int(item.uid))
				break
	else: row.weapon_id = id
	data.characters["%d:%s" % [slot,hero]] = row
	return true

func capture_chapter(chapter: int, completed: bool) -> void:
	data.chapter = chapter
	if completed:
		data.completed_chapter = maxi(int(data.get("completed_chapter",0)),chapter)
		data.chapter = mini(chapter + 1,24)

func save() -> Error:
	if blocked or not valid(data): return ERR_INVALID_DATA
	# A newer game may have saved while this instance was still open.
	if _protect_unknown_version(_read(path,false)): return ERR_INVALID_DATA
	var absolute := ProjectSettings.globalize_path(path)
	var temp := absolute + ".tmp"
	var err := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if err != OK: return err
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK or _read(temp).is_empty(): return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(absolute):
		if _read(absolute).is_empty():
			# Keep a damaged primary for recovery; never replace the known-good backup with it.
			err = DirAccess.rename_absolute(absolute,absolute + ".corrupt-" + str(Time.get_ticks_usec()))
		else:
			if FileAccess.file_exists(absolute + ".bak"):
				err = DirAccess.remove_absolute(absolute + ".bak")
				if err != OK: return err
			err = DirAccess.rename_absolute(absolute,absolute + ".bak")
		if err != OK: return err
	return DirAccess.rename_absolute(temp,absolute)
