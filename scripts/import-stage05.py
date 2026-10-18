"""Compile approved v09 sources without resizing, repainting or refitting poses.

All frame geometry stays in its author's source coordinates. Original bytes and
hashes are retained; a renderer may trim transparent margins using crop metadata.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


class Importer:
    def __init__(self, source, index, output, review=False):
        self.source, self.index, self.output = source, index, output
        self.review = review
        self.files, self.geometry = {}, {}

    def read(self, name):
        return json.loads((self.source / name).read_text('utf-8-sig'))

    def keep(self, name):
        name = str(name).replace('\\', '/')
        src = (self.source / name).resolve()
        assert src.is_relative_to(self.source.resolve()) and src.is_file(), name
        if name not in self.files:
            self.files[name] = hashlib.sha256(src.read_bytes()).hexdigest()
            if not self.review:
                dst = self.output / name
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, dst)
                assert hashlib.sha256(dst.read_bytes()).hexdigest() == self.files[name]
        return name

    def frame(self, path, anchor, height, ms, metadata=None):
        path = self.keep(path)
        if path not in self.geometry:
            with Image.open(self.source / path) as im:
                bounds = im.getchannel('A').getbbox() if im.mode == 'RGBA' else (0, 0, *im.size)
                # Empty authored FX frames are legal and kept as a 1px transparent region.
                box = bounds or (0, 0, 1, 1)
                self.geometry[path] = {'canvas': list(im.size), 'crop': [box[0], box[1], box[2]-box[0], box[3]-box[1]]}
        row = dict(path=path, anchor=list(anchor), body_height=height, duration_ms=ms, **self.geometry[path])
        if metadata:
            for key in ['weapon_tip', 'weapon_tip_canvas', 'blade_tip', 'grips', 'rear_grip', 'rear_grip_canvas', 'weapon_angle_degrees', 'feet', 'feet_canvas']:
                if key in metadata: row[key] = metadata[key]
            row['root_motion_px'] = metadata.get('world_root_motion_native_px', metadata.get('root_motion_x_px', 0))
        assert ms > 0 and height > 0
        return row

    def clip(self, frames, loop=False, **more):
        return dict(loop=loop, duration_ms=sum(x['duration_ms'] for x in frames), frames=frames, **more)

    def build(self):
        actors = {k: {} for k in ['hachiya', 'natsume', 'kusei', 'militia', 'monk']}
        base = 'hachiya/hachiya_basic_states'
        j = self.read(base+'/manifest.json')
        for action, spec in j['animations'].items():
            actors['hachiya'][action] = self.clip([self.frame(base+'/'+f['path'], j['root'], 1015, f['duration_ms']) for f in spec['frames']], spec['loop'])
        for action in ['walk', 'run']:
            base = 'hachiya/hachiya_locomotion'
            j = self.read(base+'/'+action+'_manifest.json')
            actors['hachiya'][action] = self.clip([self.frame(f'{base}/{action}/{i+1:02}.png', j['root'], 1015, f['duration_ms'], f) for i, f in enumerate(j['frames'])], True, native_face=-1 if j['facing']=='left' else 1)
        for action, manifest, folder in [('s05_hachiya_rapid','rapid','rapid_thrust_v2'), ('s05_hachiya_return','retreat_counter','retreat_counter'), ('s05_hachiya_sweep','horizontal_sweep','horizontal_sweep')]:
            base = 'hachiya/hachiya_actions'
            j = self.read(f'{base}/{manifest}_manifest_v4.json')
            frames = [self.frame(f'{base}/{folder}/{i+1:02}.png', j['root'], 1015, f.get('duration_ms', j.get('durations_ms',[0]*len(j['frames']))[i]), f) for i, f in enumerate(j['frames'])]
            actors['hachiya'][action] = self.clip(frames, events=j['events'])
        base = 'natsume/basic'
        j = self.read(base+'/manifest.json'); details = {x['id']: x for x in j['frames']}
        for action, spec in j['animations'].items():
            actors['natsume'][action] = self.clip([self.frame(base+'/frames/'+f['frame']+'.png', j['root'], 691.2, f['duration_ms'], details[f['frame']]) for f in spec['keys']], spec['loop'])
        for action in ['sweep', 'ground', 'diagonal']:
            base = 'natsume/skills/skills/'+action
            j = self.read(base+'/manifest.json'); details = {str(x['key']): x for x in j['keys']}
            actors['natsume']['s05_natsume_'+action] = self.clip([self.frame(base+'/'+details[str(f['key'])]['normalized_file'], j['root'], 691.2, f['duration_ms'], details[str(f['key'])]) for f in j['timeline']], events=j['events'])
        j = self.read('troops/manifest.json')
        for role, height in [('militia', 810), ('monk', 832)]:
            for action, spec in j['clips'][role].items():
                key = 's05_'+role+'_'+action if 'attack' in action else action
                actors[role][key] = self.clip([self.frame(f'troops/{role}/{f}.png', j['root'], height, ms, j['frames'][role].get(f, {})) for f, ms in zip(spec['frames'], spec['durations_ms'])], spec['loop'], events=spec.get('events', []))
        j = json.loads((self.index/'kusei_playback_paths.json').read_text('utf-8'))
        for action, spec in j['actions'].items():
            frames = []
            for f in spec['frames']:
                row = self.frame(f['character'], [1024,1400], 853.3333333333334, f['duration_seconds']*1000, f)
                row['layers_before'], row['layers_after'] = [], []
                for path in f.get('fx', []):
                    anchor = [1536,1784] if action == 'slash' else [1024,1400]
                    layer = self.frame(path, anchor, row['body_height'], row['duration_ms'])
                    row['layers_before' if '_back/' in path or action == 'slash' else 'layers_after'].append(layer)
                frames.append(row)
            key = 's05_kusei_'+action if action in ['guard','slash','stomp','summon'] else action
            actors['kusei'][key] = self.clip(frames, action in ['idle','walk','stunned','retreat_run'])
        assert sum(len(x) for x in actors.values()) == 50
        self.output.mkdir(parents=True, exist_ok=True)
        self.write('actors.json', actors)
        self.write('display.json', {'status':'initial integration tuning, not user mandated', 'height':{'hachiya':171.15,'natsume':180,'kusei':201.5,'militia':146,'monk':146}, 'ruler_policy':'fixed standing-body ruler for every pose; weapons excluded; no per-frame bbox fit'})
        if self.review:
            self.contact_sheets(actors)
            self.write('selected-source-sha256.json', self.files)
            return
        # The remaining effects, scenery, props, sounds and provenance keep their supplied bytes.
        for prefix in ['backgrounds', 'props', 'audio', 'music', 'hachiya/hachiya_actions/fx_v3', 'hachiya/hachiya_actions/secondary_fx_v2', 'natsume/fx_patch_v3']:
            for src in sorted((self.source/prefix).rglob('*')):
                if src.is_file() and src.suffix.lower() in ['.png','.json','.wav','.txt']:
                    self.keep(src.relative_to(self.source))
        self.keep('natsume/skills/sources/8f3c72ed36c58bb2.png')
        for path in sorted(self.source.rglob('*.json')):
            if path.parts[-1] not in ['asset_paths.json']:
                self.keep(path.relative_to(self.source))
        for name in ['event_bindings.json','proposed_defaults.json','gameplay_contract.json','kusei_playback_paths.json']:
            p=self.index/name
            if p.exists(): self.write('integration/'+name,json.loads(p.read_text('utf-8-sig')))
        for name in ['actors.json','display.json']+[str(x.relative_to(self.output)).replace('\\','/') for x in (self.output/'integration').glob('*.json')]:
            self.files[name] = hashlib.sha256((self.output/name).read_bytes()).hexdigest()
        self.write('runtime-files.json', self.files)
        print(json.dumps({'actors':len(actors),'actions':50,'files':len(self.files),'bytes':sum((self.output/p).stat().st_size for p in self.files)}))

    def write(self, name, value):
        p = self.output/name; p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

    def contact_sheets(self, actors):
        for role, clips in actors.items():
            cells=[]
            for action, clip in clips.items():
                # Every distinct pose plus enough timeline frames to expose FX/root motion.
                seen=set()
                for i,row in enumerate(clip['frames']):
                    signature=row['path']
                    if signature in seen and i % 10: continue
                    seen.add(signature)
                    cells.append((action,i,row))
            for page in range((len(cells)+29)//30):
                sheet=Image.new('RGB',(1500,1320),(28,31,35));d=ImageDraw.Draw(sheet)
                for c,(action,i,row) in enumerate(cells[page*30:(page+1)*30]):
                    x,y=(c%6)*250,(c//6)*264
                    d.text((x+6,y+5),f'{action.replace("s05_","")} [{i}]',fill='white')
                    d.text((x+6,y+20),f'{row["duration_ms"]:g}ms',fill='#b7ccd5')
                    scale=160/row['body_height']; ox,oy=x+115,y+238
                    for layer in row.get('layers_before',[])+[row]+row.get('layers_after',[]):
                        with Image.open(self.source/layer['path']) as im:
                            bx,by,bw,bh=layer['crop'];im=im.crop((bx,by,bx+bw,by+bh)).convert('RGBA')
                            im=im.resize((max(1,round(bw*scale)),max(1,round(bh*scale))),Image.Resampling.LANCZOS)
                            sheet.paste(im,(round(ox+(bx-layer['anchor'][0])*scale),round(oy+(by-layer['anchor'][1])*scale)),im)
                    d.line((x+8,oy,x+242,oy),fill='#5b797c');d.ellipse((ox-2,oy-2,ox+2,oy+2),fill='#ffbd53')
                sheet.save(self.output/f'{role}-{page+1:02}.jpg',quality=90)
        print('Review contact sheets and all 50 action timelines ready:',self.output)


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--index',type=Path,required=True);p.add_argument('--output',type=Path,default=ROOT/'game/assets/stage5');p.add_argument('--review',action='store_true');a=p.parse_args()
    Importer(a.source,a.index,a.output,a.review).build()
