extends Control

const Battle = preload("res://core/battle.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
const Typography = preload("res://render/game_typography.gd")
const Archive = preload("res://core/weapon_encyclopedia.gd")
const NAMES := ["織田信長","阿市","豐臣秀吉","德川家康","明智光秀","本多忠勝"]
signal closed
signal begin_requested
signal equipment_requested(slot: int)
signal management_requested(slot: int)
signal achievements_requested(slot: int)
signal players_requested
signal item_requested(slot: int, uid: int)
signal treasure_removed(slot: int)
signal changed
var heroes: OptionButton
var partner_heroes: OptionButton
var partner_row: HBoxContainer
var player_choices: Array[OptionButton] = []
var difficulties: OptionButton
var chapter_choice: OptionButton
var slot_choice: OptionButton
var item_list: ItemList
var item_detail: Label
var stats: Label
var title: Label
var purse: Label
var notice: Label
var equip_button: Button
var unequip_button: Button
var preview
var row: Dictionary = {}
var current_items: Array = []
var category: OptionButton
var active_slot := 0
var team_rows: Array[HBoxContainer] = []

class Preview extends "res://render/battle_view.gd":
	var fighter: Dictionary = {}
	func _process(delta: float) -> void:
		art_time += delta
		if not is_visible_in_tree() or fighter.is_empty(): return
		art_demo = false
		var frame: Dictionary = _art.animation_frame(str(fighter.kind),_fighter_animation(fighter))
		var height := 148.0 if fighter.kind == "oichi" else 155.0
		var factor := height / float(frame.body_height)
		var visible: Rect2 = frame.get("opaque_bounds",Rect2(Vector2.ZERO,frame.region.size))
		var bounds := Rect2((visible.position-Vector2(frame.anchor))*factor,visible.size*factor)
		var weapon: Dictionary = _weapons.geometry(fighter,frame,height)
		if not weapon.is_empty():
			bounds = bounds.expand(weapon.top).expand(weapon.bottom)
		var projection := shadow_projection(Vector2.ZERO,0)
		var corners := [bounds.position,bounds.end,Vector2(bounds.position.x,bounds.end.y),Vector2(bounds.end.x,bounds.position.y)]
		for point in corners: bounds = bounds.expand(projection * point)
		if not buff_icon(fighter).is_empty(): bounds = bounds.merge(buff_rect(frame,height).grow_individual(24*(Battle.TALISMANS[fighter.shield_kind].icons.size()-1)*.5,0,24*(Battle.TALISMANS[fighter.shield_kind].icons.size()-1)*.5,0))
		bounds = bounds.grow(24)
		var space: Vector2 = get_parent().size
		var available := Vector2(maxf(1,space.x-16),maxf(1,space.y-12))
		var fit := minf(available.x/bounds.size.x,available.y/bounds.size.y)
		scale = Vector2.ONE * fit
		position = space*0.5-bounds.get_center()*fit
		queue_redraw()
	func _draw() -> void:
		if fighter.is_empty(): return
		art_demo = false
		_shadow_pass = true
		_draw_art_fighter(fighter,Vector2.ZERO)
		_shadow_pass = false
		_draw_art_fighter(fighter,Vector2.ZERO)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",8)
	margin.add_child(page)
	var heading := HBoxContainer.new()
	page.add_child(heading)
	_label(heading,"角 色 狀 態 ／ 出 戰 準 備",30).size_flags_horizontal = SIZE_EXPAND_FILL
	_button(heading,"玩家設定",func(): players_requested.emit())
	_button(heading,"返回",func(): closed.emit())
	for slot in range(2):
		var team := HBoxContainer.new()
		page.add_child(team)
		team_rows.append(team)
		if slot == 1: partner_row = team
		_label(team,"%dP" % (slot + 1),20).custom_minimum_size.x = 42
		var owner := OptionButton.new()
		owner.add_theme_font_size_override("font_size",19)
		owner.custom_minimum_size.x = 205
		team.add_child(owner)
		player_choices.append(owner)
		var hero := OptionButton.new()
		hero.add_theme_font_size_override("font_size",19)
		for name in NAMES: hero.add_item(name)
		hero.size_flags_horizontal = SIZE_EXPAND_FILL
		team.add_child(hero)
		if slot == 0: heroes = hero
		else:
			partner_heroes = hero
			hero.selected = 1
		hero.item_selected.connect(func(_index): active_slot = slot; slot_choice.selected = slot; changed.emit())
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	page.add_child(body)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 604
	body.add_child(left)
	var character := VBoxContainer.new()
	left.add_child(character)
	var name_row := HBoxContainer.new()
	character.add_child(name_row)
	title = _label(name_row,"",27)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	slot_choice = OptionButton.new()
	slot_choice.add_theme_font_size_override("font_size",17)
	name_row.add_child(slot_choice)
	slot_choice.item_selected.connect(func(index): active_slot = index; changed.emit())
	var character_body := HBoxContainer.new()
	character_body.size_flags_vertical = SIZE_EXPAND_FILL
	character.add_child(character_body)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(270,245)
	character_body.add_child(stage)
	preview = Preview.new()
	preview.position = Vector2(130,242)
	preview.scale = Vector2(0.86,0.86)
	stage.add_child(preview)
	stats = _label(character_body,"",18)
	stats.size_flags_horizontal = SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	character.add_child(actions)
	_button(actions,"倉庫／準備行囊",func(): management_requested.emit(active_slot)).size_flags_horizontal = SIZE_EXPAND_FILL
	_button(actions,"成就帳",func(): achievements_requested.emit(active_slot))
	var right := PanelContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(right)
	var equipment := VBoxContainer.new()
	equipment.add_theme_constant_override("separation",8)
	right.add_child(equipment)
	var equipment_heading := HBoxContainer.new()
	equipment.add_child(equipment_heading)
	_label(equipment_heading,"出 戰 行 囊",25).size_flags_horizontal = SIZE_EXPAND_FILL
	category = OptionButton.new()
	category.add_item("護身符")
	category.add_item("武器")
	equipment_heading.add_child(category)
	category.item_selected.connect(func(_index): _refresh_items())
	purse = _label(equipment,"",18)
	item_list = ItemList.new()
	item_list.custom_minimum_size.y = 105
	item_list.size_flags_vertical = SIZE_EXPAND_FILL
	item_list.add_theme_font_size_override("font_size",19)
	item_list.add_theme_constant_override("v_separation",6)
	equipment.add_child(item_list)
	item_list.item_selected.connect(func(_index): _show_item())
	item_detail = _label(equipment,"",18)
	item_detail.custom_minimum_size.y = 95
	var equipment_actions := HBoxContainer.new()
	equipment.add_child(equipment_actions)
	equip_button = _button(equipment_actions,"裝備",func():
		var indices := item_list.get_selected_items()
		if not indices.is_empty(): item_requested.emit(active_slot,int(current_items[indices[0]].uid)))
	equip_button.size_flags_horizontal = SIZE_EXPAND_FILL
	unequip_button = _button(equipment_actions,"卸下護身符",func(): treasure_removed.emit(active_slot))
	_button(equipment,"使用白板武器 ∞",func(): item_requested.emit(active_slot,0))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	page.add_child(footer)
	difficulties = OptionButton.new()
	for name in ["故事","標準","挑戰"]: difficulties.add_item(name)
	difficulties.selected = 1
	difficulties.item_selected.connect(func(_index): changed.emit())
	footer.add_child(difficulties)
	chapter_choice = OptionButton.new()
	chapter_choice.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(chapter_choice)
	_button(footer,"出　陣",func(): begin_requested.emit()).custom_minimum_size.x = 210
	notice = _label(page,"",17)
	notice.custom_minimum_size.y = 26

func configure(coop: bool, character: Dictionary, owner: String) -> void:
	partner_row.visible = coop
	for team in team_rows: team.hide()
	slot_choice.clear()
	slot_choice.add_item("查看 1P")
	if coop: slot_choice.add_item("查看 2P")
	active_slot = mini(active_slot,1 if coop else 0)
	slot_choice.selected = active_slot
	row = character.duplicate(true)
	var hero := str(row.hero)
	title.text = NAMES[Battle.HEROES.find(hero)]
	var values := Battle.character_stats(row,["easy","normal","hard"][difficulties.selected])
	var base := Battle.character_stats(_base_row(hero),["easy","normal","hard"][difficulties.selected])
	stats.text = "%s\n生命　%d\n基準攻擊　%d　(%+d)\n攻速　%d%%　(%+d%%)\n速度　%.2f　(%+.2f)\n範圍　%.0f　(%+.0f)\n擊退　%+.1f\n投摔　%d\n護符　%s\n總積分　%d" % [owner,values.hp,values.damage,values.damage-base.damage,values.attack_speed,values.attack_speed-base.attack_speed,values.speed,values.speed-base.speed,values.reach,values.reach-base.reach,values.knockback,values.throw_damage,values.protection,int(row.score)]
	if hero == "oichi": stats.text = stats.text.replace("基準攻擊","普通弓射")
	preview.fighter = row.duplicate(true)
	preview.fighter.merge({"kind":hero,"team":0,"id":active_slot+1,"player_index":active_slot,"action":"idle","action_tick":0,"hp":values.hp,"max_hp":values.hp,"z":0,"face":1,"rage":0,"armor":0,"freeze":0,"poison":0,"invuln":0})
	purse.text = "金錢 %d 文　｜　武器 %d / 2・護符 %d / 2" % [int(row.gold),Equipment.bag_count(row,false),Equipment.bag_count(row,true)]
	unequip_button.disabled = int(row.treasure_uid) == 0
	_refresh_items()

func _base_row(hero: String) -> Dictionary:
	var base := {"hero":hero,"weapon_id":Weapons.default_for(hero),"owned_weapons":[Weapons.default_for(hero)],"max_hp_bonus":0}
	Equipment.ensure(base)
	return base

func _refresh_items() -> void:
	current_items.clear()
	item_list.clear()
	for item in row.get("inventory",[]):
		if int(item.uid) not in row.get("bag_uids",[]): continue
		if Equipment.TREASURES.has(item.item_id) != (category.selected == 0): continue
		current_items.append(item)
		var spec := Equipment.catalog(item.item_id)
		item_list.add_item(("◆ " if item.uid in [row.weapon_uid,row.treasure_uid] else "　") + "%s　%d/%d　#%d" % [spec.name,int(item.durability),int(spec.durability),int(item.uid)])
	if not current_items.is_empty(): item_list.select(0)
	_show_item()

func _show_item() -> void:
	var indices := item_list.get_selected_items()
	if indices.is_empty():
		item_detail.text = "行囊尚無護符。可從倉庫準備，或在戰場拾取。" if category.selected == 0 else "行囊尚無武器。出陣使用無限耐久白板；拾取後自行換裝。"
		equip_button.disabled = true
		return
	var item: Dictionary = current_items[indices[0]]
	var spec := Equipment.catalog(item.item_id)
	item_detail.text = spec.description if category.selected == 0 else "攻擊 %+d　攻速 %d%%　範圍 %+.0f　擊退 %+.1f\n%s\n耐久 %d / %d；每次傷到敵人減 1。" % [int(spec.damage_bonus),roundi(spec.attack_speed * 100),float(spec.reach_bonus),float(spec.knockback),spec.special,int(item.durability),int(spec.durability)]
	equip_button.disabled = item.uid in [row.weapon_uid,row.treasure_uid]
	equip_button.text = "已裝備" if equip_button.disabled else "裝備並查看變化"

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	if size >= 25:
		label.add_theme_font_override("font",Typography.font())
		label.add_theme_color_override("font_color",Typography.GOLD)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size",19)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
