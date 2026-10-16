extends SceneTree

const CharacterPanel = preload("res://ui/character_select_panel.gd")
const CollectionPanel = preload("res://ui/collection_panel.gd")
const ArchivePanel = preload("res://ui/weapon_encyclopedia_panel.gd")
const Profile = preload("res://core/save_profile.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func inside(control: Control, label: String) -> void:
	var bounds := control.get_global_rect()
	check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= 1280 and bounds.end.y <= 660,label + " fits above the controller footer: " + str(bounds))

func selected_row_visible(list: ItemList, label: String) -> void:
	var row := list.get_item_rect(list.get_selected_items()[0])
	row.position.y -= list.get_v_scroll_bar().value
	var paper := list.get_theme_stylebox("panel")
	check(row.position.y >= paper.content_margin_top and row.end.y <= list.size.y - paper.content_margin_bottom,label + " remains fully visible: " + str(row))

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/native-v34/panels")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK,"Capture " + name)

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	var profile := Profile.new("user://ui-panels-missing-%d.json" % Time.get_ticks_usec(),"測試武將")
	var row := profile.character(0,"nobunaga")
	row.score = 1000000000
	row.max_hp_bonus = 10000
	var charm := Equipment.add(row,"marici")
	Equipment.pack(row,charm,true)
	Equipment.equip(row,charm)
	var character := CharacterPanel.new()
	root.add_child(character)
	character.chapter_choice.add_item("第二大關　大高兵糧道")
	character.configure(true,row,"二十字的武者名號一二三四五六七八九十")
	character.notice.text = "兩軍各整行囊，待命出陣。"
	await settle()
	for control in [character.find_child("Begin",true,false),character.notice,character.item_list,character.find_child("StatsScroll",true,false),character.find_child("ItemDetailScroll",true,false)]: inside(control,"Character " + str(control.name))
	check(character.item_list.size.y >= 90,"Bag keeps usable list height")
	check(character.find_child("StatsScroll",true,false).focus_mode == Control.FOCUS_ALL,"Stats readable by controller")
	check(character.find_child("ItemDetailScroll",true,false).focus_mode == Control.FOCUS_ALL,"Item effects readable by controller")
	await capture("character")
	character.queue_free()
	await process_frame
	var collection := CollectionPanel.new()
	root.add_child(collection)
	var entries: Array = []
	for index in range(120):
		entries.append({"id":str(index),"name":"長船長光　耐久 120 / 120　#%d" % index,"category":"刀","description":"兵器能力與歷史說明。\n".repeat(30),"can_equip":true,"can_pack":true,"has_details":true,"image":"res://assets/v22/weapons/sword_heshikiri.png","price":180,"packed":false})
	collection.configure("武者名號一二三四五六七八九十　信長　戰功 1000000000",entries,["0"])
	collection.notice.text = "兵器 2 / 2、護符 2 / 2（含裝備中）　｜　藏兵閣 120 / 120；出陣僅攜行囊。"
	collection.select_item("119")
	await settle()
	for control in [collection.item_list,collection.equip_button,collection.pack_button,collection.sell_button,collection.details_button,collection.notice,collection.description_scroll]: inside(control,"Collection " + str(control.name))
	check(collection.item_list.size.y >= 200,"Full warehouse keeps usable list height")
	check(collection.description_scroll.size.y >= 140,"Warehouse description has a readable viewport")
	check(collection.description_scroll.focus_mode == Control.FOCUS_ALL,"Warehouse description can take controller focus")
	check(collection.description_scroll.get_v_scroll_bar().max_value > collection.description_scroll.size.y,"Long warehouse description scrolls")
	check(collection.item_list.get_selected_items()[0] == 119,"Last warehouse item remains selectable")
	check(collection.picture.texture != null,"Warehouse artwork loads without a pre-existing import cache")
	await capture("collection")
	collection.configure("空倉庫",[],[])
	check(collection.selected_id.is_empty() and collection.equip_button.disabled and collection.pack_button.disabled,"Empty warehouse disables stale item actions")
	collection.queue_free()
	await process_frame
	var archive := ArchivePanel.new()
	root.add_child(archive)
	archive.hide()
	await settle()
	archive.configure("nobunaga",["sword_uchigatana","sword_heshikiri"],"practice_nobunaga")
	archive.show()
	await settle()
	await capture("archive-first")
	selected_row_visible(archive.weapon_list,"First archive row after hidden configure")
	check(archive.picture.texture != null,"Permanent practice weapon uses its catalog artwork")
	archive.select_weapon(archive.listed_ids[-1])
	await settle()
	selected_row_visible(archive.weapon_list,"Last archive row after selection")
	archive.weapon_list.get_v_scroll_bar().value = 80
	await settle()
	check(archive.weapon_list.get_v_scroll_bar().value == 80,"Manual archive scrolling remains unchanged between selections")
	archive.select_weapon("sword_heshikiri")
	await settle()
	for control in [archive.weapon_list,archive.filter,archive.detail_scroll,archive.equip_button,archive.title]: inside(control,"Archive " + str(control.name))
	check(archive.detail_scroll.focus_mode == Control.FOCUS_ALL,"Historical text can take controller focus")
	check(archive.detail_scroll.size.x >= 500,"Historical text has readable line width")
	check(not archive.equip_button.disabled and archive.equip_button.text == "裝備","Owned compatible weapon can be equipped")
	archive.select_weapon("sword_dojigiri")
	check(archive.equip_button.disabled and archive.equip_button.text == "尚未入藏","Unavailable equipment explains why")
	await settle()
	await capture("archive")
	archive.queue_free()
	await process_frame
	print("UI PANELS V34 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
