extends SceneTree

const Battle = preload("res://core/battle.gd")
const Data = preload("res://core/stage04_data.gd")
const Encounter = preload("res://core/stage04_encounter.gd")
const Wire = preload("res://core/wire.gd")
const Art = preload("res://render/stage04_art.gd")
const View = preload("res://render/battle_view.gd")
const Audio = preload("res://render/combat_audio.gd")
const Equipment = preload("res://core/equipment.gd")
const Music = preload("res://core/campaign_music.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
		assert(ok,label)

func _initialize() -> void: run.call_deferred()

func node(number: int, players: int = 1) -> Battle:
	var sim := Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],4)
	for section in 5:
		for checkpoint in sim._campaign.segments[section].encounters.size():
			if int(sim._campaign.segments[section].encounters[checkpoint].node) == number:
				sim._enter_segment(section)
				sim._start_checkpoint(checkpoint)
				sim.state.intro.clear()
				return sim
	return sim

func actor(sim, role: String) -> Dictionary:
	return sim.state.fighters.filter(func(f):return f.get("mikawa_role","") == role)[0]

func combat_checks() -> void:
	var sim := node(13)
	var boss := actor(sim,"udono")
	var hero: Dictionary = sim.state.fighters[0]
	check(boss.max_hp == 1200 and actor(node(13,2),"udono").max_hp == 2040,"solo and coop Udono HP")
	for move in ["heavy","air_heavy","charged","special"]:
		boss.invuln = 0; boss.stun = 0; boss.action = "idle"; hero.action = move
		sim._damage(boss,10,hero.id,true,true,false,true)
		sim._launch(boss,1,12,8)
		check(boss.z == 0 and boss.vz == 0 and not boss.airborne_lock and boss.action not in ["down","launched"],"Udono standing after "+move)
		if move == "charged": check(boss.stun >= 78 and boss.action == "stunned","charged produces standing stun")
	boss.invuln=0; boss.stun=30;boss.action="stunned";hero.action="light"
	sim._damage(boss,10,hero.id,false)
	check(boss.stun==30 and boss.action=="stunned","light cannot overwrite standing stun")
	for band in ["near","far"]:
		boss.action="idle";boss.stun=0;boss.freeze=0;boss.mikawa_pressure=[];boss.mikawa_counters={"spin":0,"rock":0,"shared":0}
		hero.x=boss.x-(200 if band=="near" else 400)
		for i in 3:
			sim.state.tick=100+i*24
			Encounter.note_hit(sim,boss,hero,i,"light")
			Encounter.note_hit(sim,boss,hero,i,"light")
		check(boss.mikawa_pressure.size()==3,"distinct attacks deduplicated")
		Encounter.tick(sim)
		check(boss.action == ("udono_melee_spin_counter" if band=="near" else "udono_ranged_rock_volley"),"pressure chooses "+band)
		check(boss.mikawa_counters.shared==388,"shared counter cooldown")
	Encounter.start(sim,boss,"udono_ranged_rock_volley")
	sim.state.effects.clear()
	for tick in int(Data.attack_timing(boss)[1]):
		boss.action_tick=tick+1
		Encounter.attack(sim,boss)
	check(sim.state.effects.filter(func(e):return e.get("mikawa_projectile","")=="stone").size()==3,"three stones released at 0.8/2/3.2 seconds")
	var stone: Dictionary=sim.state.effects.filter(func(e):return e.get("mikawa_projectile","")=="stone")[0]
	check(is_equal_approx(Vector2(stone.vx,stone.vy/.4).length(),Battle.FAST_PROJECTILE_SPEED),"stones use shared gun speed")
	hero.x=stone.x+stone.vx*.5;hero.y=stone.y;hero.z=0;hero.invuln=60
	var hp: int=hero.hp
	Encounter.projectile(sim,stone)
	check(stone.life==0 and hero.hp==hp,"stone swept contact consumes with existing invulnerability")
	Encounter.start(sim,boss,"udono_ranged_rock_volley")
	boss.stun=60;boss.action_tick=48;sim.state.effects.clear()
	Encounter.attack(sim,boss)
	check(sim.state.effects.is_empty(),"stun cancels unreleased stone")
	boss.stun=0;hero.invuln=0;hero.action="idle";hero.z=0;hero.x=boss.x-100;hero.y=boss.y
	Encounter.start(sim,boss,"udono_melee_spin_counter")
	var before_spin: int=hero.hp
	for tick in range(32,64):
		boss.action_tick=tick;hero.invuln=0;hero.z=0
		Encounter.attack(sim,boss)
	check(before_spin-hero.hp==26,"spin active window hits each player once")

	sim=node(10);var kira:=actor(sim,"kira");hero=sim.state.fighters[0]
	Encounter.start(sim,kira,"kira_command");kira.action_tick=24;Encounter.attack(sim,kira)
	check(kira.mikawa_roster.size()==6,"command captures six existing archers")
	var positions: Dictionary={}
	for id in kira.mikawa_roster: positions[id]=Vector2(sim._fighter(id).x,sim._fighter(id).y)
	kira.action_tick=54;Encounter.attack(sim,kira)
	var rain: Array=sim.state.effects.filter(func(e):return e.get("mikawa_projectile","")=="rain")
	check(rain.size()==6,"one arrow per roster member")
	var locked:=Vector2(rain[0].land_x,rain[0].land_y)
	hero.x=sim._left_edge();hero.y=600
	for e in rain: e.life=0;Encounter.projectile(sim,e)
	check(Vector2(rain[0].land_x,rain[0].land_y)==locked and hero.hp==hero.max_hp,"rain landing remains fixed and can be dodged")
	for id in positions: check(Vector2(sim._fighter(id).x,sim._fighter(id).y)==positions[id],"command never teleports escorts")
	var dead: Dictionary=sim._fighter(kira.mikawa_roster[0]);dead.hp=0
	Encounter.tick(sim)
	check(sim.state.mikawa.pending.size()==1,"one replacement queued per death")
	sim.state.tick+=179;Encounter.tick(sim)
	check(sim.state.fighters.filter(func(f):return f.get("mikawa_escort",false) and f.hp>0).size()==5,"no early replacement")
	sim.state.tick+=1;Encounter.tick(sim)
	check(sim.state.fighters.filter(func(f):return f.get("mikawa_escort",false) and f.hp>0).size()==6,"replacement after three seconds")
	var replacement: Dictionary=sim.state.fighters[-1]
	check(replacement.id not in kira.mikawa_roster,"late replacement excluded from current rain")
	replacement.hp=0;Encounter.tick(sim);kira.hp=0;Encounter.tick(sim);sim.state.tick+=180;Encounter.tick(sim)
	check(sim.state.mikawa.pending.is_empty() and not sim.state.fighters.any(func(f):return f.get("mikawa_escort",false) and f.id>replacement.id),"Kira defeat cancels pending replacements")

	sim=node(11);hero=sim.state.fighters[0]
	var shield:=actor(sim,"shield_udono")
	hero.x=shield.x+shield.face*80;hero.y=shield.y;hero.combo=1;hero.action="light"
	hp=shield.hp
	check(sim._damage(shield,20,hero.id,false) and shield.hp==hp-10,"heavy shield halves first light")
	shield.invuln=0
	hero.combo=3;hp=shield.hp
	check(sim._damage(shield,20,hero.id,false) and shield.hp==hp-10,"front third light half damage")
	shield.invuln=0;shield.action="idle";hero.action="heavy"
	sim._damage(shield,20,hero.id,true);sim._launch(shield,1)
	check(shield.action!="down" and not shield.airborne_lock,"heavy shield stays grounded under ordinary heavy")
	shield.invuln=0;shield.action="idle";hero.action="charged"
	sim._damage(shield,20,hero.id,true)
	check(shield.action=="down" and not shield.airborne_lock,"explicit charged knockdown exception")

	for number in range(1,14):
		sim=node(number)
		hero=sim.state.fighters[0]
		if not sim.state.mikawa.mud.is_empty():
			var polygon:=PackedVector2Array()
			for point in sim.state.mikawa.mud: polygon.append(Vector2(point[0],point[1]))
			var middle:=Vector2.ZERO
			for point in polygon: middle+=point/polygon.size()
			hero.x=middle.x;hero.y=middle.y
			check(Encounter.in_mud(sim.state,hero),"mud polygon includes center")
			sim.state.props.clear();sim.state.fighters=[hero]
			var before: float=hero.x;sim._move_fighter(hero,10)
			check(is_equal_approx(hero.x-before,6.5),"mud slows ground movement by 35 percent")
			sim._player_input(hero,{"dx":0,"dy":0,"buttons":Battle.JUMP},0)
			check(hero.z==0 and hero.vz==0,"mud prevents starting a jump")
			hero.z=20;before=hero.x;sim._move_fighter(hero,10)
			check(is_equal_approx(hero.x-before,10),"airborne movement unaffected")
		sim=node(number)
		for enemy in sim.state.fighters:
			if enemy.team==1: enemy.hp=0
		Encounter.tick(sim)
		if number==13:
			check(sim.state.mikawa.phase=="retreat","final victory waits for authored retreat")
			for tick in 600: sim.state.tick+=1;Encounter.tick(sim)
		for tick in 1000:
			for enemy in sim.state.fighters:
				if enemy.team==1: enemy.hp=0;enemy.entering=false
			sim.state.tick+=1;Encounter.tick(sim)
			if sim.state.mikawa.phase=="complete": break
		check(sim.state.mikawa.phase=="complete","node completes without optional props %d"%number)
		check(Wire.valid_snapshot(sim.get_state()),"final node snapshot")

	sim=node(13);boss=actor(sim,"udono");hero=sim.state.fighters[0]
	boss.x=100.0;boss.hp=0;boss.damage_tick=sim.state.tick
	for tick in 2100:
		for enemy in sim.state.fighters:
			if enemy.team==1: enemy.hp=0;enemy.entering=false
		sim.step([{"dx":0,"dy":0,"buttons":0}])
	check(sim.state.phase=="won","long retreat survives ordinary corpse cleanup and completes campaign")

func audio_checks() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	for key in Data.MUSIC:
		var stream: AudioStream = audio._load_music(key)
		check(stream != null and stream.get_length()>1,"decode music "+key)
	for cue in Audio.Stage04Audio.CUES:
		var path: String=Audio.Stage04Audio.CUES[cue]
		for variant in range(1,4) if path.ends_with("_01.ogg") and cue!="flag_land" else [1]:
			check(audio._mikawa_audio.stream(path.replace("_01.ogg","_%02d.ogg"%variant)).get_length()>0,"decode SFX "+cue)
	for cue in Audio.Stage04Audio.voice_cues():
		check(audio._mikawa_audio.stream("audio/voices/processed/ogg/"+cue+".ogg").get_length()>0,"decode voice "+cue)
	var cues:=Audio.Stage04Audio.voice_cues()
	audio._mikawa_audio.play({"voice":true,"cue":cues[0],"actor":99,"id":1})
	var ongoing: AudioStream=audio._mikawa_audio.voices[99].stream
	audio._mikawa_audio.play({"voice":true,"cue":cues[1],"actor":99,"id":2})
	check(audio._mikawa_audio.voices[99].stream==ongoing,"same actor cannot overlap or cut a phrase")
	audio.set_music_paused(true)
	check(audio._mikawa_audio.voices[99].stream_paused,"pause includes new voice playback")
	audio.set_music_paused(false)
	for number in [8,10,13]:
		var sim:=node(number)
		var boss: Dictionary=sim.state.fighters.filter(func(f):return f.kind=="boss")[0]
		Encounter.intro(sim,boss);sim.step([{}])
		var event: Dictionary=sim.state.events.filter(func(e):return e.type=="boss_intro")[0]
		audio.play_event(event)
		check(audio._intro_player.playing and audio.last_spoken==sim.state.intro.line_key,"warlord entrance plays through game event "+boss.mikawa_role)
		audio.stop_speech();sim.state.intro.clear()
		var hero: Dictionary=sim.state.fighters[0]
		sim.state.events.clear();boss.invuln=0;sim._damage(boss,10,hero.id,false)
		for e in sim.state.events: audio.play_event(e)
		check(audio._mikawa_audio.voices.has(boss.id) and audio._mikawa_audio.voices[boss.id].playing,"warlord hurt voice plays")
		sim.state.events.clear();boss.invuln=0;sim._damage(boss,10000,hero.id,false)
		for e in sim.state.events: audio.play_event(e)
		audio.sync_encounter(sim.state)
		check(audio._mikawa_audio.voices[boss.id].playing and audio._mikawa_audio.voices[boss.id].get_meta("defeated",false),"death voice survives corpse sync and interrupts attack call")
		audio.stop_speech()
	for group in ["a","b"]: check(audio._mikawa_audio.stream("audio/crowd/groups/tent_support_group_%s.ogg"%group).get_length()>0,"crowd group decodes")
	audio.free()

func assets_and_burst() -> void:
	var art := Art.new()
	# These opaque source landmarks crossed the old atlas row boundaries.
	for probe in [["tominaga","recovery",7,Vector2(1570,420)],["kira","idle",0,Vector2(290,370)]]:
		var row: Dictionary = Data.actors()[probe[0]][probe[1]].frames[probe[2]]
		var drawing := art.frame(row)
		check(drawing.texture.get_image().get_pixelv(Vector2i(probe[3])).a > .9,"Regression landmark is part of the authored body")
		check(drawing.region.has_point(probe[3]),"Full head/foot remains inside the drawn frame: "+probe[0])
	var source_scales := {}
	for role in ["tominaga","kira"]:
		for clip in Data.actors()[role].values():
			for row in clip.frames:
				if source_scales.has(row.path): check(source_scales[row.path] == row.body_height,"Crouching and falling never rescale the same authored atlas")
				else: source_scales[row.path] = row.body_height
	var sim := node(13)
	for role in Data.ROLES:
		var kind := "boss" if role in ["udono","kira","tominaga"] else ("archer" if role=="archer_kira" else ("gunner" if role=="gunner" else "soldier"))
		var enemy := Encounter.spawn(sim,{"role":role,"kind":kind,"x":900,"y":500},1)
		enemy.moving=true
		var a:=art.sample(sim.state,enemy,0,0)
		var b:=art.sample(sim.state,enemy,12,12)
		check(a.clip.ends_with("walk") and a.cell!=b.cell,"authored walking cycles "+role)
	for number in [2,5,8,11,12]:
		sim=node(number)
		for prop in sim.state.props:
			if prop.mikawa_asset not in ["fence","cheval"]: continue
			var center:=Vector2(prop.x,prop.y)
			check(Encounter.barrier_blocks(prop,center-Vector2(400,0),center+Vector2(400,0)),"swept diagonal barrier "+prop.mikawa_asset)
	var bursts := {}
	for hero_kind in Battle.PLAYABLE_HEROES:
		sim=node(13)
		var hero: Dictionary=sim.state.fighters[0]
		var boss:=actor(sim,"udono")
		hero.kind=hero_kind
		var best: String="practice_"+hero_kind
		for key in Battle.Weapons.ITEMS:
			if Battle.Weapons.compatible(hero_kind,key) and Battle.Weapons.item(key).damage_bonus>Battle.Weapons.item(best).damage_bonus: best=key
		Equipment.equip(hero,Equipment.add(hero,best))
		hero.x=boss.x-100;hero.y=boss.y;hero.face=1;hero.invuln=600
		boss.cooldown=1000
		sim._begin(hero,"charge_rain" if hero_kind=="oichi" else "charged")
		for tick in 360:
			sim.state.tick+=1
			sim._tick_effects();sim._tick_fighter(hero);sim._tick_fighter(boss)
			check(boss.z==0 and not boss.airborne_lock and (boss.action!="launched" if hero_kind=="hideyoshi" else boss.action not in ["down","launched"]),"only Hideyoshi blink can knock Udono down; no charged move launches him "+hero_kind)
		bursts[hero_kind]={"weapon":best,"damage":boss.max_hp-boss.hp}
		check(boss.hp>0 and boss.hp<boss.max_hp,"best weapon charged burst hurts but never one-shots "+hero_kind)
	print("STAGE04 BURSTS "+JSON.stringify(bursts))

func run() -> void:
	combat_checks()
	assets_and_burst()
	audio_checks()
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],4)
	for section in 5:
		sim._enter_segment(section)
		for checkpoint in sim.state.stage.checkpoint_total:
			sim._start_checkpoint(checkpoint)
			check(Wire.valid_snapshot(sim.get_state()),"valid node %d"%sim.state.mikawa.node)
			for tick in 240:
				sim.step([{"dx":0,"dy":0,"buttons":0}])
				check(Wire.valid_snapshot(sim.get_state()),"valid tick %d node %d"%[tick,sim.state.mikawa.node])
	print("STAGE04 REBUILD PASS: %d checks"%checks)
	quit()
