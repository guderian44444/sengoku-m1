extends Control

signal closed
signal equip_requested(id: String)
signal details_requested(id: String)
signal sell_requested(id: String)
var entries: Array = []
var equipped: Array = []
var selected_id := ""
var listed: Array = []
var title: Label
var equipment_summary: Label
var categories: OptionButton
var item_list: ItemList
var item_name: Label
var description: Label
var picture: TextureRect
var equip_button: Button
var details_button: Button
var notice: Label
var sell_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	background.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",16)
	margin.add_child(page)
	var heading := HBoxContainer.new()
	page.add_child(heading)
	title = _label(heading,"收藏與裝備",30)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	_button(heading,"返回",func(): closed.emit()).name = "Back"
	equipment_summary = _label(page,"",21)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",24)
	page.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 340
	body.add_child(sidebar)
	categories = OptionButton.new()
	sidebar.add_child(categories)
	categories.item_selected.connect(func(_index): refresh_list())
	item_list = ItemList.new()
	item_list.size_flags_vertical = SIZE_EXPAND_FILL
	item_list.add_theme_font_size_override("font_size",21)
	item_list.add_theme_constant_override("v_separation",12)
	sidebar.add_child(item_list)
	item_list.item_selected.connect(func(index): select_item(str(listed[index].id)))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(detail)
	item_name = _label(detail,"",28)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(320,240)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(picture)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	detail.add_child(scroll)
	description = _label(scroll,"",20)
	description.size_flags_horizontal = SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	equip_button = _button(actions,"裝備",func(): equip_requested.emit(selected_id))
	details_button = _button(actions,"查看圖鑑",func(): details_requested.emit(selected_id))
	sell_button = _button(actions,"出售",func(): sell_requested.emit(selected_id))
	var buy_button := _button(actions,"購買（尚未開放）",func(): pass)
	buy_button.disabled = true
	notice = _label(page,"",18)

# Rows supply id, name, category, description and optional image/actions; the page is independent of weapon data.
func configure(owner: String, items: Array, equipped_ids: Array) -> void:
	entries = items.duplicate(true)
	equipped = equipped_ids.duplicate()
	title.text = owner + "　行囊（%d 件）" % entries.size()
	var slots: Array[String] = []
	for item in entries:
		if item.id in equipped: slots.append(str(item.get("slot","裝備")) + "：" + str(item.name))
	equipment_summary.text = "　｜　".join(slots)
	categories.clear()
	categories.add_item("全部收藏")
	categories.set_item_metadata(0,"")
	var names: Array = []
	for item in entries:
		var category := str(item.get("category","其他"))
		if category not in names: names.append(category)
	for category in names:
		categories.add_item(str(category))
		categories.set_item_metadata(categories.item_count - 1,category)
	categories.selected = 0
	selected_id = str(equipped[0]) if not equipped.is_empty() else ""
	notice.text = ""
	refresh_list()

func refresh_list() -> void:
	item_list.clear()
	listed.clear()
	var category := str(categories.get_item_metadata(categories.selected))
	for item in entries:
		if category != "" and str(item.get("category","其他")) != category: continue
		listed.append(item)
		item_list.add_item(("◆ " if item.id in equipped else "　") + str(item.name))
	if listed.is_empty():
		selected_id = ""
		item_name.text = "尚無收藏"
		description.text = ""
		picture.texture = null
		equip_button.disabled = true
		details_button.hide()
		sell_button.disabled = true
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
		description.text = str(item.get("description",""))
		var image := str(item.get("image",""))
		picture.texture = load(image) if image != "" and ResourceLoader.exists(image) else null
		equip_button.disabled = id in equipped or not item.get("can_equip",false)
		equip_button.text = "裝備"
		details_button.visible = item.get("has_details",false)
		sell_button.disabled = id in equipped
		sell_button.text = "出售　%d 文" % int(item.get("price",0))
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
	button.add_theme_font_size_override("font_size",21)
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button
