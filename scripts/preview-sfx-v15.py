"""Audit the exported runtime PCM and build local audition pages; no external audio input.

First run game/tests/export_sfx_v15.gd through Godot. These WAVs are exact
exports of combat_audio.gd::_synthesize, not separately approximated samples.
"""
from pathlib import Path
import hashlib
import html
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/audio/v15/sfx"
manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
SR = manifest["sample_rate"]
GROUPS = {
    "weapons": ["sword_whoosh", "spear_wind", "kick_whoosh", "needle_whoosh", "chain_swing", "bow_release", "gunshot"],
    "impacts": ["hit", "heavy_hit", "arrow_hit", "bullet_hit", "needle_hit", "blunt_hit", "shield_hit"],
    "support": ["guard", "guard_break", "grab", "landing", "splash", "prop_break", "shatter", "special", "defeat", "pickup"],
}
recipes = {
    "hit": "Five noise-cut edges, distinct high metal partials, descending body impacts.",
    "heavy_hit": "Five slower low-body impacts with lowpass body noise and sharp cracks.",
    "sword_whoosh": "Broad filtered air, shaped rush envelope and a brief metallic edge.",
    "spear_wind": "Broad air pressure with distinct filter, duration and wind envelopes.",
    "kick_whoosh": "Air displacement without the sword metallic edge.",
    "needle_whoosh": "Thin high air hiss and shorter flight envelope.",
    "chain_swing": "Filtered wind plus three independently timed inharmonic metal rattles.",
    "bow_release": "Plucked bowstring partials plus a sharp pluck and delayed arrow-air rush.",
    "gunshot": "Sub-millisecond powder crack, low combustion body and a decaying noisy tail.",
    "arrow_hit": "Body impact, shaft resonance and a short sharp entry transient.",
    "bullet_hit": "Sharp broadband entry crack, low body and brief metallic grit.",
    "needle_hit": "Short thin entry transient, small body and fine high metal partials.",
    "blunt_hit": "Low body thump, filtered cloth/body noise and contact transient.",
    "shield_hit": "Body-impact support beneath the target's separately played pain voice.",
    "guard": "Inharmonic metal contact, sharp broadband bite and short ringing decay.",
    "guard_break": "Metal contact with extra low structural crunch.",
    "grab": "Brief cloth-like filtered noise and hand/body contact.",
    "landing": "Low footfall body, ground noise and heel transient.",
    "splash": "Filtered water turbulence with modulated droplets.",
    "prop_break": "Irregular crack pulses, woody body and broadband fracture noise.",
    "shatter": "Inharmonic fragment resonances and granular brittle impact.",
    "special": "Low force body with a broad noise rush; no sustained single-tone beep.",
    "defeat": "Short falling body impact with broadband material noise.",
    "pickup": "Coin-like inharmonic metal strike and short transient.",
}
metrics, raw_pcm, files_seen = {}, {}, set()
for kind, clips in manifest["clips"].items():
    assert len(clips) == (5 if kind in {"hit", "heavy_hit"} else 3)
    metrics[kind] = []
    for clip in clips:
        path = OUT / clip["file"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == clip["sha256"] and digest not in files_seen
        files_seen.add(digest)
        with wave.open(str(path), "rb") as source:
            assert source.getnchannels() == 1 and source.getsampwidth() == 2 and source.getframerate() == SR
            pcm = source.readframes(source.getnframes())
        raw_pcm[clip["file"]] = pcm
        data = np.frombuffer(pcm, dtype="<i2").astype(np.float64) / 32768
        spectrum = abs(np.fft.rfft(data * np.hanning(len(data)))) ** 2
        frequencies = np.fft.rfftfreq(len(data), 1 / SR)
        total_energy = float(spectrum.sum())
        peak = float(abs(data).max())
        rms = float(np.sqrt(np.mean(data * data)))
        row = {"file":clip["file"], "seconds":len(data)/SR, "peak":peak,
               "rms_dbfs":20*np.log10(max(rms, 1e-12)),
               "crest_factor":peak/max(rms,1e-12),
               "high_frequency_energy_fraction":float(spectrum[frequencies > 2500].sum()/total_energy),
               "largest_bin_energy_fraction":float(spectrum.max()/total_energy),
               "digital_clipped_samples":int(np.count_nonzero(abs(data) >= .999)),
               "limiter_samples":int(np.count_nonzero(abs(data) >= .8498))}
        assert peak > .03 and peak < 1 and rms > .018
        assert row["digital_clipped_samples"] == 0
        # A single fixed beep concentrates its spectrum in one bin. These recipes
        # deliberately combine different materials, partials and transient noise.
        assert row["largest_bin_energy_fraction"] < .5
        metrics[kind].append(row)

preview = {}
silence = b"\x00\x00" * int(SR * .27)
for group, kinds in GROUPS.items():
    chunks, timeline, sample = [], [], 0
    for kind in kinds:
        for clip in manifest["clips"][kind]:
            pcm = raw_pcm[clip["file"]]
            timeline.append({"seconds":sample/SR, "category":kind, "variant":clip["variant"]+1})
            chunks.extend([pcm, silence])
            sample += len(pcm)//2 + len(silence)//2
    filename = f"preview-{group}.wav"
    with wave.open(str(OUT / filename), "wb") as target:
        target.setparams((1, 2, SR, 0, "NONE", "not compressed"))
        target.writeframes(b"".join(chunks))
    preview[group] = {"file":filename,"seconds":sample/SR,"timeline":timeline}

report = {"clip_count":len(files_seen), "categories":len(metrics), "all_unique":True,
          "subjective_listening":"Not performed by agent. Audition the original PCM; automated spectral checks do not establish realism or mix balance.",
          "recipes":recipes, "metrics":metrics, "previews":preview}
(OUT / "qa.json").write_text(json.dumps(report, ensure_ascii=False, indent=2),encoding="utf-8")
rows = []
for kind, clips in manifest["clips"].items():
    cells = ''.join(f'<td><div>變體 {c["variant"]+1}</div><audio controls preload="none" src="{html.escape(c["file"])}"></audio></td>' for c in clips)
    rows.append(f'<tr><th>{html.escape(kind)}<small>{html.escape(recipes[kind])}</small></th>{cells}</tr>')
players = ''.join(f'<p>{html.escape(k)} — {v["seconds"]:.1f} 秒 <audio controls preload="none" src="{v["file"]}"></audio></p>' for k,v in preview.items())
(OUT / "preview.html").write_text('<!doctype html><meta charset="utf-8"><title>v0.15 戰鬥音效試聽</title><style>body{font:16px system-ui;background:#16212a;color:#eee;padding:28px}td,th{padding:12px;border-bottom:1px solid #456;text-align:left}small{display:block;max-width:280px;font-weight:normal;color:#bac6ca;margin-top:8px}audio{width:230px}</style><h1>v0.15 戰鬥音效 — 24 類、76 段</h1><p>以下為遊戲合成器實際 PCM，變體有不同濾波、瞬態、包絡與分層。已檢查檔案唯一性、波形與頻谱；實際聽感、自然程度及混音仍待人工試聽。預覽使用原始音量，遊戲另有音效音量設定。</p>'+players+'<table>'+''.join(rows)+'</table>',encoding="utf-8")
print(json.dumps({"categories":len(metrics),"clips":len(files_seen),"preview":str(OUT / "preview.html"),"maximum_single_bin_energy":max(r["largest_bin_energy_fraction"] for group in metrics.values() for r in group)},ensure_ascii=False))
