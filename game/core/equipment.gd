extends RefCounted

const Weapons = preload("res://core/weapon_catalog.gd")
const CAPACITY := 120
const BAG_WEAPONS := 2
const BAG_TREASURES := 2
const FOODS := {
	"food_rice":{"name":"飯糰","heal":40,"durability":1,"price":0},
	"food_fish":{"name":"烤魚","heal":40,"durability":1,"price":0},
	"food_dango":{"name":"糰子","heal":40,"durability":1,"price":0},
	"food_peach":{"name":"桃子","heal":40,"durability":1,"price":0}
}
const TREASURES := preload("res://core/talisman_catalog.gd").ITEMS

static func catalog(id: String) -> Dictionary:
	if FOODS.has(id): return FOODS[id]
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
			if is_practice(str(id)): continue
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
	if int(row.weapon_uid) != 0 and (is_practice(str(instance(row,int(row.weapon_uid)).get("item_id",""))) or not Weapons.compatible(hero,str(instance(row,int(row.weapon_uid)).get("item_id","")))):
		row.weapon_uid = 0
	if not row.has("bag_uids"):
		row.bag_uids = []
		for uid in [int(row.weapon_uid),int(row.treasure_uid)]:
			if uid != 0: row.bag_uids.append(uid)
	for index in range(row.bag_uids.size()): row.bag_uids[index] = int(row.bag_uids[index])
	sync(row)

static func is_practice(id: String) -> bool:
	return id.begins_with("practice_")

static func bag_count(row: Dictionary, treasure: bool) -> int:
	var count := 0
	for uid in row.get("bag_uids",[]):
		var item := instance(row,int(uid))
		if not item.is_empty() and not FOODS.has(item.item_id) and TREASURES.has(item.item_id) == treasure: count += 1
	return count

static func pack(row: Dictionary, uid: int, carry: bool) -> bool:
	var item := instance(row,uid)
	if item.is_empty() or is_practice(item.item_id) or row.get("bag_only",false): return false
	if carry:
		if uid in row.bag_uids: return true
		var treasure := TREASURES.has(item.item_id)
		if not treasure and not FOODS.has(item.item_id) and not Weapons.compatible(str(row.get("hero",row.get("kind",""))),item.item_id): return false
		if not FOODS.has(item.item_id) and bag_count(row,treasure) >= (BAG_TREASURES if treasure else BAG_WEAPONS): return false
		row.bag_uids.append(uid)
	else:
		row.bag_uids.erase(uid)
		if int(row.weapon_uid) == uid: row.weapon_uid = 0
		if int(row.treasure_uid) == uid: row.treasure_uid = 0
	sync(row)
	return true

static func add(row: Dictionary, id: String) -> int:
	var spec := catalog(id)
	if spec.is_empty() or row.inventory.size() + int(row.get("storage_reserve",0)) >= CAPACITY: return 0
	if row.get("bag_only",false):
		if is_practice(id): return 0
		var treasure := TREASURES.has(id)
		if not FOODS.has(id) and bag_count(row,treasure) >= (BAG_TREASURES if treasure else BAG_WEAPONS): return 0
	var uid := int(row.next_item_uid)
	row.next_item_uid = uid + 1
	row.inventory.append({"uid":uid,"item_id":id,"durability":int(spec.durability)})
	if row.get("bag_only",false): row.bag_uids.append(uid)
	return uid

static func instance(row: Dictionary, uid: int) -> Dictionary:
	for item in row.get("inventory",[]):
		if int(item.uid) == uid: return item
	return {}

static func sync(row: Dictionary) -> void:
	var weapon := instance(row,int(row.get("weapon_uid",0)))
	var hero := str(row.get("hero",row.get("kind","nobunaga")))
	row.weapon_id = str(weapon.get("item_id",Weapons.default_for(hero)))
	row.owned_weapons = [Weapons.default_for(hero)]
	for item in row.get("inventory",[]):
		if Weapons.ITEMS.has(item.item_id) and item.item_id not in row.owned_weapons: row.owned_weapons.append(item.item_id)
	var charm := instance(row,int(row.get("treasure_uid",0)))
	row.shield_kind = str(charm.get("item_id",""))
	row.shield_points = int(charm.get("durability",0))
	row.treasure_reach = bonus(row,"reach_bonus")

static func equip(row: Dictionary, uid: int) -> bool:
	if uid == 0:
		row.weapon_uid = 0
		sync(row)
		return true
	var item := instance(row,uid)
	if item.is_empty() or FOODS.has(item.item_id): return false
	if is_practice(item.item_id): return equip(row,0)
	if uid not in row.get("bag_uids",[]) and not pack(row,uid,true): return false
	if TREASURES.has(item.item_id): row.treasure_uid = uid
	elif Weapons.compatible(str(row.get("hero",row.get("kind",""))),item.item_id): row.weapon_uid = uid
	else: return false
	sync(row)
	return true

static func remove(row: Dictionary, uid: int) -> void:
	var item := instance(row,uid)
	row.inventory.erase(item)
	row.get("bag_uids",[]).erase(uid)
	if int(row.weapon_uid) == uid:
		row.weapon_uid = 0
	if int(row.treasure_uid) == uid: row.treasure_uid = 0
	sync(row)

static func sale_price(item: Dictionary) -> int:
	if FOODS.has(item.item_id): return 0
	var spec := catalog(str(item.item_id))
	return maxi(1,roundi(float(spec.price) * float(item.durability) / float(spec.durability)))

static func sell(row: Dictionary, uid: int) -> int:
	var item := instance(row,uid)
	if item.is_empty() or FOODS.has(item.item_id) or uid in [int(row.weapon_uid),int(row.treasure_uid)]: return 0
	var price := sale_price(item)
	if int(row.gold) + price > 1000000000: return 0
	row.gold += price
	remove(row,uid)
	return price

static func bonus(row: Dictionary, field: String) -> float:
	var charm := instance(row,int(row.get("treasure_uid",0)))
	return float(TREASURES.get(str(charm.get("item_id","")),{}).get(field,0))

static func damage_multiplier(row: Dictionary, action: String) -> float:
	var field: String = {"heavy":"heavy_bonus","dash_heavy":"heavy_bonus","upper_heavy":"heavy_bonus","ground_slam":"heavy_bonus","charged":"charged_bonus","charge_rain":"charged_bonus","charged_upper":"charged_bonus","charged_slam":"charged_bonus","air_light":"air_bonus","air_heavy":"air_bonus","throw":"throw_bonus","special":"special_bonus"}.get(action,"")
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
		if not item is Dictionary or not _integer(item.get("uid"),1,int(row.next_item_uid)-1) or seen.has(int(item.uid)): return false
		var spec := catalog(str(item.get("item_id","")))
		if spec.is_empty() or not _integer(item.get("durability"),1,int(spec.durability)): return false
		if Weapons.ITEMS.has(item.item_id) and not Weapons.can_store(str(row.get("hero",row.get("kind",""))),item.item_id): return false
		if TREASURES.has(item.item_id) and spec.mode == "percent" and item.durability <= int(spec.durability) / 5: return false
		seen[int(item.uid)] = item.item_id
	if row.weapon_uid != 0 and not Weapons.can_store(str(row.get("hero",row.get("kind",""))),str(seen.get(int(row.weapon_uid),""))): return false
	if row.treasure_uid != 0 and not TREASURES.has(seen.get(int(row.treasure_uid),"")): return false
	var baseline := Weapons.default_for(str(row.get("hero",row.get("kind","nobunaga"))))
	if row.get("weapon_id","") != seen.get(int(row.weapon_uid),baseline) and not (row.weapon_uid == 0 and row.get("weapon_id","") == ""): return false
	if row.has("shield_kind") and row.shield_kind != seen.get(int(row.treasure_uid),""): return false
	if row.has("shield_points") and int(row.shield_points) != int(instance(row,int(row.treasure_uid)).get("durability",0)): return false
	if row.has("treasure_reach") and row.treasure_reach != bonus(row,"reach_bonus"): return false
	if not row.get("owned_weapons") is Array: return false
	var owned: Array = [baseline] if baseline in row.owned_weapons else []
	for id in seen.values():
		if Weapons.ITEMS.has(id) and id not in owned: owned.append(id)
	if row.owned_weapons != owned: return false
	if row.has("bag_uids"):
		if not row.bag_uids is Array or row.bag_uids.size() > CAPACITY: return false
		var packed := []
		for uid in row.bag_uids:
			if not _integer(uid,1,int(row.next_item_uid)-1) or not seen.has(int(uid)) or int(uid) in packed or is_practice(str(seen[int(uid)])): return false
			if not TREASURES.has(seen[int(uid)]) and not FOODS.has(seen[int(uid)]) and not Weapons.compatible(str(row.get("hero",row.get("kind",""))),seen[int(uid)]): return false
			packed.append(int(uid))
		if bag_count(row,true) > BAG_TREASURES or bag_count(row,false) > BAG_WEAPONS: return false
		for uid in [int(row.weapon_uid),int(row.treasure_uid)]:
			if uid != 0 and uid not in packed: return false
	if row.has("bag_only"):
		if not row.bag_only is bool: return false
		if row.bag_only and (not row.has("bag_uids") or row.bag_uids.size() != row.inventory.size()): return false
	if row.has("storage_reserve") and (not _integer(row.storage_reserve,0,CAPACITY) or row.inventory.size() + row.storage_reserve > CAPACITY): return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high
