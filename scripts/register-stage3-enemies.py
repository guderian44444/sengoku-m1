"""Copy the verified delivery and register fixed sockets and authority sync points."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "deliveries/stage03-enemies-20261016/source"
DEST = ROOT / "game/assets/stage3/enemies"
data = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
# Standing anatomical scale stays constant through crouches and knockdowns.
heights = dict(shield=220, spear=220, archer=220, ii_naomori=330, ujinori=360, yoshimoto=330)
sockets = dict(ii_naomori=120, yoshimoto=100)
release = {"attack":260, "thrust":310, "slash":320, "naginata_slash":460, "sword_energy":460, "bow_shot":480}
hashes = {}
for actor, row in data.items():
    row["body_height"] = heights[actor]
    row.pop("scale")
    for action, clip in row["actions"].items():
        if action in release:
            clip["release_ms"] = release[action]
        for frame in clip["frames"]:
            relative = frame["package_path"]
            src, dst = SOURCE / relative, DEST / relative
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            hashes[relative] = hashlib.sha256(dst.read_bytes()).hexdigest()
            frame["root"][0] += sockets.get(actor, 0) + (130 if actor == "ujinori" and action == "slash" else 0)
assert len(data) == 6 and sum(len(a["frames"]) for r in data.values() for a in r["actions"].values()) == 178
assert data["ii_naomori"]["actions"]["down"]["frames"][0]["root"] == [270, 500]
assert data["ujinori"]["actions"]["slash"]["frames"][0]["root"] == [270, 480]
(DEST / "registration.json").write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
(DEST / "SHA256.json").write_text(json.dumps(hashes, indent=2)+"\n", encoding="utf-8")
print(f"STAGE3 ENEMY REGISTRATION PASS: {len(hashes)} frames, unchanged image bytes")
