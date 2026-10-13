extends SceneTree
const E=preload("res://vfx/v2/effect_emitter.gd")
const A=preload("res://vfx/v2/audio/effect_audio_controller.gd")
var e
var a
var canvas: Node2D
var cues=0
var draws=0
func _initialize() -> void: run.call_deferred()
func run() -> void:
 e=E.new();a=A.new();root.add_child(e);root.add_child(a)
 assert(e.configure() and a.configure("res://vfx/v2/audio/"))
 assert(e.player.catalog.size()==28 and e.player.textures.size()==28)
 assert(e.bind_audio(a) and e.bind_audio(a))
 e.audio_cue.connect(func(_id,_key,_op,_ctx):cues+=1)
 e.set_paused(true)
 for key in e.recipes:
  assert(e.trigger(key,key,{"simulation_tick":0,"confirmed_hit":true,"confirmed_shot":true,"shot_event_id":key,"confirmed_contact":true,"contact_event_id":key,"projectile_spawn_id":key,"face":-1,"layered":true}))
 assert(e.instances.size()==25 and a.players.size()<=12)
 for p in a.players: assert(p.stream_paused)
 canvas=Node2D.new();root.add_child(canvas);canvas.draw.connect(draw_all);canvas.queue_redraw()
 await process_frame;await process_frame
 assert(draws>0)
 var before=cues
 e.set_paused(false)
 for key in e.instances.keys():e.advance(key,30)
 for key in ["arrow_trail","throwing_blade_trail"]:
  var old=cues
  e.advance(key,600);e.advance(key,600)
  assert(cues==old and e.instances.has(key))
 assert(not e.trigger("same-arrow","arrow_trail",{"projectile_spawn_id":"arrow_trail"}))
 assert(not e.trigger("same-contact","guard_sparks",{"confirmed_contact":true,"contact_event_id":"guard_sparks"}))
 assert(not e.trigger("no-contact","blunt_impact",{}))
 e.reset_scene()
 assert(e.instances.is_empty() and a.players.is_empty() and a.loops.is_empty() and a.instances.is_empty())
 e.queue_free();a.queue_free();canvas.queue_free()
 await create_timer(.2).timeout
 print("PASS integrated: 28 textures/25 recipes; idempotent audio binding; all recipes front/back mirrored draw no audio emission; pause and 12-voice cap; projectile trail one-shot whoosh despite 600tick hold; contact/projectile dedup; reset stops all tails")
 quit()
func draw_all() -> void:
 var before=cues
 for key in e.instances:
  e.draw_instance(canvas,key,Vector2(300,300),false,{"face":-1,"rotation":.3})
  e.draw_instance(canvas,key,Vector2(300,300),true,{"face":-1,"rotation":.3})
 assert(cues==before)
 draws+=1
