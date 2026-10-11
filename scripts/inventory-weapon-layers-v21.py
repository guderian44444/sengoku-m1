"""Inventory registered high-resolution hero clips; this is not a runtime routing audit."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEROES = {"nobunaga": "織田信長", "oichi": "阿市", "tadakatsu": "本多忠勝"}


def build_inventory():
    actors = {hero: {} for hero in HEROES}
    for version in range(12, 18):
        registration = ROOT / f"game/assets/v{version}/registration.json"
        data = json.loads(registration.read_text(encoding="utf-8"))
        for name, spec in data.get("actors", {}).items():
            hero = spec.get("hero")
            if hero not in actors:
                continue
            clip = spec["sheet"].split("_", 1)[1]
            count = spec["columns"] * spec["rows"]
            assert count == len(spec["feet"]), f"{name}: missing foot registrations"
            files = {spec.get("file", name + ".png"), *spec.get("frame_files", {}).values()}
            for filename in files:
                assert (registration.parent / filename).is_file(), f"Missing {filename}"
            actors[hero][clip] = {
                "clip": clip,
                "source": f"v{version}",
                "registration": registration.relative_to(ROOT).as_posix(),
                "registered_frames": count,
                "hand_points": len(spec.get("hands", {})),
                "blade_pairs": len(spec.get("blades", {})),
                "files": sorted(files),
            }
    return {
        "format": "sengoku-weapon-layer-inventory-v21",
        "baseline": "915690d (v0.20)",
        "scope": "v12-v17 registrations; latest version per hero/clip name, not runtime route or unique image count",
        "visual_check": {
            "result": "Weapons are baked into the inspected hero PNGs; no replaceable weapon renderer is present.",
            "samples": ["game/assets/v12/nobunaga-heavy1.png", "game/assets/v12/oichi-heavy1-a.png", "game/assets/v17/tadakatsu-charged_slam-a.png"],
        },
        "heroes": [
            {"id": hero, "name": name, "registered_clips": len(actors[hero]),
             "registered_frames": sum(clip["registered_frames"] for clip in actors[hero].values()),
             "clips": list(actors[hero].values())}
            for hero, name in HEROES.items()
        ],
    }


if __name__ == "__main__":
    inventory = build_inventory()
    output = ROOT / "docs/weapon-layer-inventory-v21.json"
    output.write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for hero in inventory["heroes"]:
        print(f'{hero["id"]}: {hero["registered_clips"]} registered clips, {hero["registered_frames"]} frame entries')
    print("PASS: frame counts and source files checked; no runtime or new-art acceptance claimed")
