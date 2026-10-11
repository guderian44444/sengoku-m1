extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void:
	for hero in ["nobunaga","oichi","tadakatsu"]:
		var battle := Battle.new()
		battle.reset_campaign("normal",1,[hero])
		# Refill endurance HP without inflating the player-based boss health ratio.
		var endurance_damage := 0
		var segments := []
		var last_index := -1
		var last_x := 0.0
		var last_y := 0.0
		var blocked := 0
		var last_target := {}
		var last_input := {}
		var waited_prone_ticks := 0
		var avoided_getup_ticks := 0
		for tick in range(108000):
			var player: Dictionary = battle.state.fighters[0]
			endurance_damage += int(player.max_hp)-int(player.hp)
			player.hp = player.max_hp
			if battle.state.stage.index != last_index:
				last_index = battle.state.stage.index
				segments.append({"index":last_index,"entry_tick":tick})
			var input := {"dx":0,"dy":0,"buttons":0}
			var targets: Array = battle.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0 and not f.get("entering",false))
			var standing: Array = targets.filter(func(f):return f.action not in ["down","recovering"])
			if not standing.is_empty(): targets = standing
			if targets.is_empty() or blocked > 18:
				var obstacles: Array = battle.state.props.filter(func(p):return not p.broken and p.x < battle.state.stage.encounter_end and p.x >= battle._left_edge() - p.width * 0.5)
				if not obstacles.is_empty(): targets = obstacles
			var target := {}
			var nearest := INF
			for candidate in targets:
				var distance := absf(candidate.x - player.x) + absf(candidate.y - player.y) * 2.0
				if distance < nearest:
					nearest = distance
					target = candidate
			if target.is_empty():
				if battle.state.stage.go: input.dx = 1
			else:
				var dx: float = target.x - player.x
				var dy: float = target.y - player.y
				var reach := 185.0 if target.has("broken") else 115.0
				var prone: bool = target.get("action", "") in ["down","recovering"]
				var getup: bool = target.kind == "boss" and (prone or (target.action == "idle" and target.invuln > 0))
				if prone or getup:
					waited_prone_ticks += 1 if prone else 0
					# Respect grounded immunity and leave the boss's 150px get-up ellipse.
					if getup and Vector2(dx,dy / 0.4).length() < 175.0:
						input.dx = -int(signf(dx)) if absf(dx) > 1.0 else -player.face
						input.dy = -int(signf(dy)) if absf(dy) > 1.0 else (1 if player.y < 480.0 else -1)
						avoided_getup_ticks += 1
				elif player.action == "charge":
					input.buttons = Battle.HEAVY if player.charge < 40 else 0
				# Body collision stops side-by-side approach at 28px, within the sword/needle lane.
				elif absf(dx) <= reach and absf(dy) <= (80.0 if target.has("broken") else 30.0):
					if player.face != signi(int(dx)) and absf(dx) > 2.0: input.dx = int(signf(dx))
					elif tick % 3 == 0:
						input.buttons = Battle.HEAVY if target.kind == "boss" or tick % 120 < 3 else Battle.LIGHT
				else:
					input.dx = int(signf(dx)) if absf(dx) > reach * 0.8 else 0
					input.dy = int(signf(dy)) if absf(dy) > 15.0 else 0
			# Clear bodies that block the route to a target, and spend earned rage when surrounded.
			if blocked > 18 and player.action == "idle" and tick % 3 == 0: input.buttons = Battle.SPECIAL if player.rage >= 100 else Battle.LIGHT
			if player.action == "idle" and player.rage >= 100 and nearest < 400.0: input.buttons = Battle.SPECIAL
			battle.step([input])
			last_target = target
			last_input = input
			if tick % 120 == 0 and not Wire.valid_snapshot(battle.get_state()):
				push_error("Real combat snapshot is invalid for " + hero)
				print("STAGE PLAYTHROUGH INVALID ", JSON.stringify(battle.get_state()))
				quit(1)
				return
			if (input.dx != 0 or input.dy != 0) and player.action == "idle":
				blocked = blocked + 1 if absf(player.x-last_x) + absf(player.y-last_y) < 0.05 else 0
			else: blocked = 0
			last_x = player.x
			last_y = player.y
			if battle.state.phase != "playing": break
		if battle.state.phase != "won":
			print("STAGE PLAYTHROUGH FAILED ", JSON.stringify({"hero":hero,"tick":battle.state.tick,"stage":battle.state.stage,"wave":battle.state.wave,"fighters":battle.state.fighters.filter(func(f):return f.hp>0 or f.team==0),"props":battle.state.props.filter(func(p):return not p.broken),"target":last_target,"input":last_input,"blocked":blocked,"segments":segments}))
			push_error("Real attacks must finish all sections for " + hero + "; stuck at " + str(battle.state.stage.index) + "/" + str(battle.state.wave))
			quit(1)
			return
		print("STAGE PLAYTHROUGH PASS ",hero," ",JSON.stringify({"ticks":battle.state.tick,"segments":segments,"remaining_hp":battle.state.fighters[0].hp,"endurance_damage":endurance_damage,"waited_prone_ticks":waited_prone_ticks,"avoided_getup_ticks":avoided_getup_ticks,"acceptance":"synthetic controls refill player HP each tick while preserving production max HP and boss ratios; not a difficulty or human timing measurement"}))
	quit()
