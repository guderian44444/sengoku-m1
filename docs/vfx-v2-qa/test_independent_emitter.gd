extends SceneTree
const E=preload("res://vfx/v2/effect_emitter.gd")
const C=preload("res://vfx/v2/phase_curves.gd")
var events: Array=[]
var e
var canvas: Node2D
var draw_checks=0
func _initialize() -> void: run.call_deferred()
func count_key(key: String) -> int:
 var n=0
 for event in events:
  if event[1]==key: n+=1
 return n
func run() -> void:
 assert(C.valid([[0,1],[.5,2],[1,4]]))
 assert(not C.valid([[.5,1],[.5,2]]))
 assert(is_equal_approx(C.integral([[0,0],[1,2]],.5),.25))
 assert(is_equal_approx(C.integral([[0,0],[1,2]],2),3.0))
 e=E.new();root.add_child(e)
 assert(e.configure())
 e.audio_cue.connect(func(id,key,op,ctx): events.append([id,key,op,ctx]))
 assert(e.trigger("spin","fire_growing_spin",{"simulation_tick":100}))
 assert(not e.trigger("spin","fire_growing_spin",{}))
 var initial=count_key("fire_release")
 e.advance("spin",135);assert(count_key("fire_release")==initial)
 e.advance("spin",136);assert(count_key("fire_release")==initial+1)
 e.advance("spin",136);assert(count_key("fire_release")==initial+1)
 e.advance("spin",120);assert(e.instances.spin.last_tick==136)
 assert(e.confirmed_hit("spin","target1",140))
 assert(e.instances.spin.last_tick==140)
 assert(not e.confirmed_hit("spin","target1",140))
 assert(not e.confirmed_hit("spin","target2",139))
 e.set_paused(true);e.advance("spin",150);assert(e.instances.spin.last_tick==140)
 assert(not e.confirmed_hit("spin","target2",150))
 e.set_paused(false)
 canvas=Node2D.new();root.add_child(canvas);canvas.draw.connect(draw_test);canvas.queue_redraw()
 await process_frame;await process_frame
 assert(draw_checks>0)
 e.advance("spin",172);assert(is_equal_approx(e.instances.spin.uv_offset_radians,TAU*2.0))
 e.advance("spin",190);assert(not e.instances.has("spin") and e.retired.has("spin"))
 var before=events.size();e.cancel("spin");assert(events.size()==before+1 and events[-1][2]=="stop_all")
 assert(not e.trigger("spin","fire_growing_spin",{}))
 assert(e.trigger("charge","fire_charged_wave",{"simulation_tick":200}))
 e.advance("charge",1200);assert(e.instances.charge.phase=="charge")
 assert(not e.confirmed_hit("charge","invalid",1200))
 assert(e.release("charge",1200));assert(e.instances.charge.phase=="release")
 assert(not e.release("charge",1200))
 e.reset_scene();assert(e.instances.is_empty() and e.retired.is_empty())
 assert(e.trigger("spin","fire_growing_spin",{"simulation_tick":2000}))
 e.reset_scene()
 var custom=e.recipes.fire_growing_spin.duplicate(true)
 custom.phases.release.duration_ticks=10
 custom.phases.release.next=""
 custom.phases.release.cues=[{"tick":9,"phase":"release"}]
 e.recipes["late_edge"]=custom
 assert(e.trigger("late","late_edge",{"simulation_tick":0}))
 var releases=count_key("fire_release")
 e.advance("late",1000)
 assert(count_key("fire_release")==releases)
 e.reset_scene();e.queue_free();canvas.queue_free()
 await process_frame
 print("PASS independent lifecycle: curve integral, hold/release, duplicate trigger/hit/cue, absolute tick crossing, backward rejection, pause, retired-tail cancellation, reset, draw silence")
 quit()
func draw_test() -> void:
 var before=events.size()
 e.draw_instance(canvas,"spin",Vector2(100,100),false,{"face":-1})
 e.draw_instance(canvas,"spin",Vector2(100,100),true,{"face":-1})
 assert(events.size()==before)
 draw_checks+=1
