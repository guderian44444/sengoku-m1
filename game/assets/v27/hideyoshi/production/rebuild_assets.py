#!/usr/bin/env python3
"""Rebuild a clean derivative tree from delivered sources and measured metadata.
Never writes to the game's assets. Python3.12+, Pillow, numpy required.
"""
from pathlib import Path
import argparse,json,os,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--weapons-dir');ap.add_argument('--previews',action='store_true');args=ap.parse_args();out=Path(args.output).resolve()
if out.exists() and any(out.iterdir()):raise SystemExit('Output must be new or empty; existing outputs are never overwritten.')
out.mkdir(parents=True,exist_ok=True)
# Works from standalone package/production or repo assets/v27/hideyoshi/production.
package=HERE.parent;sources=package/'sources';runtime=package/'runtime'
if not runtime.exists():runtime=package
for folder in ['metadata','reference','prompts']:shutil.copytree(HERE/folder,out/folder)
shutil.copytree(sources/'raw',out/'raw');(out/'qa').mkdir();(out/'package/runtime/ui').mkdir(parents=True);shutil.copy(out/'raw/portrait.png',out/'package/runtime/ui/portrait.png')
for name in ['compile_assets.py','grade_runtime.py','render_previews.py']:shutil.copy(HERE/name,out/name)
clips=sorted(p.stem.replace('.authored','') for p in (out/'metadata').glob('*.authored.json'));assert len(clips)==39
weapons=Path(args.weapons_dir).resolve() if args.weapons_dir else runtime/'weapons'
if args.previews and not (weapons/'registration.json').exists():raise SystemExit('Pass --weapons-dir pointing to existing game/assets/v22/weapons when no bundled review equipment exists.')
env={**os.environ,'HIDEYOSHI_BUILD_ROOT':str(out),'HIDEYOSHI_WEAPONS_DIR':str(weapons)}
subprocess.run([sys.executable,str(out/'compile_assets.py'),'--clips',*clips],check=True,env=env)
subprocess.run([sys.executable,str(out/'grade_runtime.py')],check=True,env=env)
if args.previews:subprocess.run([sys.executable,str(out/'render_previews.py'),'--weapons','sword_uchigatana','sword_kanesada_mino','sword_okanehira'],check=True,env=env)
print('Rebuilt',len(clips)*6,'frames and atlas sheets into',out/'package/runtime')
