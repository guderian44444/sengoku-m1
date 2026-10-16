extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void:
	for heroes in [["nobunaga"],["oichi"],["nobunaga","oichi"]]:
		var sim := Battle.new()
		sim.reset_campaign("normal",heroes.size(),heroes,3)
		var scenes := []
		var damage := 0
		var blocked := [0,0]
		var previous := [Vector2.ZERO,Vector2.ZERO]
		for tick in range(108000):
			if sim.state.stage.index not in scenes: scenes.append(sim.state.stage.index)
			var inputs := []
			for player in sim.state.fighters.filter(func(f):return f.team == 0):
				# Route check keeps real attacks/collisions but disables player damage; combat reactions have dedicated tests.
				damage += int(player.max_hp-player.hp)
				player.hp = player.max_hp
				player.invuln = 5
				var slot: int = player.player_index
				var position := Vector2(player.x,player.y)
				blocked[slot] = blocked[slot]+1 if position.distance_to(previous[slot]) < .1 and player.action == "idle" else 0
				previous[slot] = position
				inputs.append(pilot(sim,player,tick,blocked[slot]))
			sim.step(inputs)
			if tick % 120 == 0 and not Wire.valid_snapshot(sim.get_state()):
				print("INVALID ROUTE STATE ",JSON.stringify(sim.get_state()))
				assert(false,"Real playthrough snapshot validates: %s tick %d" % [str(heroes),tick])
			if sim.state.phase != "playing": break
		if sim.state.phase != "won":
			print("PLAYTHROUGH STUCK ",JSON.stringify({"heroes":heroes,"stage":sim.state.stage,"encounter":sim.state.encounter,"fighters":sim.state.fighters.filter(func(f):return f.hp>0),"props":sim.state.props,"inputs":sim._inputs if "_inputs" in sim else []}))
		assert(sim.state.phase == "won" and scenes == [0,1,2,3],"Real input must complete all four scenes: "+str(heroes))
		print("STAGE03 PLAYTHROUGH PASS ",JSON.stringify({"heroes":heroes,"ticks":sim.state.tick,"scenes":scenes,"endurance_damage":damage,"acceptance":"synthetic invulnerable controls; no direct objective damage, teleport, scene jump or difficulty acceptance"}))
	quit()

func pilot(sim: RefCounted, player: Dictionary, tick: int, blocked: int) -> Dictionary:
	var input := {"dx":0,"dy":0,"buttons":0}
	var e: Dictionary = sim.state.encounter
	var targets: Array = sim.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0 and not f.get("entering",false))
	var props: Array = sim.state.props.filter(func(p):return not p.broken and (p.kind == "bell_pillar" or p.get("stage03_barrier",false)))
	if not props.is_empty(): targets = props
	elif e.kind == "lieutenants":
		var bosses: Array = targets.filter(func(f):return f.kind == "boss")
		if not bosses.is_empty(): targets = bosses
	var path_blocked: bool = targets.any(func(f):return f.x >= player.x-30 and f.x-player.x < 160 and absf(f.y-player.y)<70)
	if player.action == "charge":
		input.buttons = 0
		return input
	if (sim.state.stage.go or e.kind == "formation") and not path_blocked:
		input.dx = 1
		input.dy = int(signf(590-player.y)) if absf(player.y-590)>8 else 0
		return input
	var target := {}
	var nearest := INF
	for candidate in targets:
		var distance: float = absf(candidate.x-player.x)+absf(candidate.y-player.y)*2
		if distance < nearest:
			nearest = distance
			target = candidate
	if target.is_empty(): return input
	var dx: float = target.x-player.x
	var dy: float = target.y-player.y
	var prop: bool = target.has("broken")
	var reach := 105.0
	var prone: bool = target.get("action","") in ["down","recovering"]
	if prone or (target.kind == "boss" and target.action == "idle" and target.invuln > 0):
		if target.kind == "boss" and Vector2(dx,dy/.4).length() < 175:
			input.dx = -int(signf(dx)) if absf(dx)>1 else -player.face
			input.dy = -int(signf(dy)) if absf(dy)>1 else (1 if player.y<480 else -1)
	elif player.action == "charge": input.buttons = Battle.HEAVY if player.charge < 40 else 0
	elif absf(dx) <= reach and absf(dy) <= (80.0 if prop else 30.0):
		if player.face != signi(int(dx)) and absf(dx)>2: input.dx = int(signf(dx))
		elif tick % 3 == 0: input.buttons = Battle.HEAVY if target.kind == "boss" or target.get("role","") == "shield_spear" or tick % 120 < 3 else Battle.LIGHT
	else:
		input.dx = int(signf(dx)) if absf(dx)>reach*.8 else 0
		input.dy = int(signf(dy)) if absf(dy)>15 else 0
	if blocked > 18 and player.action == "idle" and tick % 3 == 0: input.buttons = Battle.LIGHT
	if player.action == "idle" and player.rage >= 100 and nearest < 400: input.buttons = Battle.SPECIAL
	return input
