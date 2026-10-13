extends Node2D
const Adapter = preload("res://vfx/special_preset_adapter.gd")
var special = Adapter.new()
var age: float = 0
var paused := false
const HEROES = ["nobunaga","oichi","hideyoshi","ieyasu","mitsuhide","tadakatsu"]
func _process(delta: float) -> void:
	if not paused: age += delta * 60.0
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_SPACE: paused = not paused
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.04,.06,.09))
	draw_string(ThemeDB.fallback_font,Vector2(25,32),"SIX SPECIAL PRESETS / authoritative 210-tick timeline / VISUAL ONLY",0,-1,23,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(25,62),"Gray occlusion markers, not new character art. SPACE pauses. No collision or damage simulation.",0,-1,17,Color(.7,.8,.9))
	var tick := fposmod(age,270.0)
	for i in range(6):
		var hero: String = HEROES[i]
		var position := Vector2(120+(i%3)*425,310+(i/3)*310)
		var actor := {"kind":hero,"action":"special" if tick<210 else "idle","action_tick":tick,"face":1,"z":0}
		var hits: Array = special.presets[hero].hit_ticks_snapshot
		special.draw_special(self,actor,position,105,false,hits)
		draw_rect(Rect2(position-Vector2(20,100),Vector2(40,100)),Color(.32,.37,.42))
		special.draw_special(self,actor,position,105,true,hits)
		draw_string(ThemeDB.fallback_font,position+Vector2(-80,45),hero.to_upper(),0,-1,20,Color.WHITE)
		draw_string(ThemeDB.fallback_font,position+Vector2(-80,68),"tick "+str(int(tick))+" / hits "+str(hits),0,-1,12,Color(.7,.8,.9))
