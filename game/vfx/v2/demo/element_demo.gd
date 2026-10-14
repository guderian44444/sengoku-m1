extends Node2D
const Emitter=preload("res://vfx/v2/effect_emitter.gd")
const Audio=preload("res://vfx/v2/audio/effect_audio_controller.gd")
var fx=Emitter.new()
var sound=Audio.new()
const FAMILIES=["blade","fire","ice","wind","lightning"]
var tick:=0
var cycle:=0
var family_index:=0
var charge_id:=""
var spin_id:=""
var paused:=false
func _ready() -> void:
	add_child(fx);add_child(sound)
	fx.configure();sound.configure("res://vfx/v2/audio/");fx.bind_audio(sound)
	_start_family()
func _start_family() -> void:
	fx.reset_scene()
	var family: String=FAMILIES[family_index]
	charge_id=family+":charge:"+str(cycle)
	spin_id=family+":spin:"+str(cycle)
	fx.trigger(charge_id,family+"_charged_wave",{"simulation_tick":tick})
	fx.trigger(spin_id,family+"_growing_spin",{"simulation_tick":tick})
func _physics_process(_delta: float) -> void:
	if paused:return
	tick+=1
	var local:=tick%216
	if local==0:
		family_index=(family_index+1)%5
		cycle+=1
		_start_family()
	if local==60: fx.release(charge_id,tick)
	if local==72: fx.confirmed_hit(charge_id,"demo-target:"+str(cycle),tick,{"position":Vector2(550,380)})
	fx.advance(charge_id,tick);fx.advance(spin_id,tick)
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode==KEY_SPACE:
		paused=not paused;fx.set_paused(paused)
	if event.keycode==KEY_ESCAPE:fx.reset_scene()
	if event.keycode==KEY_R:
		tick=0;cycle+=1;family_index=0;_start_family()
func _draw() -> void:
	fx.player.begin_draw(self)
	draw_rect(Rect2(0,0,1280,720),Color(.045,.065,.09))
	draw_string(ThemeDB.fallback_font,Vector2(30,42),"ELEMENT VFX + OWN AUDIO / "+str(FAMILIES[family_index]).to_upper(),0,-1,27,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(30,80),"SPACE pause/resume | ESC cancel effects and tails | R restart | VISUAL-ONLY TEST",0,-1,17,Color(.7,.8,.9))
	for i in range(2):
		var origin:=Vector2(310+i*640,440)
		var id:=charge_id if i==0 else spin_id
		fx.draw_instance(self,id,origin,false)
		draw_rect(Rect2(origin-Vector2(26,110),Vector2(52,125)),Color(.27,.33,.39))
		fx.draw_instance(self,id,origin,true)
	draw_string(ThemeDB.fallback_font,Vector2(100,585),"CHARGE: GATHER > RELEASE > CONFIRMED IMPACT",0,-1,19,Color(.95,.83,.6))
	draw_string(ThemeDB.fallback_font,Vector2(725,585),("GROWING ICE RING: .55 > 1.15 > 1.8" if FAMILIES[family_index]=="ice" else "2 TURNS: RADIUS .55 > 1.15 > 1.8 > FADE"),0,-1,19,Color(.95,.83,.6))
	draw_string(ThemeDB.fallback_font,Vector2(30,660),"Size changes are visual reach only. Existing battle collision/reload/damage remains untouched.",0,-1,18,Color(.7,.8,.9))
