from pathlib import Path
import argparse,shutil
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[2]
assert not a.out.exists(), 'Choose a new output directory; never overwrite an existing project'
a.out.mkdir(parents=True)
def ignore(directory,names):return [n for n in names if n.endswith(('.uid','.import')) or n in ['.godot','vfx_demo.gd','vfx_demo.tscn','test_demo_parse.gd','test_special_presets.gd','export_demo_actors.gd']]
shutil.copytree(root/'game/vfx',a.out/'vfx',ignore=ignore)
(a.out/'project.godot').write_text('''config_version=5
[application]
config/name="Shared VFX standalone"
run/main_scene="res://vfx/demo/standalone_demo.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
''')
shutil.copy2(root/'docs/HANDOFF-SHARED-VFX-V1.md',a.out/'HANDOFF.md')
print(a.out/'project.godot')
