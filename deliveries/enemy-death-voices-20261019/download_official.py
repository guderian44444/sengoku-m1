#!/usr/bin/env python3
"""Fetch only author-hosted WAVs; preserve bytes, verify hashes, never publish them."""
import argparse
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import urllib.parse
import urllib.request
import wave

BASE = Path(__file__).resolve().parent
OUTPUT = BASE / "local-only"
ALLOWED_HOSTS = {"wingless-seraph.net", "youfulca.com"}
LIMIT = 10 * 1024 * 1024


def official_url(url):
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS
            or parsed.username or parsed.password or parsed.port not in (None, 443)):
        raise ValueError("URL is outside the approved official HTTPS sources")
    return url


class OfficialRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        official_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def validate(data, entry):
    if hashlib.sha256(data).hexdigest() != entry["sha256"]:
        raise ValueError("SHA256 mismatch; source may have changed")
    if len(data) != entry["size_bytes"]:
        raise ValueError("File size mismatch")
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("Expected RIFF/WAVE")
    with wave.open(io.BytesIO(data), "rb") as audio:
        values = (audio.getnchannels(), audio.getframerate(),
                  audio.getsampwidth() * 8, audio.getnframes())
        expected = (entry["channels"], entry["sample_rate_hz"],
                    entry["bits_per_sample"], entry["sample_frames"])
        if values != expected or audio.getcomptype() != "NONE":
            raise ValueError("PCM format or sample count mismatch")
        if not 0.5 <= audio.getnframes() / audio.getframerate() <= 1.0:
            raise ValueError("Duration is outside 0.5–1.0 seconds")
        if len(audio.readframes(audio.getnframes())) != audio.getnframes() * audio.getnchannels() * audio.getsampwidth():
            raise ValueError("Incomplete PCM data")


def fetch(entry, verify_only=False):
    name = entry["local_filename"]
    if Path(name).name != name or not name.endswith(".wav"):
        raise ValueError("Invalid local filename")
    destination = OUTPUT / name
    if destination.exists():
        validate(destination.read_bytes(), entry)
        return name + " verified (existing)"
    if verify_only:
        raise FileNotFoundError(name + " has not been downloaded")
    request = urllib.request.Request(official_url(entry["official_url"]),
        headers={"User-Agent": "Mozilla/5.0 (official game asset download)"})
    with urllib.request.build_opener(OfficialRedirect()).open(request, timeout=18) as response:
        official_url(response.url)
        data = response.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("Unexpected file size above 10 MiB")
    validate(data, entry)
    # Exclusive creation avoids overwriting an existing local asset.
    with destination.open("xb") as output:
        output.write(data)
    return name + " downloaded and verified"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true", help="Validate existing files without network")
    args = parser.parse_args()
    manifest = json.loads((BASE / "manifest.json").read_text(encoding="utf-8"))
    entries = manifest["files"]
    if len(entries) != 10 or len({x["local_filename"] for x in entries}) != 10:
        raise ValueError("Expected exactly ten unique files")
    OUTPUT.mkdir(exist_ok=True)
    errors = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = [(entry, pool.submit(fetch, entry, args.verify_only)) for entry in entries]
        for entry, future in futures:
            try:
                print(future.result())
            except Exception as error:
                errors.append(entry["id"])
                print(entry["id"] + " FAILED: " + str(error))
    print(f"Verified {10-len(errors)}/10; WAVs remain local and ignored by Git.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
