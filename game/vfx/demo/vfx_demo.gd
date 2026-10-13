extends "res://render/battle_view.gd"
## Isolated art/adapter demonstration. Does NOT run or alter battle simulation.
const VFX = preload("res://vfx/vfx_player.gd")
var shared_fx = VFX.new()
var demo_tick: float = 0.0
var paused: bool = false
var family_index: int = 0
var families := ["fire","blade","ice"]
var demo_facing: int = 1

func _ready() -> void:
	shared_fx.load_catalog()
	state = {"tick":0,"fighters":[],"effects":[],"drops":[],"props":[],"civilian_flee_tick":0}
	for i in range(3):
		state.fighters.append({"id":i+1,"kind":["ieyasu","nobunaga","oichi"][i],"team":0,"x":240+i*400,"y":540,"z":0,"vz":0,"face":1,"action":"heavy","action_tick":0,"hp":100,"max_hp":100,"combo":1,"heavy_combo":1})

func _process(delta: float) -> void:
	if not paused: demo_tick += delta * 60.0
	state.tick = int(demo_tick)
	for i in range(state.fighters.size()):
		var fighter: Dictionary = state.fighters[i]
		fighter.face = demo_facing if i != 1 else -demo_facing
		fighter.action = "charge" if i == 0 else ("charged_upper" if i == 2 else "heavy")
		var duration := 56.0 if i == 2 else 36.0
		fighter.action_tick = int(fposmod(demo_tick,duration + 30.0))
		if fighter.action_tick >= duration: fighter.action = "idle"
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_SPACE: paused = not paused
	if event.keycode == KEY_F: demo_facing *= -1
	if event.keycode == KEY_TAB: family_index = (family_index + 1) % families.size()
	if event.keycode == KEY_R: demo_tick = 0.0

func _draw_hero_power(fighter: Dictionary, ground: Vector2, height: float, pose: Dictionary, front: bool) -> void:
	var family: String = families[family_index]
	var index := int(fighter.id) - 1
	var age := fposmod(demo_tick,86.0 if index == 2 else 66.0)
	var origin := ground - Vector2(0,float(fighter.get("z",0)))
	if index == 0:
		var spin_tick := fposmod(demo_tick,120.0)
		if spin_tick >= 72.0: return
		# Two independent layers, BOTH complete two full temporal rotations in 72 ticks.
		# Two independent rings share a stable screen-horizontal depth seam.
		for ring in range(2):
			shared_fx.draw_pass(self,family + "_ring",spin_tick,origin-Vector2(0,45 + ring*48),front,{"face":fighter.face,"size":height*(2.0-ring*.3),"flow_radians_per_second":TAU * 2.0 / (72.0 / 60.0),"opacity":minf(1.0,minf(spin_tick/6.0,(72.0-spin_tick)/10.0))})
	elif index == 1:
		var frame := _art.animation_frame(str(fighter.kind),pose)
		var geometry := _weapons.geometry(fighter,frame,height)
		var local: Vector2 = geometry.get("top",Vector2(75,-90))
		var tip := origin + local * Vector2(float(fighter.face),1)
		shared_fx.draw_pass(self,family+"_arc",float(pose.tick),tip,front,{"start_tick":14,"face":fighter.face,"size":height*1.4})
	else:
		shared_fx.draw_pass(self,("blue_white_wave" if family == "fire" else family+"_wave"),float(pose.tick),origin+Vector2(float(fighter.face)*35,-65),front,{"start_tick":22,"face":fighter.face,"size":height*1.8,"velocity":Vector2(0,-80)})

func _draw() -> void:
	super._draw()
	draw_rect(Rect2(0,0,1280,130),Color(0.015,0.025,0.04,.92))
	draw_string(ThemeDB.fallback_font,Vector2(35,42),"SHARED VFX / " + families[family_index].to_upper() + " / ISOLATED ENGINE DEMO",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(35,76),"TAB: family  |  F: mirror  |  SPACE: pause  |  R: restart",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(.75,.85,1))
	draw_string(ThemeDB.fallback_font,Vector2(35,106),"Fire/blade: 2 turns / 72 ticks        Weapon-tip anchor                 Charged rising wave",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(.9,.8,.55))
