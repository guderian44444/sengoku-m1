extends Control

signal closed
signal equip_requested(id: String)
const Weapons = preload("res://core/weapon_catalog.gd")
const Archive = preload("res://core/weapon_encyclopedia.gd")
var archive = Archive.new()
var hero := "nobunaga"
var owned: Array = []
var equipped := ""
var selected_id := ""
var detail_scroll: ScrollContainer
var filter: OptionButton
var weapon_list: ItemList
var history_text: Label
var game_text: Label
var title: Label
var picture: TextureRect
var equip_button: Button
var listed_ids: Array[String] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation",16)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	title = _label(header,"武器圖鑑",30)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	equip_button = _button(header,"裝備",func(): equip_requested.emit(selected_id))
	_button(header,"返回",func(): closed.emit()).name = "BackToLoadout"
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",24)
	root.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 300
	body.add_child(sidebar)
	filter = OptionButton.new()
	for category in ["全部武器","刀","槍","弓"]: filter.add_item(category)
	sidebar.add_child(filter)
	filter.item_selected.connect(func(_index): refresh_list())
	weapon_list = ItemList.new()
	weapon_list.size_flags_vertical = SIZE_EXPAND_FILL
	weapon_list.add_theme_font_size_override("font_size",21)
	weapon_list.add_theme_constant_override("v_separation",12)
	sidebar.add_child(weapon_list)
	weapon_list.item_selected.connect(func(index): select_weapon(listed_ids[index]))
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",16)
	detail_scroll.add_child(detail)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(320,240)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(picture)
	game_text = _label(detail,"",21)
	history_text = _label(detail,"",20)

func configure(character: String, inventory: Array, current: String) -> void:
	hero = character
	owned = inventory.duplicate()
	equipped = current
	selected_id = current
	filter.selected = 0
	refresh_list()

func refresh_list() -> void:
	weapon_list.clear()
	listed_ids.clear()
	var family: String = ["","sword","spear","bow"][filter.selected]
	for id: String in Weapons.ITEMS:
		var item: Dictionary = Weapons.item(id)
		if family != "" and item.family != family: continue
		listed_ids.append(id)
		weapon_list.add_item(("◆ " if id == equipped else ("● " if id in owned else "　")) + str(item.name))
	if listed_ids.is_empty(): return
	if selected_id not in listed_ids: selected_id = listed_ids[0]
	weapon_list.select(listed_ids.find(selected_id))
	select_weapon(selected_id)

func select_weapon(id: String) -> void:
	if Weapons.item(id).is_empty(): return
	selected_id = id
	var index := listed_ids.find(id)
	if index >= 0:
		weapon_list.select(index)
		weapon_list.ensure_current_is_visible()
	detail_scroll.scroll_vertical = 0
	title.text = "武器圖鑑　／　" + str(archive.entry(id).display_name)
	picture.texture = load("res://assets/v22/weapons/%s.png" % id)
	game_text.text = Archive.stats(id)
	history_text.text = archive.history(id)
	equip_button.disabled = id == equipped or id not in owned or not Weapons.compatible(hero,id)

func _label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
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
