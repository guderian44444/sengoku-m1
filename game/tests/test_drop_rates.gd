extends SceneTree
const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

class App extends Main:
	func _save_characters(_manual: bool = false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks+=1;assert(ok,label)

func battle(rates: Dictionary) -> Battle:
	var sim:=Battle.new();sim.drop_rates=rates.duplicate()
	sim.reset_campaign("normal",1,["nobunaga"],2);sim.state.drops.clear()
	return sim

func defeat(sim: Battle, kind: String, major: bool = false, hungry: bool = false) -> void:
	var hero: Dictionary=sim.state.fighters[0]
	hero.hp=hero.max_hp/2 if hungry else hero.max_hp
	var target:=sim._make_fighter(1,kind,700,500,40);target.stage_boss=major
	sim.state.fighters=[hero,target]
	check(sim._damage(target,10000,hero.id,false,false,true),"Actual fatal hit resolves")

func run():
	var zero:={"major":0,"minor":0,"prop":0,"food":0}
	var full:={"major":100,"minor":100,"prop":100,"food":100}
	for kind in ["soldier","flag","commander","archer","gunner"]:
		var sim:=battle(full);defeat(sim,kind,false,true)
		check(sim.state.drops.size()==1 and sim.state.drops[0].kind=="food","Every grunt class drops only food, even with all equipment chances at 100%")
	for major in [false,true]:
		var sim:=battle(zero);defeat(sim,"boss",major)
		check(sim.state.drops.is_empty(),"Zero percent prevents boss equipment")
		var rates:=zero.duplicate();rates["major" if major else "minor"]=100
		sim=battle(rates);defeat(sim,"boss",major)
		check(sim.state.drops.any(func(d):return d.kind=="weapon") and sim.state.drops.any(func(d):return d.kind=="talisman"),"Each boss class uses its own shared weapon/charm probability")
	for rate in [0,100]:
		var rates:=zero.duplicate();rates.prop=rate
		var sim:=battle(rates)
		var prop: Dictionary=sim.state.props[0];prop.drop="weapon";prop.hp=1
		sim._damage_prop(prop,10000,sim.state.fighters[0].id)
		check(sim.state.drops.size()==(1 if rate==100 else 0),"Objects use the object equipment chance")
		var food_rates:=zero.duplicate();food_rates.food=rate
		sim=battle(food_rates);defeat(sim,"soldier",false,true)
		check(sim.state.drops.size()==(1 if rate==100 else 0),"Food chance is configurable independently")
	var sim:=battle(full);defeat(sim,"soldier")
	check(sim.state.drops.is_empty(),"Food retains the low-health condition")
	var hero: Dictionary=sim.state.fighters[0]
	hero.performance={"strike_hits":3};hero.performance_awards=[];hero.achievements=[]
	sim._check_achievements()
	check(sim.state.drops.is_empty() and sim.state.events.any(func(e):return e.type=="achievement" and not e.loot),"Achievements notify without dropping equipment")
	check(Wire.valid_snapshot(sim.get_state()),"Drop rates synchronize with the authoritative battle")
	for invalid in [-1,101,5.5,NAN]:
		var bad:=sim.get_state();bad.drop_rates.major=invalid
		check(not Wire.valid_snapshot(bad),"Invalid network rates are rejected")
	var app:=App.new();root.add_child(app);app.set_physics_process(false);app.audio.stop_music()
	app._show_menu_page("engineering")
	for frame in 4: await process_frame
	check(app.drop_rate_controls.size()==4,"Engineering exposes exactly three equipment rates and one food rate")
	var configured:={"major":61,"minor":37,"prop":18,"food":42}
	for key in configured:
		var control: SpinBox=app.drop_rate_controls[key]
		check(control.min_value==0 and control.max_value==100 and control.step==1,"Rate controls stay within zero to one hundred percent")
		control.value=configured[key]
		check(app.sim.state.drop_rates[key]==configured[key],"UI changes the actual battle rate")
		check(Rect2(0,0,1280,666).encloses(control.get_global_rect()),"Rate controls fit the menu")
	app.sim.drop_rates=zero.duplicate();app._load_drop_rates()
	check(app.sim.drop_rates==configured,"Saved percentages reload independently of character progress")
	app.sim.reset_campaign()
	check(app.sim.state.drop_rates==configured,"New sorties retain the saved settings")
	check(app._set_drop_rate("major",101)==ERR_INVALID_PARAMETER and app._set_drop_rate("food",NAN)==ERR_INVALID_PARAMETER,"Invalid settings cannot reach disk or the simulation")
	app.active=true;app.session="client";app.sim.state.drop_rates=full.duplicate();app._refresh_drop_rates()
	check(not app.drop_rate_controls.major.editable and app.drop_rate_controls.major.value==100,"Clients display the host's synchronized percentage read-only")
	check(app._set_drop_rate("major",0)==ERR_UNAUTHORIZED and app.sim.state.drop_rates.major==100,"Clients cannot override host drop rules")
	app.active=false;app.session="solo";app._show_menu_page("engineering")
	for frame in 4: await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		var output:=OS.get_environment("TEST_ARTIFACT_DIR")
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("engineering-drop-rates.png"))==OK,"Native engineering screenshot saved")
	app.queue_free();await process_frame
	print("DROP_RATES_PASS %d checks"%checks);quit()
