extends SceneTree
const Battle = preload("res://core/battle.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Data = preload("res://core/stage05_data.gd")

func _initialize() -> void:
	for case in [[210,0,"ground",0],[210,35,"diagonal",47],[110,0,"sweep",47]]:
		var sim := Battle.new()
		sim.reset_campaign("normal",1,["nobunaga"],5)
		sim._enter_segment(3);sim._start_checkpoint(2)
		var boss: Dictionary=sim._fighter(sim.state.ikki.boss)
		var hero: Dictionary=sim.state.fighters[0]
		boss.entering=false;boss.x=2000;boss.y=500;boss.cooldown=case[3]
		hero.x=boss.x-case[0];hero.y=500;hero.z=case[1]
		S5.ai(sim,boss,hero)
		var action: String="s05_natsume_"+case[2]
		assert(boss.action==action,"Approach selects "+action+" immediately")
		var spec: Dictionary=Data.actors().natsume[action]
		var original: Dictionary=Data.read("actors.json").natsume[action]
		assert(spec.frames.size()==original.frames.size(),"Every original pose is retained")
		for i in spec.frames.size(): assert(spec.frames[i].path==original.frames[i].path)
		for tick in range(1,18):
			boss.action_tick=tick;S5.attack(sim,boss)
			assert(sim.state.effects.filter(func(e):return e.type=="s05_wave").is_empty(),"No wave before the blade release")
		boss.action_tick=18;S5.attack(sim,boss)
		var waves: Array=sim.state.effects.filter(func(e):return e.type=="s05_wave")
		assert(waves.size()==1 and waves[0].s05_asset==case[2],"One matching wave at 300 ms")
		var release_index := Data.frame_index(spec,300)
		assert(release_index==(6 if case[2]=="sweep" else 8),"Hit timing remains on the original release pose")
		boss.action_tick=ceili(Data.duration("natsume",action)*.06);S5.attack(sim,boss)
		assert(boss.action=="idle" and boss.cooldown==18,"Recovery finishes with a 300 ms cooldown")
		print("NATSUME_APPROACH_PASS ",case[2]," release=300ms duration=",spec.duration_ms," cooldown=300ms")
	quit()
