"""Original v15 short kiai and victory lines; one local VoiceDesign model.

Keeps every raw take, including rejected long takes. Only silence is trimmed;
pitched speech is never cut to meet the short-burst duration limit. The existing
v14 files are inherited by relative path and are never rewritten.
"""
import argparse
import hashlib
import html
import importlib.util
import json
import math
import os
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v15"
CACHE = ROOT / "artifacts/voice-v15"
SPEC = importlib.util.spec_from_file_location("voices_v11", ROOT / "scripts/generate-voices-v11.py")
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)
RATE = 22050
KEY_TAG = 'v15'
SHORT_EVENTS = ("attack", "heavy", "hurt")
MAX_ATTEMPTS = 12


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def metrics(path):
    with wave.open(str(path), "rb") as wav:
        assert wav.getnchannels() == 1 and wav.getsampwidth() == 2
        rate = wav.getframerate()
        values = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(np.float64) / 32768
    peak = float(np.abs(values).max(initial=0))
    rms = float(np.sqrt(np.mean(values ** 2))) if values.size else 0
    width = max(1, int(rate * .01))
    windows = [float(np.sqrt(np.mean(values[i:i + width] ** 2))) for i in range(0, len(values), width)]
    threshold = max(.009, max(windows, default=0) * .09)
    active = np.flatnonzero(np.asarray(windows) > threshold)
    islands = 0 if not len(active) else 1 + int(np.sum(np.diff(active) > 10))
    return {"seconds": len(values) / rate, "sample_rate": rate, "channels": 1, "sample_width": 2,
            "peak": peak, "rms_dbfs": 20 * math.log10(max(rms, 1e-9)),
            "clipped_fraction": float(np.mean(np.abs(values) >= .999)) if values.size else 0,
            "active_span_seconds": float((active[-1] - active[0] + 1) * .01) if len(active) else 0,
            "bursts_separated_by_100ms": islands}


def ffmpeg_executable():
    found = shutil.which("ffmpeg")
    if found:
        return found
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def convert(ffmpeg, source, target, filters):
    subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(source), "-af", filters,
                    "-ar", str(RATE), "-ac", "1", "-c:a", "pcm_s16le", str(target)], check=True)


def jobs(source):
    for actor, spec in source["actors"].items():
        for event, lines in spec["clips"].items():
            for index, text in enumerate(lines):
                yield actor, event, index, text, spec["voice_description"] + " " + source["delivery"][event], True, None
    for actor, spec in source["victories"].items():
        for index, text in enumerate(spec["lines"]):
            yield actor, "victory", index, text, spec["voice_description"] + " " + source["delivery"][spec["delivery"]], False, spec["subtitles"][index]


def make_clip(ffmpeg, job):
    actor, event, index, text, description, short, subtitle = job
    key = f"{actor}_{KEY_TAG}_{event}_{index}"
    fingerprint = hashlib.sha256((text + description + pipeline.REVISION + pipeline.FILTER).encode()).hexdigest()[:16]
    target = OUT / f"{key}.wav"
    accepted_path = CACHE / f"{key}-accepted.json"
    if accepted_path.exists():
        accepted = json.loads(accepted_path.read_text(encoding="utf-8"))
        if accepted["fingerprint"] == fingerprint and target.exists() and sha(target) == accepted["clip"]["sha256"]:
            if subtitle: accepted["clip"]["subtitle"] = subtitle
            return key, accepted["clip"]
    for attempt in range(MAX_ATTEMPTS):
        seed = int(fingerprint[:8], 16) + attempt
        raw = CACHE / f"{key}-{fingerprint}-{attempt}.wav"
        if not raw.exists():
            pipeline.render_audio(text, description, raw, seed)
        trimmed = CACHE / f"{key}-{fingerprint}-{attempt}-trimmed.wav"
        convert(ffmpeg, raw, trimmed, pipeline.FILTER)
        before = metrics(trimmed)
        record = {"key": key, "text": text, "instruction": description, "seed": seed,
                  "model_revision": pipeline.REVISION, "raw_source": str(raw.relative_to(ROOT)).replace("\\", "/"),
                  "raw_sha256": sha(raw), "trimmed_metrics": before, "post_filter": pipeline.FILTER,
                  "status": "rejected", "attempt": attempt}
        # At most 18% faster or 12% slower. A longer cry must be regenerated,
        # never shortened by deleting a vowel, gasp, or the tail of a groan.
        tempo = min(1.18, max(.88, before["seconds"] / .42)) if short else 1.0
        projected = before["seconds"] / tempo
        reason = ""
        if short and not .30 <= projected <= .50:
            reason = "duration cannot meet 0.30-0.50s with mild tempo adjustment"
        elif short and before["bursts_separated_by_100ms"] != 1:
            reason = "multiple separated bursts or no voiced burst"
        elif not short and not .6 < before["seconds"] < 7:
            reason = "victory phrase outside compact dialogue range"
        elif before["peak"] < .015 or before["rms_dbfs"] < -40:
            reason = "insufficient voiced energy"
        if not reason:
            gain = min(2.5, .80 / max(before["peak"], .001))
            final_filter = f"atempo={tempo:.6f},volume={gain:.6f},alimiter=limit=0.85:level=false"
            if short: final_filter += ",apad=whole_dur=0.30"  # WSOLA can undershoot the predicted minimum by a few milliseconds.
            candidate = CACHE / f"{key}-{fingerprint}-{attempt}-final.wav"
            convert(ffmpeg, trimmed, candidate, final_filter)
            after = metrics(candidate)
            if short and not .30 <= after["seconds"] <= .50:
                reason = "final WSOLA duration misses short range"
            elif after["clipped_fraction"] > 0 or after["rms_dbfs"] < -30:
                reason = "final signal clips or is too quiet"
            else:
                shutil.copyfile(candidate, target)
                clip = {"file": target.name, "seconds": after["seconds"], "text": text,
                        "actor": actor, "event": event, "category": "short_burst" if short else "victory_dialogue",
                        "backend": "Qwen3-TTS-12Hz-1.7B-VoiceDesign", "instruction": description,
                        "seed": seed, "model_revision": pipeline.REVISION,
                        "raw_source": record["raw_source"], "raw_sha256": record["raw_sha256"],
                        "sha256": sha(target), "post_filter": pipeline.FILTER + "; then " + final_filter,
                        "tempo_factor": tempo, "trimmed_seconds": before["seconds"], "metrics": after,
                        "listening_review": "pending human audition; not inferred from waveform metrics"}
                if subtitle: clip["subtitle"] = subtitle
                record.update(status="accepted", final_metrics=after, tempo_factor=tempo, final_filter=final_filter)
                write_json(CACHE / f"{key}-{fingerprint}-{attempt}.json", record)
                write_json(accepted_path, {"fingerprint": fingerprint, "clip": clip})
                print(f"ACCEPT {key}: raw-trim {before['seconds']:.3f}s -> {after['seconds']:.3f}s (tempo {tempo:.3f})", flush=True)
                return key, clip
        record["reason"] = reason
        write_json(CACHE / f"{key}-{fingerprint}-{attempt}.json", record)
        print(f"RETRY {key} seed{seed}: {before['seconds']:.3f}s; {reason}", flush=True)
    raise ValueError(f"{key}: no valid take after {MAX_ATTEMPTS} seeds; retained raw takes for inspection")


def publish(source, generated):
    old_root = ROOT / "game/audio/v14"
    manifest = json.loads((old_root / "manifest.json").read_text(encoding="utf-8"))
    for clip in manifest["clips"].values():
        inherited = (old_root / clip["file"]).resolve()
        assert inherited.is_file() and inherited.is_relative_to(ROOT / "game/audio")
        clip["file"] = os.path.relpath(inherited, OUT).replace("\\", "/")
    manifest["clips"].update(generated)
    pools = {}
    for key, clip in generated.items():
        pools.setdefault(clip["actor"], {}).setdefault(clip["event"], []).append(key)
    manifest["named_calls"] = {}
    for actor in ["oichi", *source["enemy_voice_groups"]]:
        previous = manifest["actors"].get(actor, {}).get("special", [])
        if previous:
            manifest["named_calls"][actor] = previous.copy()
    for actor in ("oichi", "nobunaga"):
        manifest["actors"][actor].update(pools[actor])
    manifest["actors"]["oichi"]["guard"] = pools["oichi"]["heavy"].copy()
    manifest["actors"]["nobunaga"]["guard"] = pools["nobunaga"]["heavy"].copy()
    for actor, group in source["enemy_voice_groups"].items():
        routing = manifest["actors"].setdefault(actor, {})
        for event in ("attack", "heavy", "hurt", "special", "guard", "defeat"):
            pool_event = "hurt" if event in ("hurt", "defeat") else ("attack" if event == "attack" else "heavy")
            routing[event] = pools[group][pool_event].copy()
    for actor in ("oichi", "nobunaga"):
        manifest["named_calls"][actor] = manifest["actors"][actor].get("special", []).copy()
        for key in manifest["named_calls"][actor]:
            manifest["clips"][key]["category"] = "named_move_dialogue"
    manifest.update(version="0.15", backend="Local VoiceDesign short bursts and victory dialogue; prior dialogue inherited",
                    listening_review="Human audition pending. Duration, source, uniqueness and clipping verified; expressive delivery not asserted by metrics.",
                    combat_delivery=source["delivery"], short_burst_seconds=[.30, .50], enemy_voice_groups=source["enemy_voice_groups"])
    write_json(OUT / "manifest.json", manifest)
    return manifest


def retained_nobunaga(ffmpeg):
    old_root = ROOT / "game/audio/v14"
    old = json.loads((old_root / "manifest.json").read_text(encoding="utf-8"))
    retained = {}
    for previous_key in ("nobunaga_attack_0", "nobunaga_attack_1", "nobunaga_heavy_0"):
        clip = dict(old["clips"][previous_key])
        source = (old_root / clip["file"]).resolve()
        fingerprint = hashlib.sha256((clip["text"] + clip["instruction"] + clip["model_revision"]).encode()).hexdigest()[:16]
        attempt = clip["seed"] - int(fingerprint[:8], 16)
        suffix = f"-{attempt}" if attempt else ""
        raw = ROOT / "artifacts/voice-v11" / f"{previous_key}-{fingerprint}{suffix}.wav"
        reconstructed = CACHE / f"{previous_key}-v11-proof.wav"
        convert(ffmpeg, raw, reconstructed, pipeline.FILTER)
        with wave.open(str(source), "rb") as a, wave.open(str(reconstructed), "rb") as b:
            assert a.readframes(a.getnframes()) == b.readframes(b.getnframes()), "v11 raw provenance must reproduce the retained PCM"
        key = previous_key if clip["event"] == "attack" else "nobunaga_v15_heavy_retained"
        target = OUT / f"{key}.wav"
        post_filter = pipeline.FILTER
        if clip["event"] == "attack":
            shutil.copyfile(source, target)
            origin = "retained_byte_identical"
        else:
            after_filter = "atempo=0.88"
            convert(ffmpeg, source, target, after_filter)
            post_filter += "; then " + after_filter
            origin = "retained_take_mild_tempo_adjustment"
        measured = metrics(target)
        assert .30 <= measured["seconds"] <= .50 and measured["bursts_separated_by_100ms"] == 1
        clip.update(file=target.name, category="short_burst", origin=origin, seconds=measured["seconds"],
                    raw_source=str(raw.relative_to(ROOT)).replace("\\", "/"), raw_sha256=sha(raw),
                    sha256=sha(target), post_filter=post_filter, metrics=measured,
                    inherited_from=str(source.relative_to(ROOT)).replace("\\", "/"), inherited_sha256=sha(source),
                    listening_review="pending human audition; retained source passed duration and waveform checks")
        retained[key] = clip
    write_json(CACHE / "nobunaga-retained.json", retained)
    return retained


def preview(generated):
    cursor = 0
    chapters = []
    chunks = []
    for key, clip in generated.items():
        with wave.open(str(OUT / clip["file"]), "rb") as source:
            data = source.readframes(source.getnframes())
        frames = len(data) // 2
        chapters.append({"key": key, "start_seconds": cursor / RATE, "seconds": frames / RATE,
                         "text": clip["text"], "subtitle": clip.get("subtitle", "")})
        chunks.append(data)
        gap = int(RATE * (.32 if clip["category"] == "short_burst" else .65))
        chunks.append(b"\0\0" * gap)
        cursor += frames + gap
    with wave.open(str(CACHE / "v15-voice-preview.wav"), "wb") as target:
        target.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        target.writeframes(b"".join(chunks))
    write_json(CACHE / "preview-chapters.json", chapters)
    rows = []
    for key, clip in generated.items():
        rows.append(f'<tr><td>{html.escape(key)}</td><td lang="ja">{html.escape(clip["text"])}<br>{html.escape(clip.get("subtitle", ""))}</td><td>{clip["seconds"]:.3f}s</td><td><audio controls preload="none" src="../../game/audio/v15/{clip["file"]}"></audio></td></tr>')
    named = []
    old_root = ROOT / "game/audio/v14"
    old = json.loads((old_root / "manifest.json").read_text(encoding="utf-8"))
    for actor in ("oichi", "nobunaga"):
        for key in old["actors"][actor].get("special", []):
            clip = old["clips"][key]
            path = os.path.relpath((old_root / clip["file"]).resolve(), CACHE).replace("\\", "/")
            named.append(f'<tr><td>{html.escape(actor)}：U 必殺招式名（沿用）</td><td>{html.escape(clip["text"])}</td><td>{clip["seconds"]:.3f}s</td><td><audio controls preload="none" src="{path}"></audio></td></tr>')
    page = '<!doctype html><meta charset="utf-8"><title>v0.15 語音試聽</title><style>body{font:16px system-ui;background:#16212a;color:#eee;padding:28px}td{padding:12px;border-bottom:1px solid #456}audio{width:320px}</style><h1>v0.15 日語短音與勝利台詞</h1><p>一般發力、蓄力與受擊：0.30–0.50 秒。勝利台詞與 U 必殺招式名是完整句子，另列且不適用半秒限制。信長保留兩段合格輕擊與一段微調長度的重擊；其他段為本輪新配音。已檢查長度與音量；聽感與表演驗收待人工試聽。</p><audio controls src="v15-voice-preview.wav"></audio><table>' + ''.join(rows) + '</table><h2>沿用的完整招式名</h2><table>' + ''.join(named) + '</table>'
    (CACHE / "preview.html").write_text(page, encoding="utf-8")
    package_page = page.replace('<audio controls src="v15-voice-preview.wav"></audio>', '')
    package_page = package_page.replace('../../game/audio/v15/', '')
    package_page = package_page.replace('../../game/audio/', '../')
    (OUT / "preview.html").write_text(package_page, encoding="utf-8")
    write_json(CACHE / "metrics.json", {"version": "0.15", "clips": {key: {"sha256": clip["sha256"], **clip["metrics"]} for key, clip in generated.items()},
                                        "preview_clip_count": len(generated),
                                        "new_tts_clip_count": sum("origin" not in clip for clip in generated.values()),
                                        "human_listening": "not performed"})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, help="Generate only this many jobs without publishing the manifest")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    source = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    ffmpeg = ffmpeg_executable()
    generated = {}
    failures = []
    for index, job in enumerate(jobs(source)):
        if args.limit is not None and index >= args.limit:
            break
        try:
            key, clip = make_clip(ffmpeg, job)
            generated[key] = clip
        except ValueError as error:
            failures.append(str(error))
            print(f"PENDING: {error}", flush=True)
    preview(generated)
    if failures:
        raise ValueError("Unpublished incomplete batch: " + "; ".join(failures))
    if args.limit is None:
        assert len(generated) == len(list(jobs(source)))
        generated.update(retained_nobunaga(ffmpeg))
        preview(generated)
        short = [clip for clip in generated.values() if clip["category"] == "short_burst"]
        assert len({clip["sha256"] for clip in short}) == len(short) == 45
        assert all(.30 <= clip["seconds"] <= .50 for clip in short)
        manifest = publish(source, generated)
        assert all((OUT / clip["file"]).is_file() for clip in manifest["clips"].values())
        assert all(sha(OUT / clip["file"]) == clip["sha256"] and
                   sha(ROOT / clip["raw_source"]) == clip["raw_sha256"] for clip in generated.values())
        previous = json.loads((ROOT / "game/audio/v14/manifest.json").read_text(encoding="utf-8"))
        for actor in ("hideyoshi", "ieyasu", "tadakatsu", "mitsuhide"):
            assert manifest["actors"][actor] == previous["actors"][actor]
        for actor in source["enemy_voice_groups"]:
            for event in ("attack", "heavy", "hurt", "special", "guard", "defeat"):
                pool = manifest["actors"][actor][event]
                assert len(pool) >= 3 and all(manifest["clips"][key].get("category") == "short_burst" for key in pool)
        print(f"PASS: {len(generated)} active clips, 45 short bursts, six victory phrases; 48 new TTS takes, two byte-identical retained and one mildly retimed take; all inherited paths resolve.", flush=True)


if __name__ == "__main__":
    main()
