extends SceneTree

const Main = preload("res://main.gd")
const Profiles = preload("res://core/save_profile.gd")
var checks := 0
var failures := 0

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	var path := "user://exit-save-%d.json" % Time.get_ticks_usec()
	app.profiles = Profiles.new(path)
	app._open_selection(true)
	app.partner_heroes.selected = 0
	app._start_local_coop()
	app.sim.state.fighters[0].score = 1234
	app.sim.state.fighters[1].score = 5678
	app.sim.state.fighters[0].max_hp_bonus = 5
	app.sim.state.fighters[0].owned_weapons.append("sword_heshikiri")
	app.sim.state.fighters[0].weapon_id = "sword_heshikiri"
	app.sim.state.stage.checkpoint = 1
	app._leave_to_menu()
	check(app.active and app.menu_screen == "confirm", "Return to menu still requires confirmation")
	app._cancel_confirmation()
	check(app.active and not FileAccess.file_exists(path), "Cancelling keeps the current battle")
	app._leave_to_menu()
	app._accept_confirmation()
	var saved := Profiles.new(path)
	check(not app.active and app.menu_screen == "main", "Confirmed return completes after saving")
	check(saved.character(0,"nobunaga").score == 1234 and saved.character(1,"nobunaga").score == 5678, "Both players persist independently without manual save")
	check(saved.character(0,"nobunaga").max_hp_bonus == 5 and saved.character(0,"nobunaga").weapon_id == "sword_heshikiri", "Permanent character stats and collected gear persist")
	check(saved.data.chapter == 1 and not saved.data.has("stage") and not saved.character(0,"nobunaga").has("hp"), "Only major chapter and permanent progress are saved")
	app._start_solo()
	check(app.sim.state.fighters[0].score == 1234 and app.sim.state.stage.checkpoint == 0, "Next sortie restores character progress at chapter start")
	app.sim.state.fighters[0].score = 9000
	app.profiles.blocked = true
	app.profiles.warning = "測試：存檔不可寫入。"
	for action in [app._leave_to_menu, app._start_solo, app._start_local_coop, app._start_training, app._start_art_demo, app._host, app._join, app._request_quit]:
		action.call()
		app._accept_confirmation()
		check(app.active and app.session == "solo" and app.sim.state.fighters[0].score == 9000, "Failed save preserves the active character: " + str(action))
		check(app.paused and app.menu_screen == "pause" and app.status.text.contains("保存失敗"), "Failed save stays open and shows the reason: " + str(action))
	check(Profiles.new(path).character(0,"nobunaga").score == 1234, "Failed save retains the previous file")
	app.profiles.blocked = false
	app.profiles.warning = ""
	app._leave_to_menu()
	app._accept_confirmation()
	check(not app.active and Profiles.new(path).character(0,"nobunaga").score == 9000, "Retry saves the latest progress before leaving")
	app._start_training()
	app.sim.state.fighters[0].score = 99999
	app._leave_to_menu()
	app._accept_confirmation()
	check(Profiles.new(path).character(0,"nobunaga").score == 9000, "Leaving training does not overwrite campaign progress")
	app._start_solo()
	app.sim.state.fighters[0].score = 10001
	app.sim.state.phase = "won"
	root.close_requested.emit()
	check(app.active and app.menu_screen == "confirm", "Window close uses the same confirmed exit")
	app._cancel_confirmation()
	check(Profiles.new(path).character(0,"nobunaga").score == 9000, "Cancelled window close keeps playing")
	root.close_requested.emit()
	app._accept_confirmation()
	saved = Profiles.new(path)
	check(saved.character(0,"nobunaga").score == 10001 and saved.data.completed_chapter == 1 and saved.data.chapter == 2, "Confirmed app exit flushes the latest character and chapter completion")
	app.free()
	print("EXIT SAVE V27 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
