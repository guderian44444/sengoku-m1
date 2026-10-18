extends SceneTree
const Battle=preload("res://core/battle.gd")
const Moves=preload("res://core/combat_moves.gd")
const Wire=preload("res://core/wire.gd")
const Equipment=preload("res://core/equipment.gd")
const Weapons=preload("res://core/weapon_catalog.gd")
const Encounter=preload("res://core/stage04_encounter.gd")
const View=preload("res://render/battle_view.gd")
var checks:=0
var captures:=[]
var heavy_captures:=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	assert(ok,label)

func arena(face: int,weapon: String="") -> Battle:
	var sim:=Battle.new();sim.reset_training("hideyoshi","dummy")
	sim.state.props.clear();sim.state.fighters.resize(1)
	var f:Dictionary=sim.state.fighters[0]
	f.x=700.0 if face==1 else 1600.0;f.y=500.0;f.face=face
	if weapon!="": Equipment.equip(f,Equipment.add(f,weapon))
	return sim

func inputs() -> void:
	for face in [-1,1]:
		for weapon in Weapons.ids_for("hideyoshi"):
			var sim:=arena(face,weapon)
			var f:Dictionary=sim.state.fighters[0]
			var start:float=f.x
			for offset in range(20,427,30):
				var enemy:=sim._make_fighter(1,"dummy",start+offset*face,500,10000)
				enemy.home_x=enemy.x;enemy.home_y=enemy.y
				sim.state.fighters.append(enemy)
			for tick in 100: sim.step([{"buttons":Battle.HEAVY}])
			check(is_equal_approx(f.x,start) and f.action=="charge","Charging stays planted")
			sim.step([{}])
			check(f.action=="charged","Release selects the new technique")
			var previous:float=f.x
			var jumps:=0;var swings:=0;var ticks:=0;var seen:={}
			while f.action=="charged" and ticks<100:
				sim.step([{}]);ticks+=1
				var hits:Array=sim.state.events.filter(func(e):return e.type=="weapon_swing")
				swings+=hits.size()
				if not is_equal_approx(f.x,previous):
					jumps+=1
					check(hits.size()==1 and is_equal_approx((f.x-previous)*face,1280.0/9),"Each cut teleports exactly one third of total distance")
					check(sim.state.effects.any(func(e):return e.type=="wind_wave" and e.get("kind","")=="hideyoshi"),"Each blink emits the existing wind effect")
					if weapon==Weapons.ids_for("hideyoshi")[0]: captures.append({"world":sim.state.duplicate(true),"label":"%s / cut %d / %.0f ms"%["LEFT" if face<0 else "RIGHT",jumps,ticks*1000.0/60],"start":start})
				previous=f.x
				for enemy in sim.state.fighters:
					if enemy.team==0 or enemy.damage_tick!=sim.state.tick: continue
					seen[enemy.id]=true
					check(enemy.action=="down" and not enemy.airborne_lock,"Swept path knocks every contacted enemy down")
				check(Wire.valid_snapshot(sim.state),"Every blink frame is network-valid")
			check(ticks==90 and f.action=="idle" and jumps==3 and swings==3,"Three cuts finish in exactly 1.5 seconds, for every weapon speed")
			check(is_equal_approx((f.x-start)*face,1280.0/3),"Total movement is half the original distance, one third of the logical screen")
			check(seen.size()==14,"No enemies are skipped between teleport endpoints")

func boundaries() -> void:
	for face in [-1,1]:
		for probe in [Vector3(-18.1,0,0),Vector3(-17.9,0,1),Vector3(140,144.4,1),Vector3(140,144.6,0),Vector3(140,-144.6,0),Vector3(1280.0/9+263.12-.01,0,1),Vector3(1280.0/9+263.12+.1,0,0)]:
			var sim:=arena(face);var f:Dictionary=sim.state.fighters[0]
			var enemy:=sim._make_fighter(1,"dummy",f.x+probe.x*face,f.y+probe.y,10000)
			sim.state.fighters.append(enemy)
			sim._begin(f,"charged");sim._combat_contact_v33(f,"contact")
			check((enemy.hp<10000)==bool(probe.z),"Swept corridor boundary "+str(probe))
		for role in ["shield_kira","shield_udono","tominaga","kira","udono"]:
			var sim:=arena(face);var f:Dictionary=sim.state.fighters[0]
			var enemy:=Encounter.spawn(sim,{"role":role,"kind":"boss" if role in ["tominaga","kira","udono"] else "soldier","x":f.x+face*140,"y":500},1)
			enemy.hp=10000;enemy.max_hp=10000;enemy.entering=false
			sim.state.fighters.append(enemy)
			sim._begin(f,"charged");sim._combat_contact_v33(f,"contact")
			check(enemy.hp<10000 and enemy.action=="down" and not enemy.airborne_lock,"Charged blink knocks down even shields and officers: "+role)
			check(is_equal_approx(f.x, (700.0 if face==1 else 1600.0)+face*1280.0/9),"Heavy bodies do not block the blink")
		var sim:=arena(face);var f:Dictionary=sim.state.fighters[0]
		f.x=sim._right_edge()-10 if face==1 else sim._left_edge()+10
		sim._begin(f,"charged")
		for cut in 3: sim._combat_contact_v33(f,"contact")
		check(is_equal_approx(f.x,sim._right_edge() if face==1 else sim._left_edge()),"Blink stays inside arena")
		var blocked:=arena(face);f=blocked.state.fighters[0]
		var start:float=f.x
		blocked.state.props=[{"id":999,"kind":"crate","x":start+face*120,"y":500,"hp":10000,"max_hp":10000,"width":64,"depth":40,"broken":false,"drop":""}]
		blocked._begin(f,"charged");blocked._combat_contact_v33(f,"contact")
		check(is_equal_approx((f.x-start)*face,68) and blocked.state.props[0].hp<10000,"Unbroken scenery stops blink and receives the cut")
	var coop:=Battle.new();coop.reset_campaign("normal",2,["hideyoshi","oichi"],1)
	coop.state.fighters=coop.state.fighters.filter(func(f):return f.team==0);coop.state.props.clear()
	var hero:Dictionary=coop.state.fighters[0];var ally:Dictionary=coop.state.fighters[1]
	hero.x=1000;ally.x=300;hero.y=500;hero.face=1
	coop._begin(hero,"charged")
	for cut in 3: coop._combat_contact_v33(hero,"contact")
	check(hero.x<=ally.x+860 and ally.hp==ally.max_hp,"Co-op spacing and friendly-fire protection remain")

func tap_heavy() -> void:
	for face in [-1,1]:
		var reference:=Battle.new();reference.reset_training("nobunaga","dummy")
		reference.state.props.clear()
		var nobunaga:Dictionary=reference.state.fighters[0]
		nobunaga.face=face;reference._begin(nobunaga,"heavy");reference._combat_contact_v33(nobunaga,"contact")
		var expected:Dictionary=reference.state.effects.filter(func(e):return e.get("combat_sword_wave",false))[0]
		for distance in [60.0,200.0,300.0,340.0]:
			var sim:=arena(face);var f:Dictionary=sim.state.fighters[0]
			var enemy:=sim._make_fighter(1,"dummy",f.x+face*distance,500,10000)
			enemy.home_x=enemy.x;enemy.home_y=enemy.y
			sim.state.fighters.append(enemy)
			sim.step([{"buttons":Battle.HEAVY}]);sim.step([{}])
			check(f.action=="heavy","One tap selects horizontal heavy")
			var releases:=0;var airborne:=false;var horizontal:=false
			for tick in 100:
				sim.step([{}])
				airborne=airborne or enemy.airborne_lock
				for e in sim.state.effects:
					if not e.get("combat_sword_wave",false): continue
					if e.life==e.max_life:
						releases+=1
						check(is_equal_approx(e.range_left,expected.range_left) and e.vx==expected.vx,"Heavy wave shares Nobunaga's range and speed")
						check(is_equal_approx((e.x-f.x)*face,(expected.x-nobunaga.x)*face),"Same forward release point as Nobunaga")
						var frame:Dictionary=Moves.spec(f).frames[Moves.frame_index(Moves.spec(f),Battle.combat_time_ms(f))]
						horizontal=absf(float(frame.weapon_angle)-90)<.01
					if distance==200 and e.max_life-e.life in [0,5,10]: heavy_captures.append({"world":sim.state.duplicate(true),"label":"%s / heavy wave / %d ticks"%["LEFT" if face<0 else "RIGHT",e.max_life-e.life],"start":float(f.x)})
				check(Wire.valid_snapshot(sim.state),"Heavy wave remains network-valid")
			check(releases==1 and horizontal,"Single horizontal cut releases one sword wave")
			check(airborne if distance<340 else not airborne,"New ranged heavy launches only inside its range: "+str(distance))
			check(f.action=="idle","Horizontal heavy finishes normally")

class Board extends View:
	var cards:=[]
	var heavy_board:=false
	func _draw() -> void:
		_fx.shared_player.begin_draw(self)
		draw_rect(Rect2(0,0,2560,1080),Color("303c39"))
		for index in cards.size():
			var card:Dictionary=cards[index];state=card.world
			var f:Dictionary=state.fighters[0]
			var at:=Vector2((index/3)*1280+(320 if f.face<0 else 100),(index%3)*360+300)
			var offset:=at-Vector2(card.start+((-350 if heavy_board else -1280.0/3) if f.face<0 else 0),500)
			for enemy in state.fighters:
				if enemy.team==0: continue
				_draw_dummy(enemy,Vector2(enemy.x,enemy.y)+offset)
			_draw_art_fighter(f,Vector2(f.x,f.y)+offset)
			for source in state.effects:
				if source.type!="wind_wave" and not source.get("combat_sword_wave",false): continue
				var e:Dictionary=source.duplicate(true);e.x+=offset.x;e.y+=offset.y
				_draw_effect(e)
			Typography.draw_label(self,Vector2((index/3)*1280+25,(index%3)*360+30),card.label,24,Color.WHITE)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	inputs();boundaries();tap_heavy()
	if "--capture" in OS.get_cmdline_user_args():
		var board:=Board.new();root.add_child(board);board.set_process(false);board.cards=captures
		root.size=Vector2i(2560,1080);root.content_scale_size=root.size
		board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../artifacts/hideyoshi-blink-20261018/native.png")==OK,"Native three-cut capture")
		board.cards=heavy_captures;board.heavy_board=true
		board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../artifacts/hideyoshi-blink-20261018/heavy-native.png")==OK,"Native horizontal heavy capture")
		board.free()
	print("HIDEYOSHI BLINK PASS: %d checks"%checks)
	quit()
