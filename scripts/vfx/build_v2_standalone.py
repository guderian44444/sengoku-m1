from pathlib import Path
import argparse,shutil
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[2]
assert not a.out.exists(),'Use a fresh output directory; this builder never overwrites a project'
a.out.mkdir(parents=True)
def ignore(directory,names):return [n for n in names if n.endswith(('.uid','.import','.pyc')) or n in ['.godot','__pycache__','vfx_demo.gd','vfx_demo.tscn','test_demo_parse.gd','test_special_presets.gd','export_demo_actors.gd']]
shutil.copytree(root/'game/vfx',a.out/'vfx',ignore=ignore)
(a.out/'project.godot').write_text('''config_version=5
[application]
config/name="Shared VFX v2 with effect SFX"
run/main_scene="res://vfx/v2/demo/element_demo.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
''')
for name in ['HANDOFF-SHARED-VFX-V1.md','HANDOFF-SHARED-VFX-V2.md']:
 if (root/'docs'/name).exists():shutil.copy2(root/'docs'/name,a.out/name)
print(a.out/'project.godot')
