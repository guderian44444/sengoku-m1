extends SceneTree
const Battle=preload("res://core/battle.gd")
const Wire=preload("res://core/wire.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	assert(ok,label)
func arena(role:String,face:int)->Battle:
	var sim:=Battle.new()
	sim.reset_campaign("normal",1,["oichi"],4)
	if role=="shield_udono":sim._enter_segment(4)
	var player:Dictionary=sim.state.fighters[0]
	var target:Dictionary=sim.state.fighters.filter(func(f):return f.get("mikawa_role","")==role)[0]
	sim.state.fighters=[player,target];sim.state.props.clear();sim.state.intro.clear();sim.state.mikawa.mud=[]
	sim.state.mikawa.next_batch=sim._campaign.segments[sim.state.stage.index].encounters[0].batches.size()
	player.x=900;player.y=510;player.face=face
	target.x=player.x+face*90;target.y=player.y;target.face=-face
	target.hp=1000;target.max_hp=1000;target.cooldown=10000
	return sim
func _initialize()->void:
	for role in ["spear_kira","shield_kira","shield_udono"]:
		for face in [-1,1]:
			for count in [0,1,2,3]:
				var sim:=arena(role,face)
				var player:Dictionary=sim.state.fighters[0];var target:Dictionary=sim.state.fighters[1]
				var arrows:Array=[]
				for tick in 30:
					sim.step([{"buttons":Battle.JUMP|Battle.HEAVY if tick==0 else 0}])
					arrows=sim.state.effects.filter(func(e):return e.type=="projectile" and e.owner==player.id)
					if not arrows.is_empty():break
				check(arrows.size()==3 and target.hp==1000,"real jump-heavy emits three separate arrows before impact")
				for index in range(count,3):arrows[index].life=0
				var hits:=0
				for tick in 100:
					sim.step([{}])
					hits+=sim.state.events.filter(func(e):return e.type=="damage" and e.target==target.id).size()
					check(Wire.valid_snapshot(sim.state),"multi-arrow combat state remains valid")
					if role.begins_with("shield_"):check(not target.airborne_lock and target.action not in ["down","launched","recovering"],"aerial arrows only push the large shield")
				var per_arrow:int=12 if role.begins_with("shield_") else 24
				check(target.hp==1000-count*per_arrow and hits==count,"each connected arrow deals one full hit: %s / %d arrows / face %d; got %d damage, %d hits"%[role,count,face,1000-target.hp,hits])
				for index in count:check(arrows[index].hit_ids.count(target.id)==1,"each arrow records the target once")
	# The exception belongs to aerial arrows, not ordinary shots or all damage.
	var normal:=arena("spear_kira",1)
	var player:Dictionary=normal.state.fighters[0];var target:Dictionary=normal.state.fighters[1]
	normal._begin(player,"heavy")
	normal._combat_arrow_v33(player,false);normal._combat_arrow_v33(player,false)
	normal._tick_effects()
	check(target.hp==976,"ordinary arrows retain normal hit immunity")
	print("OICHI AIR MULTIHIT PASS: %d checks"%checks)
	quit()
