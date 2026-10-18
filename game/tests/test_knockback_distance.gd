extends SceneTree
const Battle = preload("res://core/battle.gd")
# Distances/timing measured from the pre-change motion in an unobstructed arena.
const BASE_DISTANCE := {"light":27.03856853,"shield":59.01460780,"boss":99.03022627,"heavy":37.01872190,"charged":374.14141948,"throw":427.59019369}
const BASE_TICKS := {"light":32,"shield":39,"boss":44,"heavy":18,"charged":39,"throw":39}
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)
func _initialize() -> void:
	for team in [0,1]:
		for face in [-1,1]:
			for move in ["light","shield","boss","heavy","charged","throw"]:
				var sim := Battle.new()
				sim.reset_training("nobunaga")
				sim.state.props.clear()
				var target: Dictionary=sim.state.fighters[team]
				sim.state.fighters=[target]
				target.x=1200.0;target.y=480.0
				if move in ["light","shield","boss"]:
					target.knockback=face*{"light":2.8,"shield":6.0,"boss":10.0}[move]
				else:
					sim._launch(target,face,{"heavy":2.2,"charged":14.0,"throw":16.0}[move],4.6 if move=="heavy" else 6.0)
					if move=="heavy":target.bounces_left=0
				var ticks := 0
				var peak := 0.0
				while (absf(target.knockback)>0.1 or target.airborne_lock) and ticks<160:
					sim._tick_motion(target)
					peak=maxf(peak,target.z)
					ticks+=1
				var player_long: bool=team==0 and move in ["charged","throw"]
				var expected: float=255.82278516 if player_long else BASE_DISTANCE[move]
				check(absf((target.x-1200.0)*face-expected)<0.001,"actual displacement: team %d / %s / face %d"%[team,move,face])
				check(ticks==(51 if player_long else BASE_TICKS[move]),"motion duration unchanged")
				check(is_equal_approx(peak,22.6 if move=="heavy" else (36.75 if move in ["charged","throw"] else 0.0)),"height unchanged")
				check(target.landing_count==(3 if player_long else (2 if move in ["charged","throw"] else (1 if move=="heavy" else 0))),"landing count unchanged")
	for face in [-1,1]:
		for obstacle in ["edge","prop"]:
			var sim := Battle.new()
			sim.reset_training("nobunaga")
			sim.state.props.clear()
			var target: Dictionary=sim.state.fighters[1]
			sim.state.fighters=[target]
			target.x=(2290.0 if face==1 else 90.0) if obstacle=="edge" else 1200.0
			target.y=480.0
			var start: float=target.x
			if obstacle=="prop": sim.state.props.append({"x":start+face*60,"y":480,"width":40,"depth":40,"broken":false})
			sim._launch(target,face,16,6)
			for tick in 80: sim._tick_motion(target)
			check(is_equal_approx((target.x-start)*face,10.0 if obstacle=="edge" else 20.0),"knockback stops at "+obstacle)
	for hero in ["nobunaga","oichi"]:
		for face in [-1,1]:
			var sim := Battle.new()
			sim.reset_training(hero)
			sim.state.props.clear()
			var player: Dictionary=sim.state.fighters[0]
			var target: Dictionary=sim.state.fighters[1]
			player.face=face;target.x=player.x+85*face;target.hp=10000;target.max_hp=10000
			for stage in 3:
				if stage>0:
					for tick in 16: sim.step([{"dx":face}])
				sim.step([{"buttons":Battle.LIGHT,"dx":face}])
				for tick in 120:
					sim.step([{"dx":face}])
					if player.action=="idle": break
			check(sim.state.training.hit_count==3 and sim.state.training.total_damage==54 and target.airborne_lock,"pursuit keeps the real three-hit combo working: "+hero)
	print("KNOCKBACK DISTANCE PASS: %d checks"%checks)
	quit()
