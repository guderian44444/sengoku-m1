"""Verify packaged bytes and run acceptance checks in a fresh extracted project."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"
ARCHIVE = ARTIFACTS / "吞食戰國-M1-v0.14-Windows.zip"
VERSION = "v14"
VERSIONS = ['v11', 'v12', 'v13', 'v14']
TESTS = ["audio_v14", "music_integration_v14", "combat_v14", "render_v14", "combat_v13", "render_v13", "walk_v13", "combo_movement_v12", "render_v12", "projectile_v12", "landing_animation_v12", "strike_v12", "parallax_v11", "local_coop_startup"]


def digest(stream):
    result = hashlib.sha256()
    for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
        result.update(block)
    return result.hexdigest()


def main():
    extracted = Path(tempfile.mkdtemp(prefix=f"package-{VERSION}-verify-", dir=ARTIFACTS))
    with zipfile.ZipFile(ARCHIVE) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)), "Duplicate ZIP entries"
        for name in names:
            assert (extracted / name).resolve().is_relative_to(extracted), "Unsafe ZIP path"
            with archive.open(name) as packed, (ROOT / name).open("rb") as source:
                assert digest(packed) == digest(source), f"Stale packaged file: {name}"
        archive.extractall(extracted)
    for version in VERSIONS:
        registration = json.loads((extracted / f"game/assets/{version}/registration.json").read_text(encoding="utf-8"))
        referenced = set()
        for spec in registration["actors"].values():
            for filename in [spec["file"], *spec.get("frame_files", {}).values()]:
                assert (extracted / f"game/assets/{version}" / filename).is_file(), filename
                referenced.add(filename)
        assert {p.name for p in (extracted / f"game/assets/{version}").glob('*.png')} == referenced, "Unaccepted PNGs leaked into package"
    executable = extracted / "tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
    results = {}
    for test in TESTS:
        log_path = extracted / f"{test}.log"
        args = [str(executable), "--headless", "--path", str(extracted / "game"),
                "--log-file", str(log_path), "--script", f"res://tests/test_{test}.gd"]
        if test == "local_coop_startup": args += ["--", "--local-coop"]
        if test == "render_v14": args += ["--", "--require-v14"]
        if test == "audio_v15": args += ["--", "--require-v15"]
        if test == "tadakatsu_render_v17": args += ["--", "--require-v17"]
        run = subprocess.run(args, capture_output=True, encoding="utf-8", errors="replace", timeout=120,
                             creationflags=subprocess.CREATE_NO_WINDOW)
        log = run.stdout + run.stderr
        log_path.write_text(log, encoding="utf-8")
        filtered = re.sub(r"ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\s*", "", log)
        assert run.returncode == 0 and not re.search(r"SCRIPT ERROR|Parse Error|ERROR:|Assertion failed", filtered), log
        assert "PASS:" in log or re.search(r"\bPASSED: \d+ checks|\d+ checks, 0 failures", log), f"No acceptance result from {test}"
        results[test] = "PASS"
    with ARCHIVE.open("rb") as stream: checksum = digest(stream)
    report = {"files": len(names), "source_byte_match": True, "sha256": checksum,
              "bytes": ARCHIVE.stat().st_size, "extracted_to": str(extracted), "tests": results,
              "physical_controllers_verified": False, "subjective_voice_review": False, "subjective_music_review": False}
    (ARTIFACTS / f"package-{VERSION}-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
