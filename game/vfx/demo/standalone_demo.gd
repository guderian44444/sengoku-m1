extends Node2D
const Player = preload("res://vfx/vfx_player.gd")
var fx = Player.new()
var age: float = 0
func _ready() -> void:
	fx.load_catalog()
func _process(delta: float) -> void:
	age += delta * 60.0
	queue_redraw()
func _draw() -> void:
	fx.begin_draw(self)
	draw_rect(Rect2(0,0,1280,720),Color(.045,.07,.105))
	draw_string(ThemeDB.fallback_font,Vector2(30,45),"STANDALONE VFX / NO GAME OR CHARACTER DEPENDENCIES",0,-1,25,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(30,80),"Gray plate is an occlusion marker. Single authored textures + procedural motion.",0,-1,18,Color(.7,.8,.9))
	for i in range(3):
		var family: String = ["fire","blade","ice"][i]
		var position := Vector2(215+i*425,400)
		var options := {"size":320,"face":1,"flow_radians_per_second":TAU*2.0/(72.0/60.0)}
		var tick := fposmod(age,120.0)
		options.opacity = maxf(0,minf(1,minf(tick/6.0,(72-tick)/10.0)))
		fx.draw_pass(self,family+"_ring",tick,position,false,options)
		draw_rect(Rect2(position-Vector2(40,110),Vector2(80,160)),Color(.32,.37,.43))
		fx.draw_pass(self,family+"_ring",tick,position,true,options)
		fx.draw_pass(self,family+"_arc",fposmod(age,60.0),position-Vector2(0,120),true,{"size":240,"start_tick":12})
		draw_string(ThemeDB.fallback_font,position+Vector2(-90,150),family.to_upper(),0,-1,25,Color.WHITE)
