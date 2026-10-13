extends RefCounted
## All vectors are in one world/canvas coordinate space AFTER face + body rotation.
## Returning face=1 prevents double mirroring when velocity or weapon tip is already world-facing.
static func slash_binding(hand: Vector2, tip: Vector2, reference_radius: float = 100) -> Dictionary:
	var direction:=tip-hand
	return {"origin":hand,"face":1,"rotation":direction.angle(),"size_multiplier":direction.length()/maxf(1,reference_radius),"stretch":Vector2.ONE}

static func thrust_binding(hand: Vector2, tip: Vector2, velocity: Vector2 = Vector2.ZERO) -> Dictionary:
	var direction:=tip-hand
	if direction.length_squared()<0.0001: direction=velocity
	return {"origin":tip,"face":1,"rotation":direction.angle(),"size_multiplier":clampf(direction.length()/110.0,.6,2.5),"stretch":Vector2(1,.65)}

static func trail_binding(position: Vector2, velocity: Vector2, exposure_seconds: float = .08, base_length: float = 180, thickness: float = .5) -> Dictionary:
	var speed:=velocity.length()
	if speed<.01:return {"visible":false,"origin":position,"face":1,"rotation":0.0,"size_multiplier":0.0}
	var length:=clampf(speed*exposure_seconds,12,240)
	return {"visible":true,"origin":position,"face":1,"rotation":velocity.angle(),"size_multiplier":length/maxf(1,base_length),"stretch":Vector2(1,thickness)}

static func muzzle_anchor(ground: Vector2, local_muzzle: Vector2, body_height: float, frame_body_height: float, face: float, z: float = 0, camera_x: float = 0, body_rotation: float = 0) -> Vector2:
	var local:=local_muzzle*body_height/maxf(1,frame_body_height)
	return ground-Vector2(camera_x,z)+(local*Vector2(-1 if face<0 else 1,1)).rotated(body_rotation)
