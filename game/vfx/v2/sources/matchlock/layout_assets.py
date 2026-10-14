"""Portable layout replay using shipped generated sources; never rewrite inputs."""
from pathlib import Path
from PIL import Image
import argparse,json
root=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
assert a.out.resolve()!=root.resolve(), 'Choose a separate output directory'
for spec in json.loads((root/'layout_alpha_hash.json').read_text())['assets']:
 im=Image.open(root/spec['source_file']).convert('RGBA');layout=spec['layout'];part=im.crop(layout['crop']).resize(layout['resize'],Image.Resampling.LANCZOS)
 result=Image.new('RGBA',(1024,1024));result.paste(part,layout['paste']);result.save(a.out/spec['file'])
print('Rebuilt two matchlock layout outputs')
