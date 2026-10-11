extends Control

const Typography = preload("res://render/game_typography.gd")
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Typography.font()
	for hero in PORTRAITS:
		var source := Image.load_from_file(PORTRAITS[hero][0])
		if source != null: portraits[hero] = ImageTexture.create_from_image(source.get_region(PORTRAITS[hero][1]))

func sync(world: Dictionary) -> void:
	players.clear()
	boss = {}
	for fighter in world.get("fighters", []):
		if int(fighter.get("team", 1)) == 0:
			players.append(fighter)
		elif fighter.get("kind", "") == "boss" and fighter.get("hp", 0) > 0:
			if boss.is_empty() or fighter.get("stage_boss", false): boss = fighter
	queue_redraw()

static func player_rect(slot: int) -> Rect2:
	return Rect2(16 if slot == 0 else 872, 10, 392, 84)

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
		if portraits.has(fighter.kind): draw_texture_rect(portraits[fighter.kind], portrait, false)
		draw_rect(portrait, GOLD, false, 1.0)
		var text_x := origin.x + 89
		_label(Vector2(text_x, origin.y + 24), "%dP  %s" % [slot + 1, HERO_NAMES.get(fighter.kind, fighter.kind)], 21, GOLD)
		var hp := maxi(0, int(fighter.get("hp", 0)))
		var max_hp := maxi(1, int(fighter.get("max_hp", 1)))
		_label(Vector2(text_x + 114, origin.y + 24), "體力  %d / %d" % [hp, max_hp], 16, Typography.PAPER, 181, HORIZONTAL_ALIGNMENT_RIGHT)
		var health := Rect2(text_x, origin.y + 33, 293, 16)
		_bar(health, float(hp) / max_hp, Color("dc6654") if hp < max_hp * 0.25 else Color("72bd7b"))
		var rage := clampf(float(fighter.get("rage", 0)), 0, 100)
		_label(Vector2(text_x, origin.y + 71), "氣", 15, GOLD)
		_bar(Rect2(text_x + 24, origin.y + 58, 150, 12), rage / 100.0, Color("ffd066") if rage >= 100 else Color("eea449"))
		_label(Vector2(text_x + 181, origin.y + 70), "MAX" if rage >= 100 else str(int(rage)), 13, GOLD)
		_label(Vector2(text_x + 221, origin.y + 71), "武%d  甲%d" % [fighter.get("weapon", 0), fighter.get("armor", 0)], 13, MUTED)
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
