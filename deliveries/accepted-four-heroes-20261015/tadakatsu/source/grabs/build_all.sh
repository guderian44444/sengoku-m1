#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 build_grabs.py grab_start grab_start-source-v2.png --durations 110,90,80,80,100,180 --events '{"3":["grip_collar_upperarm"],"4":["pull_target_close"],"5":["enter_grab_hold"]}'
python3 build_grabs.py grab_hold grab_hold-source.png --durations 150,150,150,150,150,150 --events '{"0":["grab_hold_loop_start"]}'
python3 build_grabs.py grab_hit_1 grab_hit_1-source.png --durations 100,90,70,60,60,80,70,90,160 --events '{"4":["knee_contact_1"],"8":["return_grab_hold"]}'
python3 build_grabs.py grab_hit_2 grab_hit_1-source.png --durations 80,70,50,50,40,60,60,70,120 --events '{"4":["knee_contact_2"],"8":["prepare_throw_forward"]}'
python3 build_grabs.py throw_forward throw_forward-source.png --durations 90,110,100,80,70,70,80,100,180 --events '{"5":["release_target_forward","enable_thrown_target_body_collision"],"8":["return_ready"]}'
python3 build_grabs.py throw_reverse throw_reverse-source.png --durations 90,90,100,100,100,80,80,100,180 --events '{"3":["target_load_on_shoulder"],"6":["release_target_reverse","enable_thrown_target_body_collision"],"8":["return_ready_left"]}'
python3 finalize_pack.py
