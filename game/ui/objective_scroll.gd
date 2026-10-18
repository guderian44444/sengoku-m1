extends Control

const Typography = preload("res://render/game_typography.gd")
const BOUNDS := Rect2(416, 8, 448, 108)
const PAPER := Color("ead8ae")
const VERMILION := Color("923a2d")
var chapter := ""
var place := ""
var order := ""
var order_state := ""
var roller_cap := StyleBoxFlat.new()

func _ready() -> void:
	name = "ObjectiveScroll"
	position = BOUNDS.position
	size = BOUNDS.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	roller_cap.bg_color = Color("a98343")
	roller_cap.border_color = Color("53351e")
	roller_cap.set_border_width_all(1)
	roller_cap.set_corner_radius_all(3)
	hide()

static func objective(world: Dictionary) -> Dictionary:
	var stage: Dictionary = world.get("stage", {})
	if stage.is_empty() or str(world.get("phase", "")) != "playing": return {}
	var order_text := "整陣戒備"
	var state := "ready"
	if stage.get("go", false):
		order_text = "全軍會合　向右進軍 →"
		state = "advance"
	elif world.get("fighters", []).any(func(fighter): return int(fighter.get("team", 0)) == 1 and int(fighter.get("hp", 0)) > 0 and fighter.get("kind", "") == "boss"):
		order_text = "擊破敵將"
		state = "boss"
	elif world.get("fighters", []).any(func(fighter): return int(fighter.get("team", 0)) == 1 and int(fighter.get("hp", 0)) > 0):
		order_text = "殲滅守軍"
		state = "battle"
	elif int(world.get("wave", 1)) < int(stage.get("wave_total", 1)):
		order_text = "整陣戒備"
	elif world.get("props", []).any(func(prop): return prop.get("mandatory", false) and not prop.get("broken", false) and float(prop.get("x", INF)) < float(stage.get("encounter_end", 0))):
		order_text = "掃除路障　打通去路"
		state = "obstacle"
	var encounter: Dictionary = world.get("encounter",{})
	if world.has("ikki") and not stage.get("go",false):
		var flags: int=world.props.filter(func(p):return p.get("s05_banner",false) and not p.broken).size()
		order_text="破旗斷援　尚餘 %d 支"%flags if flags>0 else "旗幟全破　殲滅餘軍"
		state="obstacle" if flags>0 else "battle"
	if not encounter.is_empty() and not stage.get("go",false):
		match encounter.kind:
			"alarm":
				var left: int = world.props.filter(func(p):return p.id in encounter.support_ids and not p.broken).size()
				order_text = "擊破鐘柱　尚餘 %d 根" % left if left > 0 else "警鐘已停　殲滅餘軍"
				state = "obstacle" if left > 0 else "battle"
			"barriers":
				var left: int = world.props.filter(func(p):return p.get("stage03_barrier",false) and not p.broken).size()
				order_text = "破柵停止增援　尚餘 %d 層" % left if left > 0 else "木障已破　殲滅餘軍"
				state = "obstacle" if left > 0 else "battle"
			"formation":
				order_text = "趁隙破陣　突入大帳 →" if not encounter.breached else "防線已破　全軍入帳 →"
				state = "advance"
			"lieutenants":
				order_text = "擊破井伊直盛與蒲原氏德"
				if encounter.phase == "awaiting_yoshimoto": order_text = "義元將至　整陣迎敵"
				elif encounter.phase == "yoshimoto": order_text = "擊破今川義元"
				state = "boss"
	if world.has("mikawa"):
		if world.mikawa.phase == "retreat": order_text = "長照敗退　殲滅殘餘增援"; state = "battle"
		elif world.mikawa.node == 7 and stage.get("go",false): order_text = "橋頭封鎖解除　友軍可以通行"
		elif world.mikawa.node == 10 and state == "boss": order_text = "擊敗吉良　截斷弓兵增援"
		if not world.mikawa.get("reserved",[]).is_empty(): order_text = "← 左右增援接近　第 %d 波 →" % int(world.mikawa.next_batch); state = "battle"
	return {"chapter": str(stage.get("title", "")), "place": "%s　%d／%d 陣" % [str(stage.get("name", "")), int(stage.get("checkpoint", 0)) + 1, int(stage.get("checkpoint_total", 1))], "order": order_text, "state": state}

func sync(world: Dictionary, can_show: bool, dialogue: bool = false) -> void:
	var entry := objective(world)
	visible = can_show and not dialogue and not entry.is_empty()
	if entry.is_empty():
		chapter = ""
		place = ""
		order = ""
		order_state = ""
		return
	chapter = entry.chapter
	place = entry.place
	order = entry.order
	order_state = entry.state
	queue_redraw()

func _draw() -> void:
	var paper := Rect2(19, 7, 410, 91)
	draw_rect(Rect2(14, 12, 425, 94), Color(0.03, 0.015, 0.01, 0.32))
	draw_rect(paper, PAPER)
	draw_rect(paper.grow(-3), Color("a98653"), false, 1)
	draw_rect(paper.grow(-6), Color("b99b6a"), false, 1)
	for index in range(25):
		var x := 28.0 + fmod(index * 71.0, 388.0)
		var y := 13.0 + fmod(index * 31.0, 78.0)
		draw_line(Vector2(x, y), Vector2(x + 8, y + 1), Color(0.35, 0.24, 0.12, 0.10), 1)
	for x in [10.0, 430.0]:
		draw_rect(Rect2(x, 5, 10, 96), Color("5b3825"))
		draw_rect(Rect2(x + 2, 5, 3, 96), Color("b28c53"))
		for y in [1.0, 97.0]:
			draw_style_box(roller_cap, Rect2(x - 3, y, 16, 8))
	draw_line(Vector2(57, 36), Vector2(389, 36), Color("b49464"), 1)
	_label(Vector2(42, 28), "令旨　" + chapter, 17, VERMILION, 364)
	_label(Vector2(40, 65), order, 24, Typography.INK, 342)
	_label(Vector2(42, 88), place, 15, Color("65492d"), 364)
	var seal := Rect2(390, 46, 25, 25)
	draw_rect(seal, VERMILION)
	draw_rect(seal.grow(-3), PAPER, false, 1)
	_label(Vector2(393, 65), "令", 17, PAPER, 19)

func _label(at: Vector2, value: String, font_size: int, color: Color, width: float) -> void:
	while font_size > 12 and Typography.font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	draw_string(Typography.font(), at, value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
