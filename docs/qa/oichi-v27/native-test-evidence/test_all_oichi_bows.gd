extends SceneTree

# External regression; no project or asset files are changed. Accepts an optional
# draft manifest and source folder, otherwise checks the active Oichi renderer.
const Art = preload("res://render/art_assets.gd")
const Renderer = preload("res://render/weapon_renderer.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var manifest := "res://assets/v27/oichi/registration.json"
	var source_folder := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="): manifest = arg.trim_prefix("--manifest=")
		if arg.begins_with("--sources="): source_folder = arg.trim_prefix("--sources=")
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var art := Art.new()
	if not source_folder.is_empty():
		if not source_folder.ends_with("/"): source_folder += "/"
		art.load_layered_hero_registration("oichi", source_folder, registration)
	var renderer := Renderer.new()
	var ids: Array = Weapons.ids_for("oichi")
	check(ids.size() == 16, "All sixteen interchangeable Oichi bows")
	check(registration.clips.size() == 26, "All twenty-six authored clips")
	var frames_checked := 0
	var geometries_checked := 0
	for clip in registration.clips:
		var frames: Array = art.animations.oichi["v22_" + str(clip)]
		check(frames.size() == 6, str(clip) + " has six runtime frames")
		for frame in frames:
			frames_checked += 1
			check(frame.get("source_version") == "v27", str(clip) + " active v27 artwork")
			for id in ids:
				var image: Image = renderer.textures[id].get_image()
				for face in [-1, 1]:
					geometries_checked += 1
					var actor := {"kind":"oichi", "weapon_id":id, "face":face}
					var pose: Dictionary = renderer.geometry(actor, frame, 148.0)
					if not frame.get("weapon_visible", true):
						check(pose.is_empty(), str(id) + " hidden bow remains hidden")
						continue
					check(not pose.is_empty(), str(id) + " geometry exists")
					if pose.is_empty(): continue
					check(pose.id == id and pose.family == "bow", str(id) + " correct equipped texture")
					var expected: Vector2 = frame.weapon_hand * 148.0 / float(frame.body_height)
					check(pose.hand.is_equal_approx(expected), str(id) + " exact source hand anchor")
					var grip := Vector2i(roundi(pose.grip.x), roundi(pose.grip.y))
					var inside := grip.x >= 0 and grip.y >= 0 and grip.x < image.get_width() and grip.y < image.get_height()
					check(inside and image.get_pixelv(grip).a > 0.5, str(id) + " grip touches bow pixels")
					var top: Vector2 = pose.top * Vector2(face, 1)
					var bottom: Vector2 = pose.bottom * Vector2(face, 1)
					check(top.is_finite() and bottom.is_finite(), str(id) + " mirrored endpoints are finite")
					check(top.distance_to(bottom) >= 159.9 and top.distance_to(bottom) <= 180.1, str(id) + " approved bow scale retained")
					if not frame.get("weapon_behind", false):
						check(not frame.get("hand_occluders", []).is_empty(), str(clip) + " front bow hand occlusion")
	check(frames_checked == 156, "All 156 Oichi runtime frames checked")
	check(geometries_checked == 4992, "16 bows x 156 frames x both facings checked")
	print("ALL OICHI BOWS %s: %d checks, %d failures; %d frames / %d bow-facing cases" % ["PASS" if failures == 0 else "FAILED", checks, failures, frames_checked, geometries_checked])
	quit(1 if failures else 0)
