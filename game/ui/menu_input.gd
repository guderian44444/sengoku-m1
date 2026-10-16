extends Node

const Keyboard = preload("res://ui/controller_keyboard.gd")
var app
var keyboard: Control
var held := Vector2i.ZERO
var left_axis := Vector2.ZERO
var repeat_after := 0.0
var scroll_axis := 0.0
var scroll_after := 0.0
var popups: Array[PopupMenu] = []

func initialize(owner_app) -> void:
	app = owner_app
	keyboard = Keyboard.new()
	app.menu.get_parent().add_child(keyboard)
	keyboard.closed.connect(reset)
	for control in app.menu.find_children("*", "Control", true, false):
		if control is OptionButton:
			var popup: PopupMenu = control.get_popup()
			popups.append(popup)
			popup.popup_hide.connect(reset)
	app.address.name = "Address"
	app.player_name_input.name = "PlayerName"
	app.port.get_line_edit().name = "PortValue"
	app.controls_dialog.window_input.connect(_controls_input)
	app.controls_dialog.focus_entered.connect(func(): app._set_game_focus(true))
	app.controls_dialog.focus_exited.connect(func(): app._set_game_focus(false))

func reset() -> void:
	held = Vector2i.ZERO
	left_axis = Vector2.ZERO
	scroll_axis = 0.0
	repeat_after = 0.0

func scope() -> Control:
	if keyboard.visible: return keyboard
	return app.menu_pages.get(app.menu_screen)

func focusables() -> Array[Control]:
	var result: Array[Control] = []
	var page := scope()
	if not is_instance_valid(page): return result
	for child in page.find_children("*", "Control", true, false):
		if not child.is_visible_in_tree() or child.focus_mode != Control.FOCUS_ALL: continue
		if child is BaseButton and child.disabled: continue
		if child is ScrollBar: continue
		if child is LineEdit and not child.editable: continue
		result.append(child)
	if not keyboard.visible and app.engineer_entry.is_visible_in_tree(): result.append(app.engineer_entry)
	return result

func focus_first() -> void:
	var controls := focusables()
	if not controls.is_empty(): controls[0].grab_focus()

func _process(delta: float) -> void:
	if not app._has_focus or (not app.menu.visible and not keyboard.visible):
		reset()
		return
	if app.controls_dialog.visible or _popup() != null: return
	if held != Vector2i.ZERO:
		repeat_after -= delta
		if repeat_after <= 0:
			navigate(held)
			repeat_after = 0.14
	if absf(scroll_axis) >= 0.5:
		scroll_after -= delta
		if scroll_after <= 0:
			_scroll_details(signi(int(scroll_axis * 100)))
			scroll_after = 0.1

func handle(event: InputEvent) -> bool:
	if not app._has_focus and (event is InputEventJoypadButton or event is InputEventJoypadMotion): return true
	if keyboard.visible and event is InputEventKey:
		if event.pressed and event.physical_keycode == KEY_ESCAPE:
			keyboard.finish(false)
			return true
		if event.pressed and event.physical_keycode == KEY_TAB:
			cycle(-1 if event.shift_pressed else 1)
			return true
		if event.pressed and get_viewport().gui_get_focus_owner() != keyboard.editor:
			var direction: Vector2i = {KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN, KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT}.get(event.physical_keycode, Vector2i.ZERO)
			if direction != Vector2i.ZERO:
				navigate(direction)
				return true
		if event.pressed and event.unicode >= 32 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			keyboard.editor.grab_focus()
		return false
	if not app.menu.visible and not keyboard.visible: return false
	if app.controls_dialog.visible: return false
	if _popup() != null: return false
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_Y:
			if absf(scroll_axis) < 0.5 and absf(event.axis_value) >= 0.5:
				_scroll_details(signi(int(event.axis_value * 100)))
				scroll_after = 0.35
			scroll_axis = event.axis_value
			return true
		if event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]: return false
		var direction := _axis_direction(event)
		if direction != held:
			if direction != Vector2i.ZERO: navigate(direction)
			held = direction
			repeat_after = 0.35
		return true
	if not event is InputEventJoypadButton: return false
	var direction: Vector2i = {JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN, JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT}.get(event.button_index, Vector2i.ZERO)
	if direction != Vector2i.ZERO:
		if event.pressed:
			navigate(direction)
			held = direction
			repeat_after = 0.35
		elif held == direction: held = Vector2i.ZERO
		return true
	if not event.pressed: return false
	if keyboard.visible:
		match event.button_index:
			JOY_BUTTON_B: keyboard.finish(false); return true
			JOY_BUTTON_START: keyboard.finish(true); return true
			JOY_BUTTON_X: keyboard.erase_character(); return true
			JOY_BUTTON_LEFT_SHOULDER: keyboard.change_bank(-1); return true
			JOY_BUTTON_RIGHT_SHOULDER: keyboard.change_bank(1); return true
	if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER] and app.menu_screen != "collection":
		cycle(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
		return true
	if event.button_index == JOY_BUTTON_A:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit:
			if keyboard.visible: keyboard.key_buttons[0].grab_focus()
			else: keyboard.open(focus, focus.get_parent() is SpinBox)
			reset()
			return true
		if focus == null: focus_first(); return true
	return false

func cycle(direction: int) -> void:
	var controls := focusables()
	if controls.is_empty(): return
	var index := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(index + direction, controls.size())].grab_focus()

func navigate(direction: Vector2i) -> void:
	var controls := focusables()
	if controls.is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus not in controls:
		controls[0].grab_focus()
		return
	if focus is ItemList and direction.y != 0:
		var selected: PackedInt32Array = focus.get_selected_items()
		var index: int = (selected[0] if not selected.is_empty() else -1) + direction.y
		if index >= 0 and index < focus.item_count:
			focus.select(index)
			focus.ensure_current_is_visible()
			focus.item_selected.emit(index)
			return
	if focus is Slider and direction.x != 0:
		focus.value += direction.x * focus.step
		return
	if focus is LineEdit and focus.get_parent() is SpinBox and direction.x != 0:
		var spin: SpinBox = focus.get_parent()
		spin.value += direction.x * spin.step
		return
	if focus is TabBar and direction.x != 0:
		focus.current_tab = posmod(focus.current_tab + direction.x, focus.tab_count)
		return
	if focus is ScrollContainer and direction.y != 0:
		var before: int = focus.scroll_vertical
		focus.scroll_vertical += direction.y * 64
		if focus.scroll_vertical != before: return
	if focus is RichTextLabel and direction.y != 0:
		var bar: VScrollBar = focus.get_v_scroll_bar()
		var before := bar.value
		bar.value += direction.y * 64
		if bar.value != before: return
	var origin := focus.get_global_rect().get_center()
	var best: Control
	var score := INF
	for candidate in controls:
		if candidate == focus: continue
		var distance := candidate.get_global_rect().get_center() - origin
		var along := distance.dot(Vector2(direction))
		if along <= 4: continue
		var across := absf(distance.y if direction.x != 0 else distance.x)
		var candidate_score := along + across * 3.0
		if candidate_score < score:
			score = candidate_score
			best = candidate
	if best != null: best.grab_focus()
	else: cycle(direction.x if direction.x != 0 else direction.y)

func _scroll_details(direction: int) -> void:
	if keyboard.visible: return
	for control in scope().find_children("*", "ScrollContainer", true, false):
		if control.is_visible_in_tree() and control.get_v_scroll_bar().max_value > control.get_v_scroll_bar().page:
			control.scroll_vertical += direction * 64
			return

func _popup() -> PopupMenu:
	for popup in popups:
		if is_instance_valid(popup) and popup.visible: return popup
	return null

func has_popup() -> bool:
	return _popup() != null

func _axis_direction(event: InputEventJoypadMotion) -> Vector2i:
	if event.axis == JOY_AXIS_LEFT_X: left_axis.x = event.axis_value
	else: left_axis.y = event.axis_value
	if left_axis.length() < 0.55: return Vector2i.ZERO
	if absf(left_axis.x) > absf(left_axis.y): return Vector2i(signi(int(left_axis.x * 100)), 0)
	return Vector2i(0, signi(int(left_axis.y * 100)))

func _controls_input(event: InputEvent) -> void:
	if not app._has_focus and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		app.controls_dialog.set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]:
		app._close_controls()
		app.controls_dialog.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var instructions: RichTextLabel = app.controls_dialog.find_child("ControlsText", true, false)
		if instructions != null:
			instructions.get_v_scroll_bar().value += -64 if event.button_index == JOY_BUTTON_DPAD_UP else 64
		app.controls_dialog.set_input_as_handled()
