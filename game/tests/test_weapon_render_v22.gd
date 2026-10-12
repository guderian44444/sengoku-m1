extends SceneTree

const Renderer = preload("res://render/weapon_renderer.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

class SampleCanvas extends Node2D:
	var renderer: RefCounted
	var ids: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,1080),Color("273237"))
		var index := 0
		for id in ids:
			var row: int = index / 4
			var column: int = index % 4
			var hero: String = {"sword":"nobunaga","spear":"tadakatsu","bow":"oichi"}[Weapons.ITEMS[id].family]
			var frame := {"layered_weapon":true,"weapon_hand":Vector2.ZERO,"weapon_angle":0.0,"body_height":155.0}
			var origin := Vector2(100 + column * 320,300 + row * 530)
			renderer.draw_weapon(self,{"kind":hero,"weapon_id":id},frame,origin,130,1,0,Color.WHITE,false)
			renderer.draw_weapon(self,{"kind":hero,"weapon_id":id},frame,origin + Vector2(100,0),130,-1,0,Color.WHITE,false)
			renderer.draw_drop(self,{"weapon_id":id},Vector2(origin.x + 50,455 + row * 530),0)
			index += 1

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var renderer := Renderer.new()
	check(renderer.textures.size() == Weapons.ITEMS.size() and renderer.items.size() == Weapons.ITEMS.size(),"Every catalog entry loads its actual transparent sprite")
	for id in Weapons.ITEMS:
		var spec: Dictionary = renderer.items[id]
		check(spec.length >= 600,"Weapon native length >=600: " + id)
		var hero: String = {"sword":"nobunaga","spear":"tadakatsu","bow":"oichi"}[Weapons.ITEMS[id].family]
		var fighter := {"kind":hero,"weapon_id":id}
		var frame := {"layered_weapon":true,"weapon_hand":Vector2(42,-270),"weapon_angle":37.0,"body_height":620.0}
		var before := var_to_bytes(frame)
		var pose := renderer.geometry(fighter,frame,155)
		check(pose.id == id and pose.hand.is_equal_approx(Vector2(10.5,-67.5)),"Grip follows source frame scale: " + id)
		check(is_equal_approx(pose.angle,deg_to_rad(37)) and pose.scale > 0,"Weapon orientation uses authored degrees: " + id)
		var large := renderer.geometry(fighter,frame,310)
		check(large.hand.is_equal_approx(pose.hand * 2) and is_equal_approx(large.scale,pose.scale * 2),"Character and weapon share display scaling: " + id)
		check(var_to_bytes(frame) == before,"Renderer does not mutate authoritative pose data: " + id)
		if Weapons.ITEMS[id].family == "spear":
			var grounded := frame.duplicate()
			grounded.weapon_grounded = true
			grounded.weapon_angle = 0
			var slam := renderer.geometry(fighter,grounded,155)
			check(is_zero_approx(slam.bottom.y),"Slam butt lands at ground without moving authored palm: " + id)
			check(slam.hand.is_equal_approx(pose.hand) and is_equal_approx(slam.scale,pose.scale),"Grounded spear slides grip, preserves hand and full weapon length: " + id)
		elif Weapons.ITEMS[id].family == "sword":
			var previous := frame.duplicate()
			previous.weapon_angle = -30
			previous.weapon_hand = Vector2(0,-300)
			var before_pose := renderer.geometry(fighter,previous,155)
			var trail := renderer.sweep_trail(fighter,frame,previous,155)
			check(trail.size() == 26 and trail[0].is_equal_approx(before_pose.top) and trail[12].is_equal_approx(pose.top),"Blade sweep connects actual previous and current equipped blade tips: " + id)
		frame.layered_weapon = false
		check(renderer.geometry(fighter,frame,155).is_empty(),"Legacy baked-weapon frame cannot acquire a double weapon: " + id)
		frame.layered_weapon = true
		frame.weapon_visible = false
		check(renderer.geometry(fighter,frame,155).is_empty(),"Hidden stowed pose respects authored visibility: " + id)
	check(Renderer.equipped_id({"kind":"tadakatsu"}) == "spear_tonbokiri","Tadakatsu starts with his representative Tonbokiri")
	var tonbo_spec: Dictionary = renderer.items.spear_tonbokiri
	check(is_equal_approx(float(tonbo_spec.world_length),223.7) and tonbo_spec.proportions_design_cm.shaft == 180,"Tonbokiri follows the requested 180 cm shaft plus 43.7 cm blade design")
	var tonbo_pose := renderer.geometry({"kind":"tadakatsu","weapon_id":"spear_tonbokiri"},{"layered_weapon":true,"body_height":155},155)
	check(is_equal_approx(tonbo_pose.scale * float(tonbo_spec.length),223.7),"Per-weapon length overrides the long-spear family default")
	var awase_spec: Dictionary = renderer.items.bow_awase_yumi
	var awase_pose := renderer.geometry({"kind":"oichi","weapon_id":"bow_awase_yumi"},{"layered_weapon":true,"body_height":148},148)
	check(is_equal_approx(float(awase_spec.world_length),172.0) and is_equal_approx(float(awase_spec.proportions_cm.total),231.2),"Awase museum length stays separate from normalized game display size")
	check(is_equal_approx(awase_pose.scale * float(awase_spec.length),172.0) and 172.0 / 148.0 >= 1.1 and 172.0 / 148.0 <= 1.2,"Awase display is 1.16 times Oichi reference standing height")
	for old_bow in ["bow_azusa","bow_bamboo","bow_black_lacquer","bow_red_lacquer","bow_shigeto"]:
		check(not renderer.items[old_bow].has("world_length"),"Existing bow keeps its original family scale: " + old_bow)
	check(Renderer.equipped_id({"kind":"oichi","weapon_id":"sword_heshikiri"}) == "bow_azusa","Malformed visual-only fighter safely falls back to own-family weapon")
	var fighter := {"kind":"nobunaga","action":"heavy","heavy_combo":1,"weapon_id":"sword_heshikiri"}
	var style := View.strike_accent(fighter,{"source":"v22","tick":14})
	check(is_equal_approx(View.strike_radius(fighter,style,155) + 9 + style.path[1] * .5,Battle.nobunaga_heavy_reach(1) + 22),"Heavy ribbon follows upgraded sword hit reach")
	if DisplayServer.get_name() != "headless":
		root.content_scale_size = Vector2i(1280,1080)
		root.size = Vector2i(1280,1080)
		var canvas := SampleCanvas.new()
		canvas.renderer = renderer
		root.add_child(canvas)
		var output := ProjectSettings.globalize_path("res://../artifacts/native-v22")
		DirAccess.make_dir_recursive_absolute(output)
		for hero in ["nobunaga","tadakatsu","oichi"]:
			var ids := Weapons.ids_for(hero)
			for page in range(ceili(float(ids.size()) / 8.0)):
				canvas.ids = ids.slice(page * 8,(page + 1) * 8)
				canvas.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("weapons-runtime-"+hero+"-"+str(page+1)+".png")) == OK,"Save paginated native weapons, mirrors, bowstrings and item labels without clipping")
		canvas.queue_free()
		await process_frame
	print("WEAPON RENDER V22 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
