extends Control

const Typography = preload("res://render/game_typography.gd")
const Battle = preload("res://core/battle.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
const LayeredHeroSource = preload("res://render/layered_hero_source.gd")
const HERO_NAMES := {"nobunaga":"信長", "oichi":"阿市", "hideyoshi":"秀吉", "ieyasu":"家康", "mitsuhide":"光秀", "tadakatsu":"忠勝"}
# Native source regions retain the accepted character art; no separately generated faces.
const PORTRAITS := {
	"nobunaga": ["res://assets/v03/nobunaga-transparent.png", Rect2i(208, 48, 126, 126)],
	"oichi": ["res://assets/v12/oichi-idle.png", Rect2i(115, 24, 126, 126)],
	"hideyoshi": ["res://assets/v10/hideyoshi-idle.png", Rect2i(87, 27, 110, 110)],
	"ieyasu": ["res://assets/v10/ieyasu-idle.png", Rect2i(84, 264, 110, 110)],
	"mitsuhide": ["res://assets/v10/mitsuhide-idle.png", Rect2i(85, 522, 110, 110)],
	"tadakatsu": ["res://assets/v16/tadakatsu-idle.png", Rect2i(183, 94, 176, 176)]
}
const PANEL := Color(0.035, 0.065, 0.07, 0.86)
const GOLD := Typography.GOLD
const MUTED := Color("c6b99c")
const BOSS_RECT := Rect2(320, 673, 640, 35)
var portraits: Dictionary = {}
var players: Array[Dictionary] = []
var boss: Dictionary = {}
var _font: Font
var _tick := 0

static func portrait_spec(hero: String) -> Dictionary:
	var path := LayeredHeroSource.folder(hero) + "registration.json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("portrait") is Dictionary:
			var entry: Dictionary = data.portrait
			if entry.get("rect") is Array and entry.rect.size() == 4 and entry.get("file") is String:
				return {"file":path.get_base_dir().path_join(entry.file),"region":Rect2i(int(entry.rect[0]),int(entry.rect[1]),int(entry.rect[2]),int(entry.rect[3]))}
	return {"file":PORTRAITS[hero][0],"region":PORTRAITS[hero][1]}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Typography.font()
	for hero in PORTRAITS:
		var spec := portrait_spec(hero)
		var source := Image.load_from_file(spec.file)
		if source != null: portraits[hero] = ImageTexture.create_from_image(source.get_region(spec.region))

func sync(world: Dictionary) -> void:
	_tick = int(world.get("tick",0))
	players.clear()
	boss = {}
	for fighter in world.get("fighters", []):
		if int(fighter.get("team", 1)) == 0:
			players.append(fighter)
		elif fighter.get("kind", "") == "boss" and fighter.get("hp", 0) > 0:
			if boss.is_empty() or fighter.get("stage_boss", false): boss = fighter
	queue_redraw()

static func player_rect(slot: int) -> Rect2:
	return Rect2(16 if slot == 0 else 872, 10, 392, 104)

static func player_status(fighter: Dictionary, tick: int) -> Dictionary:
	var lives := maxi(0,int(fighter.get("lives",Battle.STARTING_LIVES)))
	var extra_age := tick - int(fighter.get("extra_life_tick",-1000))
	var extra := extra_age >= 0 and extra_age < 120
	var shield := "符 %d" % maxi(0,int(fighter.get("shield_points",0)))
	if int(fighter.get("respawn_ticks",0)) > 0: shield = "再起 %.1f" % (float(fighter.respawn_ticks) / 60.0)
	return {"lives":"命×%d" % lives if lives > 0 else "命盡", "score":"分 %07d" % maxi(0,int(fighter.get("score",0))), "shield":shield, "extra":extra and extra_age % 20 < 14}

func _draw() -> void:
	if _font == null: return
	for fighter in players:
		var slot := int(fighter.get("player_index", 0))
		if slot not in [0, 1]: continue
		var panel := player_rect(slot)
		var origin := panel.position
		draw_rect(panel, PANEL)
		draw_rect(panel, Color(0.6, 0.51, 0.3, 0.7), false, 1.0)
		var portrait := Rect2(origin + Vector2(6, 6), Vector2(72, 72))
		draw_rect(portrait, Color("101a1a"))
		if portraits.has(fighter.kind):
			var texture: Texture2D = portraits[fighter.kind]
			var size := texture.get_size() * 72.0 / maxf(texture.get_width(),texture.get_height())
			draw_texture_rect(texture,Rect2(portrait.position + (portrait.size - size) * .5,size),false)
		draw_rect(portrait, GOLD, false, 1.0)
		var labels := player_status(fighter,_tick)
		draw_rect(Rect2(portrait.position + Vector2(0,53),Vector2(72,19)),Color(.025,.04,.04,.86))
		_label(portrait.position + Vector2(0,68),labels.lives,14,GOLD,72,HORIZONTAL_ALIGNMENT_CENTER)
		var text_x := origin.x + 89
		_label(Vector2(text_x, origin.y + 24), "%dP  %s" % [slot + 1, HERO_NAMES.get(fighter.kind, fighter.kind)], 21, GOLD)
		var hp := maxi(0, int(fighter.get("hp", 0)))
		var max_hp := maxi(1, int(fighter.get("max_hp", 1)))
		_label(Vector2(text_x + 114, origin.y + 24), "體力  %d / %d" % [hp, max_hp], 16, Typography.PAPER, 181, HORIZONTAL_ALIGNMENT_RIGHT)
		var health := Rect2(text_x, origin.y + 29, 293, 12)
		_bar(health, float(hp) / max_hp, Color("dc6654") if hp < max_hp * 0.25 else Color("72bd7b"))
		_label(Vector2(text_x,origin.y + 58),labels.score,14,Typography.PAPER)
		if labels.extra: _label(Vector2(text_x + 120,origin.y + 58),"+1命",14,GOLD)
		_label(Vector2(text_x + 193,origin.y + 58),labels.shield,14,GOLD,100,HORIZONTAL_ALIGNMENT_RIGHT)
		var rage := clampf(float(fighter.get("rage", 0)), 0, 100)
		_label(Vector2(text_x, origin.y + 77), "氣", 15, GOLD)
		_bar(Rect2(text_x + 24, origin.y + 65, 150, 12), rage / 100.0, Color("ffd066") if rage >= 100 else Color("eea449"))
		_label(Vector2(text_x + 181, origin.y + 77), "MAX" if rage >= 100 else str(int(rage)), 13, GOLD)
		_label(Vector2(text_x + 237, origin.y + 77), "甲%d" % fighter.get("armor", 0), 13, MUTED)
		var item := Equipment.instance(fighter,int(fighter.get("weapon_uid",0)))
		_label(Vector2(text_x, origin.y + 97), Weapons.name_for(fighter) + ("　耐 %d" % int(item.durability) if not item.is_empty() else ""), 15, GOLD)
	if not boss.is_empty():
		draw_rect(BOSS_RECT, PANEL)
		var name_text := str(boss.get("display_name", "陣營小王"))
		_label(BOSS_RECT.position + Vector2(10, 16), name_text, 16, GOLD)
		_label(BOSS_RECT.position + Vector2(230, 16), "%d / %d" % [boss.hp, boss.max_hp], 14, Typography.PAPER, 398, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Rect2(BOSS_RECT.position + Vector2(10, 23), Vector2(620, 7)), float(boss.hp) / maxf(1, boss.max_hp), Color("c85245"))

func _label(at: Vector2, text: String, font_size: int, color: Color, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	Typography.draw_label(self, at, text, font_size, color, width, alignment)

func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, Color("171e20"))
	var fill := rect
	fill.size.x *= clampf(fraction, 0, 1)
	draw_rect(fill, color)
	draw_rect(rect, Color(0.85, 0.85, 0.75, 0.5), false, 1.0)
