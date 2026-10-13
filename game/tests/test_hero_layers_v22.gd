extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const HUD = preload("res://render/combat_hud.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const LayeredHeroSource = preload("res://render/layered_hero_source.gd")
const HEROES := ["nobunaga","oichi","tadakatsu"]
const ACTIONS := ["idle","walk","run","jump","light1","light2","light3","heavy1","heavy2","charge","charge_upper","charge_slam","charged","charged_upper","charged_slam","dash_heavy","dash_strike","rising","low_sweep","air_light","air_heavy","upper_heavy","ground_slam","mixed_finisher","mixed_rising","counter_cut","holding","throw","hurt","guard","grabbed","pulled","stunned","frozen","launched","down","recovering","defeated","victory","special"]
const TIMINGS := {"light":[6,19],"heavy":[14,36],"charged":[14,36],"rising":[6,24],"low_sweep":[9,28],"dash_strike":[10,30],"dash_heavy":[12,34],"air_light":[6,20],"air_heavy":[12,38],"upper_heavy":[12,36],"charged_upper":[22,56],"ground_slam":[14,42],"charged_slam":[28,72],"counter_cut":[5,24]}
var checks := 0
var failures := 0
var coverage: Dictionary = {}

class CaptureView extends View:
	var cards: Array = []
	var samples: Dictionary = {}
	var heading := ""
	var sample_clock := 0.0
	func _art_clock() -> float:
		return sample_clock
	func _fighter_animation(fighter: Dictionary) -> Dictionary:
		return samples[int(fighter.id)] if samples.has(int(fighter.id)) else super._fighter_animation(fighter)
	func live_sample(fighter: Dictionary) -> Dictionary:
		return super._fighter_animation(fighter)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color("323c39"))
		Typography.draw_label(self,Vector2(28,44),heading,26,Typography.GOLD)
		for index in range(cards.size()):
			var at := Vector2(320 + (index % 3) * 640,430 + (index / 3) * 460)
			draw_line(at - Vector2(220,0),at + Vector2(220,0),Color(.6,.7,.6,.2),1)
			_draw_art_fighter(cards[index],at)
			var sample: Dictionary = samples[int(cards[index].id)]
			var caption: String = cards[index].get("qa_caption","%d  %s  %d/%d  tick %d" % [index+1,sample.sheet,sample.frame+1,sample.count,cards[index].action_tick])
			Typography.draw_label(self,at + Vector2(-190,75),caption,17,Typography.PAPER)
		draw_set_transform(Vector2.ZERO)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func actor_case(battle: Battle, hero: String, name: String, index: int) -> Dictionary:
	var fighter := battle._make_fighter(0,hero,640,520,120)
	fighter.id = 100 + index
	fighter.player_index = 0
	fighter.moving = name in ["walk","run"]
	fighter.sprinting = name == "run"
	fighter.action = name
	if name in ["idle","walk","run","jump"]: fighter.action = "idle"
	if name.begins_with("light"):
		fighter.action = "light"
		fighter.combo = int(name[-1])
	if name.begins_with("heavy"):
		fighter.action = "heavy"
		fighter.heavy_combo = int(name[-1])
	if name in ["charge","charge_upper","charge_slam"]:
		fighter.action = "charge"
		fighter.charge_direction = {"charge":0,"charge_upper":-1,"charge_slam":1}[name]
		fighter.charge = index * 7
		fighter.action_tick = index * 7
	elif TIMINGS.has(fighter.action):
		var timing: Array = TIMINGS[fighter.action]
		if fighter.action == "charged" and hero == "tadakatsu": timing = [5,36]
		var hit := int(timing[0])
		var after := int(timing[1]) - hit
		# Stay inside each exposure interval; rounded live attack speed can put an
		# exact one-third boundary just before the next frame.
		var ticks: Array = [0,ceili(hit * .5),floori(hit * .84),hit,hit + ceili(after * .5),hit + ceili(after * .84)]
		fighter.action_tick = Battle.hero_tick(hero,ticks[index])
	elif name in ["walk","run"]: fighter.action_tick = 0
	else:
		var duration: int = {"idle":72,"hurt":18,"guard":24,"grabbed":18,"pulled":18,"stunned":48,"frozen":18,"down":24,"defeated":24,"recovering":36,"victory":120,"special":210,"holding":36,"throw":24,"mixed_finisher":48,"mixed_rising":48}.get(name,24)
		fighter.action_tick = int(index * (duration - 1) / 5.0)
	if name in ["jump","air_light","air_heavy","launched"]:
		fighter.z = 30
		fighter.vz = 9 - index * 3.6
	if name == "defeated": fighter.hp = 0
	if name == "frozen": fighter.freeze = 90
	return fighter

func run() -> void:
	var available_only := "--available" in OS.get_cmdline_user_args()
	var selected_hero := ""
	var selected_actions: Array = ACTIONS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="): selected_hero = argument.trim_prefix("--hero=")
		if argument.begins_with("--actions="):
			selected_actions = Array(argument.trim_prefix("--actions=").split(",",false))
	check(selected_hero.is_empty() or selected_hero in HEROES,"Requested hero is a v22 character")
	check(not selected_actions.is_empty(),"At least one action is requested")
	for action in selected_actions: check(action in ACTIONS,"Requested action exists: " + str(action))
	var capture := DisplayServer.get_name() != "headless"
	var selected: Array = []
	for hero in HEROES:
		if not selected_hero.is_empty() and hero != selected_hero: continue
		if FileAccess.file_exists("res://assets/v22/" + hero + "/registration.json"): selected.append(hero)
		elif not available_only: check(false,hero + " needs its complete v22 registration")
	if selected.is_empty():
		check(available_only,"At least one v22 hero is registered")
		print("HERO LAYERS V22 %s: %d checks, %d failures; no registered hero yet" % ["PASS" if failures == 0 else "FAILED",checks,failures])
		quit(1 if failures else 0)
		return
	root.content_scale_size = Vector2i(1920,1024)
	root.size = Vector2i(1920,1024)
	var view := CaptureView.new()
	root.add_child(view)
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v22/hero-actions")
	DirAccess.make_dir_recursive_absolute(output)
	var battle := Battle.new()
	for hero in selected:
		root.content_scale_size = Vector2i(1920,1024)
		root.size = Vector2i(1920,1024)
		coverage[hero] = {}
		var sheets: Dictionary = view._art.animations.get(hero,{})
		check(sheets.has("v22_idle"),hero + " v22 registration loads into runtime art")
		var portrait := HUD.portrait_spec(hero)
		check(str(portrait.file).begins_with(LayeredHeroSource.folder(hero)),hero + " HUD uses the same active character artwork")
		for sheet in sheets:
			if not str(sheet).begins_with("v22_"): continue
			check(sheets[sheet].size() == 6,hero + " " + sheet + " retains six drawn poses")
			for frame in sheets[sheet]:
				check(frame.source == "v22" and frame.layered_weapon and frame.body_height >= 280,hero + " " + sheet + " uses native high resolution weaponless body")
				check(frame.region.encloses(Rect2(frame.anchor,Vector2.ONE)),hero + " " + sheet + " foot anchor stays inside isolated texture")
		for action in selected_actions:
			coverage[hero][action] = []
			view.cards.clear()
			view.samples.clear()
			view.heading = "%s / %s / v0.22 native weapon layers" % [hero,action]
			for index in range(6):
				var actor := actor_case(battle,hero,action,index)
				view._walk_ticks[actor.id] = index * (7.5 if action == "run" else 10)
				view.sample_clock = index * .2
				var sample := view.live_sample(actor)
				coverage[hero][action].append({"source":sample.get("source","missing"),"sheet":sample.get("sheet","missing"),"frame":sample.get("frame",-1),"tick":actor.action_tick})
				if available_only and sample.get("source") != "v22": continue
				check(sample.get("source") == "v22" and sample.get("count") == 6,hero + " " + action + " never falls back to a legacy image")
				if sample.get("source") != "v22": continue
				var frame: Dictionary = view._art.animation_frame(hero,sample)
				var geometry: Dictionary = view._weapons.geometry(actor,frame,148 if hero == "oichi" else 155)
				check(not geometry.is_empty() if frame.get("weapon_visible",true) else geometry.is_empty(),hero + " " + action + " resolves equipped weapon pose")
				view.cards.append(actor)
				view.samples[actor.id] = sample
			if action in ["walk","run","light1","light2","light3","heavy1","heavy2","charged_upper","charged_slam"] and view.cards.size() == 6:
				var seen: Array = []
				for card in view.cards:
					if not seen.has(view.samples[card.id].frame): seen.append(view.samples[card.id].frame)
				check(seen.size() == 6,hero + " " + action + " advances through all six distinct drawings")
			view.state = {"tick":120,"phase":"playing","fighters":view.cards}
			if capture and not view.cards.is_empty():
				var original := var_to_bytes(view.state)
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(original == var_to_bytes(view.state),hero + " " + action + " drawing never mutates battle state")
				check(root.get_texture().get_image().save_png(output.path_join(hero + "-" + action + ".png")) == OK,hero + " " + action + " six-pose native capture")
		view.cards.clear()
		view.samples.clear()
		view.sample_clock = 0
		view.heading = "%s / all equipped weapons / identical body artwork" % hero
		var family_ids: Array = []
		for id in Weapons.ITEMS:
			if Weapons.compatible(hero,id): family_ids.append(id)
		check(family_ids.size() == Weapons.ids_for(hero).size(),hero + " covers every catalog-compatible weapon")
		family_ids.append(Weapons.default_for(hero))
		var equipment_height := 104 + ceili(float(family_ids.size()) / 3.0) * 460
		root.content_scale_size = Vector2i(1920,equipment_height)
		root.size = Vector2i(1920,equipment_height)
		var original_texture: Texture2D
		for index in range(family_ids.size()):
			var actor := actor_case(battle,hero,"idle",index)
			actor.weapon_id = family_ids[index]
			actor.face = -1 if index == family_ids.size() - 1 else 1
			actor.qa_caption = Weapons.name_for(actor) + (" / mirror" if index == family_ids.size() - 1 else "")
			var sample := view.live_sample(actor)
			var frame: Dictionary = view._art.animation_frame(hero,sample)
			if index == 0: original_texture = frame.texture
			check(frame.texture == original_texture,hero + " changing equipment keeps exactly the same body drawing")
			check(view._weapons.geometry(actor,frame,148 if hero == "oichi" else 155).get("id") == actor.weapon_id,hero + " renders the selected weapon and mirror")
			view.cards.append(actor)
			view.samples[actor.id] = sample
		view.state = {"tick":120,"phase":"playing","fighters":view.cards}
		if capture:
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join(hero + "-equipment.png")) == OK,hero + " all weapons and mirror native capture")
	view.queue_free()
	await process_frame
	var report_name := "coverage.json"
	if selected_actions.size() != ACTIONS.size(): report_name = "coverage-%s-%s.json" % [selected_hero, "-".join(selected_actions)]
	var report := FileAccess.open(output.path_join(report_name),FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"partial":available_only or selected_actions.size() != ACTIONS.size(),"checks":checks,"failures":failures,"heroes":coverage},"\t") + "\n")
		report.close()
	print("HERO LAYERS V22 %s: %d checks, %d failures; heroes=%s; partial=%s" % ["PASS" if failures == 0 else "FAILED",checks,failures,str(selected),str(available_only or selected_actions.size() != ACTIONS.size())])
	quit(1 if failures else 0)
