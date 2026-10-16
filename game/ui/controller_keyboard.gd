extends Control

signal closed

# shortcut: 搖桿提供常用姓名選字，完整中文輸入仍使用實體鍵盤的系統輸入法。
const NAME_CHARACTERS := "林陳黃張李王吳劉蔡楊許鄭謝郭洪曾邱廖賴徐周葉蘇莊呂江何蕭羅高潘簡朱鍾彭游詹胡施沈余趙盧梁顏孫馬戴蔣杜魏藍宋唐連馮董程康曹袁鄧傅方石姚田劉龍武小大明美玉英華文志宏俊傑豪雄偉強勇剛仁義禮信忠孝和平安樂天海山風雲月雪花竹松梅蘭青紅白黑金銀光星雨陽夢心子秀麗雅君琳瑜玲萱怡婷惠芬芳靜思嘉佳家國世建德勝昇柏宇翔瑞誠智信長市織田豐臣德川本多竹中半兵衛千代幸村真田正宗伊達虎狼鷹燕忍劍影炎雷戰神一二三四五六七八九十"
const BANK_NAMES := ["名號用字", "英文小寫", "英文大寫", "數字・符號"]
const BANKS := [NAME_CHARACTERS, "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789.:_-@ /[]"]
const PAGE_SIZE := 40
var target: LineEdit
var editor: LineEdit
var heading: Label
var bank_label: Label
var keys: GridContainer
var bank := 0
var character_page := 0
var numeric := false
var key_buttons: Array[Button] = []

func _ready() -> void:
	name = "ControllerKeyboard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.025, 0.02, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-520, -310)
	panel.size = Vector2(1040, 620)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 28)
	page.add_child(heading)
	editor = LineEdit.new()
	editor.custom_minimum_size.y = 46
	editor.virtual_keyboard_enabled = false
	page.add_child(editor)
	editor.text_submitted.connect(func(_text): finish(true))
	var bank_row := HBoxContainer.new()
	page.add_child(bank_row)
	_button(bank_row, "上一字盤", func(): change_bank(-1))
	bank_label = Label.new()
	bank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank_row.add_child(bank_label)
	_button(bank_row, "下一字盤", func(): change_bank(1))
	_button(bank_row, "換頁", next_page)
	keys = GridContainer.new()
	keys.columns = 10
	keys.add_theme_constant_override("h_separation", 8)
	keys.add_theme_constant_override("v_separation", 8)
	page.add_child(keys)
	for index in range(PAGE_SIZE):
		var key := _button(keys, "", func(): insert_character(key_buttons[index].text))
		key.custom_minimum_size = Vector2(84, 47)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_buttons.append(key)
	var actions := HBoxContainer.new()
	page.add_child(actions)
	_button(actions, "刪除一字", erase_character)
	_button(actions, "清空", func(): editor.clear())
	_button(actions, "取消", func(): finish(false))
	_button(actions, "確認", func(): finish(true))
	var instructions := Label.new()
	instructions.text = "題名：方向鍵選字　×／A 輸入　□／X 刪字　L1／R1 換字盤　Options 確認　○／B 取消\n實體鍵盤／中文輸入法亦可題字。"
	instructions.add_theme_font_size_override("font_size", 18)
	page.add_child(instructions)
	hide()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 43
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open(line: LineEdit, numbers_only: bool = false) -> void:
	target = line
	numeric = numbers_only
	bank = 3 if numeric or line.name == "Address" else 0
	character_page = 0
	editor.max_length = line.max_length
	editor.text = str(int(line.get_parent().value)) if numeric else line.text
	editor.caret_column = editor.text.length()
	heading.text = "聯軍・連線埠" if numeric else ("聯軍・連線位址" if line.name == "Address" else "題名・武者名號")
	show()
	refresh_keys()
	key_buttons[0].grab_focus()

func refresh_keys() -> void:
	var characters: String = "0123456789" if numeric else BANKS[bank]
	var pages := maxi(1, ceili(float(characters.length()) / PAGE_SIZE))
	character_page = posmod(character_page, pages)
	bank_label.text = "%s　%d／%d" % [BANK_NAMES[bank], character_page + 1, pages]
	for index in range(PAGE_SIZE):
		var offset := character_page * PAGE_SIZE + index
		key_buttons[index].visible = offset < characters.length()
		if offset < characters.length(): key_buttons[index].text = characters.substr(offset, 1)

func change_bank(direction: int) -> void:
	if numeric: return
	bank = posmod(bank + direction, BANKS.size())
	character_page = 0
	refresh_keys()
	key_buttons[0].grab_focus()

func next_page() -> void:
	character_page += 1
	refresh_keys()
	key_buttons[0].grab_focus()

func insert_character(character: String) -> void:
	editor.insert_text_at_caret(character)

func erase_character() -> void:
	if editor.has_selection(): editor.delete_text(editor.get_selection_from_column(), editor.get_selection_to_column())
	elif editor.caret_column > 0: editor.delete_char_at_caret()

func finish(commit: bool) -> void:
	if is_instance_valid(target):
		if commit:
			target.text = editor.text
			if target.get_parent() is SpinBox: target.get_parent().apply()
			target.text_changed.emit(target.text)
		target.grab_focus()
	hide()
	closed.emit()
