extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

class CaptureView extends View:
	var cards: Array = []
	var rotations: Array = []
	var body_origins: Array = []
	var title := ""
	func _draw_art_frame(frame: Dictionary, origin: Vector2, height: float, face: float = 1.0, rotation: float = 0.0, tint: Color = Color.WHITE, base_height: float = 0.0) -> void:
		rotations.append(rotation)
		body_origins.append(origin)
		super._draw_art_frame(frame,origin,height,face,rotation,tint,base_height)
	func _draw_frame_shadow(frame: Dictionary, projection: Transform2D, height: float, face: float = 1.0, rotation: float = 0.0, alpha: float = .26, base_height: float = 0.0) -> void:
		rotations.append(rotation)
		super._draw_frame_shadow(frame,projection,height,face,rotation,alpha,base_height)
	func _draw() -> void:
		rotations.clear()
		body_origins.clear()
		draw_rect(Rect2(0,0,1920,900),Color("303c39"))
		Typography.draw_label(self,Vector2(24,38),title,26,Typography.PAPER)
		for index in range(cards.size()):
			var at := Vector2(320+(index%3)*640,390+(index/3)*420)
			draw_line(at-Vector2(270,0),at+Vector2(270,0),Color("637067"),1)
			_shadow_pass = true
			_draw_enemy_art(cards[index],at)
			_shadow_pass = false
			_draw_enemy_art(cards[index],at)
			Typography.draw_label(self,at+Vector2(-240,46),str(cards[index].qa_label),22,Typography.PAPER,480,HORIZONTAL_ALIGNMENT_CENTER)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var view := CaptureView.new()
	root.add_child(view)
	for variant in ["cross_spear","short_yari","long_yari"]:
		var battle := Battle.new()
		battle.reset_training("hideyoshi","boss")
		var boss: Dictionary = battle.state.fighters[1]
		boss.faction = "oda"
		boss.boss_variant = variant
		boss.stage_boss = variant == "long_yari"
		var key: String = "oda:"+variant+":reactions"
		check(view._art.enemy_clips.has(key) and view._art.enemy_clips[key].size() == 6,"Six dedicated reaction drawings load: "+variant)
		var frames: Array = view._art.enemy_clips[key]
		check(frames[4].region.size.y/float(frames[4].body_height) < .36,"Defeated body is genuinely horizontal, not an upright image")
		check(frames.all(func(f): return f.body_height == frames[0].body_height),"Crouch and corpse keep a fixed anatomical scale")
		for face in [-1,1]:
			boss.face = face
			for action in ["hurt","stunned","grabbed","pulled","frozen","down","dead","defeated","thrown","launched","recovering"]:
				boss.action = action
				boss.action_tick = 10
				boss.freeze = 0
				var before := var_to_bytes(boss)
				var sample: Dictionary = view._fighter_animation(boss)
				check(sample.sheet == "enemy_clip:"+key and sample.get("genuine_reaction",false),action+" uses a drawn reaction on both facings")
				check(var_to_bytes(boss) == before,"Sampling preserves authoritative fighter data")
		boss.action = "hurt"
		boss.action_tick = 10
		var frozen: Dictionary = view._fighter_animation(boss)
		boss.freeze = 40
		boss.action = "frozen"
		check(view._fighter_animation(boss) == frozen,"Freeze holds the dedicated impact pose")
		boss.freeze = 0
		boss.action = "down"
		for tick in [0,8,18,90]:
			boss.action_tick = tick
			check(view._fighter_animation(boss).cell == (2 if tick < 8 else (3 if tick < 18 else 4)),"Knockdown proceeds into a stable prone hold")
		boss.down_from_air = true
		boss.action_tick = 0
		check(view._fighter_animation(boss).cell == 4,"Air landing continues prone instead of replaying standing collapse")
		boss.down_from_air = false
		boss.action = "recovering"
		for pair in [[0,4],[8,3],[18,5],[30,0]]:
			boss.action_tick = pair[0]
			var sample: Dictionary = view._fighter_animation(boss)
			check(sample.cell == pair[1] and sample.sheet.ends_with(":poses" if pair[0] >= 26 else ":reactions") and sample.get("genuine_reaction",false),"Recovery proceeds from ground into rising and finally standing without synthetic rotation")
		battle._begin(boss,"idle")
		battle._damage(boss,10000,battle.state.fighters[0].id,true,true,true)
		var seen := []
		var previous := -1
		var death_ticks: int = boss.death_ticks
		for tick in range(death_ticks+1):
			var sample: Dictionary = view._fighter_animation(boss)
			check(sample.duration == death_ticks and sample.cell >= previous and Wire.valid_snapshot(battle.get_state()),"Dedicated collapse follows selected death voice with valid snapshots")
			previous = sample.cell
			if sample.cell not in seen: seen.append(sample.cell)
			if tick < death_ticks: battle._tick_motion(boss)
		check(seen == [0,1,2,3,4] and previous == 4,"All five collapse poses end in a flat corpse")
	if "--capture" in OS.get_cmdline_user_args():
		var output := ProjectSettings.globalize_path("res://../artifacts/boss-reactions-v31/bosses")
		DirAccess.make_dir_recursive_absolute(output)
		root.size = Vector2i(1920,900)
		root.content_scale_size = Vector2i(1920,900)
		for variant in ["cross_spear","short_yari","long_yari"]:
			for face in [-1,1]:
				view.cards.clear()
				view.title = "第二關頭目專用反應  "+variant+"  /  "+("左向" if face < 0 else "右向")
				for pair in [["hurt",0,"受傷後仰"],["hurt",10,"受傷彎身"],["defeated",40,"跪倒"],["defeated",70,"跌落"],["dead",100,"伏地"],["recovering",18,"起身"]]:
					var boss: Dictionary = Battle.new()._make_fighter(1,"boss",900,500,300)
					boss.id = 600+view.cards.size()
					boss.faction = "oda"
					boss.boss_variant = variant
					boss.stage_boss = true
					boss.render_scale = 1.3
					boss.face = face
					boss.action = pair[0]
					boss.action_tick = pair[1]
					boss.death_ticks = 100
					boss.qa_label = pair[2]
					boss.hp = 0 if pair[0] in ["dead","defeated"] else 300
					view.cards.append(boss)
				var before := var_to_bytes(view.cards)
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(view.rotations.size() >= 12 and view.rotations.all(func(r):return is_zero_approx(r)),"Native body and shadow draw without rotating a pose")
				for index in range(view.body_origins.size()):
					check(view.body_origins[index].is_equal_approx(Vector2(320+(index%3)*640,390+(index/3)*420)),"Native drawn reaction stays at its body contact root")
				check(var_to_bytes(view.cards) == before,"Native reaction capture preserves fighter state")
				check(root.get_texture().get_image().save_png(output.path_join(variant+("-left.png" if face < 0 else "-right.png"))) == OK,"Dedicated native reaction board saved")
	view.free()
	print("BOSS REACTIONS V31 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
