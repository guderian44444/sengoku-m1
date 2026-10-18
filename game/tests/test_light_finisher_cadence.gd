extends SceneTree
const Battle=preload("res://core/battle.gd")
const Equipment=preload("res://core/equipment.gd")
const Weapons=preload("res://core/weapon_catalog.gd")
const Wire=preload("res://core/wire.gd")
const View=preload("res://render/battle_view.gd")
var checks:=0
var captures:=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	assert(ok,label)

func arena(hero: String,weapon: String,face: int) -> Battle:
	var sim:=Battle.new();sim.reset_training(hero,"dummy")
	sim.state.props.clear();sim.state.fighters.resize(1)
	var f:Dictionary=sim.state.fighters[0]
	f.x=1100;f.y=500;f.face=face;f.combo=2;f.combo_tick=90
	Equipment.equip(f,Equipment.add(f,weapon))
	return sim

func cadence() -> void:
	for hero in Battle.PLAYABLE_HEROES:
		for weapon in Weapons.ids_for(hero):
			for face in [-1,1]:
				var sim:=arena(hero,weapon,face);var f:Dictionary=sim.state.fighters[0]
				sim.step([{"buttons":Battle.LIGHT}])
				check(f.action=="light" and f.combo==3,"Real input starts third cut")
				var attack_id:int=f.attack_id
				var contact_tick:=-1
				var next_tick:=-1
				for tick in 75:
					sim.step([{"buttons":Battle.LIGHT if tick%2==0 else 0,"dx":face}])
					var waves:Array=sim.state.effects.filter(func(e):return e.type=="slash" and e.get("finisher",false) and e.life==e.max_life)
					if not waves.is_empty() and contact_tick<0:
						contact_tick=sim.state.tick
						check(waves.size()==1 and f.light_recovery_ticks==30,"Third release emits one wave and starts a real 30-tick lock")
						check(waves[0].kind==sim._melee_weapon(f) and waves[0].radius==f.attack_reach,"Effect follows equipped weapon and actual range")
						if weapon==Weapons.default_for(hero) or (hero=="mitsuhide" and weapon=="spear_suyari"):
							captures.append({"world":sim.state.duplicate(true),"label":hero+" / "+weapon+" / "+("LEFT" if face<0 else "RIGHT")})
					if contact_tick>=0 and sim.state.tick-contact_tick<30:
						check(f.attack_id==attack_id and f.light_recovery_ticks==30-(sim.state.tick-contact_tick),"Mashing, movement and weapon speed cannot bypass 0.5 seconds")
					check(Wire.valid_snapshot(sim.state),"Finisher timer and wave survive network validation")
					if f.attack_id!=attack_id:
						next_tick=sim.state.tick
						check(f.action=="light" and f.combo==1,"Next accepted light restarts at first hit")
						break
				check(contact_tick>0 and next_tick-contact_tick in [30,31],"Next mash starts only after the fixed half-second interval")

func interruption_and_boundary() -> void:
	for hero in Battle.PLAYABLE_HEROES:
		for interruption in ["none","cancel","hurt","guard"]:
			var sim:=arena(hero,Weapons.default_for(hero),1);var f:Dictionary=sim.state.fighters[0]
			sim.step([{"buttons":Battle.LIGHT}])
			sim.step([{}]);sim.step([{"buttons":Battle.LIGHT}])
			for tick in 30:
				if f.light_recovery_ticks>0: break
				sim.step([{}])
			check(f.light_recovery_ticks==30,"Actual third contact starts recovery even on a miss")
			var attack_id:int=f.attack_id
			if interruption=="cancel": sim.cancel_input()
			if interruption=="hurt":
				f.invuln=0
				check(sim._damage(f,1,0,false,true,false,false,f.x+100,f.y,"light"),"Finisher remains vulnerable")
			for tick in range(1,30):
				var buttons:int=Battle.GUARD if interruption=="guard" and tick<27 else (Battle.LIGHT if tick%2==0 else 0)
				sim.step([{"buttons":buttons,"dx":1}])
				check(f.attack_id==attack_id,"No light during first 29 frames after interruption")
			sim.step([{"buttons":Battle.LIGHT}])
			check(f.attack_id==attack_id+1 and f.action=="light" and f.combo==1,"A fresh press is accepted exactly 30 frames after release")
		var stopped:=arena(hero,Weapons.default_for(hero),1);var f:Dictionary=stopped.state.fighters[0]
		stopped.step([{"buttons":Battle.LIGHT}]);stopped.step([{}]);stopped.step([{"buttons":Battle.LIGHT}])
		var attack_id:int=f.attack_id
		for tick in 80: stopped.step([{}])
		check(f.action=="idle" and f.attack_id==attack_id,"An early buffered fourth press is discarded instead of firing later")
	var coop:=Battle.new();coop.reset_campaign("normal",2,["nobunaga","hideyoshi"],1)
	coop.state.fighters=coop.state.fighters.filter(func(f):return f.team==0);coop.state.props.clear()
	var first:Dictionary=coop.state.fighters[0];var second:Dictionary=coop.state.fighters[1]
	first.combo=3;coop._begin(first,"light");coop._combat_contact_v33(first,"contact_launch")
	coop.step([{"buttons":Battle.LIGHT},{"buttons":Battle.LIGHT}])
	check(first.light_recovery_ticks==29 and second.action=="light" and second.combo==1,"Each player's cooldown is independent")
	for value in [-1,31,1.5]:
		first.light_recovery_ticks=value
		check(not Wire.valid_snapshot(coop.state),"Reject invalid cooldown at the network boundary")
	first.light_recovery_ticks=0
	check(Wire.valid_snapshot(coop.state),"Valid cooldown snapshot remains accepted")

class Board extends View:
	var cards:=[]
	func _draw() -> void:
		_fx.shared_player.begin_draw(self)
		draw_rect(Rect2(0,0,1600,2800),Color("303c39"))
		for index in cards.size():
			state=cards[index].world
			var f:Dictionary=state.fighters[0]
			var origin:=Vector2((index%2)*800+(480 if f.face<0 else 220),(index/2)*350+275)
			_draw_art_fighter(f,origin)
			for source in state.effects:
				if not source.get("finisher",false): continue
				var effect:Dictionary=source.duplicate(true)
				effect.x+=origin.x-f.x;effect.y+=origin.y-f.y
				_draw_effect(effect)
			Typography.draw_label(self,Vector2((index%2)*800+20,(index/2)*350+30),cards[index].label,20,Color.WHITE)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	cadence();interruption_and_boundary()
	if "--capture" in OS.get_cmdline_user_args():
		var board:=Board.new();root.add_child(board);board.set_process(false);board.cards=captures
		check(board._fx.configured,"Existing VFX catalog loads")
		root.size=Vector2i(1600,ceili(captures.size()/2.0)*350);root.content_scale_size=root.size
		board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../artifacts/light-finisher-20261018/native.png")==OK,"Native finisher capture")
		board.free()
	print("LIGHT FINISHER CADENCE PASS: %d checks"%checks)
	quit()
