extends SceneTree
const VFX=preload("res://vfx/vfx_player.gd")
const Special=preload("res://vfx/special_preset_adapter.gd")
var layer: Node2D
var draw_count := 0
var fx = VFX.new()
var special = Special.new()
func _initialize() -> void:
 assert(fx.load_catalog())
 assert(fx.catalog.size()==13 and fx.textures.size()==13)
 for key in fx.catalog:
  var spec: Dictionary=fx.catalog[key]
  assert(spec.frames==1)
  for tick in [0.0,0.5,1.0,10.0,float(spec.duration_ticks)-0.001]:
   var s: Dictionary=VFX.sample(spec,tick)
   assert(s.frame==0 and s.next==0 and s.mix==0)
   assert(s.alpha >=0 and s.alpha<=1)
  assert(VFX.sample(spec,-0.001).is_empty())
  if not spec.loop: assert(VFX.sample(spec,spec.duration_ticks).is_empty())
 assert(VFX.anchored(Vector2(100,100),Vector2(30,-60),1,155)==Vector2(130,40))
 assert(VFX.anchored(Vector2(100,100),Vector2(30,-60),-1,310)==Vector2(40,-20))
 assert(special.presets.size()==6)
 layer=Node2D.new()
 root.add_child.call_deferred(layer)
 layer.draw.connect(_draw_test)
 _deferred.call_deferred()
func _deferred() -> void:
 layer.queue_redraw()
 await process_frame
 await process_frame
 assert(draw_count>0)
 print("PASS independent QA: 13 loaded textures, single-frame stable alpha weights, timing boundaries, scale/mirror anchors, 6 special adapters; draw callbacks executed, no GPU pixels verified")
 quit()
func _draw_test() -> void:
 draw_count+=1
 for key in fx.catalog:
  for front in [false,true]:
   for face in [-1,1]:
    fx.draw_pass(layer,key,10.0,Vector2(100,100),front,{"face":face,"opacity":0.5,"rotation":0.2,"size":240.0})
 for hero in special.presets:
  var fighter: Dictionary={"kind":hero,"action":"special","action_tick":30,"face":-1,"z":10}
  var before := JSON.stringify(fighter)
  special.draw_special(layer,fighter,Vector2(200,200),155.0,false,special.presets[hero].hit_ticks_snapshot)
  special.draw_special(layer,fighter,Vector2(200,200),155.0,true,special.presets[hero].hit_ticks_snapshot)
  assert(JSON.stringify(fighter)==before)
