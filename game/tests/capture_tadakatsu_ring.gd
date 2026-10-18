extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0

class Board extends View:
	var pose: Dictionary = {}
	func _process(_delta: float) -> void: pass
	func _draw() -> void:
		if _fx.configured: _fx.shared_player.begin_draw(self)
		var fighter: Dictionary = pose.fighter
		var area: Dictionary = Battle.tadakatsu_charged_area(fighter)
		var origin := Vector2(900, 560)
		draw_rect(Rect2(0, 0, 1800, 1000), Color("1c2428"))
		draw_line(Vector2(40, origin.y), Vector2(1760, origin.y), Color("3d4a46"), 2)
		draw_line(Vector2(origin.x, 40), Vector2(origin.x, 960), Color("3d4a46"), 1)
		state = {"fighters": [fighter], "tick": pose.tick, "stage": {}}
		_draw_art_fighter(fighter, origin)
		var ellipse := PackedVector2Array()
		for step in 97:
			var angle := TAU * step / 96.0
			ellipse.append(origin + Vector2(cos(angle) * float(area.reach), sin(angle) * float(area.depth)))
		draw_polyline(ellipse, Color("e2b15a"), 2.0, true)
		for mark in pose.marks:
			var at: Vector2 = origin + Vector2(float(mark.x), float(mark.y))
			draw_circle(at, 7, Color("7dcea0") if mark.hit else Color("e07a6a"))
		draw_string(ThemeDB.fallback_font, Vector2(36, 42), pose.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f4efe2"))
		draw_string(ThemeDB.fallback_font, Vector2(36, 78), "金圈＝命中範圍　前 %.0f　縱深 %.0f　後 %.0f" % [area.reach, area.depth, area.behind], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e2b15a"))

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok, label)

func arena(weapon: String = "") -> Battle:
	var battle := Battle.new()
	battle.reset_training("tadakatsu", "dummy")
	battle.state.props.clear()
	var player: Dictionary = battle.state.fighters[0]
	player.x = 1200.0
	player.y = 500.0
	if not weapon.is_empty(): Equipment.equip(player, Equipment.add(player, weapon))
	return battle

func boundaries() -> void:
	var battle := arena()
	var player: Dictionary = battle.state.fighters[0]
	var area: Dictionary = Battle.tadakatsu_charged_area(player)
	check(is_equal_approx(area.reach, 185.0 * 1.15 * 1.48 * 2.0 * .7), "Practice spear ring shrinks 30 percent")
	check(is_equal_approx(area.depth, area.reach * Battle.TADAKATSU_RING_OUTER_Y / Battle.TADAKATSU_RING_OUTER_X), "Ring depth matches the sword-ring artwork")
	check(is_equal_approx(area.behind, area.reach), "The ring reaches equally behind the spear")
	var tonbo := arena("spear_tonbokiri")
	var longer: Dictionary = Battle.tadakatsu_charged_area(tonbo.state.fighters[0])
	check(is_equal_approx(longer.reach - area.reach, 24.0 * 1.48 * 2.0 * .7), "Tonbokiri lengthens the ring with the same scale")
	for face in [-1, 1]:
		for probe in [Vector2(area.reach - 1.0, 0), Vector2(area.reach + 8.0, 0), Vector2(40, area.depth - 1.0), Vector2(40, area.depth + 8.0), Vector2(-area.behind + 1.0, 0), Vector2(-area.behind - 8.0, 0)]:
			var trial := arena()
			var actor: Dictionary = trial.state.fighters[0]
			var target: Dictionary = trial.state.fighters[1]
			actor.face = face
			target.hp = 10000
			target.max_hp = 10000
			target.x = actor.x + probe.x * face
			target.y = actor.y + probe.y
			trial._begin(actor, "charged")
			trial._combat_contact_v33(actor, "contact")
			var inside: bool = absf(probe.x) <= area.reach - 0.5 and absf(probe.y) <= area.depth - 0.5
			check((target.hp < 10000) == inside, "Ring boundary %s face %d" % [probe, face])
			check(trial.state.effects.all(func(effect): return effect.type != "slash"), "The ring replaces the small slash")
			check(is_equal_approx(actor.attack_reach, area.reach), "Recorded reach is the ring radius")
	var ally := arena()
	ally.state.fighters[0].face = 1
	var friend := ally._make_fighter(0, "nobunaga", ally.state.fighters[0].x + 80, ally.state.fighters[0].y, 100)
	ally.state.fighters.append(friend)
	ally._begin(ally.state.fighters[0], "charged")
	ally._combat_contact_v33(ally.state.fighters[0], "contact")
	check(friend.hp == 100, "The ring does not hit the other player")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	boundaries()
	if DisplayServer.get_name() == "headless":
		print("TADAKATSU RING PASS: %d checks" % checks)
		quit()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := Board.new()
	viewport.add_child(view)
	view._fx.muted = true
	check(view._fx.configured and view._fx.shared_player.textures.has("blade_ring"), "Authored sword ring loads")
	var folder := "res://../artifacts/tadakatsu-charge-ring"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var shots := [
		{"file": "01-gather.png", "weapon": "", "tick": 6, "face": 1, "label": "蓄力放出・劍氣成形（常備直槍・右）"},
		{"file": "02-first-hit.png", "weapon": "", "tick": 15, "face": 1, "label": "第一擊・環形劍氣展開（常備直槍・右）"},
		{"file": "03-second-hit.png", "weapon": "", "tick": 54, "face": 1, "label": "第二擊・環形劍氣再亮（常備直槍・右）"},
		{"file": "04-tonbokiri-left.png", "weapon": "spear_tonbokiri", "tick": 15, "face": -1, "label": "第一擊・蜻蛉切加長（左）"},
	]
	for shot in shots:
		var battle := arena(shot.weapon)
		var player: Dictionary = battle.state.fighters[0]
		player.face = shot.face
		battle._begin(player, "charged")
		player.action_tick = shot.tick
		var area: Dictionary = Battle.tadakatsu_charged_area(player)
		var marks := []
		for probe in [Vector2(area.reach - 30, 0), Vector2(area.reach + 36, 0), Vector2(0, area.depth - 16), Vector2(0, -(area.depth + 28)), Vector2(-(area.reach - 30), 0)]:
			marks.append({"x": probe.x * shot.face, "y": probe.y, "hit": absf(probe.x) < area.reach and absf(probe.y) < area.depth})
		view.pose = {"fighter": player, "tick": battle.state.tick, "label": shot.label, "marks": marks}
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(folder + "/" + shot.file) == OK, "Saved " + shot.file)
	viewport.free()
	print("TADAKATSU RING PASS: %d checks" % checks)
	quit()
