extends SceneTree
const ArtDemo = preload("res://render/art_demo.gd")

func _initialize() -> void:
	var demo := ArtDemo.new()
	var poses := {}
	var weather := {}
	for frame in range(1450):
		poses[demo.pose()] = true
		weather[demo.weather()] = true
		var world := demo.world()
		assert(world.fighters.size() == 2)
		assert(world.fighters[0].kind == "nobunaga" and world.fighters[1].kind == "oichi")
		assert(world.fighters[0].z >= 0)
		if demo.pose() != 9: assert(world.fighters[0].x == 330.0, "Stationary poses must not fake movement by translating the image")
		demo.step(1.0 / 60.0)
	assert(poses.size() == 10 and weather.size() == 3)
	demo.running = false
	var stopped := demo.elapsed
	demo.step(8.0)
	assert(demo.elapsed == stopped)
	demo.seek(-1)
	assert(demo.pose() == 9)
	demo.seek(10)
	assert(demo.pose() == 0)
	demo.facing = -1
	assert(demo.world().fighters[0].face == -1)
	demo.weather_override = 2
	demo.seek(0)
	assert(demo.weather() == 2)
	demo.running = true
	demo.speed = 0.5
	stopped = demo.elapsed
	demo.step(2.0)
	assert(is_equal_approx(demo.elapsed - stopped, 1.0))
	print("PASS: 10 poses / 2 heroes / 3 weather states / pause / seek / facing / slow speed / fixed feet")
	quit()
