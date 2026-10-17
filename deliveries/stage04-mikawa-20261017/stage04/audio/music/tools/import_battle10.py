#!/usr/bin/env python3
"""Import the owner's official download locally. No network, no Git, no runtime edits."""
import argparse,hashlib,json,pathlib,zipfile
p=argparse.ArgumentParser();p.add_argument('official_zip',type=pathlib.Path);a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
expected_zip='98ec371f688f3d2760d33a2e29b4a5c9e63018c6843a65fa193133cdfedf2ea9'
expected_ogg='c52705340bfa48fad98ad775f59b0b62f84a1df4dcd139d8008b2830d60dab3e'
if hashlib.sha256(a.official_zip.read_bytes()).hexdigest()!=expected_zip:raise SystemExit('Official ZIP differs from reviewed version. Stop and re-check official source; do not skip this check.')
with zipfile.ZipFile(a.official_zip) as z:
 b=z.read('kk_battle10/Assets_for_Unity/kk_battle10_loop_unity.ogg')
if hashlib.sha256(b).hexdigest()!=expected_ogg:raise SystemExit('Loop checksum mismatch; nothing written.')
dst=root/'assets/s04_road_hot_battle10_loop.ogg'
if dst.exists() and dst.read_bytes()!=b:raise SystemExit('Different destination exists; no overwrite.')
dst.write_bytes(b)
print('Imported the full official loop for local game use:',dst)
print('Keep this audio and the official ZIP out of redistributed source/material packages and public Git pending specific permission.')
