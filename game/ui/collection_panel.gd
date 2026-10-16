extends Control

const Typography = preload("res://render/game_typography.gd")
signal closed
signal equip_requested(id: String)
signal details_requested(id: String)
signal sell_requested(id: String)
signal pack_requested(id: String)
signal discard_requested(id: String)
signal unequip_requested(treasure: bool)
var entries: Array = []
var equipped: Array = []
var selected_id := ""
var listed: Array = []
var title: Label
var equipment_summary: Label
var categories: TabBar
var item_list: ItemList
var item_name: Label
var description: Label
var picture: TextureRect
var description_scroll: ScrollContainer
var equip_button: Button
var details_button: Button
var notice: Label
var sell_button: Button
var pack_button: Button
var discard_button: Button
var in_battle := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Typography.theme()
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	margin.add_theme_constant_override("margin_bottom",64)
	background.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",10)
	margin.add_child(page)
	var heading := HBoxContainer.new()
	page.add_child(heading)
	title = _label(heading,"藏 兵 閣",28)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button(heading,"返回",func(): closed.emit()).name = "Back"
	equipment_summary = _label(page,"",19)
	categories = TabBar.new()
	categories.name = "Categories"
	categories.focus_mode = Control.FOCUS_ALL
	for category in ["全部","刀","槍","弓","護符"]: categories.add_tab(category)
	page.add_child(categories)
	categories.tab_changed.connect(func(_index): refresh_list())
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	page.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 350
	body.add_child(sidebar)
	item_list = ItemList.new()
	item_list.name = "StoredItems"
	item_list.focus_mode = Control.FOCUS_ALL
	item_list.size_flags_vertical = SIZE_EXPAND_FILL
	item_list.add_theme_font_size_override("font_size",20)
	item_list.add_theme_constant_override("v_separation",10)
	sidebar.add_child(item_list)
	_label(sidebar,"◆ 裝備中　▣ 隨身攜帶",17)
	item_list.item_selected.connect(func(index): select_item(str(listed[index].id)))
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation",8)
	detail_panel.add_child(detail)
	var scroll := ScrollContainer.new()
	description_scroll = scroll
	scroll.name = "DescriptionScroll"
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 120
	detail.add_child(scroll)
	var description_page := VBoxContainer.new()
	description_page.size_flags_horizontal = SIZE_EXPAND_FILL
	description_page.add_theme_constant_override("separation",8)
	scroll.add_child(description_page)
	item_name = _label(description_page,"",26)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(280,150)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	description_page.add_child(picture)
	description = _label(description_page,"",20)
	description.size_flags_horizontal = SIZE_EXPAND_FILL
	var actions := GridContainer.new()
	actions.name = "ItemActions"
	actions.columns = 3
	detail.add_child(actions)
	equip_button = _button(actions,"裝備",func(): equip_requested.emit(selected_id))
	equip_button.name = "Equip"
	pack_button = _button(actions,"放入行囊",func(): pack_requested.emit(selected_id))
	pack_button.name = "Pack"
	details_button = _button(actions,"兵器圖錄",func(): details_requested.emit(selected_id))
	details_button.name = "Details"
	sell_button = _button(actions,"出售",func(): sell_requested.emit(selected_id))
	sell_button.name = "Sell"
	discard_button = _button(actions,"丟棄",func(): discard_requested.emit(selected_id))
	discard_button.name = "Discard"
	_button(actions,"常備兵器 ∞",func(): unequip_requested.emit(false)).name = "DefaultWeapon"
	_button(actions,"卸下護符",func(): unequip_requested.emit(true)).name = "RemoveTreasure"
	for button in actions.get_children(): button.size_flags_horizontal = SIZE_EXPAND_FILL
	notice = _label(page,"",18)

# Rows supply id, name, category, description and optional image/actions; the page is independent of weapon data.
func configure(owner: String, items: Array, equipped_ids: Array, battle: bool = false) -> void:
	in_battle = battle
	entries = items.duplicate(true)
	equipped = equipped_ids.duplicate()
	title.text = ("隨身行囊" if battle else "藏兵閣") + "　／　" + owner
	var slots: Array[String] = []
	for item in entries:
		if item.id in equipped: slots.append(str(item.get("slot","裝備")) + "：" + str(item.name))
	equipment_summary.text = "裝備　" + ("　｜　".join(slots) if not slots.is_empty() else "無藏品在身")
	sell_button.visible = not battle
	pack_button.visible = not battle
	discard_button.visible = battle
	selected_id = str(equipped[0]) if not equipped.is_empty() else ""
	notice.text = ""
	refresh_list()

func refresh_list() -> void:
	item_list.clear()
	listed.clear()
	var category: String = ["","刀","槍","弓","護符"][categories.current_tab]
	for item in entries:
		if category != "" and str(item.get("category","其他")) != category: continue
		listed.append(item)
		item_list.add_item(("◆ " if item.id in equipped else ("▣ " if item.get("packed",false) else "　")) + str(item.name))
	if listed.is_empty():
		selected_id = ""
		item_name.text = "尚無藏品"
		description.text = "此類未備。"
		picture.texture = null
		equip_button.disabled = true
		details_button.hide()
		sell_button.disabled = true
		pack_button.disabled = true
		discard_button.disabled = true
		return
	if not listed.any(func(item): return str(item.id) == selected_id): selected_id = str(listed[0].id)
	select_item(selected_id)

func select_item(id: String) -> void:
	for index in range(listed.size()):
		var item: Dictionary = listed[index]
		if str(item.id) != id: continue
		selected_id = id
		item_list.select(index)
		item_list.ensure_current_is_visible()
		item_name.text = str(item.name)
		item_list.set_item_tooltip(index,str(item.name))
		description_scroll.scroll_vertical = 0
		description.text = str(item.get("description",""))
		var image := str(item.get("image",""))
		var pixels := Image.load_from_file(image) if image != "" and FileAccess.file_exists(image) else null
		picture.texture = ImageTexture.create_from_image(pixels) if pixels != null else null
		equip_button.disabled = id in equipped or not item.get("can_equip",false)
		equip_button.text = "已裝備" if id in equipped else ("裝備" if item.get("can_equip",false) else ("先放入行囊" if item.get("can_pack",false) and not item.get("packed",false) else "無法裝備"))
		details_button.visible = item.get("has_details",false)
		sell_button.disabled = id in equipped
		sell_button.text = "出售　%d 文" % int(item.get("price",0))
		pack_button.text = "存入藏兵閣" if item.get("packed",false) else "放入行囊"
		pack_button.disabled = not item.get("can_pack",false)
		discard_button.disabled = not in_battle
		details_button.visible = not in_battle and item.get("has_details",false)
		return

func _label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size",19)
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button
