"""Register the approved 16/17 clips without changing their RGB or pose rulers."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, math, hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/v33'
NOBU = ROOT / 'prototypes/nobunaga-combat-set-v1'
OICHI = ROOT / 'prototypes/oichi-final-20261014'
R = Image.Resampling.LANCZOS


def read(p):
    return json.loads(p.read_text('utf-8'))


def rgba(p):
    return Image.open(p).convert('RGBA')


def layer(im, anchor, ruler):
    # Keep source pixels and one anatomical ruler; never fill a pose's alpha box.
    return (im, list(anchor), ruler)


def bow_layer(size, grip, angle, scale, bow, draw=None):
    co, si = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    gx, gy = grip
    a, b, d, e = co/scale, si/scale, -si/scale, co/scale
    im = bow.transform(size, Image.Transform.AFFINE,
        (a,b,240-a*gx-b*gy,d,e,640-d*gx-e*gy),Image.Resampling.BICUBIC)
    def point(x,y):
        x,y = (x-240)*scale,(y-640)*scale
        return gx+co*x-si*y,gy+si*x+co*y
    tips = [point(150,16),point(142,978)]
    ImageDraw.Draw(im).line([tips[0],draw,tips[1]] if draw else tips,
        fill=(226,205,170,230),width=max(1,round(scale*3)))
    return im


class Packer:
    def __init__(self, folder):
        self.folder=folder; folder.mkdir(parents=True,exist_ok=True)
        self.pages=[]; self.page=None; self.x=self.y=self.row=0; self.cache={}

    def add(self, value):
        im,anchor,ruler=value
        # 315 standing pixels retain full quality at the maximum 240px showcase.
        scale=min(1,315/ruler)
        if scale != 1:
            im=im.resize((round(im.width*scale),round(im.height*scale)),R)
            anchor=[v*scale for v in anchor]; ruler*=scale
        box=im.getbbox()
        if not box: return None
        box=(max(0,box[0]-2),max(0,box[1]-2),min(im.width,box[2]+2),min(im.height,box[3]+2))
        crop=im.crop(box); w,h=crop.size
        digest=hashlib.sha256(crop.tobytes()).hexdigest()
        key=(digest,w,h)
        if key not in self.cache:
            if self.page is None or self.y+h>2048:
                self.page=Image.new('RGBA',(2048,2048)); self.pages.append(self.page)
                self.x=self.y=self.row=0
            if self.x+w>2048:
                self.x=0; self.y+=self.row+2; self.row=0
            if self.y+h>2048:
                self.page=Image.new('RGBA',(2048,2048)); self.pages.append(self.page)
                self.x=self.y=self.row=0
            assert w<=2048 and h<=2048
            rect=[self.x,self.y,w,h]
            self.page.alpha_composite(crop,(self.x,self.y))
            self.cache[key]=(len(self.pages)-1,rect)
            self.x+=w+2; self.row=max(self.row,h)
        page,rect=self.cache[key]
        return dict(file=f'atlas-{page:02}.png',rect=rect,
            anchor=[anchor[0]-box[0],anchor[1]-box[1]],body_height=ruler,
            rgba_sha256=digest)

    def save(self):
        for i,p in enumerate(self.pages): p.save(self.folder/f'atlas-{i:02}.png')


def nobunaga():
    clips={}
    for a in read(NOBU/'catalog.json')['clips']:
        name=a['clip']; d=NOBU/'clips'/name; m=read(d/'registration.json')
        frames=[]; start=0; events=[]
        for i,f in enumerate(m['frames']):
            suffix=f'{i:03}.png'; off=f['body_offset']; root=[420,700]
            local=[root[0]-off[0],root[1]-off[1]]
            # The simulation owns jumping. Remove the preview's baked vertical offset.
            z=f['height_above_ground']
            local[1]-=z
            stage_root=[root[0],root[1]-z]
            layers={'body':layer(rgba(d/'body'/suffix),local,315),
                    'weapon':layer(rgba(d/'weapon'/suffix),stage_root,315),
                    'hands':layer(rgba(d/'hand-foreground'/suffix),local,315)}
            if name!='heavy': layers['fx']=layer(rgba(d/'effects'/suffix),stage_root,315)
            hand=[(f['right_hand'][0]-local[0])*155/315,(f['right_hand'][1]-local[1])*155/315]
            angle=f['weapon_angle']; matrix=f['weapon_matrix']
            if f['weapon_mode']=='sheathed':
                hand=[-40*155/315,-160*155/315]; angle=225; matrix=[]
            victim=f.get('victim'); grab=None
            if victim and not victim.get('released'):
                head=victim['head']; grab=[(head[0]-stage_root[0])*155/315,(head[1]-stage_root[1])*155/315]
            frames.append(dict(duration_ms=f['duration_ms'],layers=layers,hand=hand,
                weapon_angle=angle,weapon_behind=f['weapon_mode']=='sheathed' or f['weapon_behind'],
                root_step=f['root_offset'][0]*155/315,grab_head=grab,
                weapon_matrix=matrix,weapon_mode=f['weapon_mode'],
                air_height=z*155/315))
            for e in f['events']: events.append(dict(ms=start,event=e))
            start+=f['duration_ms']
        clips[name]=dict(duration_ms=start,loop=m['loop'],frames=frames,events=events)
    # The second full rotation must also hit enemies newly entering the radius.
    clips['charge_release']['events'].append(dict(ms=850,event='contact_launch'))
    return clips


def oichi():
    clips={}; bow=rgba(OICHI/'assets/oichi/grabs/bow_azusa.png')
    for a in read(OICHI/'ACTION_MANIFEST.json'):
        name=a['id']; d=OICHI/a['asset_directory']; m=read(OICHI/a['metadata'])
        frames=[]; start=0; events=[]
        for i,f in enumerate(m['frames']):
            suffix=f'{i:02}.png'; grab=None; step=0; hand=[0,-90]; layers={}; behind=False; second=None; angle=f.get('weapon_angle',0); nocked=False
            if name.startswith('light_'):
                body=rgba(d/f'body_{suffix}'); root=f['foot']; ruler=f['body_height']; grip=f['hand']
                # Extra transparent room retains the full bow at all angles.
                pad=600; stage=Image.new('RGBA',(1800,1800));stage.alpha_composite(body,(pad,pad))
                root=[v+pad for v in root]; grip=[v+pad for v in grip]
                weapon=bow_layer(stage.size,grip,f['weapon_angle'],150/963*ruler/148,bow)
                hands=Image.new('RGBA',stage.size);hands.alpha_composite(rgba(d/f'hand_foreground_{suffix}'),(pad,pad))
                layers={k:layer(im,root,ruler) for k,im in [('body',stage),('weapon',weapon),('hands',hands)]}
                step=f['root_displacement_px148']-m['frames'][0]['root_displacement_px148']
                hand=[(grip[j]-root[j])*148/ruler for j in range(2)]
            elif 'character' in m.get('layers',[]):
                root=f['root']; ruler=148/m['game_scale']
                layers={k:layer(rgba(d/sub/suffix),root,ruler) for k,sub in [('body','character'),('weapon','bow')]}
                # Strings stay separate from the body. Detached arrows are world objects.
                strings=rgba(d/'string'/suffix)
                release_ms=next((sum(q['duration_ms'] for q in m['frames'][:j]) for j,q in enumerate(m['frames']) if q.get('release_event')),10**9)
                if start < release_ms:
                    strings.alpha_composite(rgba(d/'arrow'/suffix));strings.alpha_composite(rgba(d/'arrow_tail'/suffix))
                    nocked=rgba(d/'arrow'/suffix).getbbox() is not None
                layers['string']=layer(strings,root,ruler)
                grip=f['grip_left_hand'];hand=[(grip[j]-root[j])*148/ruler for j in range(2)]
                if f.get('right_draw_fingertips'): second=[(f['right_draw_fingertips'][j]-root[j])*148/ruler for j in range(2)]
                top,bottom=f['bow_tips'];angle=math.degrees(math.atan2(-(bottom[0]-top[0]),bottom[1]-top[1]))
                mask=Image.new('RGBA',(1024,1024));body=rgba(d/'character'/suffix)
                box=(round(grip[0]-10),round(grip[1]-10),round(grip[0]+10),round(grip[1]+10))
                mask.alpha_composite(body.crop(box),box[:2]);layers['hands']=layer(mask,root,ruler)
                if f.get('release_event'): events.append(dict(ms=start,event='projectile_release'))
            elif name in ['air_light','air_heavy','dash_heavy']:
                body=rgba(d/f'body_{i+1:02}.png');root=f['foot'];ruler=f['body_height']
                layers['body']=layer(body,root,ruler)
                grip=f['left_hand'];hand=[(grip[j]-root[j])*148/ruler for j in range(2)]
                if f.get('second_hand'): second=[(f['second_hand'][j]-root[j])*148/ruler for j in range(2)]
                nocked=name=='air_heavy' and i<3
                pad=600
                weapon=bow_layer((1800,1800),[v+pad for v in grip],f['weapon_angle'],150/963*ruler/148,bow,
                    [v+pad for v in f['second_hand']] if f.get('second_hand') else None)
                layers['weapon']=layer(weapon,[v+pad for v in root],ruler)
                mask=Image.new('RGBA',body.size)
                for x,y,x2,y2 in f['hand_occluders']: mask.alpha_composite(body.crop((x,y,x2,y2)),(x,y))
                layers['hands']=layer(mask,root,ruler)
                if name=='dash_heavy':step=f['root_preview'][0]-m['frames'][0]['root_preview'][0]
                if 'contact' in f['event'] or f['event']=='release_three_simultaneous':
                    events.append(dict(ms=start,event='projectile_release' if name=='air_heavy' else 'contact'))
            elif name=='throw_reverse':
                root=[170,202]; ruler=148; behind=True
                layers={k:layer(rgba(d/f'stable_{sub}_{suffix}'),root,ruler) for k,sub in [('body','body'),('weapon','weapon')]}
                grab=[f['victim_shoulder'][0]-170,f['victim_shoulder'][1]-202-12]
            elif name in ['grab_hit_1','throw_forward']:
                behind=True
                body=rgba(d/(f'body_{suffix}' if name=='grab_hit_1' else f['isolated_file']))
                ruler=f.get('body_height',490);s=148/ruler;off=f['preview_offset']
                root=[(155-off[0])/s,(194-off[1])/s]
                layers['body']=layer(body,root,ruler)
                weapon_path=d/(f'weapon_{suffix}' if name=='grab_hit_1' else f'throw_forward/weapon_{suffix}')
                layers['weapon']=layer(rgba(weapon_path),[155,194],148)
                grab=[63,-106] if name=='grab_hit_1' else [62,-100]
            else:
                behind=True; root=f['root']; ruler=f['body_height']
                body=rgba(d/name/f'body_{suffix}');layers['body']=layer(body,root,ruler)
                # Match the approved stowed-bow placement in the original preview.
                small=bow.copy();small.thumbnail((44,133));small=small.rotate(18,expand=True,resample=Image.Resampling.BICUBIC)
                weapon=Image.new('RGBA',(400,240));s=148/ruler
                weapon.alpha_composite(small,(round(155+(170-root[0])*s),round(194+(100-root[1])*s)))
                layers['weapon']=layer(weapon,[155,194],148)
                grab=[(f['grab_contact'][0]-root[0])*s+15,(f['grab_contact'][1]-root[1])*s-8]
            for e in f.get('events',[]):
                if e in ['knee_contact_1','knee_contact_2','throw_release','release','grab_attach']:
                    events.append(dict(ms=start,event=e))
            if behind:
                # Back attachment is a virtual weapon anchor, never an active string hand.
                im,anchor,wruler=layers['weapon'];box=im.getbbox()
                hand=[((box[j]+box[j+2])*.5-anchor[j])*148/wruler for j in range(2)]
                angle=0 if name=='throw_reverse' else -18
            frames.append(dict(duration_ms=f['duration_ms'],layers=layers,hand=hand,
                weapon_angle=angle,weapon_behind=behind,root_step=step,grab_head=grab,second_hand=second,
                weapon_stowed=behind,nocked=nocked,air_height=0))
            start+=f['duration_ms']
        if name.startswith('light_'):
            index=next(e['frame'] for e in a['events'] if 'contact' in e.get('event',''))
            events.append(dict(ms=sum(f['duration_ms'] for f in frames[:index]),event='contact'))
        clips[name]=dict(duration_ms=start,loop=name in ['charge_hold','grab_hold'],frames=frames,events=events)
    return clips


def main():
    for hero,clips in [('nobunaga',nobunaga()),('oichi',oichi())]:
        pack=Packer(OUT/hero)
        for clip in clips.values():
            for f in clip['frames']:
                f['layers']={key:packed for key,value in f['layers'].items() if key not in ['weapon','string'] and (packed:=pack.add(value))}
        assert len(clips)==(16 if hero=='nobunaga' else 17)
        assert all(sum(f['duration_ms'] for f in c['frames'])==c['duration_ms'] for c in clips.values())
        for i in [1,2]:
            assert clips[f'light_{i}']['frames'][-1]['layers']['body']['rgba_sha256']==clips[f'light_{i+1}']['frames'][0]['layers']['body']['rgba_sha256']
        result=dict(version='v33',hero=hero,complete=True,standing_battle_height=155 if hero=='nobunaga' else 148,
            source_commit='6c9ede1' if hero=='oichi' else 'local-approved-nobunaga-combat-set-v1',clips=clips)
        pack.save();(OUT/hero/'registration.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n','utf-8')
        for old in (OUT/hero).glob('atlas-*.png'):
            if int(old.stem.split('-')[-1])>=len(pack.pages): old.unlink()
        print(hero,len(clips),'clips',sum(len(c['frames']) for c in clips.values()),'frames',len(pack.pages),'atlases')


if __name__=='__main__':main()
