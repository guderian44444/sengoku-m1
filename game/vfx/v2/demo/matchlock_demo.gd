extends Node2D
const Emitter=preload("res://vfx/v2/effect_emitter.gd")
const Audio=preload("res://vfx/v2/audio/effect_audio_controller.gd")
var fx=Emitter.new()
var sound=Audio.new()
var tick:=0
var generation:=0
var origins: Dictionary={}
var paused:=false
func _ready() -> void:
	add_child(fx);add_child(sound);fx.configure();sound.configure("res://vfx/v2/audio/");fx.bind_audio(sound)
	_shot("hero",Vector2(300,280),1,0)
func _shot(kind: String, origin: Vector2, face: int, distance: float) -> void:
	var id:="gun:"+str(generation)+":"+str(tick)
	origins[id]=origin
	fx.trigger(id,kind+"_matchlock",{"simulation_tick":tick,"confirmed_shot":true,"shot_event_id":id,"face":face,"distance":distance,"variant":0})
func _physics_process(_delta: float) -> void:
	if paused:return
	tick+=1
	if tick%480==0:
		generation+=1;fx.reset_scene();origins.clear();_shot("hero",Vector2(300,280),1,0)
	var local:=tick%480
	if local==120:_shot("enemy",Vector2(930,280),-1,0)
	if local>=240 and local<=267 and (local-240)%3==0:
		var i:=(local-240)/3
		_shot("enemy",Vector2(100+i*42,520),1,.35)
	if local==360:_shot("hero",Vector2(970,520),-1,1)
	for id: String in fx.instances.keys():fx.advance(id,tick)
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.keycode==KEY_SPACE:paused=not paused;fx.set_paused(paused)
		if event.keycode==KEY_ESCAPE:fx.reset_scene()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.04,.06,.09))
	draw_string(ThemeDB.fallback_font,Vector2(25,42),"MATCHLOCK / HERO + ENEMY / SINGLE SHOT EVENTS",0,-1,28,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(25,80),"SPACE pause | ESC stop all tails | Gray lines mark barrels, not finished character art.",0,-1,17,Color(.7,.8,.9))
	for origin in [Vector2(300,280),Vector2(930,280),Vector2(970,520)]:
		var face:=-1 if origin.x>600 else 1
		draw_line(origin-Vector2(face*140,0),origin,Color(.4,.46,.5),9,true)
	for i in range(10):draw_line(Vector2(75+i*42,520),Vector2(100+i*42,520),Color(.4,.46,.5),5,true)
	for id: String in fx.instances:
		fx.draw_instance(self,id,origins[id],false)
		fx.draw_instance(self,id,origins[id],true)
	draw_string(ThemeDB.fallback_font,Vector2(100,360),"HERO: stronger crack, body, sparks and powder tail",0,-1,18,Color(.96,.83,.6))
	draw_string(ThemeDB.fallback_font,Vector2(730,360),"ENEMY: shorter / lower-cost / mirrored muzzle",0,-1,18,Color(.96,.83,.6))
	draw_string(ThemeDB.fallback_font,Vector2(70,600),"10 ENEMY SHOTS / 3 ticks apart",0,-1,19,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(800,600),"DISTANT HERO / -12 dB",0,-1,19,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(25,670),"No reload, penetration or damage rules changed. A trigger requires a unique confirmed shot event.",0,-1,17,Color(.7,.8,.9))
