"""Render original v14 voice variants with the existing local Qwen VoiceDesign.

No downloaded voices, account, credentials, or voice cloning. Raw model takes
remain in artifacts/voice-v14; the game receives trimmed/filtered PCM WAV files.
"""
import hashlib
import importlib.util
import json
import shutil
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v14"
CACHE = ROOT / "artifacts/voice-v14"
spec = importlib.util.spec_from_file_location("voices_v11", ROOT / "scripts/generate-voices-v11.py")
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


def main():
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        import imageio_ffmpeg
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    source = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "game/audio/v11/manifest.json").read_text(encoding="utf-8"))
    for clip in manifest["clips"].values():
        clip["file"] = "../v11/" + clip["file"]
    CACHE.mkdir(parents=True, exist_ok=True)
    count = 0
    for actor_id, actor in source["actors"].items():
        for event, lines in actor["clips"].items():
            pool = []
            for index, text in enumerate(lines):
                key = f"{actor_id}_v14_{event}_{index}"
                description = actor["voice_description"] + " " + source["delivery"][event]
                fingerprint = hashlib.sha256((text + description + pipeline.REVISION).encode()).hexdigest()[:16]
                target = OUT / f"{key}.wav"
                for attempt in range(3):
                    seed = int(fingerprint[:8], 16) + attempt
                    raw = CACHE / f"{key}-{fingerprint}-{attempt}.wav"
                    if not raw.exists():
                        pipeline.render_audio(text, description, raw, seed)
                    subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(raw), "-af", pipeline.FILTER,
                                    "-ar", "22050", "-ac", "1", "-c:a", "pcm_s16le", str(target)], check=True)
                    with wave.open(str(target), "rb") as audio:
                        seconds = audio.getnframes() / audio.getframerate()
                        assert audio.getnchannels() == 1 and audio.getsampwidth() == 2
                    if .08 < seconds < (3.5 if event == "special" else 1.8):
                        break
                    print(f"Retry {key}: {seconds:.2f}s exceeds short shout bound", flush=True)
                else:
                    raise ValueError((key, seconds, "No compact take after three deterministic seeds"))
                manifest["clips"][key] = {
                    "file": target.name, "seconds": seconds, "text": text,
                    "actor": actor_id, "event": event, "backend": "Qwen3-TTS-12Hz-1.7B-VoiceDesign",
                    "instruction": description, "seed": seed, "model_revision": pipeline.REVISION,
                    "raw_source": str(raw.relative_to(ROOT)).replace("\\", "/"),
                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                    "raw_sha256": hashlib.sha256(raw.read_bytes()).hexdigest(),
                    "post_filter": pipeline.FILTER,
                }
                pool.append(key)
                count += 1
                print(f"{key}: {seconds:.2f}s", flush=True)
            manifest["actors"][actor_id][event] = pool
    manifest.update(version="0.14", backend="Local Qwen3-TTS expressive variants; prior dialogue retained",
                    listening_review="pending", combat_delivery=source["delivery"])
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {count} new variants; previous dialogue and introductions retained.")


if __name__ == "__main__":
    main()
