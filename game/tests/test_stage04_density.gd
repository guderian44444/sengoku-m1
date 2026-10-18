extends SceneTree

const Battle = preload("res://core/battle.gd")
const Encounter = preload("res://core/stage04_encounter.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
const TOTALS := [18,20,28,18,20,28,28,17,20,25,32,32,27]

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func node(number: int, players: int = 1) -> Battle:
	var sim := Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],4)
	for section in 5:
		for checkpoint in sim._campaign.segments[section].encounters.size():
			if int(sim._campaign.segments[section].encounters[checkpoint].node) != number: continue
			sim._enter_segment(section)
			sim._start_checkpoint(checkpoint)
			sim.state.intro.clear()
			return sim
	return sim

func tick(sim) -> void:
	sim.state.tick += 1
	Encounter.tick(sim)

func enemies(sim) -> Array:
	return sim.state.fighters.filter(func(f): return f.team==1 and f.hp>0)

func all_nodes() -> void:
	for players in [1,2]:
		var total := 0
		for number in range(1,14):
			var sim := node(number,players)
			var spec: Dictionary=sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
			var seen := {};var last_admit := -100;var last_size := 0
			for f in enemies(sim): seen[f.id]=true
			check(seen.size()==spec.units.size(),"exact initial count, no coop inflation")
			var initial: int=seen.size()
			for i in 1000:
				# Kill bosses early and drain every admitted group, retaining corpses separately.
				for f in enemies(sim): f.hp=0;f.entering=false
				tick(sim)
				var newly: Array=enemies(sim).filter(func(f):return not seen.has(f.id))
				if not newly.is_empty():
					check(newly.size()==2,"atomic left/right pair")
					check(sim.state.tick-last_admit>=45,"at least 45 ticks between successful admissions")
					check(newly[0].x<sim.camera_left(sim.state) and newly[1].x>sim.camera_left(sim.state)+1280,"both sides enter offscreen")
					last_admit=sim.state.tick
				for f in newly: seen[f.id]=true
				var box: Dictionary=sim.state.mikawa
				check(enemies(sim).size()+box.reserved.size()*2+box.pending.size()<=spec.cap,"total reserved capacity")
				check(sim.state.fighters.filter(Encounter.regular).size()+box.reserved.size()*2<=spec.regular_cap,"regular reserved capacity")
				check(Wire.valid_snapshot(sim.get_state()),"wave state validates on wire")
				if box.phase=="complete": break
				if seen.size()<TOTALS[number-1]: check(box.phase!="complete","early boss death never skips finite waves")
				last_size=seen.size()
			check(sim.state.mikawa.phase=="complete" and seen.size()==TOTALS[number-1],"full scheduled roster drains node %d"%number)
			check(seen.size()>initial,"every node has reinforcements")
			total+=seen.size()
		check(total==313,"chapter has 313 fixed soldiers, bosses and escorts")

func gates() -> void:
	var sim:=node(3)
	for f in enemies(sim): f.hp=0
	tick(sim)
	check(sim.state.mikawa.reserved.size()==3,"whole first batch reserved once")
	var due: int=sim.state.mikawa.admit_tick
	for i in 44: tick(sim)
	check(enemies(sim).is_empty(),"warning leads admission by 45 ticks")
	tick(sim)
	check(enemies(sim).size()==2,"first pair at due tick")
	var seen:=enemies(sim)
	for i in 90: tick(sim)
	check(enemies(sim).size()==6 and sim.state.mikawa.next_batch==1,"three timed pairs finish first wave")
	for f in enemies(sim): f.hp=0
	seen[-1].hp=80;seen[-1].entering=true
	for i in 90: tick(sim)
	check(sim.state.mikawa.next_batch==1,"uncompleted entrance blocks next reservation")
	seen[-1].entering=false
	tick(sim)
	check(sim.state.mikawa.reserved.size()==4,"second batch reserves eight")
	# An occupied portal must defer the entire pair, without spending or duplicating tokens.
	sim.state.props.clear()
	var blockers:=[]
	for lane in [390,435,480,525,570]:
		var f: Dictionary=sim._make_fighter(0,"nobunaga",sim.camera_left(sim.state)-240,lane,120)
		blockers.append(f);sim.state.fighters.append(f)
	# Keep authoritative camera unchanged despite the test's synthetic player blockers.
	for f in blockers: f.team=1;f.kind="boss"
	for i in 60: tick(sim)
	check(sim.state.mikawa.reserved.size()==4,"blocked left portal defers both sides")
	for f in blockers: sim.state.fighters.erase(f)
	tick(sim)
	check(sim.state.mikawa.reserved.size()==3 and sim.state.mikawa.admit_tick==sim.state.tick+45,"successful retry restarts actual interval")
	var epoch: int=sim.state.mikawa.epoch
	sim._start_checkpoint(sim.state.stage.checkpoint)
	check(sim.state.mikawa.epoch!=epoch and sim.state.mikawa.next_batch==0 and sim.state.mikawa.reserved.is_empty(),"checkpoint retry drops old epoch and all reservations")
	var count: int=sim.state.fighters.size()
	Encounter.begin(sim,sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint])
	check(sim.state.fighters.size()==count,"same epoch begin is idempotent")
	# Actor storage cap includes corpses, independently of combat population.
	for f in enemies(sim): f.hp=0
	tick(sim)
	while sim.state.fighters.size()<47:
		var corpse: Dictionary=sim._make_fighter(1,"soldier",500,500,0)
		sim.state.fighters.append(corpse)
	for i in 60: tick(sim)
	check(sim.state.mikawa.reserved.size()==3,"48 actor capacity defers a full pair")
	sim.state.fighters=sim.state.fighters.filter(func(f):return f.team==0)
	tick(sim)
	check(enemies(sim).size()==2,"capacity release resumes without a burst")

func escorts_and_intro() -> void:
	var sim:=node(10)
	var kira: Dictionary=enemies(sim).filter(func(f):return f.mikawa_role=="kira")[0]
	var escorts: Array=enemies(sim).filter(func(f):return f.mikawa_escort)
	for f in escorts.slice(0,3): f.hp=0
	Encounter.tick(sim);Encounter.tick(sim)
	check(sim.state.mikawa.pending.size()==3,"three deaths produce exactly three escort tickets")
	check(sim.state.mikawa.reserved.size()==3,"escort pool does not block regular wave trigger")
	for i in 179: tick(sim)
	check(enemies(sim).filter(func(f):return f.mikawa_escort).size()==3,"escort delay is 180 ticks")
	tick(sim)
	check(enemies(sim).filter(func(f):return f.mikawa_escort).size()==4,"first replacement only")
	for i in 44: tick(sim)
	check(enemies(sim).filter(func(f):return f.mikawa_escort).size()==4,"escort admissions throttled")
	kira.hp=0;tick(sim)
	check(sim.state.mikawa.pending.is_empty() and enemies(sim).filter(func(f):return f.mikawa_escort).size()==4,"Kira death cancels due ticket before spawn")
	sim=node(13);var boss: Dictionary=enemies(sim).filter(func(f):return f.mikawa_role=="udono")[0]
	Encounter.intro(sim,boss)
	var clock: int=sim.state.tick
	for i in sim.state.intro.duration: sim.step([{"buttons":Battle.HEAVY}])
	check(sim.state.tick==clock and sim.state.mikawa.next_batch==0 and boss.action=="idle","introduction freezes attacks and admission clock")
	boss.hp=0
	for i in 700: tick(sim)
	check(sim.state.mikawa.escape_complete and sim.state.mikawa.phase!="complete","early escape waits for finite enemies")
	var bad:=sim.get_state();bad.mikawa.reserved=[{"left":{"role":"udono","kind":"boss"},"right":{}}]
	check(not Wire.valid_snapshot(bad),"reject invalid reservation at network boundary")

func _initialize() -> void:
	all_nodes()
	gates()
	escorts_and_intro()
	print("STAGE04 DENSITY PASS: %d checks"%checks)
	quit()
