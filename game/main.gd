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
const PlayerStore = preload("res://core/player_store.gd")
const Equipment = preload("res://core/equipment.gd")
const Achievements = preload("res://core/achievements.gd")
const CharacterSelect = preload("res://ui/character_select_panel.gd")
const MenuFrame = preload("res://ui/menu_frame.gd")
const MenuInput = preload("res://ui/menu_input.gd")
const ObjectiveScroll = preload("res://ui/objective_scroll.gd")
const MenuTheme = preload("res://ui/sengoku_theme.gd")
const ArtDemo = preload("res://render/art_demo.gd")
const BUILD := "sengoku-m1-0.33.0"
const DEFAULT_PORT := 27860
const HEROES := ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
const HERO_NAMES := {"nobunaga": "信長", "oichi": "阿市", "hideyoshi": "秀吉", "ieyasu": "家康", "mitsuhide": "顯如", "tadakatsu": "忠勝"}
const FACTION_NAMES := {"mori": "毛利", "imagawa": "今川", "oda": "織田", "saito": "齋藤", "miyoshi": "三好", "azai": "淺井", "asakura": "朝倉", "takeda": "武田", "ikko": "一向一揆", "akechi": "明智", "hashiba": "羽柴", "iga": "伊賀"}
const DIFFICULTIES := ["easy", "normal", "hard"]
const DROP_SETTINGS_PATH := "user://drop-settings.cfg"
const CONTROL_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "light", "heavy", "jump", "grab", "pickup", "eat", "guard"]
const BATTLE_HINT := "WASD 移動／雙點衝刺   J 輕擊   K 重擊／蓄力後放開   空白 跳   L 擒拿   I 格擋   E 拾取   Q 進食\n左搖桿推滿 0.2 秒衝刺 · □／X 輕擊 · ○／B 重擊 · ×／A 跳 · R2／RT 擒拿 · L2／LT 格擋 · L1／LB 拾取 · R1／RB 進食 · Options 軍議"
const TRAINING_HINT := "WASD／雙點衝刺 · 左搖桿推滿 0.2 秒衝刺   J 輕擊   K 重擊／蓄力   空白 跳   L 擒拿   I 格擋   E 拾取   Q 進食\n1 木樁   2 披甲武士   3 連陣   4 弓手   5 敵將   R 重演   Tab 換將   F1 秘卷"
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
var menu_footer: Label
var engineer_entry: Button
var volume_sliders: Dictionary = {}
var drop_rate_controls: Dictionary = {}
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
var controls_shade: ColorRect
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
var profiles = PlayerStore.new()
var _saved_profile_signature := ""
var exit_button: Button
var next_button: Button
var confirmation_text: Label
var confirmation_action: Callable
var confirmation_return := ""
var confirmation_paused := false
var ending_confirmed := false
var character_panel: Control
var player_setup_choices: Array[OptionButton] = []
var player_name_input: LineEdit
var player_notice: Label
var players_return := "main"
var achievements_return := "select"
var achievements_title: Label
var achievements_list: ItemList
var achievement_banner: Label
var _achievement_messages: Array[String] = []
var _achievement_message_time := 0.0
var login_flow := false
var player_mode_choice: OptionButton
var players_continue: Button
var roster_choices: Array[OptionButton] = []
var menu_input: Node
var objective_scroll: Control

func _ready() -> void:
	_load_drop_rates()
	_actions()
	view = BattleView.new()
	add_child(view)
	audio = CombatAudio.new()
	add_child(audio)
	audio._intro_player.finished.connect(_local_boss_voice_finished)
	sim.boss_intros = audio.speech_manifest.get("boss_intros", {}).duplicate(true)
	sim.boss_intros.merge(audio.speech_manifest.get("stage_boss_intros",{}),true)
	_build_ui()
	_setup_menu_input()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _fail("無法連線。請確認 IP、UDP 埠與防火牆。"))
	multiplayer.server_disconnected.connect(func(): _fail("主機已斷線，中途戰況未保存。請重新集結出陣。"))
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
		audio.play_title_music()
	if capture_menu and not capture_path.is_empty(): _capture.call_deferred()

func _actions() -> void:
	for retired in ["special"]:
		if InputMap.has_action(retired): InputMap.erase_action(retired)
	var keys := {
		"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
		"light": KEY_J, "heavy": KEY_K, "jump": KEY_SPACE, "grab": KEY_L, "pickup": KEY_E, "eat": KEY_Q, "guard": KEY_I
	}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.24)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
	var buttons := {"light": JOY_BUTTON_X, "heavy": JOY_BUTTON_B, "jump": JOY_BUTTON_A, "pickup": JOY_BUTTON_LEFT_SHOULDER, "eat": JOY_BUTTON_RIGHT_SHOULDER, "move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT, "move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN}
	for action in buttons:
		var button := InputEventJoypadButton.new()
		button.button_index = buttons[action]
		InputMap.action_add_event(action, button)
	for action in ["ui_accept","ui_cancel"]:
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = JOY_BUTTON_A if action == "ui_accept" else JOY_BUTTON_B
		InputMap.action_add_event(action,button)
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		var axis := InputEventJoypadMotion.new()
		axis.device = -1
		axis.axis = JOY_AXIS_LEFT_X if action in ["ui_left", "ui_right"] else JOY_AXIS_LEFT_Y
		axis.axis_value = -1.0 if action in ["ui_left", "ui_up"] else 1.0
		if not InputMap.action_has_event(action, axis): InputMap.action_add_event(action, axis)
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_X if action in ["move_left", "move_right"] else JOY_AXIS_LEFT_Y
		axis.axis_value = -1.0 if action in ["move_left", "move_up"] else 1.0
		InputMap.action_add_event(action, axis)
	var grab_axis := InputEventJoypadMotion.new()
	grab_axis.axis = JOY_AXIS_TRIGGER_RIGHT
	grab_axis.axis_value = 1.0
	InputMap.action_add_event("grab",grab_axis)
	var guard_axis := InputEventJoypadMotion.new()
	guard_axis.axis = JOY_AXIS_TRIGGER_LEFT
	guard_axis.axis_value = 1.0
	InputMap.action_add_event("guard",guard_axis)

func _setup_menu_input() -> void:
	menu_input = MenuInput.new()
	add_child(menu_input)
	menu_input.initialize(self)

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
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(ui)
	combat_hud = CombatHUD.new()
	ui.add_child(combat_hud)
	hud = Label.new()
	hud.position = Vector2(416, 15)
	hud.size = Vector2(448, 75)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Typography.PAPER)
	hud.add_theme_color_override("font_shadow_color", Typography.INK)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_theme_stylebox_override("normal", MenuTheme.panel(Color("241c16d9"), Color("98764388")))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	objective_scroll = ObjectiveScroll.new()
	ui.add_child(objective_scroll)
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
	achievement_banner = _menu_label(ui,"",21)
	achievement_banner.position = Vector2(330,125)
	achievement_banner.size = Vector2(620,70)
	achievement_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	achievement_banner.add_theme_color_override("font_color",Typography.GOLD)
	achievement_banner.hide()
	exit_button = _button("退出",_leave_to_menu,"VictoryExit",ui)
	exit_button.position = Vector2(1140,120)
	exit_button.size = Vector2(116,42)
	exit_button.hide()
	next_button = _button("下一關",_continue_campaign,"VictoryNext",ui)
	next_button.position = Vector2(1140,168)
	next_button.size = Vector2(116,42)
	next_button.hide()
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
	if font_size >= 30: label.add_theme_font_override("font",Typography.font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _menu_page(key: String, at: Vector2, width: float, heading: String = "") -> VBoxContainer:
	var paper := PanelContainer.new()
	paper.name = key.capitalize() + "Paper"
	paper.position = at - Vector2(18, 14)
	paper.size.x = width + 36
	paper.add_theme_stylebox_override("panel", MenuTheme.panel(Color.TRANSPARENT,Color.TRANSPARENT) if key in ["title","main"] else MenuTheme.panel(MenuTheme.PAPER))
	menu.add_child(paper)
	var page := VBoxContainer.new()
	page.name = key.capitalize()
	page.custom_minimum_size.x = width
	page.add_theme_constant_override("separation", 10)
	paper.add_child(page)
	menu_pages[key] = page
	if not heading.is_empty():
		var label := _menu_label(page, heading, 34)
		label.custom_minimum_size.y = 52
		label.add_theme_color_override("font_color", MenuTheme.VERMILION)
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
	menu_shade.color = Color("1e1915")
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_shade)
	menu_logo = TextureRect.new()
	menu_logo.position = Vector2(220, 40)
	menu_logo.size = Vector2(840, 280)
	menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_logo.texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/current/ui/title-logo-v34.png"))
	menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_logo)
	menu_caption = _menu_label(menu, "桶 狹 間 之 章", 25)
	menu_caption.position = Vector2(240, 304)
	menu_caption.size.x = 800
	menu_caption.add_theme_color_override("font_color", Typography.GOLD)
	var title_page := _menu_page("title", Vector2(380, 446), 520)
	_button("啟 程 ・ 按 下 開 始", func(): _open_login(false), "Start", title_page)
	_menu_label(title_page, "Enter ／ ×・A ／ Options 開始", 18).add_theme_color_override("font_color",Typography.PAPER)
	var main_page := _menu_page("main", Vector2(430, 324), 420)
	_button("一 人 出 陣", func(): _open_login(false), "Solo", main_page)
	_button("二 人 共 鬥", func(): _open_login(true), "LocalCoop", main_page)
	_button("武 者 名 簿", _open_players, "Players", main_page)
	_button("聲 畫 調 校", _open_options, "Options", main_page)
	_button("收 兵 離 營", _request_quit, "Quit", main_page)
	character_panel = CharacterSelect.new()
	character_panel.name = "CharacterSelect"
	menu.add_child(character_panel)
	menu_pages["select"] = character_panel
	heroes = character_panel.heroes
	partner_heroes = character_panel.partner_heroes
	partner_row = character_panel.partner_row
	difficulties = character_panel.difficulties
	chapter_choice = character_panel.chapter_choice
	character_panel.closed.connect(_menu_back)
	character_panel.changed.connect(_refresh_loadouts)
	character_panel.begin_requested.connect(func():
		if selection_coop: _start_local_coop()
		else: _start_solo())
	character_panel.players_requested.connect(_open_players)
	character_panel.management_requested.connect(_open_collection)
	character_panel.equipment_requested.connect(_open_collection)
	character_panel.achievements_requested.connect(_open_achievements)
	character_panel.item_requested.connect(_equip_inventory)
	character_panel.treasure_removed.connect(_unequip_treasure)
	for slot in range(2):
		character_panel.player_choices[slot].item_selected.connect(func(index):
			_change_player(slot,str(character_panel.player_choices[slot].get_item_metadata(index))))
	_build_players_page()
	_build_roster_page()
	_build_achievements_page()
	_refresh_chapters()
	var options := _menu_page("options", Vector2(310, 100), 660, "聲 畫 調 校")
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
	_button("合 戰 秘 卷", _show_controls, "Controls", options)
	_button("返　回", _menu_back, "Back", options)
	var pause_page := _menu_page("pause", Vector2(430, 80), 420, "軍 議 ・ 暫 停")
	pause_page.add_theme_constant_override("separation",8)
	_button("繼 續 戰 鬥", _resume, "Resume", pause_page)
	_button("重 新 出 陣", func():
		if training_active: _reset_training()
		elif session == "local": _start_local_coop()
		else: _start_solo(), "Restart", pause_page)
	_button("聲 畫 調 校", _open_options, "Options", pause_page)
	var collections := HBoxContainer.new()
	collections.name = "Collections"
	pause_page.add_child(collections)
	for slot in range(2):
		_button("%dP 行囊" % (slot + 1),func(): _open_collection(slot),"Collection%d" % slot,collections).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("記 錄 戰 報", func(): _save_characters(true), "SaveCharacters", pause_page)
	_button("返 回 本 陣", _leave_to_menu, "Leave", pause_page)
	var confirm_page := _menu_page("confirm",Vector2(390,225),500,"軍令確認")
	confirmation_text = _menu_label(confirm_page,"",24)
	confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("取消",_cancel_confirmation,"Cancel",confirm_page)
	_button("確認",_accept_confirmation,"Confirm",confirm_page)
	menu_panel = _menu_page("engineering", Vector2(240, 70), 800, "演 武 場 ・ 連 線")
	menu_panel.add_theme_font_size_override("font_size", 18)
	menu_panel.add_theme_constant_override("separation", 7)
	factions = OptionButton.new()
	for faction in FACTION_NAMES: factions.add_item(FACTION_NAMES[faction] + "軍")
	menu_panel.add_child(factions)
	_menu_label(menu_panel,"掉落機率（%）・自動儲存",18)
	var rates_grid := GridContainer.new()
	rates_grid.columns=2
	rates_grid.add_theme_constant_override("h_separation",24)
	menu_panel.add_child(rates_grid)
	for key in Battle.DEFAULT_DROP_RATES:
		var rate_row := HBoxContainer.new()
		rate_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		rates_grid.add_child(rate_row)
		var rate_label := _menu_label(rate_row,{"major":"大王掉寶","minor":"小王掉寶","prop":"物品掉寶","food":"食物掉落"}[key],19)
		rate_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var rate := SpinBox.new()
		rate.name="DropRate_"+key
		rate.min_value=0;rate.max_value=100;rate.step=1;rate.suffix="%"
		rate.value=sim.drop_rates[key]
		rate.custom_minimum_size=Vector2(126,38)
		rate_row.add_child(rate)
		drop_rate_controls[key]=rate
		rate.value_changed.connect(func(value: float):
			if _set_drop_rate(key,value)!=OK:
				status.text="掉落設定未儲存；連線時由主機設定。"
				_refresh_drop_rates()
		)
	_menu_label(menu_panel,"武器／護符各自判定；一般兵只掉食物。食物限半血以下，連線由主機設定。",16)
	var tools_row := HBoxContainer.new()
	menu_panel.add_child(tools_row)
	_button("出陣支度", func(): _open_selection(false), "Selection", tools_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("武藝圖譜", _start_art_demo, "ArtDemo", tools_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trials_row := HBoxContainer.new()
	menu_panel.add_child(trials_row)
	_button("演武場", _start_training, "Training", trials_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("陣營試戰", func(): _start_training("enemies"), "EnemyTraining", trials_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var network_row := HBoxContainer.new()
	menu_panel.add_child(network_row)
	address = LineEdit.new()
	address.name = "HostAddress"
	address.placeholder_text = "主機 IP"
	address.text = "127.0.0.1"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network_row.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = DEFAULT_PORT
	port.prefix = "UDP "
	port.custom_minimum_size.x = 220
	network_row.add_child(port)
	var network_buttons := HBoxContainer.new()
	menu_panel.add_child(network_buttons)
	_button("建立雙人主機", _host, "Host", network_buttons)
	_button("以 IP 加入", _join, "Join", network_buttons)
	var ips: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.is_valid_ip_address() and "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."): ips.append(ip)
	_menu_label(menu_panel, "本機 IP：" + (", ".join(ips) if not ips.is_empty() else "未偵測"), 16)
	feedback_label = _menu_label(menu_panel, "F1 合戰秘卷 · 區域網路 UDP 直連", 16)
	_button("返　回", _menu_back, "Back")
	status = _menu_label(menu, "", 18)
	status.position = Vector2(190, 614)
	status.size = Vector2(900, 48)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Typography.PAPER)
	engineer_entry = _button("演武・連線", func(): status.text = ""; _show_menu_page("engineering"), "EngineeringEntry", menu)
	engineer_entry.position = Vector2(1050, 617)
	engineer_entry.size = Vector2(190, 40)
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
	collection.equip_requested.connect(func(uid: String): _equip_inventory(encyclopedia_slot,int(uid)))
	collection.use_requested.connect(_use_food)
	collection.sell_requested.connect(_request_sale)
	collection.pack_requested.connect(_pack_item)
	collection.discard_requested.connect(_request_discard)
	collection.unequip_requested.connect(func(treasure: bool):
		if treasure: _unequip_treasure(encyclopedia_slot)
		else: _equip_inventory(encyclopedia_slot,0))
	collection.details_requested.connect(func(id: String):
		_open_weapon_encyclopedia(encyclopedia_slot,"collection")
		var row: Dictionary = profiles.character(encyclopedia_slot,_equipment_hero(encyclopedia_slot))
		encyclopedia.select_weapon(str(Equipment.instance(row,int(id)).get("item_id","")))
	)
	menu.add_child(MenuFrame.new())
	var footer_paper := Panel.new()
	footer_paper.name = "NavigationBar"
	footer_paper.position = Vector2(32, 668)
	footer_paper.size = Vector2(1216, 38)
	footer_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_paper.add_theme_stylebox_override("panel", MenuTheme.panel(Color("241c16")))
	menu.add_child(footer_paper)
	menu_footer = _menu_label(menu,"方向鍵／左搖桿 選擇　×／A 確認　○／B 返回　L1／R1 換欄　右搖桿 捲動",18)
	menu_footer.name = "NavigationHint"
	menu_footer.position = Vector2(36, 676)
	menu_footer.size = Vector2(1208, 26)
	menu_footer.add_theme_color_override("font_color", Typography.PAPER)
	menu_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_menu_page("title")

func _load_drop_rates() -> void:
	sim.drop_rates=Battle.DEFAULT_DROP_RATES.duplicate()
	var config := ConfigFile.new()
	var error := config.load(DROP_SETTINGS_PATH)
	if error==OK:
		for key in Battle.DEFAULT_DROP_RATES:
			var value: Variant=config.get_value("rates",key,Battle.DEFAULT_DROP_RATES[key])
			if value is int and value>=0 and value<=100: sim.drop_rates[key]=value
	elif error!=ERR_FILE_NOT_FOUND: push_warning("Drop settings could not be read; using default rates.")
	sim.state.drop_rates=sim.drop_rates.duplicate()

func _set_drop_rate(key: String, value: float) -> Error:
	if not sim.drop_rates.has(key) or not is_finite(value) or value<0 or value>100: return ERR_INVALID_PARAMETER
	if active and session=="client": return ERR_UNAUTHORIZED
	var previous: int=sim.drop_rates[key]
	sim.drop_rates[key]=roundi(value)
	var config := ConfigFile.new()
	for rate in sim.drop_rates: config.set_value("rates",rate,sim.drop_rates[rate])
	var error := config.save(DROP_SETTINGS_PATH)
	if error!=OK:
		sim.drop_rates[key]=previous
		return error
	sim.state.drop_rates=sim.drop_rates.duplicate()
	return OK

func _refresh_drop_rates() -> void:
	var rates: Dictionary=sim.state.get("drop_rates",sim.drop_rates) if active else sim.drop_rates
	for key in drop_rate_controls:
		drop_rate_controls[key].set_value_no_signal(rates[key])
		drop_rate_controls[key].editable=not (active and session=="client")

func _show_menu_page(page: String) -> void:
	if is_instance_valid(objective_scroll): objective_scroll.hide()
	if is_instance_valid(menu_input) and menu_input.keyboard.visible: menu_input.keyboard.finish(false)
	menu_screen = page
	if page=="engineering": _refresh_drop_rates()
	exit_button.hide()
	next_button.hide()
	menu.show()
	for key in menu_pages:
		menu_pages[key].visible = key == page
		if menu_pages[key].get_parent() is PanelContainer:
			menu_pages[key].get_parent().visible = key == page
	menu_backdrop.visible = not active
	menu_shade.color.a = 0.90 if active or page not in ["main", "title"] else 0.40
	menu_logo.visible = page in ["title", "main"]
	menu_logo.position = Vector2(300, 24) if page == "main" else Vector2(220, 40)
	menu_logo.size = Vector2(680, 230) if page == "main" else Vector2(840, 280)
	menu_caption.position.y = 250 if page == "main" else 328
	menu_caption.visible = menu_logo.visible
	engineer_entry.visible = page in ["title","main","options","pause"]
	status.visible = page not in ["select","players","roster","achievements","encyclopedia", "collection", "confirm"]
	menu_footer.text = "方向鍵／左搖桿 選擇　×／A 確認　○／B 返回　L1／R1 %s　右搖桿 捲動" % ("換分類" if page == "collection" else "換欄")
	combat_hud.visible = active
	hud.visible = active
	end_label.visible = active
	if page == "pause":
		menu_pages.pause.get_node("Resume").visible = sim.state.get("phase", "") in ["playing", "won"]
		menu_pages.pause.get_node("Restart").visible = session in ["solo", "local"]
		menu_pages.pause.get_node("SaveCharacters").visible = session in ["solo","local"] and not training_active
		menu_pages.pause.get_node("Collections").visible = session in ["solo","local"] and not training_active and not demo_active
		menu_pages.pause.get_node("Collections/Collection1").visible = session == "local"
	if is_instance_valid(menu_input):
		menu_input.reset()
		menu_input.focus_first()
		return
	for control in menu_pages[page].find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL:
			control.grab_focus()
			break

func _open_selection(coop: bool) -> void:
	equipment_in_battle = false
	selection_coop = coop
	partner_row.visible = coop
	_refresh_loadouts()
	_refresh_chapters()
	status.text = profiles.warning if profiles.warning != "" else ("二人共鬥・需兩支搖桿　｜　戰報自動保存" if coop else "整裝出陣・自章首進軍　｜　體力全滿・三命在身")
	if profiles.warning == "" and int(chapter_choice.get_item_metadata(chapter_choice.selected)) != int(profiles.data.get("chapter",1)):
		status.text = "第%d章尚未開放。可重征舊章，軍籍與藏品保留。" % int(profiles.data.chapter)
	_show_menu_page("select")
	character_panel.notice.text = status.text

func _refresh_chapters() -> void:
	chapter_choice.clear()
	var saved := int(profiles.data.get("chapter",1))
	var unlocked := maxi(saved,int(profiles.data.get("completed_chapter",0)) + 1)
	for chapter in Stages.available():
		if int(chapter.id) > unlocked: continue
		chapter_choice.add_item("第%d章　%s" % [int(chapter.id),str(chapter.title)])
		chapter_choice.set_item_metadata(chapter_choice.item_count - 1,int(chapter.id))
		if int(chapter.id) <= saved: chapter_choice.selected = chapter_choice.item_count - 1

func _refresh_loadouts() -> void:
	_refresh_player_choices()
	var slot := int(character_panel.active_slot)
	var hero: String = HEROES[heroes.selected if slot == 0 else partner_heroes.selected]
	character_panel.configure(selection_coop,profiles.character(slot,hero),profiles.name_for(slot))
	character_panel.notice.text = status.text if is_instance_valid(status) else ""

func _equipment_hero(slot: int) -> String:
	if equipment_in_battle:
		for fighter in sim.state.fighters:
			if fighter.team == 0 and int(fighter.player_index) == slot: return str(fighter.kind)
	return HEROES[heroes.selected if slot == 0 else partner_heroes.selected]

func _build_players_page() -> void:
	var page := _menu_page("players",Vector2(230,60),820,"武 者 名 簿")
	page.add_theme_constant_override("separation",8)
	_menu_label(page,"定出陣之數，點名簿之將。",21)
	player_mode_choice = OptionButton.new()
	player_mode_choice.add_item("一人出陣")
	player_mode_choice.add_item("二人共鬥")
	page.add_child(player_mode_choice)
	player_mode_choice.item_selected.connect(func(index):
		selection_coop = index == 1
		player_setup_choices[1].get_parent().visible = selection_coop)
	for slot in range(2):
		var line := HBoxContainer.new()
		page.add_child(line)
		_menu_label(line,"%dP 名簿　" % (slot+1),22)
		var choice := OptionButton.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(choice)
		player_setup_choices.append(choice)
		choice.item_selected.connect(func(index): _change_player(slot,str(choice.get_item_metadata(index))))
	var new_player := HBoxContainer.new()
	new_player.add_theme_constant_override("separation",12)
	page.add_child(new_player)
	player_name_input = LineEdit.new()
	player_name_input.name = "PlayerName"
	player_name_input.placeholder_text = "武者名號（1–20 字）"
	player_name_input.max_length = 20
	player_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_player.add_child(player_name_input)
	_button("登錄名號",_add_player,"AddPlayer",new_player)
	_menu_label(page,"×／A 字盤　｜　鍵盤・中文輸入法可直接題名",18)
	player_notice = _menu_label(page,"",18)
	player_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_notice.custom_minimum_size.y = 42
	_menu_label(page,"名簿存於本機，各自保留軍籍與戰績。",17)
	players_continue = _button("點將出陣",_open_roster,"Continue",page)
	_button("返　回",_menu_back,"Back",page)

func _open_login(coop: bool) -> void:
	login_flow = true
	selection_coop = coop
	players_return = "main"
	player_mode_choice.selected = 1 if coop else 0
	player_mode_choice.show()
	players_continue.show()
	player_setup_choices[1].get_parent().visible = coop
	_refresh_player_choices()
	player_notice.text = profiles.warning
	_show_menu_page("players")

func _build_roster_page() -> void:
	var page := _menu_page("roster",Vector2(270,150),740,"點 將 出 陣")
	_menu_label(page,"名將應召，整備兵甲。",22)
	for slot in range(2):
		var choice := OptionButton.new()
		choice.name = "Hero%d" % slot
		for hero in HEROES:
			choice.add_item(("顯如" if hero == "mitsuhide" else HERO_NAMES[hero]) + ("・尚未應召" if hero not in Battle.PLAYABLE_HEROES else ""))
			choice.set_item_disabled(choice.item_count-1,hero not in Battle.PLAYABLE_HEROES)
		page.add_child(choice)
		roster_choices.append(choice)
	_button("出陣支度",func():
		heroes.selected = roster_choices[0].selected
		partner_heroes.selected = roster_choices[1].selected
		character_panel.active_slot = 0
		_open_selection(selection_coop),"Continue",page)
	_button("返回名簿",func(): _open_login(selection_coop),"Back",page)

func _open_roster() -> void:
	if selection_coop and profiles.selected[0] == profiles.selected[1]:
		player_notice.text = "二人共鬥，須由兩冊不同名簿應召。"
		return
	roster_choices[0].selected = heroes.selected
	roster_choices[1].selected = partner_heroes.selected
	roster_choices[1].visible = selection_coop
	_show_menu_page("roster")

func _refresh_player_choices() -> void:
	if not is_instance_valid(character_panel): return
	for slot in range(2):
		var controls: Array = [character_panel.player_choices[slot]]
		if player_setup_choices.size() == 2: controls.append(player_setup_choices[slot])
		for choice in controls:
			choice.clear()
			var selected_index := 0
			for id in profiles.records:
				choice.add_item(str(profiles.records[id].data.get("name","武者")))
				choice.set_item_metadata(choice.item_count-1,id)
				if id == profiles.selected[slot]: selected_index = choice.item_count-1
			choice.select(selected_index)
			# Rebuild the hidden button's text so switching players cannot draw the old name.
			choice.text = ""
			choice.text = profiles.name_for(slot)
			choice.disabled = active

func _open_players() -> void:
	login_flow = false
	player_mode_choice.hide()
	players_continue.hide()
	player_setup_choices[1].get_parent().show()
	players_return = menu_screen
	_refresh_player_choices()
	player_notice.text = profiles.warning
	_show_menu_page("players")

func _change_player(slot: int, id: String) -> void:
	if active: return
	var err: Error = profiles.select_player(slot,id)
	player_notice.text = "應召名簿已更換。" if err == OK else "名簿設定保存失敗 (%d)。" % err
	_refresh_loadouts()
	_refresh_chapters()

func _add_player() -> void:
	var id: String = profiles.add_player(player_name_input.text)
	if id == "":
		player_notice.text = "名號未登錄：須為 1–20 字且不重名；請確認本機存檔可寫入。"
		return
	player_name_input.clear()
	_change_player(0 if login_flow else int(character_panel.active_slot),id)
	player_notice.text = "名號已入冊，軍籍獨立保存於本機。"

func _build_achievements_page() -> void:
	var page := _menu_page("achievements",Vector2(65,40),1150)
	achievements_title = _menu_label(page,"戰功簿",30)
	achievements_list = ItemList.new()
	achievements_list.custom_minimum_size.y = 460
	achievements_list.add_theme_font_size_override("font_size",21)
	achievements_list.add_theme_constant_override("v_separation",14)
	page.add_child(achievements_list)
	_menu_label(page,"奇功賞賜：1% 獲寶　｜　每戰各功一次・賞賜間隔 20 秒",18)
	_button("返　回",_menu_back,"Back",page)

func _open_achievements(slot: int) -> void:
	achievements_return = menu_screen
	var hero: String = HEROES[heroes.selected if slot == 0 else partner_heroes.selected]
	var row: Dictionary = profiles.character(slot,hero)
	achievements_title.text = "%s・%s　戰功 %d / 30" % [profiles.name_for(slot),HERO_NAMES[hero],row.achievements.size()]
	achievements_list.clear()
	for rule in Achievements.RULES: achievements_list.add_item(("◆ 已達成　" if rule[0] in row.achievements else "◇ 未達成　") + str(rule[1]) + "　｜　" + str(rule[2]))
	_show_menu_page("achievements")

func _equip_inventory(slot: int, uid: int) -> void:
	if not _prepare_inventory_save(): return
	if menu_screen == "select": equipment_in_battle = false
	encyclopedia_slot = slot
	var hero := _equipment_hero(slot)
	var profile = profiles.records[profiles.selected[slot]]
	var previous: Dictionary = profile.data.duplicate(true)
	if not profiles.equip_instance(slot,hero,uid): return
	_finish_inventory_change(slot,hero,previous,"兵甲整備，已記入軍籍。")

func _unequip_treasure(slot: int) -> void:
	if not _prepare_inventory_save(): return
	var hero := _equipment_hero(slot)
	var profile = profiles.records[profiles.selected[slot]]
	var previous: Dictionary = profile.data.duplicate(true)
	profiles.unequip_treasure(slot,hero)
	_finish_inventory_change(slot,hero,previous,"護符已卸下。")

func _pack_item(id: String) -> void:
	if active or not _prepare_inventory_save(): return
	var hero := _equipment_hero(encyclopedia_slot)
	var profile = profiles.records[profiles.selected[encyclopedia_slot]]
	var previous: Dictionary = profile.data.duplicate(true)
	var row: Dictionary = profiles.character(encyclopedia_slot,hero)
	var carry: bool = int(id) not in row.bag_uids
	if not profiles.pack(encyclopedia_slot,hero,int(id),carry):
		collection.notice.text = "此物品無法整備，請確認兵器相容性。"
		return
	_finish_inventory_change(encyclopedia_slot,hero,previous,"已收入隨身行囊。" if carry else "已送回藏兵閣。")

func _request_discard(id: String) -> void:
	if not equipment_in_battle: return
	var row: Dictionary = profiles.character(encyclopedia_slot,_equipment_hero(encyclopedia_slot))
	var item := Equipment.instance(row,int(id))
	if item.is_empty(): return
	_request_confirmation(_discard_item.bind(int(id)),"丟棄 %s？\n物品會永久消失，不能再撿回來。" % Equipment.catalog(item.item_id).name)

func _discard_item(uid: int) -> void:
	if not equipment_in_battle or not _prepare_inventory_save(): return
	var hero := _equipment_hero(encyclopedia_slot)
	var profile = profiles.records[profiles.selected[encyclopedia_slot]]
	var previous: Dictionary = profile.data.duplicate(true)
	if not profiles.discard(encyclopedia_slot,hero,uid): return
	_finish_inventory_change(encyclopedia_slot,hero,previous,"物品已從藏兵閣丟棄並消失。")

func _finish_inventory_change(slot: int, hero: String, previous: Dictionary, message: String) -> bool:
	var saved: bool = profiles.save_player(slot) == OK
	if not saved:
		profiles.records[profiles.selected[slot]].data = previous
		message = "操作未完成，已保留原裝備與物品。" + profiles.warning
	else:
		if equipment_in_battle:
			var row: Dictionary = profiles.character(slot,hero)
			for fighter in sim.state.fighters:
				if fighter.team != 0 or int(fighter.player_index) != slot: continue
				for field in ["next_item_uid","weapon_uid","treasure_uid","gold","achievements","bag_uids"]: fighter[field] = row[field].duplicate(true) if row[field] is Array else row[field]
				fighter.inventory = row.inventory.duplicate(true)
				fighter.bag_only = false
				fighter.storage_reserve = 0
				Equipment.sync(fighter)
			sim.cancel_input(slot)
	status.text = message
	_refresh_loadouts()
	_refresh_collection()
	collection.notice.text = message
	var row: Dictionary = profiles.character(slot,hero)
	encyclopedia.equipped = str(row.weapon_id)
	encyclopedia.owned = row.owned_weapons.duplicate()
	if menu_screen == "encyclopedia": encyclopedia.refresh_list()
	return saved

func _use_food(id: String) -> void:
	if not active or not paused or not equipment_in_battle or session not in ["solo","local"] or not _prepare_inventory_save(): return
	var slot := encyclopedia_slot
	var hero := _equipment_hero(slot)
	var party: Array = sim.state.fighters.filter(func(f): return f.team == 0 and int(f.player_index) == slot)
	if party.is_empty(): return
	var fighter: Dictionary = party[0]
	var item := Equipment.instance(fighter,int(id))
	if item.is_empty() or not Equipment.FOODS.has(item.item_id): return
	if fighter.hp <= 0 or fighter.hp >= fighter.max_hp:
		collection.notice.text = "體力全滿時保留食物；倒地戰敗時無法使用。"
		return
	var food_id: String = str(item.item_id)
	var previous: Dictionary = profiles.records[profiles.selected[slot]].data.duplicate(true)
	if not profiles.discard(slot,hero,int(id)): return
	# Save consumption before healing; a failed save keeps both HP and the item unchanged.
	if not _finish_inventory_change(slot,hero,previous,"已食用%s，恢復體力。" % Equipment.FOODS[food_id].name): return
	sim._eat_food(fighter,food_id.trim_prefix("food_"),int(Equipment.FOODS[food_id].heal))
	_events(sim.state.events)
	_update_view()
	_refresh_collection()
	collection.notice.text = "已食用%s，體力 %d / %d。" % [Equipment.FOODS[food_id].name,fighter.hp,fighter.max_hp]

func _request_sale(id: String) -> void:
	if equipment_in_battle: return
	var row: Dictionary = profiles.character(encyclopedia_slot,_equipment_hero(encyclopedia_slot))
	var item := Equipment.instance(row,int(id))
	if item.is_empty() or int(id) in [int(row.weapon_uid),int(row.treasure_uid)]: return
	_request_confirmation(_sell_item.bind(int(id)),"出售 %s（耐久 %d）獲得 %d 文？" % [Equipment.catalog(item.item_id).name,int(item.durability),Equipment.sale_price(item)])

func _sell_item(uid: int) -> void:
	if equipment_in_battle: return
	if not _prepare_inventory_save(): return
	var hero := _equipment_hero(encyclopedia_slot)
	var profile = profiles.records[profiles.selected[encyclopedia_slot]]
	var previous: Dictionary = profile.data.duplicate(true)
	var price: int = profiles.sell(encyclopedia_slot,hero,uid)
	if price <= 0: return
	_finish_inventory_change(encyclopedia_slot,hero,previous,"已出售，獲得 %d 文。" % price)

func _prepare_inventory_save() -> bool:
	if not profiles.migration_pending or profiles.save() == OK: return true
	status.text = "舊軍籍遷入尚未保存，操作已取消。" + profiles.warning
	character_panel.notice.text = status.text
	collection.notice.text = status.text
	return false

func _update_achievement_banner(delta: float) -> void:
	if not is_instance_valid(achievement_banner): return
	if not active:
		_achievement_messages.clear()
		_achievement_message_time = 0
		achievement_banner.hide()
		return
	if paused: return
	_achievement_message_time -= delta
	if _achievement_message_time <= 0:
		if _achievement_messages.is_empty(): achievement_banner.hide()
		else:
			achievement_banner.text = _achievement_messages.pop_front()
			achievement_banner.show()
			_achievement_message_time = 3.2

func _open_collection(slot: int) -> void:
	collection_return = menu_screen
	equipment_in_battle = active
	if equipment_in_battle and _save_characters() != OK: return
	encyclopedia_slot = slot
	_refresh_collection()
	_show_menu_page("collection")
	collection.item_list.grab_focus()

func _refresh_collection() -> void:
	var hero := _equipment_hero(encyclopedia_slot)
	var row: Dictionary = profiles.character(encyclopedia_slot,hero)
	var items := []
	for item in row.inventory:
		var spec := Equipment.catalog(str(item.item_id))
		if Equipment.FOODS.has(item.item_id):
			var food_id: String = str(item.item_id).trim_prefix("food_")
			var party: Array = sim.state.fighters.filter(func(f): return f.team == 0 and int(f.player_index) == encyclopedia_slot)
			var can_use: bool = equipment_in_battle and not party.is_empty() and party[0].hp > 0 and party[0].hp < party[0].max_hp
			items.append({"id":str(item.uid),"name":spec.name+"　×1","category":"食物","description":"恢復 %d 點體力（護符加成另計）。\n滿血拾取會收進藏兵閣；有缺血時拾取就會吃掉。\n戰鬥中按 Q／R1 食用下一份，按下時才看體力，全滿不消耗。軍議中也可選擇「使用」。"%int(spec.heal),"image":"res://assets/v18/food-source.png","image_region":view._stage_art.food[food_id].source_region,"consumable":true,"can_use":can_use,"can_pack":false,"packed":false,"can_sell":false})
			continue
		var treasure: bool = Equipment.TREASURES.has(item.item_id)
		var practice := Equipment.is_practice(item.item_id)
		items.append({"id":str(item.uid),"name":"%s　%s　#%d" % [spec.name,"耐久 ∞・常備" if practice else "%d/%d" % [int(item.durability),int(spec.durability)],int(item.uid)],"category":"護符" if treasure else {"sword":"刀","spear":"槍","bow":"弓"}[spec.family],"description":spec.description if treasure else WeaponArchive.stats(item.item_id) + "\n\n" + str(spec.history),"image":"res://assets/v21/treasures/%s.png" % spec.image if treasure else "res://assets/v22/weapons/%s.png" % Weapons.art_id(item.item_id),"can_equip":treasure or Weapons.compatible(hero,item.item_id),"can_pack":false,"packed":false,"has_details":not treasure and int(spec.tier) > 0,"slot":"護符" if treasure else "武器","price":Equipment.sale_price(item)})
	collection.configure("%s・%s　%d 文" % [profiles.name_for(encyclopedia_slot),HERO_NAMES[hero],int(row.gold)],items,[str(row.weapon_uid),str(row.treasure_uid)],equipment_in_battle)
	collection.notice.text = "藏兵閣 %d / %d；出陣直接取用全部藏品。%s" % [row.inventory.size(),Equipment.CAPACITY,"丟棄須確認，物品會永久消失。" if equipment_in_battle else ""]

func _open_weapon_encyclopedia(slot: int, return_page: String = "select") -> void:
	if equipment_in_battle: return
	encyclopedia_return = return_page
	if return_page != "collection": equipment_in_battle = false
	encyclopedia_slot = slot
	var hero := _equipment_hero(slot)
	var row: Dictionary = profiles.character(slot,hero)
	encyclopedia.configure(hero,row.owned_weapons,row.weapon_id)
	_show_menu_page("encyclopedia")

func _equip_from_encyclopedia(id: String) -> void:
	var row: Dictionary = profiles.character(encyclopedia_slot,_equipment_hero(encyclopedia_slot))
	for item in row.inventory:
		if item.item_id == id:
			_equip_inventory(encyclopedia_slot,int(item.uid))
			return

func _load_characters() -> void:
	if testing or session not in ["solo","local"]: return
	for fighter in sim.state.fighters:
		if fighter.team == 0: profiles.apply_to(fighter)
	sim.state.loot_rng = int(Time.get_unix_time_from_system()) & 0x7fffffff
	_saved_profile_signature = ""

func _save_characters(manual: bool = false) -> Error:
	if not active or testing or training_active or demo_active or session not in ["solo","local"]: return OK
	for fighter in sim.state.fighters: profiles.capture(fighter)
	if sim.state.has("stage"): profiles.capture_chapter(int(sim.state.stage.id),sim.state.phase == "won",2 if session == "local" else 1)
	var signature := JSON.stringify(profiles.data)
	if not manual and signature == _saved_profile_signature: return OK
	var err: Error = profiles.save()
	if err == OK:
		_saved_profile_signature = signature
		if manual: status.text = "軍籍、藏品與章程已保存。再度出陣，自章首進軍。"
	else:
		if profiles.warning == "": profiles.warning = "軍籍保存失敗 (%d)，原存檔與備份保留。" % err
		if is_instance_valid(status): status.text = profiles.warning
	return err

func _save_before_leaving() -> bool:
	if _save_characters(true) == OK: return true
	paused = true
	_show_menu_page("pause")
	status.text = "戰報保存失敗，已取消離開。\n" + profiles.warning
	return false

func _open_options() -> void:
	options_return = menu_screen
	status.text = "←／→ 調整音量　｜　設定自動保存"
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
		else: heroes.grab_focus()
	elif menu_screen == "collection":
		_show_menu_page(collection_return)
		if collection_return == "pause": menu_pages.pause.get_node("Collections/Collection%d" % encyclopedia_slot).grab_focus()
		else: heroes.grab_focus()
	elif menu_screen == "players": _show_menu_page(players_return)
	elif menu_screen == "select": _open_roster()
	elif menu_screen == "roster": _open_login(selection_coop)
	elif menu_screen == "achievements": _show_menu_page(achievements_return)
	elif menu_screen == "options": _show_menu_page(options_return)
	elif menu_screen == "pause": _resume()
	elif menu_screen == "main": _show_menu_page("title")
	elif menu_screen != "title": _show_menu_page("pause" if active else "main")

func _build_controls(ui: Control) -> void:
	controls_shade = ColorRect.new()
	controls_shade.name = "ControlsShade"
	controls_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls_shade.color = Color(0.04, 0.025, 0.02, 0.86)
	controls_shade.z_index = 40
	controls_shade.hide()
	ui.add_child(controls_shade)
	controls_dialog = AcceptDialog.new()
	controls_dialog.title = "吞食戰國 · 合戰秘卷"
	controls_dialog.theme = Typography.theme()
	controls_dialog.ok_button_text = "收卷"
	controls_dialog.exclusive = true
	ui.add_child(controls_dialog)
	var text := RichTextLabel.new()
	text.name = "ControlsText"
	text.focus_mode = Control.FOCUS_ALL
	text.bbcode_enabled = true
	text.custom_minimum_size = Vector2(1000, 490)
	text.add_theme_font_size_override("normal_font_size", 19)
	text.add_theme_constant_override("line_separation", 5)
	controls_dialog.add_child(text)
	text.text = "[b]信長・阿市　合戰之法[/b]\n" + BATTLE_HINT + "\n\n[b]連擊與奧義[/b]\nJ 連按三次：三連擊，末式帶武器氣勁，範圍再＋20% 並擊飛。第三下出手後至少間隔 0.5 秒才可再輕攻擊。\nK 點放：信長斬出劍氣，阿市射出單箭；可擊退，出招亦可被打斷。\n重手與蓄力皆可左右轉向，勁力不散。\n長按 K 蓄滿後放開：信長雙旋斬，阿市貫穿箭；阿市上＋放開為箭雨。\n跳＋J：近身揮打，威力與範圍＋20%。\n跳＋K：信長重落斬（＋30%），阿市近中遠三箭。\n按住 I／L2／LT：正面格擋減傷 80%，仍會被擊退、擊倒；放開解除，背襲不減傷。\n秀吉輕手三段範圍＋30%；K 點放：橫斬擊飛劍氣，射程同信長。\n秀吉蓄滿放開：三連瞬移斬，1.5 秒前進約 1/3 畫面，沿途擊倒。\n擒敵後 J：兩擊後摔出；反推方向立即過肩摔。\n衝刺＋K：踏步撞進，破陣擊飛；盾兵可受擊，敵將可格擋。\n\n[b]兵甲與軍令[/b]\nE／L1 拾取。滿血拾取食物會收入行囊；缺血時直接食用。行囊有食物時，人物欄下方顯示下一份；Q／R1 按下才看體力，全滿不消耗。軍議中仍可選用。\n兵器命中耗損耐久，折損後改持常備兵器；軍議中可開行囊換裝。\n奉令清敵破障，全軍會合後向右進軍。三命在身，每 10000 戰績添一命。\nF11 全螢幕／視窗　｜　Esc／Options 軍議　｜　F1 合戰秘卷\n\n[b]演武之法[/b]\n" + TRAINING_HINT
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
	if is_instance_valid(objective_scroll): objective_scroll.hide()
	if is_instance_valid(menu_input): menu_input.reset()
	controls_was_paused = paused
	controls_shade.show()
	_cancel_local_controls()
	if active and session in ["solo", "local"]:
		paused = true
	controls_dialog.popup_centered(Vector2i(1040, 570))

func _close_controls() -> void:
	if is_instance_valid(menu_input): menu_input.reset()
	var had_focus := _has_focus
	controls_dialog.hide()
	controls_shade.hide()
	paused = controls_was_paused or not had_focus or (session == "local" and (player_devices[0] < 0 or player_devices[1] < 0))
	_input_armed = false
	_partner_input_armed = false

func _button(text: String, callback: Callable, node_name: String, parent: Node = null) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	if parent != null and parent.name in ["Title","Main"]:
		button.add_theme_font_size_override("font_size",26)
		button.custom_minimum_size.y = 54
	button.pressed.connect(callback)
	(parent if parent != null else menu_panel).add_child(button)
	return button

func _choices() -> void:
	if HEROES[heroes.selected] not in Battle.PLAYABLE_HEROES: heroes.selected = 0
	if HEROES[partner_heroes.selected] not in Battle.PLAYABLE_HEROES: partner_heroes.selected = 1
	selected_hero = HEROES[heroes.selected]
	selected_chapter = int(chapter_choice.get_item_metadata(chapter_choice.selected))
	difficulty = DIFFICULTIES[difficulties.selected]
	selected_faction = FACTION_NAMES.keys()[factions.selected]

func _close_network(keep_music: bool = false) -> bool:
	if not _save_before_leaving(): return false
	_stop_rumble()
	player_devices = [-1, -1]
	audio.stop_speech()
	if not keep_music: audio.stop_music()
	pending_intro_actor = 0
	received_intro_actor = 0
	training_active = false
	demo_active = false
	view.art_demo = false
	view.demo_pose = -1
	demo_controls.hide()
	hint.hide()
	combat_hud.sync({})
	objective_scroll.sync({}, false)
	hud.text = ""
	exit_button.hide()
	next_button.hide()
	hint.text = BATTLE_HINT
	active = false
	session = "solo"
	remote_id = 0
	connecting_since = 0
	waiting_peer_since = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	return true

func _start_solo() -> void:
	if _confirm_end(_start_solo,"重新開始這一戰？"): return
	if not _close_network(true): return
	_choices()
	local_slot = 0
	sim.reset_campaign(difficulty, 1, [selected_hero],selected_chapter)
	_load_characters()
	_activate()

func _start_local_coop() -> void:
	if _confirm_end(_start_local_coop,"重新開始雙人戰鬥？"): return
	if profiles.selected[0] == profiles.selected[1]:
		status.text = "二人共鬥，須由兩冊不同名簿應召。"
		character_panel.notice.text = status.text
		return
	if _connected_pads().size() < 2:
		status.text = "雙搖桿合作需要兩支搖桿。請接上兩支，再按雙搖桿合作。"
		character_panel.notice.text = status.text
		return
	if not _close_network(true): return
	_choices()
	session = "local"
	local_slot = 0
	sim.reset_campaign(difficulty, 2, [selected_hero, HEROES[partner_heroes.selected]],selected_chapter)
	_load_characters()
	_activate()
	hint.text = "同機合作：1P／2P 各用一支搖桿，鍵盤也可控制 1P；同畫面共同前進\n□／X 輕擊 · ○／B 重擊 · ×／A 跳 · R2／RT 抓技 · L2／LT 格擋 · L1／LB 拾取 · R1／RB 進食 · Options 暫停"

func _start_training(drill: String = "") -> void:
	if _confirm_end(_start_training.bind(drill),"收兵離陣，轉赴演武場？"): return
	if drill != "": training_drill = drill
	if not _close_network(true): return
	_choices()
	training_active = true
	local_slot = 0
	_reset_training()

func _reset_training() -> void:
	if not training_active: return
	if _confirm_end(_reset_training,"重演此陣？"): return
	audio.stop_speech()
	sim.reset_training(selected_hero, training_drill, selected_faction)
	_activate()
	hint.text = TRAINING_HINT
	_update_view()

func _switch_training_hero() -> void:
	if not training_active: return
	if _confirm_end(_switch_training_hero,"換將並重演此陣？"): return
	selected_hero = Battle.PLAYABLE_HEROES[(Battle.PLAYABLE_HEROES.find(selected_hero) + 1) % Battle.PLAYABLE_HEROES.size()]
	heroes.selected = HEROES.find(selected_hero)
	_reset_training()

func _choose_training_drill(drill: String) -> void:
	if _confirm_end(_choose_training_drill.bind(drill),"更換演武陣式，重新列陣？"): return
	training_drill = drill
	_reset_training()

func _start_art_demo() -> void:
	if _confirm_end(_start_art_demo,"收兵離陣，翻閱武藝圖譜？"): return
	if not _close_network(): return
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
	view.demo_pose = -1
	view.demo_progress = art_demo.progress()
	view.weather = art_demo.weather()
	view.camera_x = 0.0
	view.state = art_demo.world()
	view.queue_redraw()
	demo_toggle.text = "暫停" if art_demo.running else "繼續循環"
	demo_speed.text = "速度 0.5×" if art_demo.speed < 1.0 else "速度 1×"
	var sample: Dictionary = view.animation_sample()
	hud.text = "武藝圖譜　%02d／10・%s　%s\n信長／阿市　%s %d／%d 幀　空白 暫停 · ← → 換招 · [ ] 逐幀 · S 慢放 · F 轉向" % [art_demo.pose() + 1, ArtDemo.POSES[art_demo.pose()], ["晴天", "夕照", "雨夜"][art_demo.weather()], "待機" if sample.clip == "idle" else "招式", int(sample.frame) + 1, int(sample.count)]

func _activate() -> void:
	terminal_voice_played = false
	_victory_spoken.clear()
	_victory_subtitle = ""
	active = true
	paused = false
	if sim.state.has("stage") and not audio.is_title_music(): audio.stop_music()
	audio.sync_stage_music(sim.state)
	audio.play_music()
	last_event = -1
	audio.clear_enemy_death_seen()
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
	if not _close_network(true): return
	_choices()
	var peer := ENetMultiplayerPeer.new()
	if not smoke.is_empty(): peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(int(port.value), 1, 3)
	if error != OK:
		_fail("無法建立主機（錯誤 %s），埠可能已使用。" % error)
		return
	multiplayer.multiplayer_peer = peer
	session = "host"
	audio.play_title_music()
	local_slot = 0
	status.text = "等待第二台電腦加入 · UDP %d\n請隊友輸入本機 IPv4。按返回可結束等候。" % int(port.value)
	_show_menu_page("engineering")

func _join() -> void:
	if _confirm_end(_join,"結束目前階段，加入連線戰鬥？"): return
	if not _close_network(true): return
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
	audio.play_title_music()
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
	if build != BUILD or fingerprint != _fingerprint() or hero not in Battle.PLAYABLE_HEROES:
		rejected.rpc_id(sender, "版本／內容不一致，請雙方使用同一版本。")
		return
	remote_id = sender
	waiting_peer_since = 0
	sim.reset_campaign(difficulty, 2, [selected_hero, hero],selected_chapter)
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
	if not _close_network(true): return
	paused = false
	_show_menu_page("main")
	audio.play_title_music()
	status.text = message
	if not smoke.is_empty():
		_report({"ok": false, "error": message})
		get_tree().quit(1)

func _next_chapter_id() -> int:
	if not sim.state.has("stage"): return 0
	var nxt := int(sim.state.stage.id) + 1
	for chapter in Stages.available():
		if int(chapter.id) == nxt: return nxt
	return 0

func _campaign_party() -> Array:
	var party: Array = sim.state.get("fighters", []).filter(func(fighter): return int(fighter.get("team", 1)) == 0)
	party.sort_custom(func(a, b): return int(a.get("player_index", 0)) < int(b.get("player_index", 0)))
	var heroes: Array = []
	for fighter in party: heroes.append(str(fighter.kind))
	if heroes.is_empty(): heroes.append(selected_hero)
	return heroes

func _continue_campaign() -> void:
	if _confirm_end(_continue_campaign, "進軍下一關？"): return
	var nxt := _next_chapter_id()
	if nxt <= 0 or session == "client": return
	var heroes := _campaign_party()
	var players := clampi(heroes.size(), 1, 2)
	if session in ["solo", "local"] and _save_characters(true) != OK: return
	_refresh_chapters()
	selected_chapter = nxt
	for index in chapter_choice.item_count:
		if int(chapter_choice.get_item_metadata(index)) == nxt:
			chapter_choice.selected = index
			break
	var mode := str(sim.state.get("difficulty", difficulty))
	if mode not in DIFFICULTIES: mode = difficulty
	difficulty = mode
	sim.reset_campaign(mode, players, heroes, nxt)
	if session in ["solo", "local"]: _load_characters()
	_activate()
	if session == "host" and remote_id != 0: begin_client.rpc_id(remote_id, sim.get_state(), mode)

func _leave_to_menu() -> void:
	if _confirm_end(_leave_to_menu,"收兵返回本陣？"): return
	if not _close_network(true): return
	paused = false
	_show_menu_page("main")
	audio.play_title_music()
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
		_request_confirmation(_request_quit,"收兵離營，結束遊戲？")
		return
	if _save_before_leaving(): get_tree().quit()

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
		var pad_buttons := {JOY_BUTTON_X:Battle.LIGHT,JOY_BUTTON_B:Battle.HEAVY,JOY_BUTTON_A:Battle.JUMP,JOY_BUTTON_LEFT_SHOULDER:Battle.INTERACT,JOY_BUTTON_RIGHT_SHOULDER:Battle.EAT}
		for button in pad_buttons:
			if Input.is_joy_button_pressed(device,button): frame.buttons |= pad_buttons[button]
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.24: frame.buttons |= Battle.GRAB
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.24: frame.buttons |= Battle.GUARD
		var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		frame.dx = int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
		frame.dy = int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
		if absf(x) > 0.24: frame.dx = int(signf(x))
		if absf(y) > 0.24: frame.dy = int(signf(y))
		if absf(x) > 0.24 or absf(y) > 0.24: frame.stick_full = Vector2(x,y).length() >= 0.9
	if slot == local_slot:
		var keys := {KEY_J:Battle.LIGHT,KEY_K:Battle.HEAVY,KEY_SPACE:Battle.JUMP,KEY_L:Battle.GRAB,KEY_E:Battle.INTERACT,KEY_Q:Battle.EAT,KEY_I:Battle.GUARD}
		for key in keys:
			if Input.is_physical_key_pressed(key): frame.buttons |= keys[key]
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
	if is_instance_valid(menu_input): menu_input.reset()
	if testing or not smoke.is_empty(): return
	# The F1 child window owns focus and pause until it closes.
	if controls_dialog.visible:
		_has_focus = focused or controls_dialog.has_focus()
		return
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
	view._fx.set_paused(not active or paused or menu.visible or controls_dialog.visible)
	if not active and view._fx.last_tick >= 0: view._fx.reset_scene()
	_update_achievement_banner(_delta)
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
	if local_frame % 120 == 0 or sim.state.events.any(func(event): return event.type in ["pickup","food_stored","defeat"]): _save_characters()
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
		end_label.text = "合戰大捷" if sim.state.phase == "won" else "此戰未竟"
		if not _victory_subtitle.is_empty(): end_label.text += "\n" + _victory_subtitle
		if sim.state.phase == "lost": end_label.text += "\n按 Esc 返回選單／重新開始"

func _events(events: Array) -> void:
	view.state = sim.state
	view._fx.muted = testing or not smoke.is_empty()
	view._fx.sync(sim.state,view)
	var pulses := {}
	for event in events:
		if not event is Dictionary: continue
		var event_id := int(event.get("id", -1))
		if event_id <= last_event: continue
		last_event = event_id
		_collect_rumble(event, pulses)
		if event.type == "achievement": _achievement_messages.append("%dP  %s\n%s%s" % [int(sim._fighter(int(event.actor)).get("player_index",0))+1,str(event.name),str(event.description),"　・　獲得戰利品！" if event.get("loot",false) else ""])
		elif event.type == "weapon_break": _achievement_messages.append(str(event.name) + " 已折・改持常備兵器")
		elif event.type == "food_stored": _achievement_messages.append("%dP 食物已收入行囊。Q／R1 食用下一份，全滿不消耗。" % (int(sim._fighter(int(event.actor)).player_index)+1))
		elif event.type == "inventory_full": _achievement_messages.append("藏兵閣已滿，騰出空位後再拾取。地上物品保留。")
		elif event.type == "challenge_complete": _achievement_messages.append("糧車奪回・每將獲賞 %d 金" % int(event.amount))
		elif event.type == "challenge_failed": _achievement_messages.append("糧車損毀・仍可繼續進軍")
		if event.get("type", "") == "boss_intro" and session == "host" and remote_id != 0:
			pending_intro_actor = int(event.actor)
			receive_boss_voice.rpc_id(remote_id, int(event.actor), str(event.line_key))
		if smoke.is_empty() and not testing:
			audio.prepare_enemy_death(event)
			var voiced: Dictionary = event.duplicate()
			voiced.shared_sfx = view._fx.accept_event(event,sim.state,view)
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
	if int(sim.state.get("stage",{}).get("id",0))==5: view._stage05_art.prepare_scene(sim.state)
	view._fx.muted = testing or not smoke.is_empty()
	view._fx.sync(sim.state,view)
	view._fx.sound.set_voice_duck(audio.speech_playing())
	combat_hud.show()
	combat_hud.sync(sim.state)
	hud.position = Vector2(416, 15)
	hud.size = Vector2(448, 75)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio.sync_encounter(sim.state if active else {})
	if active: audio.sync_stage_music(sim.state)
	var victory_ready: bool = active and str(sim.state.get("phase","")) == "won" and bool(sim.state.get("victory_looting",false)) and not menu.visible
	exit_button.visible = victory_ready
	next_button.visible = victory_ready and session != "client" and _next_chapter_id() > 0
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
	hud.visible = training_active
	hud.text = ""
	if training_active:
		var player: Dictionary = sim.state.fighters[0]
		var stats: Dictionary = sim.state.training
		var full_ms := float(Battle.CombatMoves.registration(str(player.kind)).clips.charge_ready.duration_ms)
		var charge_percent := mini(100,roundi(float(player.charge)*1000/60/full_ms*100))
		var move_name: String = {"guard":"格擋","idle":"衝刺" if player.get("sprinting",false) else "待機","light":"輕手 %d/3" % player.combo,"heavy":"單箭・擊退" if player.kind == "oichi" else ("橫斬劍氣・擊飛" if player.kind == "hideyoshi" else "下斬劍氣・擊退"),"charged":"貫穿箭・擊退" if player.kind == "oichi" else ("三連瞬移斬・沿途擊倒" if player.kind == "hideyoshi" else "旋斬兩圈・擊飛"),"charge_rain":"朝天箭雨・範圍擊倒","grab_start":"抓取起手","holding":"抓住：輕手兩次，第三次摔／反推過肩摔","grab_hit_1":"膝擊一" if player.kind == "oichi" else "頭槌一","grab_hit_2":"膝擊二" if player.kind == "oichi" else "頭槌二","throw":"摔投","dash_heavy":"跑步重手","air_light":"空中輕手","air_heavy":"空中三箭" if player.kind == "oichi" else "重落地下斬","charge":"滿蓄・放開施放" if charge_percent >= 100 else "蓄力 %d%%" % charge_percent,"recovering":"起身中","launched":"被擊飛","down":"倒地"}.get(player.action,player.action)
		var drill_name: String = {"dummy": "木樁演武", "shield": "破盾演武", "enemies": FACTION_NAMES.get(selected_faction, selected_faction) + "軍試戰", "ranged": "弓銃演武", "boss": "敵將試煉"}.get(training_drill, training_drill)
		var living := 0
		for enemy in sim.state.fighters:
			if enemy.team == 1 and enemy.hp > 0: living += 1
		hud.text = "%s・%s\n餘敵 %d　中敵 %d 次" % [drill_name,move_name,living,stats.hit_count]
	var introduction: Dictionary = sim.state.get("intro", {})
	var dialogue: bool = int(introduction.get("remaining_ticks", 0)) > 0 or audio.intro_playing()
	objective_scroll.sync(sim.state, active and not paused and not menu.visible and not controls_dialog.visible and not training_active and not demo_active, dialogue)
	if dialogue:
		var key := str(introduction.get("line_key", ""))
		end_label.position = Vector2(200,100)
		end_label.add_theme_font_size_override("font_size", 23)
		end_label.text = str(introduction.get("name", "")) + "\n" + str(introduction.get("line",audio.speech_manifest.get("clips", {}).get(key, {}).get("text", "")))
	elif sim.state.get("phase", "") == "playing":
		end_label.text = ""

func _input(event: InputEvent) -> void:
	if is_instance_valid(menu_input) and menu_input.handle(event):
		get_viewport().set_input_as_handled()
		return
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
	if is_instance_valid(menu_input) and menu_input.keyboard.visible: return
	if is_instance_valid(menu_input) and menu_input.has_popup(): return
	if menu.visible:
		if menu_screen == "collection" and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			var direction := -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
			collection.categories.current_tab = posmod(collection.categories.current_tab+direction,collection.categories.tab_count)
			collection.item_list.grab_focus()
			get_viewport().set_input_as_handled()
			return
		var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
		if back or start:
			if start and menu_screen == "title": _open_login(false)
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
	if demo_active and not menu.visible:
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
	if is_instance_valid(menu_input): menu_input.reset()
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
	feedback_label.text = "搖桿已連接；R2／RT 抓人；支援震動。" if connected else "搖桿已拔除。雙人合作需兩支搖桿；未拔除的玩家保留原本席位。"

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

