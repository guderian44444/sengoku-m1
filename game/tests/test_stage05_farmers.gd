extends SceneTree
const Battle = preload("res://core/battle.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Data = preload("res://core/stage05_data.gd")
const Wire = preload("res://core/wire.gd")

func fixture(role: String, face: int) -> Battle:
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],5)
	var hero: Dictionary=sim.state.fighters[0]
	hero.x=600+face*100;hero.y=480
	sim.state.fighters.append(S5.spawn(sim,role,600,480))
	sim.state.props.clear();sim.state.ikki.pending.clear()
	return sim

func _initialize() -> void:
	var encounter := Battle.new()
	encounter.reset_campaign("normal",1,["nobunaga"],5)
	var roles: Array=encounter.state.ikki.pending.map(func(u):return u.role)
	for role in Data.FARMERS: assert(role in roles,"Each farmer weapon participates in ordinary banner reinforcements")
	for role in ["sickle_farmer","hunting_bow_farmer"]:
		assert(Data.actors()[role].size()==12)
		assert(Data.duration(role,"walk")==1000 and Data.actors()[role].walk.frames.size()==6)
		for face in [-1,1]:
			var sim := fixture(role,face)
			var farmer: Dictionary=sim.state.fighters[1]
			var hero: Dictionary=sim.state.fighters[0]
			assert(farmer.max_hp==53 and Data.height(role)==146)
			var action: String="s05_sickle_farmer_attack" if role=="sickle_farmer" else "s05_hunting_bow_farmer_shot"
			S5.start(sim,farmer,action,hero)
			var before: int=hero.hp
			var release: int=16 if role=="sickle_farmer" else 29
			for tick in range(1,release):
				farmer.action_tick=tick;S5.attack(sim,farmer)
				assert(hero.hp==before and sim.state.effects.is_empty(),"Windup does not damage or create an arrow")
			farmer.action_tick=release;S5.attack(sim,farmer)
			S5.attack(sim,farmer) # A duplicate callback cannot repeat the release.
			if role=="sickle_farmer":
				assert(hero.hp==before-7)
				for tick in range(17,23):
					hero.invuln=0;farmer.action_tick=tick;S5.attack(sim,farmer)
				assert(hero.hp==before-7,"One hit per target across the active window")
				assert(sim.state.events.filter(func(e):return e.type=="weapon_swing").size()==1)
			else:
				assert(hero.hp==before and sim.state.effects.filter(func(e):return e.type=="projectile").size()==1,"Bow has no melee damage and emits one projectile")
				var arrow: Dictionary=sim.state.effects[0]
				assert(arrow.s05_arrow and arrow.vx*face>0 and is_equal_approx(arrow.z,592.0*146/810))
				assert(is_equal_approx(arrow.x,farmer.x+face*406.0*146/810),"Collision starts at the painted arrow tip")
				assert(arrow.arcing and arrow.origin_x==arrow.x and arrow.start_z==arrow.z and arrow.target_x==hero.x)
				assert(sim.state.events.filter(func(e):return e.type=="bow_release").size()==1)
				sim._tick_effects()
				assert(arrow.z>arrow.start_z and hero.hp==before,"Arrow rises before landing")
				for tick in int(arrow.flight_ticks): sim._tick_effects()
				assert(hero.hp==before-7,"The arcing arrow lands in both facing directions")
				assert(sim.state.effects.filter(func(e):return e.get("s05_arrow",false)).is_empty(),"Arrow is consumed on landing")
			assert(Wire.valid_snapshot(sim.state),"New roles, action IDs and arrow data travel through the wire")
	# A cancelled draw must not release; the hurt reaction owns the subsequent ticks.
	var sim := fixture("hunting_bow_farmer",1)
	var farmer: Dictionary=sim.state.fighters[1]
	S5.start(sim,farmer,"s05_hunting_bow_farmer_shot",sim.state.fighters[0])
	farmer.action_tick=28;sim._begin(farmer,"hurt");farmer.action_tick=29
	assert(not S5.attack(sim,farmer) and sim.state.effects.is_empty())
	# Late entry into the visible sickle arc still hits inside the 260–360 ms window.
	sim=fixture("sickle_farmer",1);farmer=sim.state.fighters[1]
	var hero: Dictionary=sim.state.fighters[0]
	hero.x=800;S5.start(sim,farmer,"s05_sickle_farmer_attack",hero)
	farmer.action_tick=16;S5.attack(sim,farmer);hero.x=680;farmer.action_tick=19;S5.attack(sim,farmer)
	assert(hero.hp==hero.max_hp-7)
	print("STAGE05_FARMERS_PASS two complete variants; mirrored release/collision; one release per attack; cancelled draw; sickle active window")
	quit()
