extends RefCounted

const SengokuTheme = preload("res://ui/sengoku_theme.gd")
const FONT_PATH := "res://assets/current/fonts/Bakudai-Regular.ttf"
const CJK_FALLBACK_PATH := "res://assets/v20/fonts/NotoSerifTC-VF.ttf"
const REFERENCE_FALLBACK_PATH := "res://assets/current/fonts/SengokuReferenceFallback.otf"
const PAPER := Color("fff0c8")
const GOLD := Color("f7cf73")
const INK := Color("1a090b")
static var _font: FontVariation
static var _theme: Theme

static func font() -> Font:
	if _font == null:
		_font = _load_font(FONT_PATH)
		# Rare reference names retain bundled glyphs even on an offline Windows PC.
		_font.fallbacks = [_load_font(CJK_FALLBACK_PATH), _load_font(REFERENCE_FALLBACK_PATH)]
	return _font

static func _load_font(path: String) -> FontVariation:
	var face := FontFile.new()
	var error := face.load_dynamic_font(path)
	assert(error == OK, "Bundled font must be available: " + path)
	face.allow_system_fallback = false
	var bold := FontVariation.new()
	bold.base_font = face
	bold.variation_embolden = 1.0
	return bold

static func body_font() -> Font:
	return font()

static func draw_label(canvas: CanvasItem, at: Vector2, text: String, size: int = 24, color: Color = PAPER, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var edge := Color(INK, color.a)
	canvas.draw_string_outline(font(), at + Vector2(1, 2), text, alignment, width, size, 2 if size >= 22 else 1, edge)
	canvas.draw_string(font(), at, text, alignment, width, size, color)

static func theme() -> Theme:
	if _theme == null:
		_theme = SengokuTheme.create_theme(font())
	return _theme
