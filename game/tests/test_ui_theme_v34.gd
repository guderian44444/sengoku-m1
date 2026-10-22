extends SceneTree

const Typography = preload("res://render/game_typography.gd")
const SengokuTheme = preload("res://ui/sengoku_theme.gd")
const MenuFrame = preload("res://ui/menu_frame.gd")
var checked := {}
var missing: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var face := Typography.font()
	assert(face == Typography.body_font(), "Every Control and canvas uses the same brush face.")
	assert(face.get_font_name().contains("MasaFont"))
	assert(face is FontVariation and face.variation_embolden == 0.0)
	assert(not face.base_font.allow_system_fallback)
	assert(face.fallbacks.size() == 2)
	for fallback in face.fallbacks:
		assert(fallback is FontVariation and fallback.variation_embolden == 0.0 and not fallback.base_font.allow_system_fallback)
	var brush := FontFile.new()
	assert(brush.load_dynamic_font(Typography.FONT_PATH) == OK)
	brush.allow_system_fallback = false
	for letter in "吞食戰國開始遊戲雙人合作設定玩家姓名儲存刪除編輯取消確認倉庫行囊裝備護符刀槍弓織田信長阿市1234567890ABC":
		assert(brush.has_char(letter.unicode_at(0)), "Common UI glyph must use the brush face: " + letter)
	for path in ["res://main.gd", "res://core", "res://ui", "res://render", "res://data", "res://assets/v22/weapons/encyclopedia.json"]:
		_check_source(path, face)
	assert(missing.is_empty(), "Bundled glyphs missing: " + ", ".join(missing))
	var style := Typography.theme()
	assert(style == Typography.theme() and style.default_font == face)
	for type in ["Label", "Button", "LineEdit", "TextEdit", "OptionButton", "ItemList"]:
		assert(style.get_color("font_color", type) == SengokuTheme.INK)
		assert(style.get_constant("outline_size", type) == 0)
	var button_focus := style.get_stylebox("focus", "Button") as SengokuTheme.WashiButton
	assert(button_focus.border_width >= 3 and button_focus.border_color == SengokuTheme.FOCUS_BORDER)
	assert(button_focus.paper_tint == SengokuTheme.BUTTON_SELECTED_TINT)
	assert(style.get_stylebox("hover", "Button").paper_tint == button_focus.paper_tint)
	assert(style.get_stylebox("normal", "Button").paper_tint == Color.WHITE)
	assert(_contrast(SengokuTheme.INK, SengokuTheme.PAPER_LIGHT * button_focus.paper_tint) >= 4.5, "Selected brown paper keeps dark labels readable.")
	for type in ["LineEdit", "ItemList", "HSlider"]:
		var focus := style.get_stylebox("focus", type) as StyleBoxFlat
		assert(focus.border_width_left >= 3 and focus.border_color == SengokuTheme.VERMILION)
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var button := style.get_stylebox(state, type)
			assert(button is SengokuTheme.WashiButton)
			for size in [Vector2(28, 28), Vector2(64, 48), Vector2(420, 52)]:
				var bounds := Rect2(Vector2(12, 8), size)
				var pieces: Array[Rect2] = button.slices(bounds)
				assert(pieces.size() == 3)
				assert(pieces[0].position == bounds.position and pieces[2].end == bounds.end)
				for piece in pieces:
					assert(bounds.grow(0.01).encloses(piece), "Scroll stays inside the original hit area.")
				assert(pieces[1].size.x >= bounds.size.x * .5, "Narrow controls retain readable central paper.")
	assert(_contrast(SengokuTheme.INK, SengokuTheme.PAPER_LIGHT) >= 7.0)
	assert(_contrast(SengokuTheme.FOCUS_GOLD, SengokuTheme.BUTTON_HOVER) >= 4.5)
	assert(_contrast(SengokuTheme.INK, SengokuTheme.PAPER) >= 7.0)
	assert(_contrast(SengokuTheme.PAPER_LIGHT, SengokuTheme.VERMILION) >= 4.5)
	assert(_contrast(SengokuTheme.VERMILION, SengokuTheme.PAPER_LIGHT) >= 4.5)
	assert(style.get_icon("grabber", "HSlider").get_width() == 24)
	assert(FileAccess.file_exists("res://assets/current/fonts/MasaFont-OFL.txt"))
	var logo := Image.load_from_file("res://assets/current/ui/title-logo-v34.png")
	assert(logo != null and logo.get_size() == Vector2i(2172, 724))
	assert(logo.get_format() == Image.FORMAT_RGBA8 and logo.get_pixel(0, 0).a == 0)
	var frame := MenuFrame.new()
	root.add_child(frame)
	assert(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	frame.free()
	print("UI THEME V34 PASS: %d bundled glyphs, MasaFont without synthetic bold, scroll paper, ink contrast, visible focus" % checked.size())
	quit()

func _check_source(path: String, face: Font) -> void:
	if DirAccess.dir_exists_absolute(path):
		for file in DirAccess.get_files_at(path):
			if file.get_extension() in ["gd", "json"]:
				_check_source(path.path_join(file), face)
		return
	for letter in FileAccess.get_file_as_string(path):
		var code := letter.unicode_at(0)
		if code < 32 or checked.has(code):
			continue
		checked[code] = true
		if not face.has_char(code):
			missing.append(letter)

func _contrast(first: Color, second: Color) -> float:
	var a := first.srgb_to_linear().get_luminance()
	var b := second.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
