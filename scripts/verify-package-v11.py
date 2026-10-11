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
ARCHIVE = ARTIFACTS / "吞食戰國-M1-v0.11-Windows.zip"


def digest(stream):
    result = hashlib.sha256()
    for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
        result.update(block)
    return result.hexdigest()


def main():
    extracted = Path(tempfile.mkdtemp(prefix="package-v11-verify-", dir=ARTIFACTS))
    with zipfile.ZipFile(ARCHIVE) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)), "Duplicate ZIP entries"
        for name in names:
            assert (extracted / name).resolve().is_relative_to(extracted), "Unsafe ZIP path"
            with archive.open(name) as packed, (ROOT / name).open("rb") as source:
                assert digest(packed) == digest(source), f"Stale packaged file: {name}"
        archive.extractall(extracted)
    registration = json.loads((extracted / "game/assets/v11/registration.json").read_text(encoding="utf-8"))
    for spec in registration["actors"].values():
        for filename in [spec["file"], *spec.get("frame_files", {}).values()]:
            assert (extracted / "game/assets/v11" / filename).is_file(), filename
    executable = extracted / "tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
    results = {}
    for test in ["input_v11", "render_v11", "audio_v11", "local_coop_startup"]:
        log_path = extracted / f"{test}.log"
        args = [str(executable), "--headless", "--path", str(extracted / "game"),
                "--log-file", str(log_path), "--script", f"res://tests/test_{test}.gd"]
        if test == "local_coop_startup": args += ["--", "--local-coop"]
        run = subprocess.run(args, capture_output=True, encoding="utf-8", errors="replace", timeout=120,
                             creationflags=subprocess.CREATE_NO_WINDOW)
        log = run.stdout + run.stderr
        log_path.write_text(log, encoding="utf-8")
        filtered = re.sub(r"ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\s*", "", log)
        assert run.returncode == 0 and not re.search(r"SCRIPT ERROR|Parse Error|ERROR:|Assertion failed", filtered), log
        assert "PASS:" in log or re.search(r"V11 (?:INPUT|AUDIO): \d+ checks, 0 failures;", log), f"No acceptance result from {test}"
        results[test] = "PASS"
    with ARCHIVE.open("rb") as stream: checksum = digest(stream)
    report = {"files": len(names), "source_byte_match": True, "sha256": checksum,
              "bytes": ARCHIVE.stat().st_size, "extracted_to": str(extracted), "tests": results,
              "physical_controllers_verified": False, "subjective_voice_review": False}
    (ARTIFACTS / "package-v11-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
