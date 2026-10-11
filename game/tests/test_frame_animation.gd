extends SceneTree

const Frames = preload("res://render/frame_animation.gd")

func _init() -> void:
	for clip in ["light", "heavy", "special"]:
		var spec: Dictionary = Frames.CLIPS[clip]
		var before := Frames.sample(clip, spec.hit - 0.01)
		var impact := Frames.sample(clip, spec.hit)
		assert(before.frame == int(spec.count) / 2 - 1 and not before.released)
		assert(impact.frame == int(spec.count) / 2 and impact.released, "Impact must align with core tick: " + clip)
		var visited: Array = []
		for tick in range(spec.duration):
			var frame: int = Frames.sample(clip, tick).frame
			if not visited.has(frame): visited.append(frame)
		assert(visited.size() == spec.count, "Every attack frame must be played")
		assert(Frames.sample(clip, spec.duration + 100).frame == spec.count - 1)
	var expected := [0, 1, 2, 3, 2, 1, 0]
	for index in range(expected.size()):
		assert(Frames.sample("idle", index * 10).frame == expected[index])
		assert(Frames.sample("charge", index * 10).frame == expected[index])
	for index in range(5):
		assert(Frames.sample("walk", index * 7.5).frame == index % 4)
	assert(Frames.jump_sample(1, 9).frame == 0)
	assert(Frames.jump_sample(65, 3).frame == 1)
	assert(Frames.jump_sample(65, -3).frame == 2)
	assert(Frames.jump_sample(10, -7).frame == 3)
	assert(Frames.demo_sample(2, 0.0).clip == "idle")
	var impact_progress: float = (Frames.DEMO_HOLD + 14.0 / (60.0 * Frames.DEMO_SPEED)) / Frames.DEMO_SECONDS
	assert(Frames.demo_sample(2, impact_progress + 0.00001).frame == 4)
	assert(Frames.demo_sample(2, 0.95).clip == "idle")
	assert(Frames.demo_sample(1, 0.45).clip == "idle", "Short light attack must finish promptly")
	assert(Frames.demo_sample(7, 0.5).clip == "special")
	assert(Frames.demo_sample(9, 0.5, 0.125).clip == "walk")
	assert(Frames.demo_sample(9, 0.5, 0.125).frame == 1)
	var impact_cells := [2, 6, 10]
	for stage in range(1, 4):
		assert(not Frames.combo_sample(stage, 5.99).released)
		var impact := Frames.combo_sample(stage, 6)
		assert(impact.released and impact.cell == impact_cells[stage - 1])
		assert(impact.duration == 19 and impact.combo_stage == stage)
		var cells := []
		for tick in range(19):
			var cell: int = Frames.combo_sample(stage, tick).cell
			if not cells.has(cell): cells.append(cell)
		assert(cells.size() == 4)
		assert(impact.sheet == "combo")
	for hero in ["nobunaga", "oichi"]:
		var heavy_before := Frames.heavy_chain_sample(2, 13.99, hero)
		var heavy_impact := Frames.heavy_chain_sample(2, 14, hero)
		assert(not heavy_before.released and heavy_before.frame == (3 if hero == "nobunaga" else 1))
		assert(heavy_impact.released and heavy_impact.frame == (4 if hero == "nobunaga" else 2))
		assert(heavy_impact.cell == (10 if hero == "oichi" else 4) and heavy_impact.duration == 36)
		assert(heavy_impact.sheet == ("special" if hero == "nobunaga" else "combo"))
		assert(Frames.heavy_chain_sample(1, 14, hero).sheet == "attacks")
	for clip in Frames.CLIPS:
		for tick in range(300):
			var result := Frames.sample(clip, tick)
			assert(result.frame >= 0 and result.frame < result.count)
			assert(result.cell >= 0 and result.cell < 12)
	print("PASS: all animation frames, exact hit ticks, loop order, jump phase and quick demo timing")
	quit()
