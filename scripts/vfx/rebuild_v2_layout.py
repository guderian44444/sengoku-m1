"""Replay all 15 added layouts to a fresh destination, then compare exact RGBA pixels."""
from pathlib import Path
from PIL import Image
import argparse,json,subprocess
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[2];v=root/'game/vfx/v2';a.out.mkdir(parents=True,exist_ok=True)
cat=json.load(open(v/'catalog.json'))['effects'];count=0
for family in ['wind','lightning']:
 for kind in ['arc','ring','wave','hit']:
  key=family+'_'+kind;im=Image.open(v/f'sources/{family}/{key}_source.png').convert('RGBA');im.thumbnail((896,896),Image.Resampling.LANCZOS);result=Image.new('RGBA',(1024,1024));result.paste(im,((1024-im.width)//2,(1024-im.height)//2));result.save(a.out/f'{key}.png')
for spec in json.load(open(v/'sources/matchlock/layout_alpha_hash.json'))['assets']:
 im=Image.open(v/'sources/matchlock'/spec['source_file']).convert('RGBA');layout=spec['layout'];part=im.crop(layout['crop']).resize(layout['resize'],Image.Resampling.LANCZOS);result=Image.new('RGBA',(1024,1024));result.paste(part,layout['paste']);result.save(a.out/spec['file'])
for key in ['neutral_slash_arc','neutral_thrust_cone','neutral_trail_strip','neutral_hit_burst','neutral_dust']:
 subprocess.run(['magick',str(v/f'sources/neutral/sources/{key}.png'),'-filter','Lanczos','-resize','896x896','-background','none','-gravity','center','-extent','1024x1024',str(a.out/f'{key}.png')],check=True)
for key,spec in cat.items():
 if not spec['texture'].startswith('res://vfx/v2/art/'):continue
 expected=Image.open(v/'art'/f'{key}.png').convert('RGBA');actual=Image.open(a.out/f'{key}.png').convert('RGBA');assert actual.tobytes()==expected.tobytes(),key;count+=1
print(f'PASS {count} new base layouts pixel-identical; sources never modified')
