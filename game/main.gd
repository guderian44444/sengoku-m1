extends Node

const Battle = preload("res://core/battle.gd")
const BattleView = preload("res://render/battle_view.gd")
const CombatAudio = preload("res://render/combat_audio.gd")
const CombatHUD = preload("res://render/combat_hud.gd")
const Typography = preload("res://render/game_typography.gd")
const Wire = preload("res://core/wire.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const WeaponEncyclopedia = preload("res://ui/weapon_encyclopedia_panel.gd")
const CollectionPanel = preload("res://ui/collection_panel.gd")
const WeaponArchive = preload("res://core/weapon_encyclopedia.gd")
const Stages = preload("res://core/stage_data.gd")
const SaveProfile = preload("res://core/save_profile.gd")
const ArtDemo = preload("res://render/art_demo.gd")
const BUILD := "sengoku-m1-0.27.0"
const DEFAULT_PORT := 27860
const HEROES := ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
const HERO_NAMES := {"nobunaga": "信長", "oichi": "阿市", "hideyoshi": "秀吉", "ieyasu": "家康", "mitsuhide": "光秀", "tadakatsu": "忠勝"}
const FACTION_NAMES := {"mori": "毛利", "imagawa": "今川", "oda": "織田", "saito": "齋藤", "miyoshi": "三好", "azai": "淺井", "asakura": "朝倉", "takeda": "武田", "ikko": "一向一揆", "akechi": "明智", "hashiba": "羽柴", "iga": "伊賀"}
const DIFFICULTIES := ["easy", "normal", "hard"]
const CONTROL_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "light", "heavy", "jump", "grab", "special", "pickup", "guard"]
const BATTLE_HINT := "WASD 移動／雙點衝刺   J 輕擊   K 重擊／蓄力   I 防禦   空白 跳躍   L 抓摔\n搖桿 □／X 輕擊 · ○／B 重擊 · ×／A 跳 · △／Y 按住抓人、放開摔 · R1 必殺 · L2 防禦 · Options 選單"
const TRAINING_HINT := "WASD／雙點衝刺   J/K 輕重擊   I 防禦   空白 跳躍   L 抓摔   U 滿怒必殺   E 拾取\n1 木樁   2 肉盾   3 分波試戰   4 遠程兵   5 小王   R 重置   Tab 換人   F1 操作表"
var sim = Battle.new()
var view: Node2D
var audio: Node
var active := false
var paused := false
var session := "solo"
var local_slot := 0
var remote_id := 0
var remote_input := {"dx": 0, "dy": 0, "buttons": 0}
var remote_frame := -1
var remote_received_tick := 0
var local_frame := 0
var last_event := -1
var terminal_voice_played := false
var _victory_spoken: Dictionary = {}
var _victory_subtitle := ""
var pending_intro_actor := 0
var received_intro_actor := 0
var connecting_since := 0
var waiting_peer_since := 0
var selected_hero := "nobunaga"
var selected_chapter := 1
var selected_faction := "mori"
var difficulty := "normal"
var net_events: Array = []
var menu: Control
var menu_panel: VBoxContainer
var menu_pages: Dictionary = {}
var menu_screen := "title"
var options_return := "main"
var encyclopedia: Control
var encyclopedia_slot := 0
var encyclopedia_return := "select"
var collection: Control
var collection_return := "select"
var equipment_in_battle := false
var chapter_choice: OptionButton
var selection_coop := false
var partner_row: HBoxContainer
var menu_backdrop: TextureRect
var menu_shade: ColorRect
var menu_logo: TextureRect
var menu_caption: Label
var engineer_entry: Button
var volume_sliders: Dictionary = {}
var _camera_scene := -1
var status: Label
var hud: Label
var combat_hud: Control
var fullscreen_button: Button
var hint: Label
var end_label: Label
var address: LineEdit
var port: SpinBox
var heroes: OptionButton
var partner_heroes: OptionButton
var difficulties: OptionButton
var factions: OptionButton
var feedback_label: Label
var controls_dialog: AcceptDialog
var controls_was_paused := false
var smoke := ""
var smoke_terminal := false
var report_path := ""
var capture_path := ""
var capture_menu := false
var captured := false
var app_ticks := 0
var received_snapshots := 0
var testing := false
var training_active := false
var training_requested := false
var local_coop_requested := false
var training_drill := "dummy"
var _has_focus := true
var _input_armed := false
var _partner_input_armed := false
var player_devices: Array[int] = [-1, -1]
var _cancel_input_pending := false
var _cancel_sequence := -1
var art_demo := ArtDemo.new()
var demo_active := false
var demo_controls: HBoxContainer
var demo_toggle: Button
var demo_weather: OptionButton
var demo_speed: Button
var demo_requested := false
var demo_capture_pose := -1
var demo_capture_dir := ""
var demo_capture_next := 0
var demo_capture_busy := false
var demo_facing_left := false
var profiles = SaveProfile.new()
var weapon_choices: Array[OptionButton] = []
var weapon_rows: Array[HBoxContainer] = []
var _saved_profile_signature := ""
var exit_button: Button
var confirmation_text: Label
var confirmation_action: Callable
var confirmation_return := ""
var confirmation_paused := false
var ending_confirmed := false

func _ready() -> void:
	_actions()
	view = BattleView.new()
	add_child(view)
	audio = CombatAudio.new()
	add_child(audio)
	audio._intro_player.finished.connect(_local_boss_voice_finished)
	sim.boss_intros = audio.speech_manifest.get("boss_intros", {}).duplicate(true)
	sim.boss_intros.merge(audio.speech_manifest.get("stage_boss_intros",{}),true)
	_build_ui()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _fail("無法連線。請確認 IP、UDP 埠與防火牆。"))
	multiplayer.server_disconnected.connect(func(): _fail("主機已斷線。此 M1 不保留中途進度，請重新開局。"))
	Input.joy_connection_changed.connect(_joy_changed)
	get_window().focus_exited.connect(func(): _set_game_focus(false))
	get_window().focus_entered.connect(func(): _set_game_focus(true))
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_request_quit)
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-host": smoke = "host"
		elif arg == "--smoke-client": smoke = "client"
		elif arg == "--smoke-terminal": smoke_terminal = true
		elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg == "--capture-menu": capture_menu = true
		elif arg == "--autoplay": testing = true
		elif arg == "--training": training_requested = true
		elif arg == "--local-coop": local_coop_requested = true
		elif arg.begins_with("--drill="):
			var drill := arg.trim_prefix("--drill=")
			if drill in ["dummy", "shield", "enemies", "ranged", "boss"]: training_drill = drill
		elif arg == "--art-demo": demo_requested = true
		elif arg == "--art-facing-left": demo_facing_left = true
		elif arg.begins_with("--art-pose="): demo_capture_pose = clampi(int(arg.trim_prefix("--art-pose=")), 0, ArtDemo.POSES.size() - 1)
		elif arg.begins_with("--art-capture-dir="): demo_capture_dir = arg.trim_prefix("--art-capture-dir=")
	_configure_display()
	if smoke == "host":
		port.value = 27861
		_host()
	elif smoke == "client":
		port.value = 27861
		address.text = "127.0.0.1"
		heroes.selected = 1
		_join()
	elif local_coop_requested:
		_start_local_coop()
		if not active: _open_selection(true)
	elif training_requested:
		_start_training()
	elif demo_requested:
		_start_art_demo()
		if demo_facing_left: art_demo.facing = -1
		if demo_capture_pose >= 0:
			art_demo.seek(demo_capture_pose)
			art_demo.running = false
			_update_art_demo()
		if not demo_capture_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(demo_capture_dir)
			art_demo.running = false
			art_demo.seek(0)
			_update_art_demo()
	elif testing:
		_start_solo()
	if menu.visible:
		_show_menu_page("engineering" if not smoke.is_empty() else ("select" if local_coop_requested else "title"))
		audio.play_music()
	if capture_menu and not capture_path.is_empty(): _capture.call_deferred()

func _actions() -> void:
	var keys := {
		"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
		"light": KEY_J, "heavy": KEY_K, "jump": KEY_SPACE, "grab": KEY_L, "special": KEY_U, "pickup": KEY_E, "guard": KEY_I
	}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.24)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
	var buttons := {"light": JOY_BUTTON_X, "heavy": JOY_BUTTON_B, "jump": JOY_BUTTON_A, "grab": JOY_BUTTON_Y, "special": JOY_BUTTON_RIGHT_SHOULDER, "pickup": JOY_BUTTON_LEFT_SHOULDER, "move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT, "move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN}
	for action in buttons:
		var button := InputEventJoypadButton.new()
		button.button_index = buttons[action]
		InputMap.action_add_event(action, button)
	for action in ["ui_accept","ui_cancel"]:
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = JOY_BUTTON_A if action == "ui_accept" else JOY_BUTTON_B
		InputMap.action_add_event(action,button)
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_X if action in ["move_left", "move_right"] else JOY_AXIS_LEFT_Y
		axis.axis_value = -1.0 if action in ["move_left", "move_up"] else 1.0
		InputMap.action_add_event(action, axis)
	var guard_axis := InputEventJoypadMotion.new()
	guard_axis.axis = JOY_AXIS_TRIGGER_LEFT
	guard_axis.axis_value = 1.0
	InputMap.action_add_event("guard", guard_axis)

static func should_start_fullscreen(args: PackedStringArray, display_name: String, automated: bool) -> bool:
	if automated or display_name == "headless": return false
	for arg in args:
		if arg in ["--headless", "--script", "-s", "--windowed", "-w"] or arg.begins_with("--capture") or arg.begins_with("--art-capture") or arg.begins_with("--smoke"):
			return false
	return true

func _configure_display() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if should_start_fullscreen(args, DisplayServer.get_name(), testing or not capture_path.is_empty() or not demo_capture_dir.is_empty()):
		_set_fullscreen(true)
	else:
		_update_fullscreen_button()

func _set_fullscreen(enabled: bool) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	_update_fullscreen_button()

func _toggle_fullscreen() -> void:
	_set_fullscreen(get_window().mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN])

func _update_fullscreen_button() -> void:
	fullscreen_button.text = "切換視窗 (F11)" if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else "切換全螢幕 (F11)"

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Typography.theme()
	layer.add_child(ui)
	combat_hud = CombatHUD.new()
	ui.add_child(combat_hud)
	hud = Label.new()
	hud.position = Vector2(416, 15)
	hud.size = Vector2(448, 75)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 18)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	hint = Label.new()
	hint.text = BATTLE_HINT
	hint.hide()
	ui.add_child(hint)
	end_label = Label.new()
	end_label.position = Vector2(200, 138)
	end_label.size = Vector2(880, 130)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 32)
	end_label.add_theme_color_override("font_color", Typography.GOLD)
	end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(end_label)
	exit_button = _button("退出",_leave_to_menu,"VictoryExit",ui)
	exit_button.position = Vector2(1140,120)
	exit_button.size = Vector2(116,42)
	exit_button.hide()
	_build_menu(ui)
	_build_controls(ui)
	demo_controls = HBoxContainer.new()
	demo_controls.position = Vector2(24, 652)
	demo_controls.add_theme_constant_override("separation", 8)
	ui.add_child(demo_controls)
	demo_controls.add_theme_font_size_override("font_size", 17)
	demo_toggle = _button("暫停", _toggle_art_demo, "PauseDemo", demo_controls)
	_button("上一招", func(): _seek_art_demo(-1), "PreviousPose", demo_controls)
	_button("下一招", func(): _seek_art_demo(1), "NextPose", demo_controls)
	_button("上一幀", func(): _step_art_frame(-1), "PreviousFrame", demo_controls)
	_button("下一幀", func(): _step_art_frame(1), "NextFrame", demo_controls)
	demo_speed = _button("速度 1×", _toggle_art_speed, "DemoSpeed", demo_controls)
	_button("轉向", func(): art_demo.facing *= -1; _update_art_demo(), "FlipDemo", demo_controls)
	demo_weather = OptionButton.new()
	for label in ["天氣自動循環", "晴天", "夕照", "雨夜"]: demo_weather.add_item(label)
	demo_weather.item_selected.connect(func(index: int): art_demo.weather_override = index - 1; _update_art_demo())
	demo_controls.add_child(demo_weather)
	_button("回到選單", _leave_to_menu, "ExitDemo", demo_controls)
	demo_controls.hide()

func _menu_label(parent: Node, text: String, font_size: int = 24) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _menu_page(key: String, at: Vector2, width: float, heading: String = "") -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = key.capitalize()
	page.position = at
	page.size.x = width
	page.add_theme_constant_override("separation", 12)
	menu.add_child(page)
	menu_pages[key] = page
	if not heading.is_empty():
		var label := _menu_label(page, heading, 38)
		label.custom_minimum_size.y = 70
		label.add_theme_color_override("font_color", Typography.GOLD)
	return page

func _build_menu(ui: Control) -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	menu_backdrop = TextureRect.new()
	menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_path := "res://assets/v20/title/title-background.png"
	if FileAccess.file_exists(background_path): menu_backdrop.texture = ImageTexture.create_from_image(Image.load_from_file(background_path))
	menu.add_child(menu_backdrop)
	menu_shade = ColorRect.new()
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_shade.color = Color(0.06, 0.025, 0.06, 0.25)
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_shade)
	menu_logo = TextureRect.new()
	menu_logo.position = Vector2(220, 40)
	menu_logo.size = Vector2(840, 280)
	menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_logo.texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/v20/title/title-logo.png"))
	menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_logo)
	menu_caption = _menu_label(menu, "桶 狹 間 之 章", 25)
	menu_caption.position = Vector2(240, 304)
	menu_caption.size.x = 800
	menu_caption.add_theme_color_override("font_color", Typography.GOLD)
	var title_page := _menu_page("title", Vector2(380, 437), 520)
	_button("按下開始   PRESS START", func(): _show_menu_page("main"), "Start", title_page)
	_menu_label(title_page, "ENTER  ／  START", 17)
	var main_page := _menu_page("main", Vector2(430, 358), 420)
	_button("一 人 出 陣", func(): _open_selection(false), "Solo", main_page)
	_button("二 人 共 鬥", func(): _open_selection(true), "LocalCoop", main_page)
	_button("遊 戲 設 定", _open_options, "Options", main_page)
	_button("離 開 遊 戲", _request_quit, "Quit", main_page)
	var select_page := _menu_page("select", Vector2(320, 35), 640, "選 擇 武 將")
	select_page.add_theme_constant_override("separation",8)
	var first_row := HBoxContainer.new()
	select_page.add_child(first_row)
	_menu_label(first_row, "一番隊　", 25)
	heroes = OptionButton.new()
	for label in ["織田信長｜炎刀", "阿市｜短針・長弓", "豐臣秀吉｜短槍", "德川家康｜太刀", "明智光秀｜拔刀", "本多忠勝｜長槍"]: heroes.add_item(label)
	heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first_row.add_child(heroes)
	partner_row = HBoxContainer.new()
	select_page.add_child(partner_row)
	_menu_label(partner_row, "二番隊　", 25)
	partner_heroes = OptionButton.new()
	for hero in HEROES: partner_heroes.add_item(HERO_NAMES[hero])
	partner_heroes.selected = 1
	partner_heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	partner_row.add_child(partner_heroes)
	for slot in range(2):
		var row := HBoxContainer.new()
		select_page.add_child(row)
		_menu_label(row,"%dP 武器　" % (slot + 1),20)
		var choice := OptionButton.new()
		choice.name = "Weapon%d" % slot
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(choice)
		_button("圖鑑", func(): _open_weapon_encyclopedia(slot), "Encyclopedia%d" % slot, row)
		_button("裝備", func(): _open_collection(slot), "Collection%d" % slot, row)
		weapon_rows.append(row)
		weapon_choices.append(choice)
		choice.item_selected.connect(func(index: int):
			var hero: String = HEROES[heroes.selected if slot == 0 else partner_heroes.selected]
			var id: String = str(choice.get_item_metadata(index))
			if profiles.equip(slot,hero,id):
				if active and session in ["solo","local"] and not training_active:
					for fighter in sim.state.fighters:
						if fighter.team == 0 and fighter.player_index == slot and fighter.kind == hero and id in fighter.owned_weapons: fighter.weapon_id = id
				status.text = "武器裝備已保存。" if profiles.save() == OK else "裝備已套用，但存檔失敗。" + profiles.warning
		)
	heroes.item_selected.connect(func(_index): _refresh_loadouts())
	partner_heroes.item_selected.connect(func(_index): _refresh_loadouts())
	var difficulty_row := HBoxContainer.new()
	select_page.add_child(difficulty_row)
	_menu_label(difficulty_row, "難　度　", 25)
	difficulties = OptionButton.new()
	for label in ["故事", "標準", "挑戰"]: difficulties.add_item(label)
	difficulties.selected = 1
	difficulties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_row.add_child(difficulties)
	var chapter_row := HBoxContainer.new()
	select_page.add_child(chapter_row)
	_menu_label(chapter_row,"大　關　",25)
	chapter_choice = OptionButton.new()
	chapter_choice.name = "Chapter"
	chapter_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_row.add_child(chapter_choice)
	_refresh_chapters()
	_button("出　陣", func():
		if selection_coop: _start_local_coop()
		else: _start_solo(), "Begin", select_page)
	_button("返　回", _menu_back, "Back", select_page)
	var options := _menu_page("options", Vector2(310, 100), 660, "遊 戲 設 定")
	for category in ["music", "sfx", "voice"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		options.add_child(row)
		var label := _menu_label(row, {"music":"音 樂", "sfx":"音 效", "voice":"語 音"}[category], 25)
		label.custom_minimum_size.x = 100
		var slider := HSlider.new()
		slider.name = category.capitalize() + "Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = audio.get_category_volume(category) * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 48
		row.add_child(slider)
		var number := _menu_label(row, "%d%%" % int(slider.value), 24)
		number.custom_minimum_size.x = 88
		slider.value_changed.connect(func(value: float):
			number.text = "%d%%" % int(value)
			if audio.set_category_volume(category, value / 100.0) != OK: status.text = "音量已套用，但設定儲存失敗。"
		)
		volume_sliders[category] = slider
	fullscreen_button = _button("全螢幕 (F11)", _toggle_fullscreen, "Fullscreen", options)
	_button("操 作 與 招 式", _show_controls, "Controls", options)
	_button("返　回", _menu_back, "Back", options)
	var pause_page := _menu_page("pause", Vector2(430, 50), 420, "暫 停")
	pause_page.add_theme_constant_override("separation",8)
	_button("繼 續 戰 鬥", _resume, "Resume", pause_page)
	_button("重 新 出 陣", func():
		if training_active: _reset_training()
		elif session == "local": _start_local_coop()
		else: _start_solo(), "Restart", pause_page)
	_button("遊 戲 設 定", _open_options, "Options", pause_page)
	var collections := HBoxContainer.new()
	collections.name = "Collections"
	pause_page.add_child(collections)
	for slot in range(2):
		_button("%dP 裝備與收藏" % (slot + 1),func(): _open_collection(slot),"Collection%d" % slot,collections).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("保 存 人 物", func(): _save_characters(true), "SaveCharacters", pause_page)
	_button("返 回 主 畫 面", _leave_to_menu, "Leave", pause_page)
	var confirm_page := _menu_page("confirm",Vector2(390,225),500,"確認操作")
	confirmation_text = _menu_label(confirm_page,"",24)
	_button("取消",_cancel_confirmation,"Cancel",confirm_page)
	_button("確認",_accept_confirmation,"Confirm",confirm_page)
	menu_panel = _menu_page("engineering", Vector2(260, 30), 760, "工 程 入 口")
	menu_panel.add_theme_font_size_override("font_size", 18)
	menu_panel.add_theme_constant_override("separation", 7)
	factions = OptionButton.new()
	for faction in FACTION_NAMES: factions.add_item(FACTION_NAMES[faction] + "軍")
	menu_panel.add_child(factions)
	var tools_row := HBoxContainer.new()
	menu_panel.add_child(tools_row)
	_button("武將與難度設定", func(): _open_selection(false), "Selection", tools_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("逐招素材展示", _start_art_demo, "ArtDemo", tools_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trials_row := HBoxContainer.new()
	menu_panel.add_child(trials_row)
	_button("練習場", _start_training, "Training", trials_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("陣營試戰", func(): _start_training("enemies"), "EnemyTraining", trials_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var network_row := HBoxContainer.new()
	menu_panel.add_child(network_row)
	address = LineEdit.new()
	address.placeholder_text = "主機 IP"
	address.text = "127.0.0.1"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network_row.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = DEFAULT_PORT
	port.prefix = "UDP "
	port.custom_minimum_size.x = 175
	network_row.add_child(port)
	var network_buttons := HBoxContainer.new()
	menu_panel.add_child(network_buttons)
	_button("建立雙人主機", _host, "Host", network_buttons)
	_button("以 IP 加入", _join, "Join", network_buttons)
	var ips: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.is_valid_ip_address() and "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."): ips.append(ip)
	_menu_label(menu_panel, "本機 IP：" + (", ".join(ips) if not ips.is_empty() else "未偵測"), 16)
	feedback_label = _menu_label(menu_panel, "F1 操作表 · 區域網路 UDP 直連", 16)
	_button("返　回", _menu_back, "Back")
	status = _menu_label(menu, "", 18)
	status.position = Vector2(190, 608)
	status.size = Vector2(900, 48)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	engineer_entry = _button("工程入口", func(): _show_menu_page("engineering"), "EngineeringEntry", menu)
	engineer_entry.position = Vector2(535, 666)
	engineer_entry.size = Vector2(210, 36)
	engineer_entry.add_theme_font_size_override("font_size", 17)
	encyclopedia = WeaponEncyclopedia.new()
	encyclopedia.name = "WeaponEncyclopedia"
	menu.add_child(encyclopedia)
	menu_pages["encyclopedia"] = encyclopedia
	encyclopedia.closed.connect(_menu_back)
	encyclopedia.equip_requested.connect(_equip_from_encyclopedia)
	collection = CollectionPanel.new()
	collection.name = "Collection"
	menu.add_child(collection)
	menu_pages["collection"] = collection
	collection.closed.connect(_menu_back)
	collection.equip_requested.connect(_equip_from_encyclopedia)
	collection.details_requested.connect(func(id: String):
		_open_weapon_encyclopedia(encyclopedia_slot,"collection")
		encyclopedia.select_weapon(id)
	)
	_show_menu_page("title")

func _show_menu_page(page: String) -> void:
	menu_screen = page
	exit_button.hide()
	menu.show()
	for key in menu_pages: menu_pages[key].visible = key == page
	menu_backdrop.visible = not active
	menu_shade.color.a = 0.72 if active or page not in ["main", "title"] else 0.18
	menu_logo.visible = page in ["title", "main"]
	menu_caption.visible = menu_logo.visible
	engineer_entry.visible = page not in ["engineering", "encyclopedia", "collection", "confirm"]
	status.visible = page not in ["encyclopedia", "collection", "confirm"]
	combat_hud.visible = active
	hud.visible = active
	end_label.visible = active
	if page == "pause":
		menu_pages.pause.get_node("Resume").visible = sim.state.get("phase", "") in ["playing", "won"]
		menu_pages.pause.get_node("Restart").visible = session in ["solo", "local"]
		menu_pages.pause.get_node("SaveCharacters").visible = session in ["solo","local"] and not training_active
		menu_pages.pause.get_node("Collections").visible = session in ["solo","local"] and not training_active and not demo_active
		menu_pages.pause.get_node("Collections/Collection1").visible = session == "local"
	for control in menu_pages[page].find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL:
			control.grab_focus()
			break

func _open_selection(coop: bool) -> void:
	selection_coop = coop
	partner_row.visible = coop
	_refresh_loadouts()
	_refresh_chapters()
	status.text = profiles.warning if profiles.warning != "" else ("雙人合作請連接兩支搖桿。人物、裝備與大關自動保存。" if coop else "讀取人物、收藏與大關；出陣從大關起點開始，滿血三條命。")
	if profiles.warning == "" and int(chapter_choice.get_item_metadata(chapter_choice.selected)) != int(profiles.data.get("chapter",1)):
		status.text = "記錄中的第%d大關尚未開放；目前可重玩已開放大關，人物與收藏保留。" % int(profiles.data.chapter)
	_show_menu_page("select")

func _refresh_chapters() -> void:
	chapter_choice.clear()
	var saved := int(profiles.data.get("chapter",1))
	var unlocked := maxi(saved,int(profiles.data.get("completed_chapter",0)) + 1)
	for chapter in Stages.available():
		if int(chapter.id) > unlocked: continue
		chapter_choice.add_item("第%d大關　%s" % [int(chapter.id),str(chapter.title)])
		chapter_choice.set_item_metadata(chapter_choice.item_count - 1,int(chapter.id))
		if int(chapter.id) == saved: chapter_choice.selected = chapter_choice.item_count - 1

func _refresh_loadouts() -> void:
	for slot in range(weapon_choices.size()):
		weapon_rows[slot].visible = slot == 0 or selection_coop
		var hero: String = HEROES[heroes.selected if slot == 0 else partner_heroes.selected]
		var row: Dictionary = profiles.character(slot,hero)
		var choice := weapon_choices[slot]
		choice.clear()
		for id in row.owned_weapons:
			var weapon: Dictionary = Weapons.item(id)
			choice.add_item("%s　階%d" % [weapon.name,weapon.tier])
			choice.set_item_metadata(choice.item_count - 1,id)
			if id == row.weapon_id: choice.selected = choice.item_count - 1

func _equipment_hero(slot: int) -> String:
	if equipment_in_battle:
		for fighter in sim.state.fighters:
			if fighter.team == 0 and int(fighter.player_index) == slot: return str(fighter.kind)
	return HEROES[heroes.selected if slot == 0 else partner_heroes.selected]

func _open_collection(slot: int) -> void:
	collection_return = menu_screen
	equipment_in_battle = menu_screen == "pause"
	if equipment_in_battle: _save_characters()
	encyclopedia_slot = slot
	_refresh_collection()
	_show_menu_page("collection")
	collection.item_list.grab_focus()

func _refresh_collection() -> void:
	var hero := _equipment_hero(encyclopedia_slot)
	var row: Dictionary = profiles.character(encyclopedia_slot,hero)
	var items := []
	for id in row.owned_weapons:
		var weapon: Dictionary = Weapons.item(id)
		items.append({"id":id,"name":"%s　階%d" % [str(weapon.name),int(weapon.tier)],"category":"武器／" + {"sword":"刀","spear":"槍","bow":"弓"}[weapon.family],
			"description":WeaponArchive.stats(id) + "\n\n" + encyclopedia.archive.history(id),"image":"res://assets/v22/weapons/%s.png" % id,"can_equip":Weapons.compatible(hero,id),"has_details":true,"slot":"武器"})
	collection.configure("%dP %s　｜　總積分 %d　生命追加 +%d" % [encyclopedia_slot + 1,HERO_NAMES[hero],int(row.score),int(row.max_hp_bonus)],items,[row.weapon_id])

func _open_weapon_encyclopedia(slot: int, return_page: String = "select") -> void:
	encyclopedia_return = return_page
	if return_page != "collection": equipment_in_battle = false
	encyclopedia_slot = slot
	var hero := _equipment_hero(slot)
	var row: Dictionary = profiles.character(slot,hero)
	encyclopedia.configure(hero,row.owned_weapons,row.weapon_id)
	_show_menu_page("encyclopedia")

func _equip_from_encyclopedia(id: String) -> void:
	var hero := _equipment_hero(encyclopedia_slot)
	if not profiles.equip(encyclopedia_slot,hero,id): return
	if equipment_in_battle:
		for fighter in sim.state.fighters:
			if fighter.team == 0 and int(fighter.player_index) == encyclopedia_slot: fighter.weapon_id = id
		sim.cancel_input(encyclopedia_slot)
	status.text = "" if profiles.save() == OK else "存檔失敗。" + profiles.warning
	_refresh_loadouts()
	var row: Dictionary = profiles.character(encyclopedia_slot,hero)
	encyclopedia.equipped = str(row.weapon_id)
	encyclopedia.owned = row.owned_weapons.duplicate()
	encyclopedia.refresh_list()
	if status.text != "": encyclopedia.game_text.text += "\n\n" + status.text
	_refresh_collection()
	collection.notice.text = status.text

func _load_characters() -> void:
	if testing or session not in ["solo","local"]: return
	for fighter in sim.state.fighters:
		if fighter.team == 0: profiles.apply_to(fighter)
	sim.state.loot_rng = int(Time.get_unix_time_from_system()) & 0x7fffffff
	_saved_profile_signature = ""

func _save_characters(manual: bool = false) -> void:
	if not active or testing or training_active or demo_active or session not in ["solo","local"]: return
	for fighter in sim.state.fighters: profiles.capture(fighter)
	if sim.state.has("stage"): profiles.capture_chapter(int(sim.state.stage.id),sim.state.phase == "won")
	var signature := JSON.stringify(profiles.data)
	if not manual and signature == _saved_profile_signature: return
	var err: Error = profiles.save()
	if err == OK:
		_saved_profile_signature = signature
		if manual: status.text = "人物、收藏裝備與大關已保存；再次出陣從大關起點開始。"
	else:
		if profiles.warning == "": profiles.warning = "角色存檔失敗 (%d)，原存檔與備份保留。" % err
		if is_instance_valid(status): status.text = profiles.warning

func _open_options() -> void:
	options_return = menu_screen
	status.text = "音量會自動保存；左右調整，確認返回。"
	_show_menu_page("options")

func _menu_back() -> void:
	if menu_screen == "confirm":
		_cancel_confirmation()
		return
	status.text = ""
	if not active and session in ["host", "client"]:
		_leave_to_menu()
		return
	if menu_screen == "encyclopedia":
		_show_menu_page(encyclopedia_return)
		if encyclopedia_return == "collection": collection.item_list.grab_focus()
		else: weapon_rows[encyclopedia_slot].get_node("Encyclopedia%d" % encyclopedia_slot).grab_focus()
	elif menu_screen == "collection":
		_show_menu_page(collection_return)
		if collection_return == "pause": menu_pages.pause.get_node("Collections/Collection%d" % encyclopedia_slot).grab_focus()
		else: weapon_rows[encyclopedia_slot].get_node("Collection%d" % encyclopedia_slot).grab_focus()
	elif menu_screen == "options": _show_menu_page(options_return)
	elif menu_screen == "pause": _resume()
	elif menu_screen == "main": _show_menu_page("title")
	elif menu_screen != "title": _show_menu_page("pause" if active else "main")

func _build_controls(ui: Control) -> void:
	controls_dialog = AcceptDialog.new()
	controls_dialog.title = "吞食戰國 · 操作與 COMBO"
	controls_dialog.theme = Typography.theme()
	controls_dialog.ok_button_text = "回到遊戲"
	controls_dialog.exclusive = true
	ui.add_child(controls_dialog)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.custom_minimum_size = Vector2(1000, 490)
	text.add_theme_font_size_override("normal_font_size", 19)
	text.add_theme_constant_override("line_separation", 5)
	controls_dialog.add_child(text)
	var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://controls-v11.json"))
	text.text = "[b]畫面與進軍[/b]\nF11 全螢幕／視窗 · Esc / Options 開啟選單 · F1 關閉本表\n畫面上方：肖像、體力、氣力、命數與積分。每人三條命（含目前），每 10000 分加一命。滿氣 U / R1 必殺。\n每區兩個據點；擊破敵人與路障後，看到 GO → 就一起向右前進。\n食物回復體力，護符提供 40／75／110 點抵傷；走近按 E / L1 拾取。護符光芒消失表示用盡。\n倒地死亡後約 2 秒再起、3 秒保護；三命用盡即出局。雙人需各接一支搖桿。\n\n[b]六主角操作表[/b]\n" + BATTLE_HINT + "\nU 滿怒必殺 · E 拾取 · 同方向雙點按住衝刺（上下走位保持快跑）\n一般受擊 +1% 氣力；紅血（低於25%體力）受擊 +5%\n按住左右連打：出招時停止前進，停打恢復；新按左右＋J：突進技\n先衝刺再按 K：立即衝刺重手，朝面前攻擊；不進入蓄力\n\n[b]練習場[/b]\n" + TRAINING_HINT + "\n\n"
	for row in guide.rows:
		text.text += "[color=#ffd581][b]%s[/b][/color]\n" % row.input
		for hero in HEROES:
			text.text += "%s：%s\n" % [HERO_NAMES[hero], row.get(hero, row.note)]
		text.text += "%s\n\n" % row.note
	text.text += "[b]COMBO 練習[/b]\n" + "\n".join(guide.chains) + "\n\n" + guide.gamepad + "\n\n" + guide.training
	controls_dialog.confirmed.connect(_close_controls)
	controls_dialog.canceled.connect(_close_controls)
	controls_dialog.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
			_close_controls()
			controls_dialog.set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
			_toggle_fullscreen()
			controls_dialog.set_input_as_handled()
	)

func _show_controls() -> void:
	controls_was_paused = paused
	_cancel_local_controls()
	if active and session in ["solo", "local"]:
		paused = true
	controls_dialog.popup_centered(Vector2i(1040, 570))

func _close_controls() -> void:
	controls_dialog.hide()
	paused = controls_was_paused or not _has_focus or (session == "local" and (player_devices[0] < 0 or player_devices[1] < 0))
	_input_armed = false
	_partner_input_armed = false

func _button(text: String, callback: Callable, node_name: String, parent: Node = null) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	(parent if parent != null else menu_panel).add_child(button)
	return button

func _choices() -> void:
	selected_hero = HEROES[heroes.selected]
	selected_chapter = int(chapter_choice.get_item_metadata(chapter_choice.selected))
	difficulty = DIFFICULTIES[difficulties.selected]
	selected_faction = FACTION_NAMES.keys()[factions.selected]

func _close_network() -> void:
	_save_characters()
	_stop_rumble()
	player_devices = [-1, -1]
	audio.stop_speech()
	audio.stop_music()
	pending_intro_actor = 0
	received_intro_actor = 0
	training_active = false
	demo_active = false
	view.art_demo = false
	view.demo_pose = -1
	demo_controls.hide()
	hint.hide()
	combat_hud.sync({})
	hud.text = ""
	exit_button.hide()
	hint.text = BATTLE_HINT
	active = false
	session = "solo"
	remote_id = 0
	connecting_since = 0
	waiting_peer_since = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _start_solo() -> void:
	if _confirm_end(_start_solo,"重新開始這一戰？"): return
	_close_network()
	_choices()
	local_slot = 0
	sim.reset_campaign(difficulty, 1, [selected_hero],selected_chapter)
	_load_characters()
	_activate()

func _start_local_coop() -> void:
	if _confirm_end(_start_local_coop,"重新開始雙人戰鬥？"): return
	if _connected_pads().size() < 2:
		status.text = "雙搖桿合作需要兩支搖桿。請接上兩支，再按雙搖桿合作。"
		return
	_close_network()
	_choices()
	session = "local"
	local_slot = 0
	sim.reset_campaign(difficulty, 2, [selected_hero, HEROES[partner_heroes.selected]],selected_chapter)
	_load_characters()
	_activate()
	hint.text = "同機合作：1P／2P 各用一支搖桿，鍵盤也可控制 1P；同畫面共同前進\n□／X 輕擊 · ○／B 重擊 · ×／A 跳 · △／Y 按住抓人、放開摔 · R1／RB 必殺 · L2／LT 防禦 · Options 暫停"

func _start_training(drill: String = "") -> void:
	if _confirm_end(_start_training.bind(drill),"結束目前階段，進入練習場？"): return
	if drill != "": training_drill = drill
	_close_network()
	_choices()
	training_active = true
	local_slot = 0
	_reset_training()

func _reset_training() -> void:
	if not training_active: return
	if _confirm_end(_reset_training,"重置目前練習？"): return
	audio.stop_speech()
	sim.reset_training(selected_hero, training_drill, selected_faction)
	_activate()
	hint.text = TRAINING_HINT
	_update_view()

func _switch_training_hero() -> void:
	if not training_active: return
	if _confirm_end(_switch_training_hero,"切換人物並重置練習？"): return
	selected_hero = HEROES[(HEROES.find(selected_hero) + 1) % HEROES.size()]
	heroes.selected = HEROES.find(selected_hero)
	_reset_training()

func _choose_training_drill(drill: String) -> void:
	if _confirm_end(_choose_training_drill.bind(drill),"切換項目並重置練習？"): return
	training_drill = drill
	_reset_training()

func _start_art_demo() -> void:
	if _confirm_end(_start_art_demo,"結束目前階段，進入素材展示？"): return
	_close_network()
	art_demo = ArtDemo.new()
	demo_active = true
	paused = false
	menu.hide()
	hud.show()
	end_label.show()
	hint.hide()
	end_label.text = ""
	demo_controls.show()
	demo_weather.selected = 0
	_update_art_demo()

func _toggle_art_demo() -> void:
	art_demo.running = not art_demo.running
	_update_art_demo()

func _seek_art_demo(direction: int) -> void:
	art_demo.seek(art_demo.pose() + direction)
	art_demo.running = false
	_update_art_demo()

func _toggle_art_speed() -> void:
	art_demo.speed = 0.5 if art_demo.speed == 1.0 else 1.0
	_update_art_demo()

func _step_art_frame(direction: int) -> void:
	art_demo.running = false
	var current: Dictionary = view.animation_sample()
	var start := art_demo.pose() * ArtDemo.POSE_SECONDS
	for attempt in range(145):
		art_demo.elapsed = start + fposmod(art_demo.elapsed - start + direction / 60.0, ArtDemo.POSE_SECONDS)
		_update_art_demo()
		var next: Dictionary = view.animation_sample()
		if next.clip != current.clip or next.frame != current.frame: break

func _update_art_demo() -> void:
	combat_hud.hide()
	hud.position = Vector2(28, 15)
	hud.size = Vector2(1220, 80)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	view.art_demo = true
	view.art_time = art_demo.elapsed
	view.demo_pose = art_demo.pose()
	view.demo_progress = art_demo.progress()
	view.weather = art_demo.weather()
	view.camera_x = 0.0
	view.state = art_demo.world()
	view.queue_redraw()
	demo_toggle.text = "暫停" if art_demo.running else "繼續循環"
	demo_speed.text = "速度 0.5×" if art_demo.speed < 1.0 else "速度 1×"
	var sample: Dictionary = view.animation_sample()
	hud.text = "吞食戰國  M1 逐格動畫 v0.7    %02d / 10 · %s    %s\n信長／阿市    %s %d/%d 幀    空白暫停 · ← → 逐招 · [ ] 逐幀 · S 慢速 · F 轉向" % [art_demo.pose() + 1, ArtDemo.POSES[art_demo.pose()], ["晴天", "夕照", "雨夜"][art_demo.weather()], "待機" if sample.clip == "idle" else "動作", int(sample.frame) + 1, int(sample.count)]

func _activate() -> void:
	terminal_voice_played = false
	_victory_spoken.clear()
	_victory_subtitle = ""
	active = true
	paused = false
	audio.play_music()
	audio.sync_stage_music(sim.state)
	last_event = -1
	local_frame = 0
	remote_frame = -1
	remote_input = _neutral()
	_input_armed = false
	_partner_input_armed = false
	_sync_devices()
	_cancel_input_pending = false
	_cancel_sequence = -1
	net_events.clear()
	menu.hide()
	hud.show()
	end_label.show()
	_camera_scene = -1
	end_label.text = ""
	end_label.position = Vector2(200, 210)
	view.local_slot = local_slot
	_update_view()
	if smoke.is_empty() and not testing and sim.state.get("intro", {}).is_empty():
		for fighter in sim.state.fighters:
			if fighter.team == 0: audio.play_character(fighter.kind, "intro", fighter.player_index, true)

func _host() -> void:
	if _confirm_end(_host,"結束目前階段，建立連線戰鬥？"): return
	_close_network()
	_choices()
	var peer := ENetMultiplayerPeer.new()
	if not smoke.is_empty(): peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(int(port.value), 1, 3)
	if error != OK:
		_fail("無法建立主機（錯誤 %s），埠可能已使用。" % error)
		return
	multiplayer.multiplayer_peer = peer
	session = "host"
	audio.play_music()
	local_slot = 0
	status.text = "等待第二台電腦加入 · UDP %d\n請隊友輸入本機 IPv4。按返回可結束等候。" % int(port.value)
	_show_menu_page("engineering")

func _join() -> void:
	if _confirm_end(_join,"結束目前階段，加入連線戰鬥？"): return
	_close_network()
	_choices()
	if not address.text.strip_edges().is_valid_ip_address():
		_fail("IP 格式不正確，請輸入主機的 IPv4／IPv6 位址。")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.text.strip_edges(), int(port.value), 3)
	if error != OK:
		_fail("無法開始連線（錯誤 %s）。" % error)
		return
	multiplayer.multiplayer_peer = peer
	session = "client"
	audio.play_music()
	local_slot = 1
	connecting_since = Time.get_ticks_msec()
	status.text = "正在連線至 %s:%d…" % [address.text, int(port.value)]

func _fingerprint() -> String:
	return FileAccess.get_sha256("res://core/battle.gd")

func _peer_connected(id: int) -> void:
	if session == "host":
		waiting_peer_since = Time.get_ticks_msec()
		status.text = "對方已連上，檢查版本與角色中…"

func _connected() -> void:
	hello.rpc_id(1, BUILD, _fingerprint(), selected_hero)

@rpc("any_peer", "call_remote", "reliable", 0)
func hello(build: String, fingerprint: String, hero: String) -> void:
	if session != "host" or remote_id != 0: return
	var sender := multiplayer.get_remote_sender_id()
	if build != BUILD or fingerprint != _fingerprint() or hero not in HEROES:
		rejected.rpc_id(sender, "遊戲版本／內容不一致，請使用同一份 M1 原型。")
		return
	remote_id = sender
	waiting_peer_since = 0
	sim.reset_campaign(difficulty, 2, [selected_hero, hero])
	_activate()
	begin_client.rpc_id(sender, sim.get_state(), difficulty)

@rpc("authority", "call_remote", "reliable", 0)
func rejected(reason: String) -> void:
	_fail(reason)

@rpc("authority", "call_remote", "reliable", 0)
func begin_client(world: Dictionary, mode: String) -> void:
	if session != "client": return
	if not Wire.valid_snapshot(world) or mode not in DIFFICULTIES:
		_fail("主機傳來的關卡資料格式不符，請使用同一版本。")
		return
	connecting_since = 0
	difficulty = mode
	sim.state = world
	_activate()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(sequence: int, frame: Dictionary) -> void:
	if session != "host" or not active or multiplayer.get_remote_sender_id() != remote_id: return
	if sequence < 0 or sequence <= remote_frame or not Wire.valid_input(frame): return
	remote_frame = sequence
	remote_input = frame.duplicate()
	remote_received_tick = int(sim.state.tick)

@rpc("any_peer", "call_remote", "reliable", 0)
func cancel_controls(sequence: int) -> void:
	if session != "host" or not active or multiplayer.get_remote_sender_id() != remote_id or sequence < 0: return
	sim.cancel_input(1)
	remote_input = {"dx": 0, "dy": 0, "buttons": 64}
	remote_frame = maxi(remote_frame, sequence)
	remote_received_tick = int(sim.state.tick)
	controls_cancelled.rpc_id(remote_id, sequence)

@rpc("authority", "call_remote", "reliable", 0)
func controls_cancelled(sequence: int) -> void:
	if session == "client" and sequence == _cancel_sequence:
		_cancel_sequence = -1

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(world: Dictionary) -> void:
	if session != "client" or not active: return
	if not Wire.valid_snapshot(world):
		_fail("收到無效的連線資料，已返回選單。")
		return
	if not _newer_snapshot(world): return
	sim.state = world
	received_snapshots += 1
	_events(world.get("events", []))

func _newer_snapshot(world: Dictionary) -> bool:
	if int(world.tick) != int(sim.state.tick): return int(world.tick) > int(sim.state.tick)
	# Boss dialogue freezes world ticks; its countdown and first event must still reach the client.
	return int(world.event_seq) > int(sim.state.event_seq) or int(world.get("intro", {}).get("remaining_ticks", 0)) < int(sim.state.get("intro", {}).get("remaining_ticks", 0))

func _peer_disconnected(id: int) -> void:
	if smoke == "host" and int(sim.state.get("tick", 0)) >= (65 if smoke_terminal else 180) and remote_frame > 0:
		_report({"ok": true, "mode": smoke, "tick": sim.state.tick, "phase": sim.state.phase, "players": 2, "remote_sequence": remote_frame})
		get_tree().quit()
		return
	if session == "host":
		_fail("隊友已離線。本次關卡中止，可重新建立主機。")
	elif session == "client":
		_fail("連線中斷，請回主選單重新連線。")

func _fail(message: String) -> void:
	_close_network()
	paused = false
	_show_menu_page("main")
	audio.play_music()
	status.text = message
	if not smoke.is_empty():
		_report({"ok": false, "error": message})
		get_tree().quit(1)

func _leave_to_menu() -> void:
	if _confirm_end(_leave_to_menu,"結束目前階段，返回主選單？"): return
	_close_network()
	paused = false
	_show_menu_page("main")
	audio.play_music()
	end_label.text = ""
	status.text = ""

func _confirm_end(action: Callable, message: String) -> bool:
	if ending_confirmed or (not active and not demo_active and session not in ["host","client"]): return false
	_request_confirmation(action,message)
	return true

func _request_confirmation(action: Callable, message: String) -> void:
	if menu.visible and menu_screen == "confirm": return
	confirmation_action = action
	confirmation_return = menu_screen if menu.visible else ""
	confirmation_paused = paused
	paused = true
	_cancel_local_controls()
	confirmation_text.text = message
	_show_menu_page("confirm")
	menu_pages.confirm.get_node("Cancel").grab_focus()

func _cancel_confirmation() -> void:
	confirmation_action = Callable()
	paused = confirmation_paused or not _has_focus
	if confirmation_return == "": menu.hide()
	else: _show_menu_page(confirmation_return)
	_input_armed = false
	_partner_input_armed = false

func _accept_confirmation() -> void:
	var action := confirmation_action
	_cancel_confirmation()
	ending_confirmed = true
	if action.is_valid(): action.call()
	ending_confirmed = false

func _request_quit() -> void:
	if not ending_confirmed:
		_request_confirmation(_request_quit,"離開遊戲？")
		return
	_save_characters()
	get_tree().quit()

func _resume() -> void:
	if session == "local" and (player_devices[0] < 0 or player_devices[1] < 0):
		status.text = "隊友搖桿尚未連接。接回兩支搖桿後再繼續。"
		return
	if active:
		paused = false
		_input_armed = false
		_partner_input_armed = false
		menu.hide()

func _neutral() -> Dictionary:
	return {"dx": 0, "dy": 0, "buttons": 0}

func _input_frame() -> Dictionary:
	if session == "client" and _cancel_sequence >= 0: return {"dx": 0, "dy": 0, "buttons": 64}
	# A cancelled input must not be interpreted as deliberately releasing a held enemy.
	if _cancel_input_pending or menu.visible or controls_dialog.visible or paused or not _has_focus:
		_cancel_input_pending = false
		return {"dx": 0, "dy": 0, "buttons": 64} if session in ["host", "client"] else _neutral()
	if not smoke.is_empty() or testing:
		return {"dx": 1 if local_frame < 160 else 0, "dy": 0, "buttons": 1 if local_frame % 22 < 2 else 0}
	var frame := _player_frame(local_slot)
	if not _input_armed:
		_input_armed = frame.buttons == 0 and frame.dx == 0 and frame.dy == 0
		return _neutral()
	return frame

func _partner_frame() -> Dictionary:
	if menu.visible or controls_dialog.visible or paused or not _has_focus: return _neutral()
	var frame := _player_frame(1)
	if not _partner_input_armed:
		_partner_input_armed = frame.buttons == 0 and frame.dx == 0 and frame.dy == 0
		return _neutral()
	return frame

func _player_frame(slot: int) -> Dictionary:
	var frame := _neutral()
	# Poll each device directly: Godot's shared InputMap merges controllers together.
	var device := player_devices[slot]
	if device >= 0:
		var pad_buttons := [JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER]
		for i in range(pad_buttons.size()):
			if Input.is_joy_button_pressed(device, pad_buttons[i]): frame.buttons |= 1 << i
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.24: frame.buttons |= Battle.GUARD
		var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		frame.dx = int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
		frame.dy = int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
		if absf(x) > 0.24: frame.dx = int(signf(x))
		if absf(y) > 0.24: frame.dy = int(signf(y))
	if slot == local_slot:
		for i in range(6):
			if Input.is_physical_key_pressed([KEY_J, KEY_K, KEY_SPACE, KEY_L, KEY_U, KEY_E][i]): frame.buttons |= 1 << i
		if Input.is_physical_key_pressed(KEY_I): frame.buttons |= Battle.GUARD
		frame.dx = clampi(frame.dx + int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)), -1, 1)
		frame.dy = clampi(frame.dy + int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)), -1, 1)
	return frame

func _connected_pads() -> Array[int]:
	return Input.get_connected_joypads()

func _sync_devices() -> void:
	var connected := _connected_pads()
	for slot in range(2):
		if player_devices[slot] not in connected: player_devices[slot] = -1
	for slot in ([0, 1] if session == "local" else [local_slot]):
		if player_devices[slot] >= 0: continue
		for device in connected:
			if device not in player_devices:
				player_devices[slot] = device
				break

func _cancel_local_controls() -> void:
	_input_armed = false
	_partner_input_armed = false
	_cancel_input_pending = true
	_stop_rumble()
	if active and session != "client":
		for slot in ([0, 1] if session == "local" else [local_slot]): sim.cancel_input(slot)

func _keep_local_party_in_view() -> void:
	if session != "local": return
	var party: Array = sim.state.fighters.filter(func(f): return f.team == 0 and f.hp > 0)
	if party.size() != 2 or absf(party[0].x - party[1].x) <= 860.0: return
	var middle: float = (party[0].x + party[1].x) / 2.0
	for fighter in party:
		fighter.x = clampf(fighter.x, middle - 430.0, middle + 430.0)
		if fighter.knockback * (fighter.x - middle) > 0: fighter.knockback = 0.0
	# A held enemy must move with its holder when the shared screen edge stops them.
	sim._sync_grabs()

func _set_game_focus(focused: bool) -> void:
	if testing or not smoke.is_empty(): return
	# The F1 child window owns focus and pause until it closes.
	if controls_dialog.visible: return
	if menu.visible and menu_screen == "confirm":
		_has_focus = focused
		return
	_has_focus = focused
	_input_armed = false
	_partner_input_armed = false
	if focused: return
	_cancel_local_controls()
	for action in CONTROL_ACTIONS: Input.action_release(action)
	if active and session in ["solo", "local"]:
		paused = true
		# A popup takes window focus while opening; hiding its page here crashes the native focus handoff.
		if not menu.visible:
			_show_menu_page("pause")
			status.text = "遊戲已暫停。回到視窗後，放開按鍵並按「繼續」。"

func _physics_process(_delta: float) -> void:
	app_ticks += 1
	if demo_active:
		if not menu.visible: art_demo.step(_delta)
		_update_art_demo()
		if not demo_capture_dir.is_empty() and not demo_capture_busy and app_ticks > 4:
			_capture_art_pose()
		elif demo_capture_dir.is_empty() and not capture_path.is_empty() and not captured and app_ticks > 4:
			captured = true
			_capture()
		return
	if connecting_since > 0 and Time.get_ticks_msec() - connecting_since > 10000: _fail("連線逾時。請確認主機已建立、IP 與 UDP 埠相同。")
	if waiting_peer_since > 0 and Time.get_ticks_msec() - waiting_peer_since > 10000: _fail("版本握手逾時，請雙方重新開局。")
	if not smoke.is_empty() and app_ticks > 900:
		_report({"ok": false, "error": "smoke timeout"})
		get_tree().quit(1)
	if not active or paused: return
	local_frame += 1
	if smoke == "client" and not smoke_terminal:
		if local_frame == 90: _cancel_input_pending = true
		if local_frame == 130: assert(_cancel_sequence == -1, "Loopback cancellation must receive its reliable acknowledgement")
	var request_cancel := _cancel_input_pending and _cancel_sequence < 0
	var frame := _input_frame()
	if session == "client":
		# Wait for reliable cancellation acknowledgement before any neutral release can arrive.
		if request_cancel:
			_cancel_sequence = local_frame
			cancel_controls.rpc_id(1, _cancel_sequence)
		submit_input.rpc_id(1, local_frame, frame)
	else:
		if int(sim.state.tick) - remote_received_tick > 18: remote_input = {"dx": 0, "dy": 0, "buttons": 64}
		sim.step([frame, _partner_frame()] if session == "local" else ([frame, remote_input] if session == "host" else [frame]))
		_keep_local_party_in_view()
		if smoke_terminal and smoke == "host" and int(sim.state.tick) == 65:
			sim.state.phase = "lost"
		var events: Array = sim.state.get("events", [])
		_events(events)
		if session == "host":
			net_events.append_array(events)
			if net_events.size() > 64: net_events = net_events.slice(-64)
			if local_frame % 3 == 0 and remote_id != 0:
				var snapshot: Dictionary = sim.get_state()
				snapshot["events"] = net_events.duplicate(true)
				receive_state.rpc_id(remote_id, snapshot)
				net_events.clear()
	_update_view()
	var smoke_done := int(sim.state.get("tick", 0)) >= (240 if smoke == "host" else 180)
	if local_frame % 120 == 0 or sim.state.events.any(func(event): return event.type in ["pickup","defeat"]): _save_characters()
	if smoke_terminal: smoke_done = smoke == "client" and sim.state.get("phase", "") == "lost"
	if not smoke.is_empty() and smoke_done:
		var player_count := 0
		for fighter in sim.state.fighters:
			if int(fighter.get("team", 1)) == 0: player_count += 1
		var ok := player_count == 2 and (remote_frame > 0 if smoke == "host" else received_snapshots > (0 if smoke_terminal else 10))
		_report({"ok": ok, "mode": smoke, "tick": sim.state.tick, "phase": sim.state.phase, "players": player_count, "snapshots": received_snapshots, "remote_sequence": remote_frame})
		get_tree().quit(0 if ok else 1)
	if testing and not capture_path.is_empty() and not captured and local_frame >= 120:
		captured = true
		_capture()
	if sim.state.get("phase", "") != "playing":
		if not terminal_voice_played:
			terminal_voice_played = true
		if sim.state.phase == "won":
			for fighter in sim.state.fighters:
				if fighter.team != 0 or fighter.hp <= 0 or fighter.action != "victory" or fighter.action_tick < Battle.VICTORY_VOICE_TICK or _victory_spoken.has(fighter.id): continue
				if audio.speech_playing(): break
				audio.play_character(fighter.kind, "victory", fighter.player_index, true)
				_victory_spoken[fighter.id] = true
				var line: Dictionary = audio.speech_manifest.get("clips", {}).get(audio.last_spoken, {})
				_victory_subtitle = HERO_NAMES.get(fighter.kind, fighter.kind) + "：「" + str(line.get("subtitle", line.get("text", ""))) + "」"
			if session != "client" and not sim.state.get("victory_looting",false) and not audio.speech_playing() and sim.state.fighters.all(func(f): return f.team != 0 or f.hp <= 0 or (_victory_spoken.has(f.id) and f.action == "victory" and f.action_tick >= Battle.VICTORY_TICKS)):
				sim.state.victory_looting = true
				for fighter in sim.state.fighters:
					if fighter.team == 0 and fighter.hp > 0:
						sim._begin(fighter,"idle")
						sim.cancel_input(fighter.player_index)
		end_label.position = Vector2(200, 138)
		end_label.add_theme_font_size_override("font_size", 26)
		end_label.text = ("第一關突破！" if sim.state.has("stage") else "前哨突破！") if sim.state.phase == "won" else "此戰未竟"
		if not _victory_subtitle.is_empty(): end_label.text += "\n" + _victory_subtitle
		if sim.state.phase == "lost": end_label.text += "\n按 Esc 返回選單／重新開始"

func _events(events: Array) -> void:
	var pulses := {}
	for event in events:
		if not event is Dictionary: continue
		var event_id := int(event.get("id", -1))
		if event_id <= last_event: continue
		last_event = event_id
		_collect_rumble(event, pulses)
		if event.get("type", "") == "boss_intro" and session == "host" and remote_id != 0:
			pending_intro_actor = int(event.actor)
			receive_boss_voice.rpc_id(remote_id, int(event.actor), str(event.line_key))
		if smoke.is_empty() and not testing:
			var voiced: Dictionary = event.duplicate()
			for fighter in sim.state.fighters:
				if fighter.id == event.get("actor", 0): voiced.actor_slot = fighter.player_index
				if fighter.id == event.get("target", 0): voiced.target_slot = fighter.player_index
			audio.play_event(voiced)
	if active and _has_focus and not paused and not menu.visible and not controls_dialog.visible:
		for device in pulses:
			var pulse: Array = pulses[device]
			_vibrate_device(device, pulse[0], pulse[1], pulse[2])

func _collect_rumble(event: Dictionary, pulses: Dictionary) -> void:
	var profile: Array = {"hit": [0.22, 0.1, 0.075], "heavy_hit": [0.4, 0.7, 0.16], "guard": [0.2, 0.35, 0.09], "guard_break": [0.45, 0.65, 0.18], "special": [0.6, 0.85, 0.32], "grab": [0.12, 0.2, 0.07], "shield_hit": [0.25, 0.4, 0.11], "defeat": [0.4, 0.7, 0.22]}.get(event.get("type", ""), [])
	if profile.is_empty(): return
	for fighter in sim.state.get("fighters", []):
		if fighter.team != 0: continue
		var slot := int(fighter.player_index)
		if slot != local_slot and session != "local": continue
		if fighter.id != event.get("actor", 0) and fighter.id != event.get("target", 0): continue
		var device := player_devices[slot]
		if device < 0: continue
		if not pulses.has(device): pulses[device] = [0.0, 0.0, 0.0]
		for index in range(3): pulses[device][index] = maxf(pulses[device][index], profile[index])

func _vibrate_device(device: int, weak: float, strong: float, seconds: float) -> void:
	Input.start_joy_vibration(device, weak, strong, seconds)

func _stop_rumble() -> void:
	for device in player_devices:
		if device >= 0: Input.stop_joy_vibration(device)

func _exit_tree() -> void:
	_save_characters()
	_stop_rumble()
	if is_instance_valid(audio): audio.stop_music()

@rpc("authority", "call_remote", "reliable")
func receive_boss_voice(actor: int, line_key: String) -> void:
	if session != "client" or not active or actor < 1 or line_key.length() > 200: return
	# Reliable delivery survives a lost first snapshot; audio deduplicates the matching ordinary event.
	received_intro_actor = actor
	audio.play_event({"type":"boss_intro", "actor":actor, "line_key":line_key})
	if not audio.intro_playing(): _local_boss_voice_finished()

func _local_boss_voice_finished() -> void:
	if session == "client" and active and received_intro_actor > 0:
		boss_voice_finished.rpc_id(1, received_intro_actor)
		received_intro_actor = 0

@rpc("any_peer", "call_remote", "reliable")
func boss_voice_finished(actor: int) -> void:
	if session == "host" and multiplayer.get_remote_sender_id() == remote_id and pending_intro_actor == actor:
		pending_intro_actor = 0

func _update_view() -> void:
	view.state = sim.state
	combat_hud.show()
	combat_hud.sync(sim.state)
	hud.position = Vector2(416, 15)
	hud.size = Vector2(448, 75)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if active and sim.state.get("phase","") == "playing": audio.sync_stage_music(sim.state)
	exit_button.visible = active and sim.state.get("phase","") == "won" and sim.state.get("victory_looting",false) and not menu.visible
	var x := 480.0
	var living_x: Array[float] = []
	for fighter in sim.state.get("fighters", []):
		if int(fighter.get("team", 1)) != 0: continue
		var slot := int(fighter.get("player_index", 0))
		if slot == local_slot: x = float(fighter.x)
		if fighter.hp > 0: living_x.append(float(fighter.x))
	if session in ["local","host","client"] and not living_x.is_empty():
		x = 0.0
		for position in living_x: x += position / living_x.size()
	var camera_target := Battle.camera_left(sim.state) if sim.state.has("stage") else clampf(x - (640.0 if session in ["local","host","client"] else 540.0), 0.0, 1100.0)
	var camera_scene := int(sim.state.get("stage", {}).get("index", -2))
	# Unlocking the next checkpoint must scroll toward the party without a camera jump.
	view.camera_x = camera_target if _camera_scene != camera_scene else move_toward(view.camera_x, camera_target, 10.0)
	_camera_scene = camera_scene
	if not living_x.is_empty():
		view.camera_x = clampf(view.camera_x, maxf(0.0, living_x.max() - 1200.0), maxf(0.0, living_x.min() - 80.0))
	if sim.state.has("stage"):
		view.camera_x = clampf(view.camera_x, 0.0, maxf(0.0, float(sim.state.stage.encounter_end) - 1280.0))
	view.queue_redraw()
	var mode := "單人" if session == "solo" else ("雙搖桿合作" if session == "local" else "IP 直連 · " + ("主機" if session == "host" else "客端"))
	hud.text = "吞食戰國・%s" % mode
	if sim.state.has("stage"):
		var stage: Dictionary = sim.state.stage
		var objective := "GO → 全員向右前進" if stage.go else ""
		if not stage.go and not sim.state.fighters.any(func(f): return f.team == 1 and f.hp > 0) and sim.state.props.any(func(p): return p.get("mandatory",false) and not p.broken): objective = "擊破拒馬／柵欄，打通出口"
		hud.text = "%02d/%02d　%s\n據點 %d/%d　%s" % [stage.index + 1,stage.total,stage.name,int(stage.get("checkpoint", 0)) + 1,int(stage.get("checkpoint_total", 2)),objective]
	if training_active:
		var player: Dictionary = sim.state.fighters[0]
		var stats: Dictionary = sim.state.training
		var move_name: String = {"idle": "待機", "light": "輕擊 %d/3" % player.combo, "charge": "蓄力完成・放開出招" if player.charge >= 35 else "蓄力 %d%%" % int(player.charge * 100.0 / 35.0), "heavy": "重擊 %d/2" % player.heavy_combo, "charged": "爆裂冰箭" if player.kind == "oichi" else "炎刃斷陣", "rising": "上揚飛針" if player.kind == "oichi" else "上挑", "low_sweep": "低位攻擊", "dash_strike": "踏步突進", "dash_heavy": "衝刺重擊", "air_light": "空中輕擊", "air_heavy": "空中重擊", "upper_heavy": "三段落矢" if player.kind == "oichi" else "挑空重擊", "charged_upper": "蓄力三段落矢" if player.kind == "oichi" else "蓄力升空技", "mixed_finisher": "混合連段終結", "ground_slam": "震地／落矢", "charged_slam": "霜華冰陣・前方120°" if player.kind == "oichi" else ("炎獄裂地・全周360°" if player.kind == "nobunaga" else "大範圍蓄力地陣"), "holding": "肉盾 %.1f秒・放開摔" % maxf(0.0, (180.0 - player.action_tick) / 60.0), "throw": "飛摔", "special": "必殺・全程無敵", "stunned": "暈眩", "pulled": "被鎖鏈拉近"}.get(player.action, player.action)
		if player.action == "mixed_rising": move_name = "重轉輕追擊"
		elif player.action == "guard": move_name = "防禦・受擊集怒"
		elif player.action == "recovering": move_name = "起身中"
		elif player.action == "launched": move_name = "被擊飛"
		elif player.action == "down": move_name = "倒地"
		elif player.get("sprinting", false): move_name = "衝刺・撞開"
		if player.action == "charged" and player.kind not in ["nobunaga", "oichi"]: move_name = "滿蓄重擊"
		if player.kind == "tadakatsu":
			if player.action == "charged": move_name = "長槍突進"
			elif player.action == "charged_slam": move_name = "槍底震地・全周衝擊波"
		var drill_name: String = {"dummy": "木樁練習", "shield": "肉盾演練", "enemies": FACTION_NAMES.get(selected_faction, selected_faction) + "軍試戰", "ranged": "弓箭／鐵砲撤退", "boss": "陣營小王"}.get(training_drill, training_drill)
		var living := 0
		for enemy in sim.state.fighters:
			if enemy.team == 1 and enemy.hp > 0: living += 1
		hud.text = "%s・%s\n敵人 %d　命中 %d 次" % [drill_name,move_name,living,stats.hit_count]
	var introduction: Dictionary = sim.state.get("intro", {})
	if int(introduction.get("remaining_ticks", 0)) > 0 or audio.intro_playing():
		var key := str(introduction.get("line_key", ""))
		end_label.position = Vector2(200,100)
		end_label.add_theme_font_size_override("font_size", 23)
		end_label.text = str(introduction.get("name", "")) + "\n" + str(introduction.get("line",audio.speech_manifest.get("clips", {}).get(key, {}).get("text", "")))
	elif sim.state.get("phase", "") == "playing":
		end_label.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		if controls_dialog.visible: _close_controls()
		else: _show_controls()
		get_viewport().set_input_as_handled()
		return
	if controls_dialog.visible: return
	if menu.visible:
		var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
		if back or start:
			if start and menu_screen == "title": _show_menu_page("main")
			elif start and menu_screen == "pause": _resume()
			elif back: _menu_back()
			get_viewport().set_input_as_handled()
			return
	if active and ((event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)):
		_unhandled_input(event)
		return
	if training_active and active and not menu.visible and _has_focus and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			_reset_training()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB:
			_switch_training_hero()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			_choose_training_drill(["dummy", "shield", "enemies", "ranged", "boss"][event.physical_keycode - KEY_1])
			get_viewport().set_input_as_handled()
	if demo_active:
		var handled := true
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_SPACE: _toggle_art_demo()
				KEY_LEFT: _seek_art_demo(-1)
				KEY_RIGHT: _seek_art_demo(1)
				KEY_F: art_demo.facing *= -1; _update_art_demo()
				KEY_BRACKETLEFT: _step_art_frame(-1)
				KEY_BRACKETRIGHT: _step_art_frame(1)
				KEY_S: _toggle_art_speed()
				KEY_ESCAPE: _leave_to_menu()
				_: handled = false
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_A: _toggle_art_demo()
				JOY_BUTTON_LEFT_SHOULDER: _seek_art_demo(-1)
				JOY_BUTTON_RIGHT_SHOULDER: _seek_art_demo(1)
				JOY_BUTTON_START: _leave_to_menu()
				_: handled = false
		else: handled = false
		if handled: get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		if not active: return
		if event is InputEventJoypadButton and event.device not in player_devices: return
		if menu.visible:
			_menu_back()
		else:
			paused = session in ["solo", "local"]
			_show_menu_page("pause")
			_cancel_local_controls()
			status.text = "連線中選單不暫停全隊；你的角色停止輸入。" if session in ["host", "client"] else ""
		get_viewport().set_input_as_handled()

func _joy_changed(device: int, connected: bool) -> void:
	var assigned := device in player_devices or player_devices[local_slot] < 0
	if not connected and assigned and active:
		_cancel_local_controls()
		for action in CONTROL_ACTIONS: Input.action_release(action)
		if session in ["solo", "local"]:
			paused = true
			_show_menu_page("pause")
			status.text = "搖桿已拔除，遊戲暫停。接回搖桿、放開按鍵後按繼續。" if session == "local" else "搖桿已拔除，遊戲暫停。可重新連接或使用鍵盤繼續。"
	var previous := player_devices.duplicate()
	_sync_devices()
	if previous != player_devices:
		_cancel_local_controls()
	feedback_label.text = "搖桿已連接；△／Y 按住抓人、放開摔；支援震動。" if connected else "搖桿已拔除。雙人合作需兩支搖桿；未拔除的玩家保留原本席位。"

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	_report({"ok": error == OK, "capture": capture_path, "tick": sim.state.tick})
	get_tree().quit(0 if error == OK else 1)

func _capture_art_pose() -> void:
	demo_capture_busy = true
	art_demo.seek(demo_capture_next)
	_update_art_demo()
	await RenderingServer.frame_post_draw
	var path := demo_capture_dir.path_join("pose-%02d.png" % (demo_capture_next + 1))
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_report({"ok": false, "error": "pose capture failed", "path": path})
		get_tree().quit(1)
		return
	demo_capture_next += 1
	if demo_capture_next >= ArtDemo.POSES.size():
		_report({"ok": true, "poses": demo_capture_next, "heroes": 2, "weather_states": 3, "capture_dir": demo_capture_dir})
		get_tree().quit()
		return
	demo_capture_busy = false

func _report(data: Dictionary) -> void:
	print(JSON.stringify(data))
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(data))

