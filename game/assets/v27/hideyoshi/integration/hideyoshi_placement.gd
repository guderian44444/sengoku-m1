class_name HideyoshiPlacement
extends RefCounted
## Proposed integration helper; not installed or native-game tested.
## Placement JSON contains per-frame per-item measured grips. Do not rescale swords.
static func effective_grip(item: Dictionary, placement: Dictionary) -> Vector2:
 var original := Vector2(item.grip[0], item.grip[1])
 var offset: Array = placement.get("weapon_grip_offset_normalized", [0.0, 0.0])
 return original + Vector2(offset[0], offset[1]) * float(item.length)

static func body_local_to_world(p: Array, frame: Dictionary, root: Vector2, face: float = 1.0, world_height: float = 155.0) -> Vector2:
 var foot := Vector2(frame.foot[0], frame.foot[1])
 var delta := (Vector2(p[0], p[1]) - foot) * world_height / float(frame.body_height)
 delta.x *= face
 return root + delta

static func blade_inside_sheath(world_point: Vector2, mouth: Vector2, inward: Vector2) -> bool:
 ## Clip only the inserted blade beyond the entrance plane; retain hilt outside.
 return (world_point - mouth).dot(inward.normalized()) > 0.0
