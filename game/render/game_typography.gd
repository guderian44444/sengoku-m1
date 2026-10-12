extends RefCounted

const FONT_PATH := "res://assets/v20/fonts/NotoSerifTC-VF.ttf"
const REFERENCE_FALLBACK_PATH := "res://assets/v24/fonts/SengokuReferenceFallback.otf"
const PAPER := Color("fff0c8")
const GOLD := Color("f7cf73")
const INK := Color("1a090b")
static var _font: FontVariation
static var _theme: Theme

static func font() -> Font:
	if _font == null:
		var source := FontFile.new()
		var error := source.load_dynamic_font(FONT_PATH)
		assert(error == OK, "The bundled Traditional Chinese font must be available.")
		var reference_fallback := FontFile.new()
		var fallback_error := reference_fallback.load_dynamic_font(REFERENCE_FALLBACK_PATH)
		assert(fallback_error == OK,"Bundled Japanese reference glyphs must be available.")
		source.fallbacks = [reference_fallback]
		_font = FontVariation.new()
		_font.base_font = source
		_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 850.0}
	return _font

static func draw_label(canvas: CanvasItem, at: Vector2, text: String, size: int = 24, color: Color = PAPER, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var edge := Color(INK, color.a)
	canvas.draw_string_outline(font(), at + Vector2(1, 2), text, alignment, width, size, 3 if size >= 22 else 2, edge)
	canvas.draw_string(font(), at, text, alignment, width, size, color)

static func theme() -> Theme:
	if _theme != null: return _theme
	_theme = Theme.new()
	_theme.default_font = font()
	_theme.default_font_size = 24
	for type in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit", "PopupMenu", "RichTextLabel"]:
		_theme.set_color("font_color", type, PAPER)
		_theme.set_color("font_outline_color", type, INK)
		_theme.set_constant("outline_size", type, 3)
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		_theme.set_color("font_hover_color", type, Color.WHITE)
		_theme.set_color("font_focus_color", type, GOLD)
		_theme.set_color("font_pressed_color", type, GOLD)
		_theme.set_color("font_disabled_color", type, Color("897d72"))
		_theme.set_stylebox("normal", type, _panel(Color("23161bee"), Color("89613c")))
		_theme.set_stylebox("hover", type, _panel(Color("462025f0"), GOLD))
		_theme.set_stylebox("pressed", type, _panel(Color("641e22"), GOLD))
		_theme.set_stylebox("disabled", type, _panel(Color("211b1ccc"), Color("51433b")))
		var focus := _panel(Color.TRANSPARENT, GOLD)
		focus.set_border_width_all(2)
		_theme.set_stylebox("focus", type, focus)
	for type in ["PanelContainer", "Panel", "PopupMenu"]:
		_theme.set_stylebox("panel", type, _panel(Color("21151df5"), Color("b58c50")))
	_theme.set_stylebox("normal", "LineEdit", _panel(Color("130e14"), Color("89613c")))
	_theme.set_stylebox("focus", "LineEdit", _panel(Color.TRANSPARENT, GOLD))
	_theme.set_color("font_selected_color", "PopupMenu", GOLD)
	_theme.set_color("font_hover_color", "PopupMenu", GOLD)
	_theme.set_color("font_shadow_color", "Label", Color("10060ab3"))
	_theme.set_constant("shadow_offset_x", "Label", 1)
	_theme.set_constant("shadow_offset_y", "Label", 2)
	return _theme

static func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(9)
	return style
