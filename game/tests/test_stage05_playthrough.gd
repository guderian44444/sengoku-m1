extends SceneTree
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void:
	for players in [1,2]:
		var sim := Battle.new()
		sim.reset_campaign("normal",players,["nobunaga","oichi"],5)
		var nodes := []
		for tick in 108000:
			if sim.state.ikki.node not in nodes:
				nodes.append(sim.state.ikki.node)
				print("STAGE05_ROUTE players=",players," node=",sim.state.ikki.node," tick=",tick)
			var inputs := []
			for hero in sim.state.fighters.filter(func(f):return f.team==0):
				# Route verification uses real controls and collision; difficulty acceptance is separate.
				hero.hp=hero.max_hp;hero.invuln=5
				inputs.append(pilot(sim,hero,tick))
			sim.step(inputs)
			if tick%120==0: assert(Wire.valid_snapshot(sim.state),"route snapshot")
			if sim.state.phase!="playing": break
		if sim.state.phase!="won": print("ROUTE_STUCK ",JSON.stringify({"stage":sim.state.stage,"ikki":sim.state.ikki,"fighters":sim.state.fighters.filter(func(f):return f.hp>0),"props":sim.state.props}))
		assert(sim.state.phase=="won" and nodes==range(1,13),"real controls complete twelve nodes")
		print("STAGE05_PLAYTHROUGH_PASS players=%d ticks=%d nodes=%s"%[players,sim.state.tick,str(nodes)])
	quit()

static func pilot(sim, hero: Dictionary, tick: int) -> Dictionary:
	var input := {"dx":0,"dy":0,"buttons":0}
	if sim.state.stage.go:
		input.dx=1
		input.dy=int(signf(590-hero.y)) if absf(590-hero.y)>8 else 0
		return input
	var candidates: Array=sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0)
	# Break any obstruction through normal attacks.
	candidates.append_array(sim.state.props.filter(func(p):return not p.broken and absf(p.x-hero.x)<180 and absf(p.y-hero.y)<70))
	var target := {}
	var nearest := INF
	for candidate in candidates:
		var distance: float=absf(candidate.x-hero.x)+absf(candidate.y-hero.y)*2
		if candidate.get("s05_role","")=="kusei": distance-=220
		if distance<nearest: target=candidate;nearest=distance
	if target.is_empty(): return input
	var dx: float=target.x-hero.x
	var dy: float=target.y-hero.y
	if hero.action=="charge": return input
	if absf(dx)<110 and absf(dy)<35:
		if absf(dx)>2 and hero.face!=int(signf(dx)): input.dx=int(signf(dx))
		elif tick%3==0: input.buttons=Battle.HEAVY if target.get("kind","")=="boss" else Battle.LIGHT
	else:
		input.dx=int(signf(dx)) if absf(dx)>85 else 0
		input.dy=int(signf(dy)) if absf(dy)>15 else 0
	if hero.action=="idle" and hero.rage>=100 and nearest<300: input.buttons=Battle.SPECIAL
	return input
