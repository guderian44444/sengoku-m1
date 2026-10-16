extends RefCounted

const ROOT := "res://assets/current/heroes/"

static func complete_registration(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != "current" or not value.get("complete",false): return false
	var clips: Variant = value.get("clips")
	if not clips is Dictionary or clips.is_empty(): return false
	for clip in clips.values():
		if not clip is Dictionary or not clip.get("frames") is Array or clip.frames.is_empty(): return false
		var timed := 0
		for frame in clip.frames:
			if not frame is Dictionary: return false
			if frame.has("duration_ms"):
				var duration: Variant = frame.duration_ms
				if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) <= 0: return false
				timed += 1
		if timed != 0 and timed != clip.frames.size(): return false
	return true

static func folder(hero: String) -> String:
	return ROOT + hero + "/"
