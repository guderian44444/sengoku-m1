extends RefCounted

const Weapons = preload("res://core/weapon_catalog.gd")
const DATA_PATH := "res://assets/v22/weapons/encyclopedia.json"
var entries: Dictionary = {}
var warning := ""

func _init(path: String = DATA_PATH) -> void:
	if not FileAccess.file_exists(path):
		warning = "史料資料尚未載入。"
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		warning = "史料資料格式錯誤；能力值仍以遊戲資料為準。"
		return
	entries = parsed

func entry(id: String) -> Dictionary:
	var item: Dictionary = Weapons.item(id)
	var raw: Variant = entries.get(id,{})
	var result: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	result["display_name"] = result.get("display_name",item.get("name",id))
	result["historical_type"] = result.get("historical_type","形制待考")
	result["period"] = result.get("period","年代待考")
	result["facts"] = result.get("facts",[item.get("history","史料待補。")])
	result["dimensions"] = result.get("dimensions",{})
	result["attribution_note"] = result.get("attribution_note","歷史形制與人物持有關係須分別考證。")
	result["game_note"] = result.get("game_note","階位、裝具、傷害與元素屬遊戲設計，不代表史實優劣。")
	result["sources"] = result.get("sources",[{"title":"原始館藏／官方資料","url":item.get("source",""),"institution":""}])
	result["reference_images"] = result.get("reference_images",[])
	return result

# Unknown rights never become an image merely because a URL exists.
static func image_allowed(reference: Dictionary) -> bool:
	var local_path := str(reference.get("local_path",""))
	return reference.get("embed_allowed",false) == true and license_confirmed(reference) and local_path.begins_with("res://assets/v22/weapons/references/") and not local_path.contains("..") and safe_url(str(reference.get("source_url",""))) and not str(reference.get("credit","")).is_empty()

static func license_confirmed(reference: Dictionary) -> bool:
	var license_name := str(reference.get("license","")).strip_edges().to_lower()
	return license_name in ["cc0", "cc0 1.0", "cc0 / public domain", "public domain", "public domain (pd-japan-oldphoto / pd-us)", "cc by 4.0", "cc-by-4.0", "cc by-sa 4.0", "cc-by-sa-4.0", "cc by-sa 2.0 fr"]

static func safe_url(url: String) -> bool:
	return url.begins_with("https://") and not url.contains("\n") and not url.contains("\r") and not url.contains(" ")

static func stats(id: String) -> String:
	var item: Dictionary = Weapons.item(id)
	if item.is_empty(): return "尚無遊戲能力資料"
	var element := str(item.get("element",""))
	return "階位　%d\n傷害加成　%s\n攻速　%d%%\n攻擊距離加成　%s\n擊退加成　%s\n耐久上限　%d\n特殊能力　%s\n元素　%s" % [int(item.tier),signed_value(item.damage_bonus),roundi(float(item.get("attack_speed",1.0))*100),signed_value(item.reach_bonus),signed_value(item.knockback),int(item.get("durability",180)),str(item.get("special","無")),{"":"無","fire":"火","ice":"冰","earth":"地","blade":"刃"}.get(element,element)]

func history(id: String) -> String:
	var info := entry(id)
	var lines: Array[String] = [str(info.historical_type) + "　｜　" + str(info.period)]
	var labels := {"blade_cm":"刃長","total_cm":"全長","curvature_cm":"反","catalogue_length_cm":"館載長度","tang_cm":"茎長","base_width_cm":"元幅","blade_lower_bound_cm":"刃長大於"}
	for key in labels:
		if info.dimensions.get(key) != null: lines.append("%s %s cm" % [labels[key],str(info.dimensions[key])])
	for fact in info.facts: lines.append(str(fact))
	if not str(info.attribution_note).is_empty(): lines.append(str(info.attribution_note))
	return "\n".join(lines)

static func signed_value(value: Variant) -> String:
	return ("+" if float(value) >= 0 else "") + str(value)
