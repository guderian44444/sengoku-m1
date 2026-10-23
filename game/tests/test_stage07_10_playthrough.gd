extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void:
	for chapter in [7,8,9,10]:
		for players in [1,2]:
			var sim := Battle.new()
			sim.reset_campaign("normal",players,["nobunaga","oichi"],chapter)
			var nodes := []
			for tick in 120000:
				if sim.state.expedition.node not in nodes:
					nodes.append(int(sim.state.expedition.node))
					print("STAGE0710_ROUTE chapter=%d players=%d node=%d tick=%d"%[chapter,players,sim.state.expedition.node,tick])
				var inputs := []
				for hero in sim.state.fighters.filter(func(f):return f.team==0):
					# Prove route/collision with real input; this does not claim human difficulty acceptance.
					hero.hp=hero.max_hp;hero.invuln=5
					inputs.append(pilot(sim,hero,tick))
				sim.step(inputs)
				if tick%120==0: assert(Wire.valid_snapshot(sim.state),"Playable-route snapshot")
				if sim.state.phase!="playing": break
			if sim.state.phase!="won":
				print("STAGE0710_STUCK ",JSON.stringify({"stage":sim.state.stage,"expedition":sim.state.expedition,"fighters":sim.state.fighters.filter(func(f):return f.hp>0),"props":sim.state.props}))
				assert(false,"All ten nodes must be reachable with real controls")
			assert(nodes==range(1,11),"Complete every checkpoint without skipping")
			print("STAGE0710_PLAYTHROUGH_PASS chapter=%d players=%d ticks=%d"%[chapter,players,sim.state.tick])
	quit()

static func pilot(sim, hero: Dictionary, tick: int) -> Dictionary:
	var input := {"dx":0,"dy":0,"buttons":0}
	var leader: Dictionary=sim.state.fighters[0]
	if hero.player_index==1 and absf(leader.x-hero.x)>500:
		input.dx=int(signf(leader.x-hero.x));input.dy=int(signf(leader.y-hero.y)) if absf(leader.y-hero.y)>15 else 0
		if tick%3==0: input.buttons=Battle.LIGHT
		return input
	if sim.state.stage.go or sim.state.expedition.phase=="evacuating":
		input.dx=1;input.dy=int(signf(590-hero.y)) if absf(590-hero.y)>8 else 0
		if sim.state.props.any(func(p):return not p.broken and p.x>hero.x and p.x-hero.x<155 and absf(p.y-hero.y)<45):
			input.dy=0
			if tick%3==0: input.buttons=Battle.LIGHT
		return input
	var candidates: Array=sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0 and not f.get("entering",false))
	candidates.append_array(sim.state.props.filter(func(p):return not p.broken))
	var target := {}
	var nearest := INF
	for candidate in candidates:
		var distance: float=absf(candidate.x-hero.x)+absf(candidate.y-hero.y)*2
		if candidate.get("team",0)==1 and absf(candidate.x-hero.x)<145 and absf(candidate.y-hero.y)<45: distance-=350
		if candidate.get("mandatory",false): distance-=180
		if candidate.get("expedition_asset","") in ["rock_support","signal"]: distance-=100
		if distance<nearest: target=candidate;nearest=distance
	if target.is_empty(): return input
	var dx: float=target.x-hero.x;var dy: float=target.y-hero.y
	if hero.action=="charge": return input
	# Props are hittable at their outer edge; walking into their center stalls at collision.
	var prop_depth := float(target.get("depth",0))*.5
	var prop_width := float(target.get("width",0))*.5
	if absf(dx)<140+prop_width and absf(dy)<35+prop_depth:
		if absf(dx)>2 and hero.face!=int(signf(dx)): input.dx=int(signf(dx))
		elif tick%3==0: input.buttons=Battle.HEAVY if target.get("kind","")=="boss" or target.get("role","")=="shield_spear" else Battle.LIGHT
	else:
		input.dx=int(signf(dx)) if absf(dx)>100 else 0
		input.dy=int(signf(dy)) if absf(dy)>15 else 0
	return input
