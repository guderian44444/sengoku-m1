extends RefCounted

const FrameAnimation = preload("res://render/frame_animation.gd")

# shortcut: portable projects load raw PNGs; include these files when producing a game export.
const ROOT := "res://assets/v03/"
const ANIMATION_ROOT := "res://assets/v04/"
const UPGRADE_ROOT := "res://assets/v05/"
const LATEST_ROOT := "res://assets/v06/"
const REFINED_ROOT := "res://assets/v07/"
const COMBAT_ROOT := "res://assets/v09/"
const EXPANDED_ROOT := "res://assets/v10/"
# Measured shoe contacts in each source cell; VFX never determine figure scale.
const ANIMATION_BODY_HEIGHTS := {
	"nobunaga": {"motion": 245.0, "attacks": 215.0, "special": 205.0, "physical": 240.0},
	"oichi": {"motion": 270.0, "attacks": 225.0, "special": 225.0, "physical": 245.0}
}
const SUPPORT_OFFSET := {"nobunaga": 95.0 / 245.0, "oichi": 62.75 / 270.0}
# Irregular atlas gutters retain full swords/shoes and exclude neighboring drawings.
const NOBUNAGA_REGIONS := {
	"motion": {4: Rect2i(0,341,404,342), 5: Rect2i(412,341,356,342), 8: Rect2i(0,683,404,341), 9: Rect2i(416,683,352,341)},
	"attacks": {0: Rect2i(0,0,384,360), 1: Rect2i(384,0,384,360), 2: Rect2i(768,0,384,360), 3: Rect2i(1152,0,384,360), 4: Rect2i(0,370,384,313), 5: Rect2i(384,370,410,313), 6: Rect2i(798,370,354,313), 7: Rect2i(1152,370,384,313), 9: Rect2i(384,683,410,341), 10: Rect2i(800,683,352,341)},
	"special": {3: Rect2i(1152,0,384,358), 7: Rect2i(1152,365,384,318)}
}
const SUPPORT_FEET := {
	"nobunaga": {
		"motion": [Vector2(90,332), Vector2(98,331), Vector2(92,332), Vector2(70,332), Vector2(116,303), Vector2(151,304), Vector2(101,304), Vector2(134,304), Vector2(161,265), Vector2(143,266), Vector2(87,264), Vector2(72,267)],
		"attacks": [Vector2(80,338), Vector2(121,337), Vector2(112,337), Vector2(140,337), Vector2(78,303), Vector2(64,303), Vector2(88,303), Vector2(91,303), Vector2(85,270), Vector2(82,270), Vector2(96,270), Vector2(83,269)],
		"special": [Vector2(85,335), Vector2(112,335), Vector2(94,335), Vector2(90,335), Vector2(80,321), Vector2(61,321), Vector2(89,322), Vector2(109,321), Vector2(85,284), Vector2(109,284), Vector2(100,284), Vector2(104,284)],
		"physical": [Vector2(205,317), Vector2(200,317), Vector2(178,317), Vector2(172,317), Vector2(104,297), Vector2(127,298), Vector2(101,299), Vector2(94,299), Vector2(120,276), Vector2(111,277), Vector2(124,276), Vector2(122,277)]
	},
	"oichi": {
		"motion": [Vector2(150,334), Vector2(141,334), Vector2(130.5,334), Vector2(120.5,334), Vector2(132.5,312), Vector2(206,313), Vector2(114.5,313), Vector2(219.5,313), Vector2(123,294), Vector2(163,297), Vector2(101,297), Vector2(124,298)],
		"attacks": [Vector2(138,313), Vector2(133,312), Vector2(127.5,312), Vector2(85.5,312), Vector2(85.5,294), Vector2(104.5,294), Vector2(104.5,293), Vector2(133.5,298), Vector2(125,282), Vector2(112.5,282), Vector2(106.5,282), Vector2(137,282)],
		"special": [Vector2(111.5,328), Vector2(115.5,328), Vector2(68,328), Vector2(84.5,329), Vector2(77.5,315), Vector2(113,315), Vector2(148,317), Vector2(136,319), Vector2(113,297), Vector2(115.5,298), Vector2(83.5,298), Vector2(111.5,300)],
		"physical": [Vector2(213,318), Vector2(211,318), Vector2(205,318), Vector2(218,318), Vector2(123.5,301), Vector2(137,301), Vector2(104,300), Vector2(152,301), Vector2(146,297), Vector2(152,297), Vector2(149,297), Vector2(153,297)]
	}
}
const POSES := ["idle", "light", "heavy", "charge", "jump", "throw", "hurt", "special", "victory"]
# Feet are anchored to the figure, not to the bounds of baked weapon trails or victims.
const HERO_ANCHORS := {
	"nobunaga": [Vector2(263, 309), Vector2(747, 309), Vector2(1239, 309), Vector2(263, 648), Vector2(756, 609), Vector2(1251, 646), Vector2(352, 954), Vector2(764, 940), Vector2(1259, 960)],
	"oichi": [Vector2(249, 322), Vector2(695, 321), Vector2(1192, 321), Vector2(245, 631), Vector2(690, 611), Vector2(1213, 629), Vector2(262, 937), Vector2(766, 924), Vector2(1279, 948)]
}
const HERO_BODY_HEIGHT := {"nobunaga": 248.0, "oichi": 232.0}
# The final special cells were reduced to contain their effects; undo that source reduction.
const SPECIAL_SOURCE_SCALE := {"nobunaga": 0.74, "oichi": 0.8}

var heroes: Dictionary = {}
var animations: Dictionary = {}
var enemies: Dictionary = {}
var enemy_reactions: Dictionary = {}
var enemy_movements: Dictionary = {}
var enemy_attacks: Dictionary = {}
var enemy_clips: Dictionary = {}
var v11_counts: Dictionary = {}
var combat_registration: Dictionary = {}
var expanded_registration: Dictionary = {}
var enemy_clip_sizes: Dictionary = {}
var npc_frames: Dictionary = {}
var prop_frames: Dictionary = {}
var weather_frames: Array = []
var scenery_frames: Array = []
var villager_frames: Array = []
var day_frame: Dictionary = {}

func _init() -> void:
	for hero in ["nobunaga", "oichi"]:
		var frames := _load_grid(ROOT + hero + "-transparent.png", 3, 3, true)
		if frames.size() == 9:
			for index in range(9):
				var texture_size: Vector2 = frames[index].texture.get_size()
				var source_scale := texture_size / Vector2(1536, 1024)
				frames[index]["anchor"] = HERO_ANCHORS[hero][index] * source_scale - frames[index].region.position
				frames[index]["body_height"] = HERO_BODY_HEIGHT[hero] * source_scale.y * (SPECIAL_SOURCE_SCALE[hero] if index == 7 else 1.0)
			heroes[hero] = frames
		_load_animation(hero)
		_load_upgrade(hero)
		_load_upgrade(hero, LATEST_ROOT, "v06", hero == "oichi")
		_load_upgrade(hero, REFINED_ROOT, "v07", hero == "nobunaga")
	_load_combat_atlases()
	_load_combat_atlases(EXPANDED_ROOT, "v10")
	_load_combat_atlases("res://assets/v11/", "v11")
	_load_combat_atlases("res://assets/v12/", "v12")
	_load_combat_atlases("res://assets/v13/", "v13")
	_load_combat_atlases("res://assets/v14/", "v14")
	_load_combat_atlases("res://assets/v15/", "v15")
	_load_combat_atlases("res://assets/v16/", "v16")
	_load_combat_atlases("res://assets/v17/", "v17")
	_load_combat_atlases("res://assets/v19/enemies/", "v19")
	weather_frames = _load_grid(ROOT + "castle-road-weather-v03.png", 1, 3)
	scenery_frames = _load_grid(ROOT + "scenery-sprites-v03.png", 4, 2, true)
	villager_frames = _load_grid(ANIMATION_ROOT + "scenery/villager-walk-run.png", 4, 2, true)
	for index in range(villager_frames.size()):
		var texture_size: Vector2 = villager_frames[index].texture.get_size()
		var cell := cell_rect(Vector2i(texture_size), 4, 2, index)
		var source_scale := texture_size / Vector2(1536, 1024)
		var foot := Vector2(192, 478 if index < 4 else 446)
		villager_frames[index]["anchor"] = Vector2(cell.position) + foot * source_scale - villager_frames[index].region.position
		villager_frames[index]["body_height"] = 388.0 * source_scale.y
	_load_villager_upgrade()
	var day := _load_grid(ROOT + "castle-road-day-v03.png", 1, 1)
	if not day.is_empty():
		day_frame = day[0]

func hero_frame(hero: String, pose: int) -> Dictionary:
	if not heroes.has(hero):
		return animations[hero].combat[0] if has_v10(hero) else {}
	return heroes[hero][clampi(pose, 0, 8)]

func has_animation(hero: String) -> bool:
	return animations.has(hero)

func has_combo(hero: String) -> bool:
	return animations.has(hero) and animations[hero].has("combo")

func has_v06(hero: String) -> bool:
	return animations.has(hero) and animations[hero].has("attacks") and animations[hero].attacks[0].get("source", "") in ["v06", "v07"]

func has_v10(hero: String) -> bool:
	return animations.has(hero) and animations[hero].has("combat") and animations[hero].combat[0].get("source", "") == "v10"

func has_enemy_v10(kind: String, faction: String = "mori") -> bool:
	var key := _enemy_key(kind, faction)
	return enemies.has(key) and enemies[key][0].get("source", "") == "v10"

func enemy_clip_size(kind: String, faction: String = "mori") -> int:
	return int(enemy_clip_sizes.get(_enemy_key(kind, faction), 4))

func animation_source(hero: String, sample: Dictionary) -> String:
	var frame := animation_frame(hero, sample)
	return str(frame.get("source", "v04")) if not frame.is_empty() else "v03"

func animation_frame(hero: String, sample: Dictionary) -> Dictionary:
	if not animations.has(hero) or not animations[hero].has(sample.sheet):
		return {}
	var frames: Array = animations[hero][sample.sheet]
	return frames[clampi(int(sample.cell), 0, frames.size() - 1)] if not frames.is_empty() else {}

func _enemy_key(kind: String, faction: String) -> String:
	var faction_key := kind + "-" + faction
	return faction_key if enemies.has(faction_key) else kind

func enemy_frame(kind: String, cell: int, faction: String = "mori", sheet: String = "enemy") -> Dictionary:
	if sheet.begins_with("enemy_clip:"):
		var frames: Array = enemy_clips.get(sheet.trim_prefix("enemy_clip:"),[])
		return frames[clampi(cell,0,frames.size() - 1)] if not frames.is_empty() else {}
	var key := _enemy_key(kind, faction)
	var source: Dictionary = {"enemy_reaction":enemy_reactions,"enemy_movement":enemy_movements,"enemy_attack":enemy_attacks}.get(sheet,enemies)
	return source[key][clampi(cell, 0, source[key].size() - 1)] if source.has(key) else {}

func npc_frame(kind: String, cell: int) -> Dictionary:
	return npc_frames[kind][clampi(cell, 0, npc_frames[kind].size() - 1)] if npc_frames.has(kind) else {}

func prop_frame(kind: String, damage: int) -> Dictionary:
	return prop_frames[kind][clampi(damage, 0, prop_frames[kind].size() - 1)] if prop_frames.has(kind) else {}

func has_techniques(hero: String) -> bool:
	return animations.has(hero) and animations[hero].has("techniques")

func _load_combat_atlases(asset_root: String = COMBAT_ROOT, version: String = "v09") -> void:
	var path := asset_root + "registration.json"
	if not FileAccess.file_exists(path): return
	var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not registration is Dictionary: return
	if version == "v10":
		for extra_name in ["hero-registration.json", "boss-registration.json", "troop-registration.json"]:
			var extra_path: String = asset_root + str(extra_name)
			if not FileAccess.file_exists(extra_path): continue
			var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
			if extra is Dictionary and extra.get("actors", {}) is Dictionary:
				registration.actors.merge(extra.get("actors", {}), true)
	var runtime_registration: Dictionary = registration.duplicate(true)
	if version == "v10": expanded_registration = runtime_registration
	elif version == "v09": combat_registration = runtime_registration
	for actor in registration.get("actors", {}):
		var spec: Dictionary = registration.actors[actor]
		var columns := int(spec.get("columns", 4))
		var rows := int(spec.get("rows", 2 if str(actor).ends_with("-air") else 4))
		var count := rows * columns
		if columns <= 0 or rows <= 0 or spec.get("feet", []).size() != count or float(spec.get("body_height", 0)) <= 0: continue
		if spec.has("body_heights") and spec.body_heights.size() != count: continue
		var regions: Dictionary = {}
		for key in spec.get("regions", {}):
			var region: Array = spec.regions[key]
			if region.size() != 4: continue
			regions[int(key)] = Rect2i(region[0], region[1], region[2], region[3])
		var frame_files := {}
		for index in spec.get("frame_files",{}): frame_files[int(index)] = asset_root + str(spec.frame_files[index])
		var frames := _load_grid(asset_root + str(spec.get("file",str(actor) + ".png")), columns, rows, true, regions, frame_files, version in ["v16", "v17", "v19"])
		if frames.size() != count: continue
		var hero := str(spec.get("hero", str(actor).trim_suffix("-air").trim_suffix("-advanced")))
		var target := str(spec.get("target", "hero" if animations.has(hero) else "enemy"))
		var sheet := str(spec.get("sheet", "air" if str(actor).ends_with("-air") else ("advanced" if str(actor).ends_with("-advanced") else "techniques")))
		if version == "v11": v11_counts[str(actor)] = spec.get("frame_counts", [])
		var source_images := {}
		var unplanted: Array[int] = []
		for index in spec.get("unplanted",[]): unplanted.append(int(index))
		runtime_registration.actors[actor]["regions"] = {}
		runtime_registration.actors[actor]["clip_polygons"] = {}
		runtime_registration.actors[actor]["anchors_global"] = []
		for index in range(count):
			var cell := cell_rect(frames[index].get("source_size", Vector2i(frames[index].texture.get_size())), columns, rows, index)
			var foot: Array = spec.feet[index]
			if foot.size() != 2: continue
			var source_region: Rect2 = frames[index].get("source_region", frames[index].region)
			var frame_padding: Vector2 = frames[index].get("frame_padding", Vector2.ZERO)
			var support: Vector2 = (Vector2.ZERO if spec.get("feet_global", false) else Vector2(cell.position)) + Vector2(foot[0], foot[1]) - source_region.position + frame_padding
			var body_height := float(spec.body_heights[index] if spec.has("body_heights") else spec.body_height)
			var planted: bool = index not in unplanted and not str(actor).ends_with("-air") and (target == "hero" or (target == "enemy" and index >= columns))
			var offset := float(SUPPORT_OFFSET.get(hero, spec.get("support_offset", 0.32 if target == "hero" else 0))) * body_height if planted else 0.0
			frames[index].merge({"anchor": support + Vector2(offset, 0), "support_point": support, "planted": planted, "body_height": body_height, "source": version})
			if spec.get("frame_ticks",[]).size() == count: frames[index]["frame_tick"] = int(spec.frame_ticks[index])
			var bounds: Rect2 = source_region
			var local_bounds: Rect2 = frames[index].region
			var global_anchor: Vector2 = frames[index].anchor + bounds.position - frame_padding
			runtime_registration.actors[actor].anchors_global.append([global_anchor.x,global_anchor.y])
			runtime_registration.actors[actor].regions[str(index)] = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
			if spec.get("component_clip", false):
				var texture_id: int = frames[index].texture.get_instance_id()
				if not source_images.has(texture_id): source_images[texture_id] = frames[index].texture.get_image()
				var polygon := _component_polygon(source_images[texture_id], Rect2i(local_bounds), float(spec.get("component_alpha_threshold", 0.30)))
				if not polygon.is_empty():
					frames[index]["clip_polygon"] = polygon
					var points := []
					for point in polygon: points.append([point.x + bounds.position.x,point.y + bounds.position.y])
					runtime_registration.actors[actor].clip_polygons[str(index)] = points
			var hands: Variant = spec.get("hands", {})
			var hand: Array = hands[index] if hands is Array and index < hands.size() else (hands.get(str(index), []) if hands is Dictionary else [])
			if hand.size() == 2:
				frames[index]["hand_offset"] = (Vector2.ZERO if spec.get("hands_global", false) else Vector2(cell.position)) + Vector2(hand[0], hand[1]) - source_region.position + frame_padding - frames[index].anchor
			var blade: Array = spec.get("blades", {}).get(str(index), [])
			if blade.size() == 2:
				var blade_origin: Vector2 = (Vector2.ZERO if spec.get("blades_global", false) else Vector2(cell.position)) - source_region.position + frame_padding - frames[index].anchor
				frames[index]["blade_offsets"] = [blade_origin + Vector2(blade[0][0],blade[0][1]), blade_origin + Vector2(blade[1][0],blade[1][1])]
		if target == "hero":
			if sheet == "motion" and frames.size() >= 4:
				var shoes := _slice_frame(frames[0], frames[0].region.position.y + frames[0].support_point.y - 22.0, false)
				for idle_index in range(4):
					frames[idle_index]["layers"] = [shoes, _slice_frame(frames[idle_index], frames[idle_index].region.position.y + frames[idle_index].support_point.y - 21.0, true)]
			if not animations.has(hero): animations[hero] = {}
			animations[hero][sheet] = frames
		elif target == "enemy_clip":
			var key := str(spec.get("key",str(spec.get("faction","mori")) + ":" + str(spec.get("kind",actor)) + ":" + sheet))
			enemy_clips[key] = frames
		elif target in ["enemy", "enemy_reaction", "enemy_movement", "enemy_attack"]:
			var destination: Dictionary = {"enemy_reaction":enemy_reactions,"enemy_movement":enemy_movements,"enemy_attack":enemy_attacks}.get(target,enemies)
			if spec.has("groups"):
				for kind in spec.groups:
					var group: Array = []
					for index in spec.groups[kind]:
						if int(index) >= 0 and int(index) < count: group.append(frames[int(index)])
					if not group.is_empty():
						destination[kind] = group
						if target == "enemy": enemy_clip_sizes[kind] = columns
			else:
				var kind := str(spec.get("kind", actor))
				enemies[kind] = frames
				enemy_clip_sizes[kind] = columns
		elif target in ["npc", "prop"]:
			var destination: Dictionary = npc_frames if target == "npc" else prop_frames
			for kind in spec.get("groups", {}):
				var group: Array = []
				for index in spec.groups[kind]:
					if int(index) >= 0 and int(index) < count: group.append(frames[int(index)])
				if not group.is_empty(): destination[kind] = group

func _component_polygon(image: Image, region: Rect2i, alpha_threshold: float = 0.30) -> PackedVector2Array:
	var mask := BitMap.new()
	mask.create_from_image_alpha(image.get_region(region), alpha_threshold)
	var best := PackedVector2Array()
	var best_area := 0.0
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,region.size),1.5):
		var area := 0.0
		for index in range(polygon.size()):
			area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
		if absf(area) > best_area:
			best_area = absf(area)
			best = polygon
	if not best.is_empty() and Geometry2D.triangulate_polygon(best).is_empty():
		best = Geometry2D.convex_hull(best)
	return best

func _load_upgrade(hero: String, asset_root: String = UPGRADE_ROOT, version: String = "v05", require_complete: bool = false) -> void:
	var path := asset_root + hero + "/registration.json"
	if not animations.has(hero) or not FileAccess.file_exists(path):
		return
	var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not registration is Dictionary or not registration.get("sheets", {}) is Dictionary:
		return
	var upgraded: Dictionary = {}
	for sheet in registration.sheets:
		var spec: Dictionary = registration.sheets[sheet]
		if spec.get("feet", []).size() != 12 or spec.get("row_starts", []).size() != 3 or float(spec.get("body_height", 0)) <= 0:
			continue
		var regions: Dictionary = {}
		for key in spec.get("regions", {}):
			var rect: Array = spec.regions[key]
			regions[int(key)] = Rect2i(rect[0], rect[1], rect[2], rect[3])
		var frames := _load_grid(asset_root + hero + "/" + sheet + ".png", 4, 3, true, regions)
		if frames.size() != 12:
			continue
		var unplanted: Array[int] = []
		for value in spec.get("unplanted", []): unplanted.append(int(value))
		for index in range(12):
			var body_height := float(spec.body_heights[index] if spec.has("body_heights") else spec.body_height)
			var source_origin := Vector2((index % 4) * 384, spec.row_starts[index / 4])
			var point: Array = spec.feet[index]
			var support: Vector2 = source_origin + Vector2(point[0], point[1]) - frames[index].region.position
			var planted: bool = index not in unplanted
			var offset := Vector2(-float(SUPPORT_OFFSET[hero]) * body_height, 0) if planted else Vector2.ZERO
			frames[index].merge({"anchor": support - offset, "support_point": support, "planted": planted, "body_height": body_height, "source": version})
			if spec.get("hands", {}).has(str(index)):
				var hand: Array = spec.hands[str(index)]
				frames[index]["hand_offset"] = source_origin + Vector2(hand[0], hand[1]) - frames[index].region.position - frames[index].anchor
			if spec.get("blades", {}).has(str(index)):
				var blade: Array = spec.blades[str(index)]
				frames[index]["blade_offsets"] = [source_origin + Vector2(blade[0][0], blade[0][1]) - frames[index].region.position - frames[index].anchor, source_origin + Vector2(blade[1][0], blade[1][1]) - frames[index].region.position - frames[index].anchor]
			if sheet == "motion" and index in [4, 5, 6, 7]:
				frames[index]["contacts"] = []
				for side in ["left_support", "right_support"]:
					if spec.get(side, []).size() != 12: continue
					var sole: Array = spec[side][index]
					if float(sole[1]) >= float(point[1]) - 6.0:
						frames[index].contacts.append(float(sole[0]) - float(point[0]))
		if sheet == "motion":
			var shoes := _slice_frame(frames[0], frames[0].region.position.y + frames[0].support_point.y - 22.0, false)
			for index in range(4):
				frames[index]["layers"] = [shoes, _slice_frame(frames[index], frames[index].region.position.y + frames[index].support_point.y - 21.0, true)]
		upgraded[sheet] = frames
	if require_complete:
		for sheet in ["motion", "combo", "attacks", "special", "physical"]:
			if not upgraded.has(sheet): return
	animations[hero].merge(upgraded, true)

func projectile_origin(sample: Dictionary, height: float) -> Vector2:
	var frame := animation_frame("oichi", sample)
	if frame.has("hand_offset"):
		return frame.hand_offset * height / float(frame.body_height)
	return needle_origin(str(sample.get("clip", "light")), height)

func needle_origin(clip: String, height: float) -> Vector2:
	if has_v06("oichi") and clip == "jump":
		var jump_frame: Dictionary = animations.oichi.physical[1]
		if jump_frame.has("hand_offset"):
			return jump_frame.hand_offset * height / float(jump_frame.body_height)
	if clip == "light" and has_combo("oichi"):
		var combo_frame: Dictionary = animations.oichi.combo[2]
		if combo_frame.has("hand_offset"):
			return combo_frame.hand_offset * height / float(combo_frame.body_height)
	if has_v06("oichi") and clip in ["heavy", "charged", "special"]:
		var bow := FrameAnimation.sample("special", 26) if clip == "special" else FrameAnimation.bow_sample(clip, 14)
		var bow_frame := animation_frame("oichi", bow)
		if bow_frame.has("hand_offset"):
			return bow_frame.hand_offset * height / float(bow_frame.body_height)
	var release := {"light": ["attacks", 10, Vector2(318,84)], "heavy": ["attacks", 4, Vector2(312,112)], "special": ["special", 4, Vector2(268,166)], "jump": ["physical", 2, Vector2(312,252)]}
	if not animations.has("oichi") or not release.has(clip):
		return Vector2(57, -131)
	var point: Array = release[clip]
	var frame: Dictionary = animations.oichi[point[0]][point[1]]
	var cell := int(point[1])
	if frame.has("hand_offset"):
		return frame.hand_offset * height / float(frame.body_height)
	var source := Vector2((cell % 4) * 384, floori((cell / 4) * 1024.0 / 3.0)) + Vector2(point[2])
	return (source - frame.region.position - frame.anchor) * height / float(frame.body_height)

func _load_villager_upgrade() -> void:
	var path := UPGRADE_ROOT + "scenery/registration.json"
	if not FileAccess.file_exists(path): return
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not spec is Dictionary or spec.get("feet", []).size() != 8 or float(spec.get("body_height", 0)) <= 0: return
	var regions: Dictionary = {}
	for key in spec.get("regions", {}):
		var rect: Array = spec.regions[key]
		regions[int(key)] = Rect2i(rect[0], rect[1], rect[2], rect[3])
	var frames := _load_grid(UPGRADE_ROOT + "scenery/villager-walk-run.png", 4, 2, true, regions)
	if frames.size() != 8: return
	for index in range(8):
		var point: Array = spec.feet[index]
		var source_origin := Vector2((index % 4) * 384, spec.get("row_starts", [0,512])[index / 4])
		frames[index]["anchor"] = source_origin + Vector2(point[0],point[1]) - frames[index].region.position
		frames[index]["body_height"] = float(spec.body_heights[index] if spec.has("body_heights") else spec.body_height)
		frames[index]["source"] = "v05"
	villager_frames = frames

func _load_animation(hero: String) -> void:
	var sheets: Dictionary = {}
	for sheet in ["motion", "attacks", "special", "physical"]:
		var regions: Dictionary = NOBUNAGA_REGIONS.get(sheet, {}) if hero == "nobunaga" else {}
		var frames := _load_grid(ANIMATION_ROOT + hero + "/" + sheet + ".png", 4, 3, true, regions)
		if frames.size() != 12:
			return
		for index in range(12):
			var texture_size: Vector2 = frames[index].texture.get_size()
			var source_scale := texture_size / Vector2(1536, 1024)
			var row := index / 4
			var top := floori(row * 1024.0 / 3.0) if hero == "oichi" else roundi(row * 1024.0 / 3.0)
			var source_origin := Vector2((index % 4) * 384, top) * source_scale
			var body_height := float(ANIMATION_BODY_HEIGHTS[hero][sheet])
			if hero == "oichi" and sheet == "physical" and index >= 8:
				body_height = 265.0
			var foot: Vector2 = SUPPORT_FEET[hero][sheet][index]
			var planted: bool = not (sheet == "motion" and index in [4, 5, 6, 7]) and not (sheet == "physical" and index < 4)
			if sheet == "motion" and index in [4, 5, 6, 7]:
				var centers := [202,194,186,185] if hero == "nobunaga" else [212,213,201,219]
				foot = Vector2(centers[index - 4], 305 if hero == "nobunaga" else 313)
			var support_point: Vector2 = source_origin + foot * source_scale - frames[index].region.position
			var offset := Vector2(-float(SUPPORT_OFFSET[hero]) * body_height, 0) * source_scale if planted else Vector2.ZERO
			frames[index]["anchor"] = support_point - offset
			frames[index]["support_point"] = support_point
			frames[index]["planted"] = planted
			frames[index]["body_height"] = body_height * source_scale.y
		sheets[sheet] = frames
	# Keep both shoes from the first idle drawing; animate the genuine upper-body frames.
	var idle: Array = sheets.motion
	var shoes := _slice_frame(idle[0], idle[0].region.position.y + idle[0].support_point.y - 22.0, false)
	for index in range(4):
		var upper := _slice_frame(idle[index], idle[index].region.position.y + idle[index].support_point.y - 21.0, true)
		idle[index]["layers"] = [shoes, upper]
	animations[hero] = sheets

func _slice_frame(frame: Dictionary, cut: float, upper: bool) -> Dictionary:
	var region: Rect2 = frame.region
	var sliced := Rect2(region.position, Vector2(region.size.x, cut - region.position.y)) if upper else Rect2(Vector2(region.position.x, cut), Vector2(region.size.x, region.end.y - cut))
	return {"texture": frame.texture, "region": sliced, "anchor": frame.anchor + region.position - sliced.position, "body_height": frame.body_height}

func background(weather: int) -> Dictionary:
	if weather <= 0 and not day_frame.is_empty():
		return day_frame
	if weather_frames.size() == 3:
		return weather_frames[clampi(weather, 0, 2)]
	return day_frame

static func pose_for(action: String, z: float, won: bool = false) -> int:
	if action in ["hurt", "down", "defeated", "dead", "grabbed", "thrown", "stunned"]:
		return 6
	if won:
		return 8
	match action:
		"light", "attack", "light_attack", "rising": return 1
		"heavy", "charged", "heavy_attack", "ground_slam": return 2
		"charge": return 3
		"throw", "holding": return 5
		"special": return 7
		"victory": return 8
	return 4 if z > 1.0 else 0

static func cell_rect(size: Vector2i, columns: int, rows: int, index: int) -> Rect2i:
	var column := index % columns
	var row := floori(float(index) / columns)
	var left := roundi(float(column * size.x) / columns)
	var top := roundi(float(row * size.y) / rows)
	var right := roundi(float((column + 1) * size.x) / columns)
	var bottom := roundi(float((row + 1) * size.y) / rows)
	return Rect2i(left, top, right - left, bottom - top)

func _load_grid(path: String, columns: int, rows: int, transparent: bool = false, regions: Dictionary = {}, frame_files: Dictionary = {}, isolate_frames: bool = false) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() < columns or image.get_height() < rows:
		push_warning("Art sheet could not be loaded: " + path)
		return []
	if transparent and image.detect_alpha() == Image.ALPHA_NONE:
		push_warning("Art sheet needs a transparent background: " + path)
		return []
	var texture := ImageTexture.create_from_image(image)
	var sources := {path: [image,texture]}
	var frames: Array = []
	for index in range(columns * rows):
		var source: String = frame_files.get(index,path)
		if not sources.has(source):
			var extra := Image.load_from_file(source)
			if extra == null or extra.is_empty() or (transparent and extra.detect_alpha() == Image.ALPHA_NONE): return []
			sources[source] = [extra,ImageTexture.create_from_image(extra)]
		image = sources[source][0]
		texture = sources[source][1]
		var region: Rect2i = regions.get(index, cell_rect(image.get_size(), columns, rows, index))
		if not region.has_area() or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
			push_warning("Art frame exceeds sheet bounds: " + path)
			return []
		if transparent:
			var used := image.get_region(region).get_used_rect()
			if not used.has_area():
				push_warning("Art sheet contains an empty cell: " + path)
				return []
			region = Rect2i(region.position + used.position, used.size)
		var frame_texture := texture
		var frame_region := Rect2(region)
		var frame_padding := Vector2.ZERO
		if isolate_frames:
			const padding := 2
			var frame_image := image.get_region(region)
			var padded_image := Image.create(region.size.x + padding * 2, region.size.y + padding * 2, false, Image.FORMAT_RGBA8)
			padded_image.fill(Color.TRANSPARENT)
			padded_image.blit_rect(frame_image, Rect2i(Vector2i.ZERO, frame_image.get_size()), Vector2i.ONE * padding)
			frame_texture = ImageTexture.create_from_image(padded_image)
			frame_padding = Vector2.ONE * padding
			frame_region = Rect2(frame_padding, region.size)
		frames.append({"texture": frame_texture, "region": frame_region, "source_region": Rect2(region), "source_size": image.get_size(), "frame_padding": frame_padding})
	return frames
