extends RefCounted

# Asset revisions can reuse the v22 six-frame animation/layering contract without
# changing combat timing or the weapon catalog. A complete registration is the
# activation marker; the v27 builder only writes it after validating all 156 poses.
const OVERRIDES := {"oichi":"res://assets/v27/oichi/"}

static func complete_registration(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != "v27" or not value.get("complete",false): return false
	var clips: Variant = value.get("clips")
	if not clips is Dictionary or clips.size() != 26: return false
	for clip in clips.values():
		if not clip is Dictionary or not clip.get("frames") is Array or clip.frames.size() != 6: return false
	return true

static func folder(hero: String) -> String:
	var replacement := str(OVERRIDES.get(hero,""))
	if not replacement.is_empty() and FileAccess.file_exists(replacement + "registration.json"):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(replacement + "registration.json"))
		if complete_registration(manifest): return replacement
	return "res://assets/v22/" + hero + "/"
