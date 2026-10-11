"""Register Tadakatsu's separate original drawings through the established v14/v15 pipeline."""
import importlib.util
import hashlib
import json
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent
module = importlib.util.spec_from_file_location("register_v14", SCRIPT / "register-v14.py")
previous = importlib.util.module_from_spec(module)
module.loader.exec_module(previous)
ROOT = SCRIPT.parent / "game/assets/v17"
OUT = SCRIPT.parent / "artifacts/tadakatsu-atlas-v17"
previous.existing.ROOT = ROOT
previous.existing.VERSION = "v17"
CLIPS = ["slam_charge", "charged_slam", "upper", "low_sweep", "dash", "air_light", "air_heavy",
         "hurt", "guard", "death", "recover", "special", "charge_forward", "holding", "throw", "launched"]

# Standing-equivalent anatomy excludes the spear and antlers; crouching does not inflate the figure.
BODY_HEIGHTS = {"charged_slam": [300, 300], "charge_forward": [350, 350], "air_heavy": [300, 300],
                "dash": [300, 300], "holding": [330, 330], "throw": [310, 310],
                "launched": [350, 350], "hurt": [320, 320], "death": [320, 320]}
LANDMARKS = {
    "slam_charge-a": [[278, 447], [795, 448], [1285, 449], [298, 962], [792, 957], [1284, 964]],
    "slam_charge-b": [[287, 474], [790, 474], [1277, 474], [299, 978], [797, 978], [1290, 978]],
    "charged_slam-a": [[316, 526], [773, 526], [1223, 526], [321, 981], [790, 981], [1260, 981]],
    "charged_slam-b": [[307, 470], [769, 470], [1279, 470], [303, 950], [792, 950], [1290, 950]],
    "upper-a": [[279, 448], [787, 448], [1285, 448], [280, 952], [765, 952], [1270, 952]],
    "upper-b": [[280, 505], [769, 505], [1260, 505], [280, 950], [760, 950], [1260, 950]],
    "low_sweep-a": [[266, 457], [757, 457], [1245, 457], [280, 926], [757, 916], [1250, 916]],
    "low_sweep-b": [[266, 446], [765, 447], [1282, 453], [302, 917], [787, 917], [1265, 914]],
    "dash-a": [[269, 426], [777, 427], [1254, 428], [245, 887], [734, 887], [1245, 894]],
    "dash-b": [[271, 425], [777, 425], [1290, 425], [263, 906], [769, 914], [1264, 914]],
    "air_light-a": [[250, 428], [763, 457], [1254, 451], [246, 879], [731, 879], [1230, 879]],
    "air_light-b": [[213, 424], [775, 424], [1270, 424], [275, 915], [778, 915], [1282, 915]],
    "air_heavy-a": [[295, 505], [844, 505], [1350, 505], [312, 968], [839, 968], [1354, 968]],
    "air_heavy-b": [[228, 488], [741, 488], [1252, 494], [256, 934], [777, 934], [1266, 934]],
    "charge_forward-a": [[267, 503], [775, 503], [1278, 503], [279, 953], [801, 953], [1301, 953]],
    "charge_forward-b": [[271, 471], [786, 471], [1281, 471], [278, 952], [786, 952], [1283, 952]],
    "special-a": [[267, 470], [790, 470], [1268, 470], [299, 929], [850, 929], [1274, 929]],
    "special-b": [[274, 458], [790, 458], [1352, 458], [288, 937], [778, 937], [1272, 937]],
    "holding-a": [[276, 499], [799, 499], [1309, 499], [277, 1002], [803, 1002], [1303, 1002]],
    "holding-b": [[278, 497], [800, 497], [1309, 497], [280, 992], [803, 992], [1302, 992]],
    "throw-a": [[287, 475], [801, 475], [1310, 475], [285, 960], [821, 960], [1330, 960]],
    "throw-b": [[297, 488], [815, 488], [1315, 488], [287, 951], [800, 951], [1303, 951]],
    "launched-a": [[303, 478], [802, 478], [1288, 478], [286, 941], [794, 941], [1328, 941]],
    "launched-b": [[305, 500], [817, 500], [1295, 500], [283, 959], [808, 959], [1314, 959]],
}
SEQUENCE = {"slam_charge": [0, 1, 2, 6, 7, 8, 3, 5, 4, 9, 10, 11],
            "charge_forward": [0, 1, 10, 9, 2, 6, 7, 3, 11, 8, 4, 5],
            "special": [0, 1, 3, 4, 5, 8, 6, 7, 2, 9, 10, 11]}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    actors, clips, checked, errors, incomplete = {}, {}, [], {}, []
    reaction_path = ROOT / "reaction-landmarks.json"
    reaction_landmarks = json.loads(reaction_path.read_text(encoding="utf-8-sig")) if reaction_path.exists() else {}
    for clip in CLIPS:
        parts = []
        for part_index, suffix in enumerate(["a", "b"]):
            filename = f"tadakatsu-{clip}-{suffix}.png"
            if not (ROOT / filename).is_file():
                continue
            part = {"file": filename, "columns": 3, "rows": 2, "frame_count": 6,
                    "body_height": BODY_HEIGHTS.get(clip, [280, 280])[part_index]}
            if f"{clip}-{suffix}" in LANDMARKS:
                part["feet"] = LANDMARKS[f"{clip}-{suffix}"]
            if f"{clip}-{suffix}" in reaction_landmarks:
                part.update(reaction_landmarks[f"{clip}-{suffix}"])
            try:
                item = previous.register("tadakatsu-" + clip, {**part, "part": True})
            except AssertionError as error:
                errors[filename] = str(error)
                continue
            checked.append({"file": filename, "body_height": part["body_height"], "feet": item["feet"],
                            "body_heights": part.get("body_heights", [part["body_height"]] * 6),
                            "regions": item["regions"], "frames": len(item["feet"]),
                            "sha256": hashlib.sha256((ROOT / filename).read_bytes()).hexdigest()})
            parts.append(part)
        if len(parts) != 2:
            incomplete.append(clip)
            continue
        name = "tadakatsu-" + clip
        meta = {"frame_count": 12, "parts": parts}
        if clip in SEQUENCE:
            meta["select"] = SEQUENCE[clip]
        actor = previous.register(name, meta)
        actor["component_alpha_threshold"] = 90 / 255
        assert len(actor["feet"]) == 12 and len(actor["frame_files"]) == 12
        assert len({(actor["frame_files"][str(index)], tuple(actor["regions"][str(index)])) for index in range(12)}) == 12
        actors[name], clips[name] = actor, meta
    (ROOT / "tadakatsu-clips.json").write_text(json.dumps(clips, indent=2) + "\n", encoding="utf-8")
    (ROOT / "registration.json").write_text(json.dumps({"version": "0.17", "actors": actors}, indent=2) + "\n", encoding="utf-8")
    report = {"complete_clips": list(actors), "incomplete_clips": incomplete, "source_errors": errors,
              "checked_sources": checked, "original_pixel_changes": False}
    (OUT / "v17-build-status.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    inventory = {"version": "0.17", "hero": "tadakatsu", "expected_clips": CLIPS, "complete_clips": list(actors),
                 "frames": sum(len(actor["feet"]) for actor in actors.values()), "assets": checked,
                 "sequence_overrides": SEQUENCE, "incomplete_clips": incomplete, "rejected_sources": errors,
                 "registration_sha256": hashlib.sha256((ROOT / "registration.json").read_bytes()).hexdigest(),
                 "acceptance": "Whole-figure bounds and source transparency verified here. Native polygon pixel tests, ordered contact boards, and live camera/input checks are separate evidence."}
    base_root = ROOT.parent / "v16"
    repairs_path = base_root / "tadakatsu-repairs-v17.json"
    if repairs_path.exists():
        repairs = json.loads(repairs_path.read_text(encoding="utf-8-sig"))
        replacement_files = sorted({item["file"] for frames in repairs.values() for item in frames.values()})
        inventory["base_repairs"] = [{"file": "../v16/" + filename, "sha256": hashlib.sha256((base_root / filename).read_bytes()).hexdigest(), "frames": 6} for filename in replacement_files]
        inventory["base_registration_sha256"] = hashlib.sha256((base_root / "registration.json").read_bytes()).hexdigest()
        inventory["base_repairs_sha256"] = hashlib.sha256(repairs_path.read_bytes()).hexdigest()
    inventory["superseded_original_sources"] = [
        {"file": "../v16/tadakatsu-special.png", "reason": "Adjacent spear/effect drawings merged; replaced by twelve separate v17_special drawings."},
        {"file": "../v16/tadakatsu-heavy1.png", "reason": "Frame 2 spear hits the source canvas edge; whole twelve-frame clip replaced without trimming artwork."},
        {"file": "../v16/tadakatsu-walk.png", "reason": "Frames 3,7,11 spear tips hit the canvas edge; whole twelve-frame walk replaced."},
    ]
    inventory["evidence"] = {"pixel_audit": "artifacts/tadakatsu-atlas-v17/verification.json",
                             "native_boards": "artifacts/tadakatsu-atlas-v17/clips/",
                             "base_before_after": "artifacts/tadakatsu-atlas-v17/",
                             "visual_review": "artifacts/tadakatsu-atlas-v17/visual-review.json"}
    (SCRIPT.parent / "docs/character-assets-v17.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(f"V17 registration: {len(actors)}/{len(CLIPS)} complete clips; {len(checked)} checked original sheets")
    for filename, error in errors.items():
        print(f"REJECTED {filename}: {error}")
    if "--require-all" in sys.argv:
        assert not errors and not incomplete, f"Missing/rejected clips: {incomplete}; {errors}"
    elif errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
