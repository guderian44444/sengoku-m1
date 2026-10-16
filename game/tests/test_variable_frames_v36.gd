extends SceneTree

const Source = preload("res://render/layered_hero_source.gd")
const Art = preload("res://render/art_assets.gd")
const FrameAnimation = preload("res://render/frame_animation.gd")
const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func _initialize() -> void:
	var art := Art.new()
	var folder := Source.folder("nobunaga")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"registration.json"))
	for count in [1,2,5,7,10,24]:
		var frames := []
		for index in range(count):
			var frame: Dictionary = original.clips.walk.frames[index%6].duplicate(true)
			frame.duration_ms = 30+index*10
			frames.append(frame)
		var manifest := {"version":"current","complete":true,"clips":{"walk":{"frames":frames,"loop":true},"down":{"frames":frames,"loop":false}}}
		check(Source.complete_registration(manifest),"Accept nonempty variable count %d" % count)
		art.load_layered_hero_registration("fixture",folder,manifest)
		var sheets: Dictionary = art.animations.fixture
		check(sheets.v22_walk.size()==count,"Loader preserves every pose")
		var elapsed := 0.0
		for index in range(count):
			var fighter := {"kind":"fixture","action":"idle","moving":true,"locomotion_tick":(elapsed+1)*.06}
			check(FrameAnimation.hero_v22_sample(fighter,sheets).frame==index,"Authored unequal hold timing")
			fighter.locomotion_tick = elapsed*.06
			check(FrameAnimation.hero_v22_sample(fighter,sheets).frame==index,"Exact duration boundary advances pose")
			elapsed += float(frames[index].duration_ms)
		check(FrameAnimation.hero_v22_sample({"kind":"fixture","action":"idle","moving":true,"locomotion_tick":(elapsed+1)*.06},sheets).frame==0,"Loop wraps")
		var down := {"kind":"fixture","action":"down","action_tick":10000,"down_from_air":true}
		check(FrameAnimation.hero_v22_sample(down,sheets).frame==count-1,"Terminal hold and odd/single counts")
		frames[0].duration_ms = 0
		check(not Source.complete_registration(manifest),"Reject zero duration")
		frames[0].duration_ms = "30"
		check(not Source.complete_registration(manifest),"Reject nonnumeric duration")
		frames[0].erase("duration_ms")
		if count>1: check(not Source.complete_registration(manifest),"Reject mixed timed and untimed frames")
	check(not Source.complete_registration({"version":"current","complete":true,"clips":{"walk":{"frames":[]}}}),"Reject empty clip")
	check(Source.complete_registration(original),"Legacy untimed assets unchanged")
	for hero in Moves.HEROES:
		var registration := Moves.registration(hero)
		for action in ["heavy","light"]:
			var clip := "light_1" if action=="light" else "heavy"
			var backup: Dictionary = registration.clips[clip].duplicate(true)
			var baseline := chain_tick(hero,action)
			if hero=="oichi" and action=="heavy": check(baseline>=27 and baseline<=28,"Oichi heavy keeps the 0.45 second commitment")
			# Add a long visual tail: buffered input must still cancel at the same tick.
			registration.clips[clip].frames[-1].duration_ms += 5000
			registration.clips[clip].duration_ms += 5000
			check(chain_tick(hero,action)==baseline,"Animation tail never delays buffered input: "+hero+" "+action)
			registration.clips[clip] = backup
	print("VARIABLE FRAMES V36 PASS: %d checks" % checks)
	quit()

func chain_tick(hero: String, action: String) -> int:
	var battle := Battle.new()
	battle.reset_training(hero,"dummy")
	var fighter: Dictionary = battle.state.fighters[0]
	fighter.combo = 1
	fighter.combo_tick = roundi(Battle.fighter_tick(fighter,19)*Battle.LIGHT_TIME_SCALE)+24
	battle._begin(fighter,action)
	for tick in range(1,180):
		battle.step([{"buttons":Battle.LIGHT if tick==2 else 0,"dx":0,"dy":0}])
		if fighter.action=="light" and (action!="light" or fighter.combo==2):
			check(tick<120,"Buffered action starts during recovery: "+hero)
			return tick
	check(false,"Queued light was lost: "+hero)
	return -1
