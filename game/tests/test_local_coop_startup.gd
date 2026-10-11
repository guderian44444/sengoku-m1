extends SceneTree

class VirtualPads:
	extends "res://main.gd"
	var pads: Array[int] = [3, 7]
	func _connected_pads() -> Array[int]: return pads
	func _stop_rumble() -> void: pass

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	assert("--local-coop" in OS.get_cmdline_user_args(), "Launch with the same flag as the co-op shortcut")
	var app := VirtualPads.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	assert(app.local_coop_requested and app.active and app.session == "local")
	assert(app.player_devices == [3, 7] and not app.menu.visible)
	assert(app.sim.state.fighters[0].kind == "nobunaga" and app.sim.state.fighters[1].kind == "oichi")
	app.audio.stop_speech()
	app.queue_free()
	await process_frame
	var unplugged := VirtualPads.new()
	unplugged.pads = []
	root.add_child(unplugged)
	await process_frame
	unplugged.set_physics_process(false)
	assert(not unplugged.active and unplugged.menu.visible)
	assert(unplugged.status.text.contains("兩支搖桿"))
	unplugged.queue_free()
	await process_frame
	print("LOCAL CO-OP STARTUP PASS: two assigned pads start; missing pads return to menu")
	quit()
