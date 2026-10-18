extends SceneTree
const Battle=preload("res://core/battle.gd")
const Equipment=preload("res://core/equipment.gd")
const Weapons=preload("res://core/weapon_catalog.gd")
var checks:=0

func _initialize() -> void:
	for hero in Battle.PLAYABLE_HEROES:
		for weapon in Weapons.ids_for(hero):
			var equipment: Dictionary={} if hero=="oichi" else Weapons.item(weapon)
			var base: float=115.0 if hero=="oichi" else Battle.LIGHT_REACH[hero]
			var reach: float=(base+float(equipment.get("reach_bonus",0))+12.0)*Battle.HERO_PROFILES[hero].reach*(1.3 if hero=="oichi" else 1.0)
			var depth: float=48.0*Battle.HERO_PROFILES[hero].depth
			if hero=="hideyoshi":
				reach*=1.3
				depth*=1.3
			for face in [-1,1]:
				for combo in [1,2,3]:
					var scale:=1.44 if combo==3 else 1.0
					for probe in [Vector3(reach*scale-.01,0,1),Vector3(reach*scale+.1,0,0),Vector3(70,depth*scale-.01,1),Vector3(70,-depth*scale+.01,1),Vector3(70,depth*scale+.1,0),Vector3(reach*1.1,0,int(combo==3)),Vector3(70,depth*1.1,int(combo==3))]:
						var sim:=Battle.new();sim.reset_training(hero,"dummy")
						var f:Dictionary=sim.state.fighters[0]
						f.x=700;f.y=500;f.face=face;f.combo=combo
						Equipment.equip(f,Equipment.add(f,weapon))
						Equipment.equip(f,Equipment.add(f,"moon"))
						var target:Dictionary=sim.state.fighters[1]
						target.x=f.x+face*probe.x;target.y=f.y+probe.y;target.hp=10000;target.max_hp=10000;target.armor=0
						sim.state.props=[{"id":1000,"kind":"crate","x":target.x,"y":target.y,"hp":10000,"max_hp":10000,"width":0.0,"depth":0.0,"broken":false,"drop":""}]
						sim._begin(f,"light")
						sim._combat_contact_v33(f,"contact")
						var label: String=hero+"/"+weapon+"/"+str(combo)+"/"+str(probe)
						assert((target.hp<10000)==bool(probe.z),"Enemy hit boundary "+label)
						assert((sim.state.props[0].hp<10000)==bool(probe.z),"Prop hit boundary "+label)
						assert(is_equal_approx(f.attack_reach,reach*scale),"Equipment-adjusted reach "+label)
						var waves:Array=sim.state.effects.filter(func(e):return e.get("finisher",false))
						assert(waves.size()==(1 if combo==3 else 0),"Only third hit emits a finisher wave "+label)
						checks+=4
						if probe.z==1:
							var damage:=roundi((14+combo*2+f.weapon*5+int(equipment.get("damage_bonus",0)))*float(Battle.HERO_PROFILES[hero].damage))
							assert(10000-target.hp==damage,"Damage stays unchanged "+label)
							assert(target.airborne_lock==(combo==3),"Only finisher launches "+label)
							checks+=2
	print("LIGHT FINISHER PASS: %d checks"%checks)
	quit()
