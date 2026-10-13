extends RefCounted

const Weapons = preload("res://core/weapon_catalog.gd")
const CAPACITY := 120
const TREASURES := preload("res://core/talisman_catalog.gd").ITEMS

static func catalog(id: String) -> Dictionary:
	if TREASURES.has(id): return TREASURES[id]
	if not Weapons.ITEMS.has(id): return {}
	var row: Dictionary = Weapons.item(id).duplicate()
	row.durability = int(row.get("durability", {"sword":120,"spear":150,"bow":100}[row.family] + int(row.tier) * 24 + Weapons.ITEMS.keys().find(id) % 4 * 8))
	row.price = 80 + int(row.tier) * 100
	row.description = str(row.history)
	return row

static func ensure(row: Dictionary) -> void:
	if not row.has("inventory"):
		row.inventory = []
		row.next_item_uid = 1
		row.weapon_uid = 0
		row.treasure_uid = 0
		for id in row.get("owned_weapons", [Weapons.default_for(str(row.get("kind",row.get("hero","nobunaga"))))]):
			var uid := add(row,str(id))
			if id == row.get("weapon_id",""): row.weapon_uid = uid
	if not row.has("gold"): row.gold = 0
	if not row.has("achievements"): row.achievements = []
	# JSON numbers arrive as floats; instance IDs must also work in array membership checks.
	for field in ["next_item_uid","weapon_uid","treasure_uid","gold"]: row[field] = int(row[field])
	for item in row.inventory:
		item.uid = int(item.uid)
		item.durability = int(item.durability)
	var hero := str(row.get("hero",row.get("kind","")))
	if hero == "hideyoshi" and not Weapons.compatible(hero,str(instance(row,int(row.weapon_uid)).get("item_id",""))) and int(row.weapon_uid) != 0:
		row.weapon_uid = 0
		for item in row.inventory:
			if Weapons.compatible(hero,item.item_id): row.weapon_uid = item.uid; break
		if int(row.weapon_uid) == 0: row.weapon_uid = add(row,Weapons.default_for(hero))
	sync(row)

static func add(row: Dictionary, id: String) -> int:
	var spec := catalog(id)
	if spec.is_empty() or row.inventory.size() >= CAPACITY: return 0
	var uid := int(row.next_item_uid)
	row.next_item_uid = uid + 1
	row.inventory.append({"uid":uid,"item_id":id,"durability":int(spec.durability)})
	return uid

static func instance(row: Dictionary, uid: int) -> Dictionary:
	for item in row.get("inventory",[]):
		if int(item.uid) == uid: return item
	return {}

static func sync(row: Dictionary) -> void:
	var weapon := instance(row,int(row.get("weapon_uid",0)))
	row.weapon_id = str(weapon.get("item_id",""))
	row.owned_weapons = []
	for item in row.get("inventory",[]):
		if Weapons.ITEMS.has(item.item_id) and item.item_id not in row.owned_weapons: row.owned_weapons.append(item.item_id)
	var charm := instance(row,int(row.get("treasure_uid",0)))
	row.shield_kind = str(charm.get("item_id",""))
	row.shield_points = int(charm.get("durability",0))
	row.treasure_reach = bonus(row,"reach_bonus")

static func equip(row: Dictionary, uid: int) -> bool:
	var item := instance(row,uid)
	if item.is_empty(): return false
	if TREASURES.has(item.item_id): row.treasure_uid = uid
	elif Weapons.compatible(str(row.get("hero",row.get("kind",""))),item.item_id): row.weapon_uid = uid
	else: return false
	sync(row)
	return true

static func remove(row: Dictionary, uid: int) -> void:
	var item := instance(row,uid)
	row.inventory.erase(item)
	if int(row.weapon_uid) == uid:
		row.weapon_uid = 0
		for spare in row.inventory:
			if Weapons.compatible(str(row.get("hero",row.get("kind",""))),spare.item_id):
				row.weapon_uid = spare.uid
				break
	if int(row.treasure_uid) == uid: row.treasure_uid = 0
	sync(row)

static func sale_price(item: Dictionary) -> int:
	var spec := catalog(str(item.item_id))
	return maxi(1,roundi(float(spec.price) * float(item.durability) / float(spec.durability)))

static func sell(row: Dictionary, uid: int) -> int:
	var item := instance(row,uid)
	if item.is_empty() or uid in [int(row.weapon_uid),int(row.treasure_uid)]: return 0
	var price := sale_price(item)
	if int(row.gold) + price > 1000000000: return 0
	row.gold += price
	remove(row,uid)
	return price

static func bonus(row: Dictionary, field: String) -> float:
	var charm := instance(row,int(row.get("treasure_uid",0)))
	return float(TREASURES.get(str(charm.get("item_id","")),{}).get(field,0))

static func damage_multiplier(row: Dictionary, action: String) -> float:
	var field: String = {"heavy":"heavy_bonus","dash_heavy":"heavy_bonus","upper_heavy":"heavy_bonus","ground_slam":"heavy_bonus","charged":"charged_bonus","charged_upper":"charged_bonus","charged_slam":"charged_bonus","air_light":"air_bonus","air_heavy":"air_bonus","throw":"throw_bonus","special":"special_bonus"}.get(action,"")
	return 1.0 + bonus(row,field)

static func reduction(row: Dictionary) -> float:
	var charm := instance(row,int(row.get("treasure_uid",0)))
	var spec: Dictionary = TREASURES.get(str(charm.get("item_id","")),{})
	return float(spec.get("reduction",0)) * float(charm.get("durability",0)) / maxf(1,float(spec.get("durability",1)))

static func absorb(row: Dictionary, damage: int) -> int:
	var charm := instance(row,int(row.get("treasure_uid",0)))
	if charm.is_empty(): return 0
	var spec: Dictionary = TREASURES[charm.item_id]
	var absorbed := mini(damage,int(charm.durability)) if spec.mode == "fixed" else mini(int(charm.durability),mini(damage,ceili(damage * reduction(row))))
	charm.durability -= absorbed
	if int(charm.durability) <= (0 if spec.mode == "fixed" else int(spec.durability) / 5): remove(row,int(charm.uid))
	else: sync(row)
	return absorbed

static func valid(row: Dictionary) -> bool:
	if not row.get("inventory") is Array or row.inventory.size() > CAPACITY: return false
	for field in ["next_item_uid","weapon_uid","treasure_uid","gold"]:
		if not _integer(row.get(field),1 if field == "next_item_uid" else 0,1000000000): return false
	var seen := {}
	for item in row.inventory:
		if not item is Dictionary or not _integer(item.get("uid"),1,int(row.next_item_uid)-1) or seen.has(item.uid): return false
		var spec := catalog(str(item.get("item_id","")))
		if spec.is_empty() or not _integer(item.get("durability"),1,int(spec.durability)): return false
		if Weapons.ITEMS.has(item.item_id) and not Weapons.can_store(str(row.get("hero",row.get("kind",""))),item.item_id): return false
		if TREASURES.has(item.item_id) and spec.mode == "percent" and item.durability <= int(spec.durability) / 5: return false
		seen[item.uid] = item.item_id
	if row.weapon_uid != 0 and not Weapons.can_store(str(row.get("hero",row.get("kind",""))),str(seen.get(row.weapon_uid,""))): return false
	if row.treasure_uid != 0 and not TREASURES.has(seen.get(row.treasure_uid,"")): return false
	if row.get("weapon_id","") != seen.get(row.weapon_uid,""): return false
	if row.has("shield_kind") and row.shield_kind != seen.get(row.treasure_uid,""): return false
	if row.has("shield_points") and int(row.shield_points) != int(instance(row,int(row.treasure_uid)).get("durability",0)): return false
	if row.has("treasure_reach") and row.treasure_reach != bonus(row,"reach_bonus"): return false
	if not row.get("owned_weapons") is Array: return false
	var owned: Array = []
	for id in seen.values():
		if Weapons.ITEMS.has(id) and id not in owned: owned.append(id)
	if row.owned_weapons != owned: return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high
