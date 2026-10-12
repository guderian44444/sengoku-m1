extends Control

signal closed
signal equip_requested(id: String)
const Weapons = preload("res://core/weapon_catalog.gd")
const Archive = preload("res://core/weapon_encyclopedia.gd")
const Typography = preload("res://render/game_typography.gd")
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
var sources_box: VBoxContainer
var references_box: VBoxContainer
var equip_button: Button
var preview: AcceptDialog
var preview_texture: TextureRect
var preview_caption: Label
var listed_ids: Array[String] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,22)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation",12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	title = _label(header,"武器圖鑑",30)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	var back := _button(header,"返回裝備",func(): closed.emit())
	back.name = "BackToLoadout"
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	root.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 250
	body.add_child(sidebar)
	filter = OptionButton.new()
	for category in ["全部武器","刀","槍","弓"]: filter.add_item(category)
	sidebar.add_child(filter)
	filter.item_selected.connect(func(_index): refresh_list())
	weapon_list = ItemList.new()
	weapon_list.size_flags_vertical = SIZE_EXPAND_FILL
	weapon_list.add_theme_font_size_override("font_size",19)
	weapon_list.add_theme_constant_override("v_separation",10)
	sidebar.add_child(weapon_list)
	weapon_list.item_selected.connect(func(index): select_weapon(listed_ids[index]))
	_label(sidebar,"● 已收藏　◆ 已裝備\n未取得也可查閱史料",15)
	var scroll := ScrollContainer.new()
	detail_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",16)
	scroll.add_child(detail)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",24)
	detail.add_child(columns)
	var history := VBoxContainer.new()
	history.size_flags_horizontal = SIZE_EXPAND_FILL
	columns.add_child(history)
	_label(history,"史實與館藏資料",24).add_theme_color_override("font_color",Typography.GOLD)
	history_text = _label(history,"",18)
	var gameplay := VBoxContainer.new()
	gameplay.custom_minimum_size.x = 280
	columns.add_child(gameplay)
	_label(gameplay,"遊戲設定",24).add_theme_color_override("font_color",Typography.GOLD)
	game_text = _label(gameplay,"",18)
	equip_button = _button(gameplay,"裝備此武器",func(): equip_requested.emit(selected_id))
	_label(detail,"實物參考圖",24).add_theme_color_override("font_color",Typography.GOLD)
	references_box = VBoxContainer.new()
	detail.add_child(references_box)
	_label(detail,"官方來源（點擊以瀏覽器開啟）",22)
	sources_box = VBoxContainer.new()
	detail.add_child(sources_box)
	_label(root,"能力值直接讀取遊戲武器資料。歷史年代、尺寸及持有人不等於遊戲設定。",16)
	preview = AcceptDialog.new()
	preview.title = "實物參考圖 · 授權與來源"
	preview.size = Vector2i(920,600)
	add_child(preview)
	var preview_box := VBoxContainer.new()
	preview.add_child(preview_box)
	preview_texture = TextureRect.new()
	preview_texture.custom_minimum_size = Vector2(840,430)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_box.add_child(preview_texture)
	preview_caption = _label(preview_box,"",17)
	preview.close_requested.connect(cancel_preview)
	preview.confirmed.connect(cancel_preview)
	preview.window_input.connect(func(event: InputEvent):
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			cancel_preview()
			preview.hide()
	)

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
	var list_index := listed_ids.find(id)
	if list_index >= 0:
		weapon_list.select(list_index)
		weapon_list.ensure_current_is_visible()
	detail_scroll.scroll_vertical = 0
	var entry: Dictionary = archive.entry(id)
	title.text = "武器圖鑑　／　" + str(entry.display_name)
	var historical := "%s　｜　%s\n\n" % [entry.historical_type,entry.period]
	for fact in entry.facts: historical += "• " + str(fact) + "\n\n"
	var dims: Dictionary = entry.dimensions
	var dimensions: Array[String] = []
	for key in ["blade_cm","total_cm","curvature_cm","catalogue_length_cm","tang_cm","base_width_cm","blade_lower_bound_cm"]:
		if dims.get(key) != null:
			dimensions.append("%s %s cm" % [{"blade_cm":"刃長","total_cm":"全長","curvature_cm":"反","catalogue_length_cm":"館載長度（非含柄總長）","tang_cm":"茎長","base_width_cm":"元幅","blade_lower_bound_cm":"刃長大於"}[key],str(dims[key])])
	historical += ("館藏尺寸：" + "／".join(dimensions)) if not dimensions.is_empty() else "館藏尺寸：未確認；不以遊戲比例推算。"
	history_text.text = historical + "\n\n歸屬與考證\n" + str(entry.attribution_note)
	game_text.text = Archive.stats(id) + "\n\n" + str(entry.game_note) + "\n\n" + ("◆ 目前裝備" if id == equipped else ("● 已收藏" if id in owned else "尚未取得"))
	equip_button.disabled = id == equipped or id not in owned or not Weapons.compatible(hero,id)
	equip_button.text = "目前已裝備" if id == equipped else ("裝備此武器" if id in owned and Weapons.compatible(hero,id) else "取得同類武器後可裝備")
	_clear(sources_box)
	for source in entry.sources:
		if source is Dictionary and Archive.safe_url(str(source.get("url",""))):
			_link(sources_box,str(source.get("institution","")) + " · " + str(source.get("title","官方資料")),str(source.url))
	_clear(references_box)
	var permitted := 0
	var external_references := 0
	for reference in entry.reference_images:
		if not reference is Dictionary: continue
		if not Archive.image_allowed(reference) or not FileAccess.file_exists(str(reference.local_path)):
			if Archive.safe_url(str(reference.get("source_url",""))) and Archive.license_confirmed(reference):
				external_references += 1
				_link(references_box,"參考照可於來源查看 · " + str(reference.get("caption","館藏照片")),str(reference.source_url))
			continue
		permitted += 1
		var thumbnail := TextureButton.new()
		thumbnail.texture_normal = ImageTexture.create_from_image(Image.load_from_file(str(reference.local_path)))
		thumbnail.ignore_texture_size = true
		thumbnail.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.custom_minimum_size.y = 150
		thumbnail.tooltip_text = "點擊放大 · " + str(reference.get("caption","館藏照片"))
		thumbnail.pressed.connect(func(): show_reference(reference))
		references_box.add_child(thumbnail)
		_button(references_box,"放大實物參考圖 · " + str(reference.get("caption","館藏照片")),func(): show_reference(reference))
		_link(references_box,"照片來源 · " + str(reference.get("credit","")),str(reference.source_url))
		if Archive.safe_url(str(reference.get("license_url",""))): _link(references_box,"使用授權 · " + str(reference.license),str(reference.license_url))
	if permitted == 0: _label(references_box,("圖片授權已核對；本地照片尚未備妥。" if external_references > 0 else "實物照片待授權") + "\n" + str(entry.get("photo_status","可由官方來源查看館藏；遊戲美術不充作實物照片。")),18)

func show_reference(reference: Dictionary) -> void:
	if not Archive.image_allowed(reference): return
	cancel_preview()
	preview_texture.texture = null
	preview_caption.text = str(reference.get("caption","館藏照片")) + "\n" + str(reference.credit) + " · " + str(reference.license)
	var path := str(reference.local_path)
	if FileAccess.file_exists(path):
		var bitmap := Image.load_from_file(path)
		if bitmap != null: preview_texture.texture = ImageTexture.create_from_image(bitmap)
	if preview_texture.texture == null: preview_caption.text = "實物照片待授權或本機檔案尚未備妥。請使用官方來源連結。"
	preview.popup_centered()

func cancel_preview() -> void:
	if is_instance_valid(preview): preview.hide()
	if is_instance_valid(preview_texture): preview_texture.texture = null

func _exit_tree() -> void:
	cancel_preview()

func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size",18)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _link(parent: Node, value: String, url: String) -> void:
	var link := _button(parent,value,func(): OS.shell_open(url))
	link.tooltip_text = url

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
