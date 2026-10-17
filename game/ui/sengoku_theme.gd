extends RefCounted

const WashiButton = preload("res://ui/washi_button.gd")

const PAPER := Color("dfc99d")
const PAPER_LIGHT := Color("efddba")
const INK := Color("24180f")
const VERMILION := Color("772d24")
const GOLD := Color("896237")
const MUTED := Color("69563d")
const BUTTON := Color("624331")
const BUTTON_HOVER := Color("754834")
const FOCUS_GOLD := Color("ffd380")
const FOCUS_BORDER := Color("f2cb73")
const BACKGROUND := Color("1b201d")

static func panel(fill: Color = PAPER, border: Color = GOLD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	return style

static func button(fill: Color = BUTTON, border: Color = GOLD, focused: bool = false) -> StyleBox:
	var style := WashiButton.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width = 3.0 if focused else 1.0
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func create_theme(face: Font) -> Theme:
	var result := Theme.new()
	result.default_font = face
	result.default_font_size = 22
	for type in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit", "TextEdit", "PopupMenu", "RichTextLabel", "ItemList", "TabBar"]:
		result.set_color("font_color", type, INK)
		result.set_color("font_outline_color", type, Color.TRANSPARENT)
		result.set_constant("outline_size", type, 0)
	result.set_color("default_color", "RichTextLabel", INK)
	for font_name in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		result.set_font(font_name, "RichTextLabel", face)
	for type in ["PanelContainer", "Panel", "PopupPanel", "PopupMenu", "AcceptDialog"]:
		result.set_stylebox("panel", type, panel())
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		result.set_color("font_color", type, INK)
		result.set_color("font_hover_color", type, INK)
		result.set_color("font_focus_color", type, INK)
		result.set_color("font_pressed_color", type, INK)
		result.set_color("font_hover_pressed_color", type, INK)
		result.set_color("font_disabled_color", type, MUTED)
		result.set_color("icon_normal_color", type, INK)
		result.set_color("icon_hover_color", type, INK)
		result.set_color("icon_focus_color", type, INK)
		result.set_color("icon_pressed_color", type, INK)
		result.set_stylebox("normal", type, button())
		result.set_stylebox("hover", type, button(BUTTON_HOVER, FOCUS_BORDER))
		result.set_stylebox("pressed", type, button(VERMILION, GOLD))
		result.set_stylebox("hover_pressed", type, button(VERMILION, GOLD))
		result.set_stylebox("disabled", type, button(Color("bba888"), Color("998263")))
		result.set_stylebox("focus", type, button(Color.TRANSPARENT, FOCUS_BORDER, true))
	for type in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", type, panel(PAPER_LIGHT))
		result.set_stylebox("read_only", type, panel(Color("ded0b1")))
		result.set_stylebox("focus", type, _focus())
		result.set_color("caret_color", type, VERMILION)
		result.set_color("font_placeholder_color", type, MUTED)
		result.set_color("font_selected_color", type, PAPER_LIGHT)
		result.set_color("selection_color", type, VERMILION)
	result.set_stylebox("panel", "ItemList", panel(PAPER_LIGHT))
	result.set_stylebox("selected", "ItemList", panel(Color("e8c98d"), VERMILION))
	result.set_stylebox("selected_focus", "ItemList", panel(Color("e8c98d"), VERMILION))
	result.set_stylebox("cursor", "ItemList", _focus())
	result.set_stylebox("cursor_unfocused", "ItemList", panel(Color.TRANSPARENT))
	result.set_stylebox("focus", "ItemList", _focus())
	result.set_color("font_selected_color", "ItemList", INK)
	result.set_constant("v_separation", "ItemList", 10)
	result.set_constant("h_separation", "ItemList", 12)
	result.set_stylebox("hover", "PopupMenu", panel(PAPER_LIGHT, VERMILION))
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_color("font_disabled_color", "PopupMenu", MUTED)
	result.set_constant("v_separation", "PopupMenu", 12)
	result.set_color("font_selected_color", "TabBar", INK)
	result.set_color("font_unselected_color", "TabBar", INK)
	result.set_stylebox("tab_selected", "TabBar", button(BUTTON_HOVER, FOCUS_BORDER))
	result.set_stylebox("tab_unselected", "TabBar", button())
	result.set_stylebox("tab_focus", "TabBar", button(Color.TRANSPARENT,FOCUS_BORDER,true))
	for type in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type, panel(Color("d5c6a8"), Color("d5c6a8")))
		result.set_stylebox("grabber", type, panel(GOLD, GOLD))
		result.set_stylebox("grabber_highlight", type, panel(VERMILION, VERMILION))
		result.set_stylebox("grabber_pressed", type, panel(VERMILION, VERMILION))
	for type in ["HSlider", "VSlider"]:
		var rail := panel(Color("d5c6a8"), GOLD)
		rail.set_content_margin_all(3)
		result.set_stylebox("slider", type, rail)
		result.set_stylebox("grabber_area", type, panel(GOLD, GOLD))
		result.set_stylebox("grabber_area_highlight", type, panel(VERMILION, VERMILION))
		result.set_stylebox("focus", type, _focus())
		result.set_icon("grabber", type, _diamond_icon(GOLD))
		result.set_icon("grabber_highlight", type, _diamond_icon(VERMILION))
		result.set_icon("grabber_disabled", type, _diamond_icon(MUTED))
	for type in ["HBoxContainer", "VBoxContainer"]:
		result.set_constant("separation", type, 10)
	for type in ["HSeparator", "VSeparator"]:
		var rule := panel(GOLD, GOLD)
		rule.set_content_margin_all(1)
		result.set_stylebox("separator", type, rule)
	result.set_color("title_color", "Window", PAPER_LIGHT)
	result.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)
	result.set_font("title_font", "Window", face)
	result.set_font_size("title_font_size", "Window", 26)
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit"]:
		for style_name in result.get_stylebox_list(type):
			var style := result.get_stylebox(style_name, type)
			style.content_margin_top = 6
			style.content_margin_bottom = 6
	return result

static func _focus(border: Color = VERMILION) -> StyleBoxFlat:
	var style := panel(Color.TRANSPARENT, border)
	style.set_border_width_all(3)
	return style

static func _diamond_icon(color: Color) -> Texture2D:
	var image := Image.new()
	var error := image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><path d="M12 1L23 12 12 23 1 12Z" fill="#%s" stroke="#30251d" stroke-width="2"/></svg>' % color.to_html(false))
	assert(error == OK)
	return ImageTexture.create_from_image(image)
