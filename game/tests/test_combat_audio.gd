extends SceneTree
const CombatAudio = preload("res://render/combat_audio.gd")

func _initialize() -> void:
	var audio := CombatAudio.new()
	for kind in CombatAudio.EVENT_SOUNDS:
		var sound: AudioStreamWAV = audio._synthesize(kind)
		assert(sound.data.size() > 4000 and sound.mix_rate == 22050)
		var peak := 0
		for offset in range(0, sound.data.size(), 2):
			peak = maxi(peak, absi(sound.data.decode_s16(offset)))
		assert(peak > 500 and peak < 32767, "SFX must be audible without clipped samples")
	assert(audio._synthesize("shield_hit").data != audio._synthesize("hit").data, "Meat shield impacts need a distinct sound beneath the target's voice")
	audio.free()
	print("PASS: combat SFX, meat shield impact, bow release and unclipped special audio")
	quit()
