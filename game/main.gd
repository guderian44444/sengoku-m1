extends Node

const Battle = preload("res://core/battle.gd")
const BattleView = preload("res://render/battle_view.gd")
const CombatAudio = preload("res://render/combat_audio.gd")
const Wire = preload("res://core/wire.gd")
const ArtDemo = preload("res://render/art_demo.gd")
const BUILD := "sengoku-m1-0.17.0"
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
var paused := false:
	set(value):
		paused = value
		if is_instance_valid(audio): audio.set_music_paused(value)
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
var selected_faction := "mori"
var difficulty := "normal"
var net_events: Array = []
var menu: Control
var menu_panel: VBoxContainer
var status: Label
var hud: Label
var rage_bars: Array[ProgressBar] = []
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

func _ready() -> void:
	_actions()
	view = BattleView.new()
	add_child(view)
	audio = CombatAudio.new()
	add_child(audio)
	audio._intro_player.finished.connect(_local_boss_voice_finished)
	sim.boss_intros = audio.speech_manifest.get("boss_intros", {}).duplicate(true)
	_build_ui()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _fail("無法連線。請確認 IP、UDP 埠與防火牆。"))
	multiplayer.server_disconnected.connect(func(): _fail("主機已斷線。此 M1 不保留中途進度，請重新開局。"))
	Input.joy_connection_changed.connect(_joy_changed)
	get_window().focus_exited.connect(func(): _set_game_focus(false))
	get_window().focus_entered.connect(func(): _set_game_focus(true))
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
	if menu.visible: menu_panel.get_node("Training").grab_focus()
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
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_X if action in ["move_left", "move_right"] else JOY_AXIS_LEFT_Y
		axis.axis_value = -1.0 if action in ["move_left", "move_up"] else 1.0
		InputMap.action_add_event(action, axis)
	var guard_axis := InputEventJoypadMotion.new()
	guard_axis.axis = JOY_AXIS_TRIGGER_LEFT
	guard_axis.axis_value = 1.0
	InputMap.action_add_event("guard", guard_axis)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 19
	ui.theme = theme
	var hud_bg := ColorRect.new()
	hud_bg.color = Color(0.025, 0.06, 0.065, 0.93)
	hud_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_bg.offset_bottom = 112
	hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud_bg)
	var controls_bg := ColorRect.new()
	controls_bg.color = Color(0.025, 0.06, 0.065, 0.93)
	controls_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls_bg.offset_top = -82
	controls_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(controls_bg)
	hud = Label.new()
	hud.position = Vector2(28, 15)
	hud.size = Vector2(1220, 80)
	hud.add_theme_color_override("font_color", Color("#eee2bd"))
	ui.add_child(hud)
	for slot in range(2):
		var meter := ProgressBar.new()
		meter.position = Vector2(28 + slot * 620, 88)
		meter.size = Vector2(290, 10)
		meter.show_percentage = false
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("bc6435")
		meter.add_theme_stylebox_override("fill", fill)
		meter.hide()
		ui.add_child(meter)
		rage_bars.append(meter)
	hint = Label.new()
	hint.position = Vector2(24, 650)
	hint.size = Vector2(1230, 62)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#c4d0bb"))
	hint.text = BATTLE_HINT
	ui.add_child(hint)
	end_label = Label.new()
	end_label.position = Vector2(200, 210)
	end_label.size = Vector2(880, 130)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 36)
	end_label.add_theme_color_override("font_color", Color("#f7d797"))
	end_label.add_theme_color_override("font_outline_color", Color("#17110d"))
	end_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(end_label)
	menu = CenterContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#152c2b")
	style.border_color = Color("#9a8856")
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	menu.add_child(panel)
	menu_panel = VBoxContainer.new()
	menu_panel.add_theme_constant_override("separation", 7)
	panel.add_child(menu_panel)
	var title := Label.new()
	title.text = "吞 食 戰 國   ／   M1 戰鬥原型"
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#ead69b"))
	menu_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "v0.17 本多忠勝完整招式 · 槍底震地 · 平順突進"
	subtitle.add_theme_font_size_override("font_size", 17)
	menu_panel.add_child(subtitle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	menu_panel.add_child(row)
	heroes = OptionButton.new()
	for label in ["信長｜炎刀", "阿市｜短針・長弓", "秀吉｜短槍快攻", "家康｜太刀・防禦", "光秀｜拔刀反擊", "忠勝｜長槍重投"]: heroes.add_item(label)
	row.add_child(heroes)
	difficulties = OptionButton.new()
	for label in ["故事難度", "標準難度", "挑戰難度"]: difficulties.add_item(label)
	difficulties.selected = 1
	row.add_child(difficulties)
	factions = OptionButton.new()
	for faction in FACTION_NAMES: factions.add_item(FACTION_NAMES[faction] + "軍")
	row.add_child(factions)
	_button("鍵盤練習場｜立即試打木樁", _start_training, "Training")
	_button("目前陣營試戰｜分波攻防", func(): training_drill = "enemies"; _start_training(), "EnemyTraining")
	_button("單人關卡／重新開始", _start_solo, "Solo")
	var coop_row := HBoxContainer.new()
	menu_panel.add_child(coop_row)
	partner_heroes = OptionButton.new()
	for hero in HEROES: partner_heroes.add_item("2P " + HERO_NAMES[hero])
	partner_heroes.selected = 1
	coop_row.add_child(partner_heroes)
	_button("雙搖桿合作｜兩支搖桿同機遊玩", _start_local_coop, "LocalCoop", coop_row)
	_button("信長／阿市｜逐招素材展示", _start_art_demo, "ArtDemo")
	var network_row := HBoxContainer.new()
	network_row.add_theme_constant_override("separation", 10)
	menu_panel.add_child(network_row)
	address = LineEdit.new()
	address.placeholder_text = "主機 IPv4，例如 192.168.1.10"
	address.text = "127.0.0.1"
	address.custom_minimum_size.x = 350
	network_row.add_child(address)
	port = SpinBox.new()
	port.custom_minimum_size.x = 170
	port.min_value = 1024
	port.max_value = 65535
	port.value = DEFAULT_PORT
	port.prefix = "UDP "
	network_row.add_child(port)
	var row_buttons := HBoxContainer.new()
	menu_panel.add_child(row_buttons)
	_button("建立雙人主機", _host, "Host", row_buttons)
	_button("以 IP 加入", _join, "Join", row_buttons)
	var ip_text := Label.new()
	var ips: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.is_valid_ip_address() and "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."): ips.append(ip)
	ip_text.text = "本機 IPv4：" + (", ".join(ips) if not ips.is_empty() else "未偵測到區域網路位址")
	ip_text.add_theme_font_size_override("font_size", 15)
	menu_panel.add_child(ip_text)
	status = Label.new()
	status.text = "雙機同網段先行；無中繼。跨網路可能需 UDP 開埠，CGNAT 不保證。\n主機選難度與角色；對方加入後立即開始。"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 700
	status.add_theme_font_size_override("font_size", 16)
	menu_panel.add_child(status)
	feedback_label = Label.new()
	feedback_label.text = "抓摔：△／Y 按住抓人、放開摔。支援的搖桿會震動；離開不保存進度。"
	feedback_label.add_theme_font_size_override("font_size", 14)
	menu_panel.add_child(feedback_label)
	var bottom := HBoxContainer.new()
	menu_panel.add_child(bottom)
	_button("繼續遊戲／練習", _resume, "Resume", bottom)
	_button("結束連線／返回", _leave_to_menu, "Leave", bottom)
	_button("離開程式", func(): get_tree().quit(), "Quit", bottom)
	_button("操作／COMBO表 (F1)", _show_controls, "Controls", bottom)
	_build_controls(ui)
	hud.text = "吞食戰國    M1 六武將試戰    0.15.0"
	demo_controls = HBoxContainer.new()
	demo_controls.position = Vector2(24, 652)
	demo_controls.add_theme_constant_override("separation", 12)
	ui.add_child(demo_controls)
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

func _build_controls(ui: Control) -> void:
	controls_dialog = AcceptDialog.new()
	controls_dialog.title = "吞食戰國 v0.17 · 操作與 COMBO"
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
	text.text = "[b]六主角操作表[/b]\nWASD 移動 · 空白 跳躍 · E 拾取 · I 防禦 · 同方向雙點按住衝刺\n按住左右連打：出招時停止前進，停打恢復；新按左右＋J：突進技\n先衝刺再按 K：立即衝刺重手，朝面前攻擊；不進入蓄力\n\n"
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
	difficulty = DIFFICULTIES[difficulties.selected]
	selected_faction = FACTION_NAMES.keys()[factions.selected]

func _close_network() -> void:
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
	hint.show()
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
	_close_network()
	_choices()
	local_slot = 0
	sim.reset(difficulty, 1, [selected_hero], selected_faction)
	_activate()

func _start_local_coop() -> void:
	if _connected_pads().size() < 2:
		status.text = "雙搖桿合作需要兩支搖桿。請接上兩支，再按雙搖桿合作。"
		return
	_close_network()
	_choices()
	session = "local"
	local_slot = 0
	sim.reset(difficulty, 2, [selected_hero, HEROES[partner_heroes.selected]], selected_faction)
	_activate()
	hint.text = "同機合作：1P／2P 各用一支搖桿，鍵盤也可控制 1P；同畫面共同前進\n□／X 輕擊 · ○／B 重擊 · ×／A 跳 · △／Y 按住抓人、放開摔 · R1／RB 必殺 · L2／LT 防禦 · Options 暫停"

func _start_training() -> void:
	_close_network()
	_choices()
	training_active = true
	local_slot = 0
	_reset_training()

func _reset_training() -> void:
	if not training_active: return
	audio.stop_speech()
	sim.reset_training(selected_hero, training_drill, selected_faction)
	_activate()
	hint.text = TRAINING_HINT
	_update_view()

func _switch_training_hero() -> void:
	if not training_active: return
	selected_hero = HEROES[(HEROES.find(selected_hero) + 1) % HEROES.size()]
	heroes.selected = HEROES.find(selected_hero)
	_reset_training()

func _start_art_demo() -> void:
	_close_network()
	art_demo = ArtDemo.new()
	demo_active = true
	paused = false
	menu.hide()
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
	end_label.text = ""
	end_label.position = Vector2(200, 210)
	view.local_slot = local_slot
	if smoke.is_empty() and not testing and sim.state.get("intro", {}).is_empty():
		for fighter in sim.state.fighters:
			if fighter.team == 0: audio.play_character(fighter.kind, "intro", fighter.player_index, true)

func _host() -> void:
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
	local_slot = 0
	status.text = "等待第二台電腦加入 · UDP %d\n輸入上方本機 IPv4。關閉本畫面請按「結束連線／返回」。" % int(port.value)
	menu.show()

func _join() -> void:
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
	sim.reset(difficulty, 2, [selected_hero, hero], selected_faction)
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
	menu.show()
	status.text = message
	if not smoke.is_empty():
		_report({"ok": false, "error": message})
		get_tree().quit(1)

func _leave_to_menu() -> void:
	_close_network()
	paused = false
	menu.show()
	end_label.text = ""
	status.text = "已返回選單。本次 M1 試玩不保存進度。"

func _resume() -> void:
	if session == "local" and (player_devices[0] < 0 or player_devices[1] < 0):
		status.text = "隊友搖桿尚未連接。接回兩支搖桿後再繼續。"
		return
	if active and session in ["solo", "local"] and sim.state.get("phase", "") in ["playing", "won"]:
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
	_has_focus = focused
	_input_armed = false
	_partner_input_armed = false
	if focused: return
	_cancel_local_controls()
	for action in CONTROL_ACTIONS: Input.action_release(action)
	if active and session in ["solo", "local"]:
		paused = true
		menu.show()
		status.text = "遊戲已暫停。回到視窗後，放開按鍵並按「繼續遊戲／練習」。"

func _physics_process(_delta: float) -> void:
	app_ticks += 1
	if demo_active:
		art_demo.step(_delta)
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
	# Playback is real-time; leave the intro paused if rendering runs ahead of its spoken clip.
	if session != "client" and (audio.intro_playing() or pending_intro_actor > 0) and int(sim.state.get("intro", {}).get("remaining_ticks", 0)) <= 1:
		_update_view()
		return
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
			audio.stop_music()
			if sim.state.phase == "won":
				for fighter in sim.state.fighters:
					if fighter.team == 0 and fighter.hp > 0 and fighter.kind not in ["nobunaga", "oichi", "tadakatsu"]:
						audio.play_character(fighter.kind, "victory", fighter.player_index, true)
		if sim.state.phase == "won":
			for fighter in sim.state.fighters:
				if fighter.team != 0 or fighter.hp <= 0 or fighter.action != "victory" or fighter.action_tick < Battle.VICTORY_VOICE_TICK or _victory_spoken.has(fighter.id): continue
				if audio.speech_playing(): break
				audio.play_character(fighter.kind, "victory", fighter.player_index, true)
				_victory_spoken[fighter.id] = true
				var line: Dictionary = audio.speech_manifest.get("clips", {}).get(audio.last_spoken, {})
				_victory_subtitle = HERO_NAMES.get(fighter.kind, fighter.kind) + "：「" + str(line.get("subtitle", line.get("text", ""))) + "」"
		end_label.position = Vector2(200, 138)
		end_label.add_theme_font_size_override("font_size", 26)
		end_label.text = "前哨突破！" if sim.state.phase == "won" else "此戰未竟"
		if not _victory_subtitle.is_empty(): end_label.text += "\n" + _victory_subtitle
		end_label.text += "\n按 Esc 返回選單／重新開始"

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
	var x := 480.0
	var living_x: Array[float] = []
	var lines: Array[String] = []
	for meter in rage_bars: meter.hide()
	for fighter in sim.state.get("fighters", []):
		if int(fighter.get("team", 1)) != 0: continue
		var slot := int(fighter.get("player_index", 0))
		if slot == local_slot: x = float(fighter.x)
		if fighter.hp > 0: living_x.append(float(fighter.x))
		var name_text: String = HERO_NAMES.get(fighter.kind, fighter.kind)
		if slot >= 0 and slot < rage_bars.size():
			rage_bars[slot].show()
			rage_bars[slot].value = fighter.rage
			rage_bars[slot].modulate = Color("ffe0a1") if fighter.rage >= 100 else Color.WHITE
		lines.append("%dP %s   體力 %d/%d   怒氣 %d   甲 %d / 武 %d" % [slot + 1, name_text, fighter.hp, fighter.max_hp, fighter.rage, fighter.armor, fighter.weapon])
	if session == "local" and not living_x.is_empty():
		x = 0.0
		for position in living_x: x += position / living_x.size()
	view.camera_x = clampf(x - (640.0 if session == "local" else 540.0), 0.0, 1100.0)
	view.queue_redraw()
	var mode := "單人" if session == "solo" else ("雙搖桿合作" if session == "local" else "IP 直連 · " + ("主機" if session == "host" else "客端"))
	hud.text = "吞食戰國  M1    %s    第 %d 波    %s\n%s" % [mode, int(sim.state.get("wave", 1)), difficulty, "    │    ".join(lines)]
	if training_active:
		var player: Dictionary = sim.state.fighters[0]
		var stats: Dictionary = sim.state.training
		var move_name: String = {"idle": "待機", "light": "輕擊 %d/3" % player.combo, "charge": "蓄力完成・放開出招" if player.charge >= 35 else "蓄力 %d%%" % int(player.charge * 100.0 / 35.0), "heavy": "重擊 %d/2" % player.heavy_combo, "charged": "爆裂冰箭" if player.kind == "oichi" else "炎刃斷陣", "rising": "上揚飛針" if player.kind == "oichi" else "上挑", "low_sweep": "低位攻擊", "dash_strike": "踏步突進", "dash_heavy": "衝刺重擊", "air_light": "空中輕擊", "air_heavy": "空中重擊", "upper_heavy": "挑空重擊", "charged_upper": "蓄力升空技", "mixed_finisher": "混合連段終結", "ground_slam": "震地／落矢", "charged_slam": "霜華冰陣・前方120°" if player.kind == "oichi" else ("炎獄裂地・全周360°" if player.kind == "nobunaga" else "大範圍蓄力地陣"), "holding": "肉盾 %.1f秒・放開摔" % maxf(0.0, (180.0 - player.action_tick) / 60.0), "throw": "飛摔", "special": "必殺・全程無敵", "stunned": "暈眩", "pulled": "被鎖鏈拉近"}.get(player.action, player.action)
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
		var rage_hint := "木樁怒氣無限" if training_drill == "dummy" else ("怒氣滿！按 U" if player.rage >= 100 else "挨打／格擋集怒")
		hud.text = "%s v0.17  ·  %s  ·  %s\n體力 %d/%d   怒氣 %d/100   第 %d 波・敵人 %d   命中 %d 次   %s" % [drill_name, HERO_NAMES.get(player.kind, player.kind), move_name, player.hp, player.max_hp, player.rage, sim.state.wave, living, stats.hit_count, rage_hint]
	var introduction: Dictionary = sim.state.get("intro", {})
	if int(introduction.get("remaining_ticks", 0)) > 0 or audio.intro_playing():
		var key := str(introduction.get("line_key", ""))
		end_label.add_theme_font_size_override("font_size", 27)
		end_label.text = str(introduction.get("name", "")) + "\n" + str(audio.speech_manifest.get("clips", {}).get(key, {}).get("text", ""))
		end_label.text += "\n—— 武將出場・台詞結束後開戰 ——"
	elif sim.state.get("phase", "") == "playing":
		end_label.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		if controls_dialog.visible: _close_controls()
		else: _show_controls()
		get_viewport().set_input_as_handled()
		return
	if controls_dialog.visible: return
	if training_active and active and not menu.visible and _has_focus and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			_reset_training()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB:
			_switch_training_hero()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			training_drill = ["dummy", "shield", "enemies", "ranged", "boss"][event.physical_keycode - KEY_1]
			_reset_training()
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
		if session in ["host", "client"]:
			menu.visible = not menu.visible
			_input_armed = false
			if menu.visible: _cancel_local_controls()
			status.text = "連線中開啟選單不暫停全隊；你的角色停止輸入。離線請按結束連線。"
		else:
			if paused: _resume()
			else:
				paused = true
				menu.show()
				_cancel_local_controls()
		if menu.visible: menu_panel.get_node("Training").grab_focus()

func _joy_changed(device: int, connected: bool) -> void:
	var assigned := device in player_devices or player_devices[local_slot] < 0
	if not connected and assigned and active:
		_cancel_local_controls()
		for action in CONTROL_ACTIONS: Input.action_release(action)
		if session in ["solo", "local"]:
			paused = true
			menu.show()
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

