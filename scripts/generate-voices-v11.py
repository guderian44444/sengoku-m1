"""Render original, instructed battle shouts; keep v10 dialogue and introductions.

Uses local Qwen VoiceDesign weights with GPU PyTorch and ffmpeg on PATH.
Generation dependencies and model live only in artifacts/voice-v11-runtime.
Model: Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign, revision below.
No account, credentials, or voice cloning is used.
"""
import hashlib
import json
import shutil
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v11"
CACHE = ROOT / "artifacts/voice-v11"
RUNTIME = ROOT / "artifacts/voice-v11-runtime"
REVISION = "5ecdb67327fd37bb2e042aab12ff7391903235d3"
sys.path.insert(0, str(RUNTIME / "packages"))
MODEL = None
FILTER = (
    "silenceremove=start_periods=1:start_threshold=-42dB,areverse,"
    "silenceremove=start_periods=1:start_threshold=-42dB,areverse,"
    "highpass=f=100,lowpass=f=8200,equalizer=f=1800:t=q:w=1:g=2,"
    "acompressor=threshold=0.16:ratio=2.5:attack=3:release=45:makeup=1.5,"
    "alimiter=limit=0.85:level=false"
)


def render_audio(text, description, target, seed):
    import torch
    import soundfile
    from qwen_tts import Qwen3TTSModel
    global MODEL
    if MODEL is None:
        MODEL = Qwen3TTSModel.from_pretrained(str(RUNTIME / "model"), device_map="cuda",
                                             dtype=torch.bfloat16, attn_implementation="sdpa")
    torch.manual_seed(seed)
    wavs, sample_rate = MODEL.generate_voice_design(text=text, language="Japanese", instruct=description,
                                                   non_streaming_mode=True, max_new_tokens=128)
    soundfile.write(str(target), wavs[0], sample_rate, subtype="PCM_16")


def main():
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        import imageio_ffmpeg
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    source = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "game/audio/v10/manifest.json").read_text(encoding="utf-8"))
    for clip in manifest["clips"].values():
        clip["file"] = "../v10/" + clip["file"]
    CACHE.mkdir(parents=True, exist_ok=True)
    count = 0
    for actor_id, actor in source["actors"].items():
        for event, lines in actor["clips"].items():
            for index, text in enumerate(lines):
                key = f"{actor_id}_{event}_{index}"
                assert key in manifest["clips"], key
                description = actor["voice_description"] + " " + source["delivery"][event]
                fingerprint = hashlib.sha256((text + description + REVISION).encode()).hexdigest()[:16]
                target = OUT / f"{key}.wav"
                for attempt in range(3):
                    seed = int(fingerprint[:8], 16) + attempt
                    suffix = f"-{attempt}" if attempt else ""
                    raw = CACHE / f"{key}-{fingerprint}{suffix}.wav"
                    if not raw.exists():
                        render_audio(text, description, raw, seed)
                    subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(raw), "-af", FILTER,
                                    "-ar", "22050", "-ac", "1", "-c:a", "pcm_s16le", str(target)], check=True)
                    with wave.open(str(target), "rb") as audio:
                        seconds = audio.getnframes() / audio.getframerate()
                        assert audio.getnchannels() == 1 and audio.getsampwidth() == 2
                    if 0.08 < seconds < (4.0 if event == "special" else 2.0):
                        break
                    print(f"Retrying {key}: {seconds:.2f}s is not a compact shout", flush=True)
                else:
                    raise ValueError((key, seconds, "No bounded take after three seeds"))
                manifest["clips"][key] = {"file": target.name, "seconds": seconds, "text": text,
                                          "actor": actor_id, "event": event,
                                          "backend": "Qwen3-TTS-12Hz-1.7B-VoiceDesign",
                                          "instruction": description, "seed": seed, "model_revision": REVISION}
                count += 1
                print(f"{key}: {seconds:.2f}s", flush=True)
    manifest.update(version="0.11", backend="Qwen3-TTS instructed combat shouts; v10 Edge dialogue retained",
                    listening_review="pending", combat_delivery=source["delivery"])
    # Publish the manifest only after every new clip passed decoding and duration checks.
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {count} instructed battle clips; retained {len(manifest['clips']) - count} dialogue clips.")


if __name__ == "__main__":
    main()
