extends SceneTree

const Typography = preload("res://render/game_typography.gd")
const SengokuTheme = preload("res://ui/sengoku_theme.gd")

func _initialize() -> void:
	var face := Typography.font()
	assert(face == Typography.font(), "Font is shared by canvas and Control text.")
	assert(face.get_font_name().contains("Bakudai"))
	assert(face == Typography.body_font())
	var sample := "吞食戰國開始遊戲雙人合作設定工程入口體力氣必殺技信長阿市忠勝松井宗信瀨名氏俊鵜殿長照井伊直盛音樂音效語音繼續向右0123456789GO"
	for letter in sample:
		assert(face.has_char(letter.unicode_at(0)), "Bundled font missing: " + letter)
	var style := Typography.theme()
	assert(style == Typography.theme())
	assert(style.default_font == face)
	for type in ["Label", "Button", "OptionButton", "LineEdit", "PopupMenu"]:
		assert(style.get_constant("outline_size", type) == 0)
		assert(style.get_color("font_color", type) == SengokuTheme.INK)
	assert(style.get_stylebox("focus", "Button").border_width_left >= 3)
	var logo := Image.load_from_file("res://assets/current/ui/title-logo-v34.png")
	assert(logo != null and logo.get_width() >= 1600 and logo.get_height() >= 500)
	assert(logo.get_format() == Image.FORMAT_RGBA8 and logo.get_pixel(0, 0).a == 0)
	var backdrop := Image.load_from_file("res://assets/v20/title/title-background.png")
	assert(backdrop != null and backdrop.get_width() >= 1600)
	assert(absf(float(backdrop.get_width()) / backdrop.get_height() - 16.0 / 9.0) < 0.01)
	assert(FileAccess.file_exists("res://assets/v20/fonts/OFL.txt"))
	print("PASS typography_v20: shared bundled brush font, paper controls, Japanese calligraphy title")
	quit()
