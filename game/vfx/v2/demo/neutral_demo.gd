extends Node2D
const Emitter=preload("res://vfx/v2/effect_emitter.gd")
const Audio=preload("res://vfx/v2/audio/effect_audio_controller.gd")
const Motion=preload("res://vfx/v2/weapon_motion.gd")
const RECIPES=["neutral_slash_arc","thrust_cone","arrow_trail","throwing_blade_trail","blunt_impact","guard_sparks","slash_hit","dash_dust"]
var fx=Emitter.new()
var sound=Audio.new()
var tick:=0
var generation:=0
var paused:=false
func _ready() -> void:
	add_child(fx);add_child(sound);fx.configure();sound.configure("res://vfx/v2/audio/");fx.bind_audio(sound);_begin()
func _begin() -> void:
	fx.reset_scene()
	var i:=(tick/60)%8
	var id:=str(generation)+":"+str(i)
	fx.trigger(id,RECIPES[i],{"simulation_tick":tick,"confirmed_contact":true,"contact_event_id":id,"projectile_spawn_id":id})
func _physics_process(_delta: float) -> void:
	if paused:return
	tick+=1
	if tick%60==0:generation+=1;_begin()
	if tick%60==55:
		fx.cancel(str(generation)+":2");fx.cancel(str(generation)+":3")
	for id: String in fx.instances.keys():fx.advance(id,tick)
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.keycode==KEY_SPACE:paused=not paused;fx.set_paused(paused)
		if event.keycode==KEY_ESCAPE:fx.reset_scene()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.04,.06,.09))
	draw_string(ThemeDB.fallback_font,Vector2(25,40),"NEUTRAL WEAPON MOTION / 8 RECIPES, 5 BASES / NO ELEMENT GLOW",0,-1,24,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(25,72),"Velocity-aligned tails, hand-to-tip arcs, confirmed contact sparks. Gray lines are geometry markers.",0,-1,16,Color(.7,.8,.9))
	for i in range(8):
		var id:=str(generation)+":"+str(i)
		var origin:=Vector2(155+(i%4)*320,300+(i/4)*300)
		var binding: Dictionary={}
		if i==0:
			var direction:=Vector2.from_angle(-1.2+float(tick%60)*.07)*80
			binding=Motion.slash_binding(origin,origin+direction,100)
			draw_line(origin,origin+direction,Color(.4,.46,.5),3,true)
		elif i==1:
			var direction:=Vector2(80,-25)
			binding=Motion.thrust_binding(origin-direction,origin,direction)
			draw_line(origin-direction,origin,Color(.4,.46,.5),3,true)
		elif i in [2,3]:
			var velocity:=Vector2(850, -250 if i==2 else 260)
			if generation%2==1:velocity.x*=-1
			binding=Motion.trail_binding(origin,velocity,.12 if i==2 else .08,180,.5)
			draw_line(origin-velocity.normalized()*20,origin+velocity.normalized()*8,Color(.5,.55,.58),3,true)
		var position: Vector2=binding.get("origin",origin)
		fx.draw_instance(self,id,position,false,binding)
		fx.draw_instance(self,id,position,true,binding)
		draw_string(ThemeDB.fallback_font,origin+Vector2(-140,58),str(RECIPES[i]),0,-1,17,Color(.95,.84,.64))
