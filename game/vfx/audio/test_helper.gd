extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var helper = load("res://vfx/audio/special_audio.gd").new()
	root.add_child(helper)
	assert(helper.configure("res://vfx/audio/"))
	for actor in ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]:
		helper.begin_cast(actor, actor)
		assert(helper.active_voice_count == 1)
		var count: int = helper.speakers.size()
		helper.begin_cast(actor, actor)
		assert(helper.speakers.size() == count)
		helper.advance_cast(actor, 0)
		assert(helper.speakers.size() == count)
		var ticks: Array = helper.manifest.actors[actor].hit_ticks
		helper.advance_cast(actor, int(ticks[0]))
		assert(helper.speakers.size() == count + 1)
		helper.advance_cast(actor, int(ticks[0]))
		assert(helper.speakers.size() == count + 1)
		helper.advance_cast(actor, 210)
		assert(helper.speakers.size() == count + ticks.size())
		helper.set_audio_paused(true)
		for player in helper.speakers: assert(player.stream_paused)
		helper.set_audio_paused(false)
		helper.cancel_all()
		assert(helper.active_voice_count == 0 and helper.speakers.is_empty())
	assert(not helper.play_authored_voice("new", {"new_asset": null}))
	helper.begin_cast("new_no_legacy", "ieyasu", false)
	assert(helper.active_voice_count == 0)
	helper.cancel_all()
	helper.queue_free()
	await create_timer(0.2).timeout
	print("PASS six actors, single voice, hit cues, same-tick idempotence, skipped ticks, pause, cancel, missing slot silence")
	quit()
