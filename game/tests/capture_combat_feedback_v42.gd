extends SceneTree
const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Encounter = preload("res://core/stage04_encounter.gd")
const Equipment = preload("res://core/equipment.gd")
var folder := "res://../artifacts/nobunaga-combat-20261018/captures/"

class Board extends View:
	var cards := []
	func _process(_delta: float) -> void: pass
	func _draw() -> void:
		_fx.shared_player.begin_draw(self)
		draw_rect(Rect2(0,0,1920,1200),Color("273337"))
		for i in cards.size():
			var card: Dictionary=cards[i]
			state=card.world
			var hero: Dictionary=state.fighters[0]
			var origin:=Vector2(i%4*480+240,i/4*400+335)
			camera_x=float(hero.x)-origin.x
			draw_line(Vector2(i%4*480,origin.y),Vector2(i%4*480+480,origin.y),Color("536365"))
			if card.get("enemy",false):
				_draw_enemy_art(state.fighters[1],origin)
			else:
				_draw_art_fighter(hero,origin)
				for source in state.effects:
					var effect: Dictionary=source.duplicate(true)
					effect.y+=origin.y-float(hero.y)
					_draw_effect(effect)
			draw_string(ThemeDB.fallback_font,Vector2(i%4*480+15,i/4*400+28),card.label,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1920,1200);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view:=Board.new();viewport.add_child(view);view._fx.muted=true
	for page in ["light","heavy","held","udono"]:
		view.cards=[]
		if page=="udono":
			for action in Encounter.Data.actors().udono:
				var sim:=Battle.new();sim.reset_campaign("normal",1,["nobunaga"],4)
				var enemy:=Encounter.spawn(sim,{"role":"udono","kind":"boss","x":600,"y":500},1)
				enemy.action=action;enemy.action_tick=Encounter.Data.attack_timing(enemy)[0] if Encounter.Data.HITS.has(action) else 0
				enemy.face=1
				sim.state.fighters=[sim.state.fighters[0],enemy]
				view.cards.append({"world":sim.state.duplicate(true),"label":action,"enemy":true})
		elif page=="held":
			for role in ["spear_kira","spear_udono","shield_kira","shield_udono","archer_kira","gunner"]:
				for action in (["idle","spear_butt"] if role in Encounter.Data.SHIELD_ROLES else ["idle","grabbed"]):
					var sim:=Battle.new();sim.reset_campaign("normal",1,["nobunaga"],4)
					var enemy:=Encounter.spawn(sim,{"role":role,"kind":"gunner" if role=="gunner" else ("archer" if role=="archer_kira" else "soldier"),"x":600,"y":500},1)
					enemy.face=1;enemy.action=action;enemy.action_tick=60;enemy.held_by=sim.state.fighters[0].id if action=="grabbed" else 0
					sim.state.fighters=[sim.state.fighters[0],enemy];view.cards.append({"world":sim.state.duplicate(true),"label":role+" / "+action,"enemy":true})
		else:
			for action in (["light","light","light"] if page=="light" else ["dash_heavy","heavy","air_heavy"]):
				var combo:=view.cards.size()/4+1
				for column in 4:
					var sim:=Battle.new();sim.reset_training("nobunaga","dummy");sim.state.props.clear()
					var hero: Dictionary=sim.state.fighters[0];hero.x=600;hero.y=500;hero.face=1 if column<2 else -1
					hero.combo=combo;sim._begin(hero,action)
					var desired: int=([8,9,7][combo-1] if page=="light" else (7 if action=="dash_heavy" else (9 if action=="heavy" else 0)))+(column%2)
					for tick in 100:
						hero.action_tick=tick
						if view._fighter_animation(hero).frame>=desired: break
					if action=="heavy":sim._combat_sword_wave_v33(hero)
					if action=="air_heavy":hero.z=90;sim._combat_contact_v33(hero,"contact")
					view.cards.append({"world":sim.state.duplicate(true),"label":action+" %d / face %d / pose %d"%[combo,hero.face,desired]})
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(folder+page+".png")==OK)
	viewport.free()
	print("COMBAT FEEDBACK CAPTURE PASS")
	quit()
