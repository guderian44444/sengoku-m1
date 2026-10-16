"""Import accepted deliveries into the existing layered runtime; never include proxy victims."""
from pathlib import Path
import importlib.util, json, math, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('combat_builder', ROOT/'scripts/build-combat-v33.py')
builder = importlib.util.module_from_spec(spec); spec.loader.exec_module(builder)
read, rgba, layer, Packer = builder.read, builder.rgba, builder.layer, builder.Packer
SOURCE = ROOT/'deliveries/accepted-four-heroes-20261015'
PACKAGE = ROOT/'artifacts/basic36-nobunaga16-git-20261016/deliveries/basic36-nobunaga16-hires-20261016'
HEIGHTS = {'tadakatsu':163, 'hideyoshi':150, 'ieyasu':152, 'kennyo':163}

def staff_socket(layers, angle):
    source=rgba(SOURCE/'kennyo/source/sources/weapons/ornate_shakujo.png')
    rotated=source.rotate(-angle,Image.Resampling.BICUBIC,expand=True)
    target=next(im.copy() for k,im in layers.items() if k in ['weapon','weapon_back'] and im is not None)
    if layers.get('weapon') is not None and layers.get('weapon_back') is not None:
        target=layers['weapon'].copy();target.alpha_composite(layers['weapon_back'])
    a=rotated.getbbox();b=target.getbbox();assert a and b
    x,y=64-source.width/2,178-source.height/2;t=math.radians(angle)
    return [x*math.cos(t)-y*math.sin(t)+rotated.width/2+(b[0]+b[2]-a[0]-a[2])/2,
            x*math.sin(t)+y*math.cos(t)+rotated.height/2+(b[1]+b[3]-a[1]-a[3])/2]

def staff_weapons():
    src=SOURCE/'kennyo/source/sources/weapons';out=ROOT/'game/assets/v22/weapons'
    reg=read(out/'registration.json')
    for name,w in read(src/'weapons-metadata.json')['weapons'].items():
        key='staff_'+name;shutil.copyfile(src/(name+'.png'),out/(key+'.png'))
        reg['items'][key]=dict(file=key+'.png',grip=w['main_grip'],tip_top=w['tip_axis'],tip_bottom=w['butt'],
            length=w['physical_length_px'],world_length=w['physical_length_px'],size=[128,256],sha256=w['sha256'])
    (out/'registration.json').write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def relative(point, root, scale=1):
    return [(point[i]-root[i])*scale for i in range(2)]

def image_at(folder, names, required=False):
    for name in names:
        p=folder/name
        if p.is_file(): return rgba(p)
    assert not required, (folder, names)
    return None

def finish(folder, hero, clips, height, common=False):
    pack=Packer(folder)
    for name,c in clips.items():
        assert c['frames'] and all(f['duration_ms']>0 for f in c['frames']),name
        for f in c['frames']:
            f['layers']={k:v for k,im in f['layers'].items() if (v:=pack.add(im))}
            assert 'body' in f['layers'],(hero,name)
        assert all(0<=e['ms']<c['duration_ms'] for e in c['events']),(hero,name,c['events'])
    pack.save()
    result=dict(version='current' if common else 'v33',hero=hero,complete=True,
        layer_format='combat',standing_battle_height=height,source_revision='accepted-deliveries-20261016',clips=clips)
    (folder/'registration.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(hero,'common' if common else 'combat',len(clips),'clips',sum(len(c['frames']) for c in clips.values()),'frames',len(pack.pages),'atlases',flush=True)

def frame(duration, layers, root, ruler, height, grip=None, angle=0, behind=False, step=0, grab=None, **extra):
    return dict(duration_ms=duration,layers={k:layer(im,root,ruler) for k,im in layers.items() if im is not None},
        hand=relative(grip or root,root,height/ruler),weapon_angle=angle or 0,weapon_behind=behind,
        root_step=step,grab_head=relative(grab,root,height/ruler) if grab else None,air_height=0,
        authored_weapon=True,**extra)

def clip(frames,events=None,loop=False):
    return dict(frames=frames,events=events or [],duration_ms=sum(f['duration_ms'] for f in frames),loop=loop)

def common(hero):
    base=PACKAGE/'four-heroes'; h=HEIGHTS[hero]; clips={}
    for entry in read(base/'manifest.json')['actions']:
        if entry['character']!=hero: continue
        contract=read(base/entry['contract']); frames=[]
        for f in contract['frames']:
            ls={('hands' if k=='hand_occlusion' else k):rgba(base/p) for k,p in f['layers'].items()}
            root=f['root_canvas_px']; grip=f.get('weapon_anchor_canvas_px')
            if hero=='tadakatsu' and entry['action'] in ['jump','launched']:
                offset=f.get('pose_offset_already_baked_px') or [0,0]
                root=[root[j]+offset[j] for j in range(2)]
            behind=f['layer_order_back_to_front'].index('weapon')<f['layer_order_back_to_front'].index('body')
            frames.append(frame(f['duration_ms'],ls,root,h,h,grip,f.get('weapon_angle_degrees') or 0,behind,
                weapon_visible=f.get('grip_state') not in ['released','absent']))
        clips[entry['action']]=clip(frames,loop=contract['loop'])
    d=base/hero; m=read(d/'integration_manifest.json')
    if hero=='tadakatsu':
        q=d/'identity'; a=read(q/'registration.json'); root=[220,238]; grip=a['grip_canvas']; angle=a['weapon_angle_degrees']
        ls={k:image_at(q,[f'{n}_01.png'],True) for k,n in [('body','body'),('weapon','weapon'),('hands','hand_occlusion')]}
    elif hero=='hideyoshi':
        q=d/'idle'; a=read(q/'metadata.json'); root=[185,251]; grip=a['frame']['grip_canvas'];angle=a['frame']['weapon_angle_deg']
        ls={k:rgba(q/a['frame'][n]) for k,n in [('body','body'),('weapon','weapon'),('hands','hand_occlusion')]}
    elif hero=='ieyasu':
        q=d/'idle'; a=read(q/'registration.json'); root=a['root_canvas'];grip=a['grip_canvas'];angle=a['weapon_angle_degrees']
        ls={k:image_at(q,[f'{n}_01.png',f'{n}_00.png',f'{n}.png'],True) for k,n in [('body','body'),('weapon','weapon'),('hands','hand_occlusion')]}
    else:
        q=d/'idle';a=read(q/'metadata.json')['frames'][0];root=a['root'];grip=a['grips_root_local'][0];angle=a['weapon_angle_degrees']
        ls={k:image_at(q,[f'{n}_01.png',f'{n}.png'],True) for k,n in [('body','body'),('weapon','weapon'),('hands','hand_occlusion')]}
    clips['idle']=clip([frame(1000,ls,root,h,h,grip,angle)],loop=True)
    ident='mitsuhide' if hero=='kennyo' else hero
    out=ROOT/'game/assets/current/heroes'/ident
    finish(out,ident,clips,h,True)
    portrait=m.get('portrait')
    if not portrait: portrait=next(str(p.relative_to(d)) for p in d.rglob('*.png') if 'portrait' in p.name)
    shutil.copyfile(d/portrait,out/'portrait.png')
    reg=read(out/'registration.json');size=Image.open(out/'portrait.png').size
    reg['portrait']={'file':'portrait.png','rect':[0,0,*size]}
    (out/'registration.json').write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def combat(hero):
    h=HEIGHTS[hero];clips={}
    for entry in read(SOURCE/'ACCEPTED_ACTIONS.json')['actions']:
        if entry['hero']!=hero:continue
        name=entry['id']; path=SOURCE/entry['metadata']; d=path.parent; m=read(path)
        grab=name.startswith(('grab_','throw_'))
        if hero=='ieyasu' and grab: m=m[name]; d=d/name
        fs=m.get('frames',[])
        if hero=='kennyo' and name=='charge_hold': fs=[dict(root=m['root'],duration_ms=1000)]
        frames=[];events=[];time=0; first_root=None
        for i,f in enumerate(fs):
            one=i+1; root=None;grip=None;grasp=None;behind=grab;angle=0;ruler=h;step=0
            ls={}; duration=f.get('duration_ms',f.get('duration',0))
            if hero=='tadakatsu':
                ruler=160
                if grab:
                    root=f['registration_anchor'];grasp=f.get('contacts',{}).get('collar_glove')
                    ls={'body':rgba(d/f'character/{i:02}.png'),'weapon':rgba(d/f'weapon_back/{i:02}.png')}
                elif name.startswith('air_'):
                    ls={k:image_at(d,[f'{n}/{i:02}.png']) for k,n in [('body','character'),('weapon','weapon'),('hands','hand_occlusion'),('fx','effect')]}
                    ls['weapon']=image_at(d,[f'weapon_front/{i:02}.png'],True)
                    ls['weapon_back']=image_at(d,[f'weapon_back/{i:02}.png'],True)
                    # The engine supplies jump height; hip registration remains fixed across airborne poses.
                    root=f.get('root_canvas',[245,345]);root=[root[0],root[1]+80] if name=='air_light' else root
                    if name=='air_heavy':root=[f.get('original_metadata',{}).get('screen_root',[250,376])[0],f['body_alpha_max_y']]
                    grip=f['hands_canvas'][0];angle=f.get('weapon_angle_degrees',f.get('weapon_angle',0))
                else:
                    root=f['screen_root'];grip=f['screen_grip'];angle=f['angle'];behind=f.get('weapon_behind',False)
                    ls={k:image_at(d,[f'{n}_{one:02}.png']) for k,n in [('body','body_canvas'),('weapon','weapon'),('hands','hand_occlusion'),('fx','effect')]}
            elif hero=='hideyoshi':
                root=f.get('root',f.get('scale_anchor',f.get('anatomical_scale_anchor',[185,251])))
                if grab:root=f['support_foot'];grasp=f['hand_contact']
                grip=f.get('grip_world');angle=f.get('weapon_angle',f.get('blade_angle',0))
                ls={k:image_at(d,[f'{n}_{i:02}.png']) for k,n in [('body','body_canvas'),('weapon','weapon'),('hands','hand_occlusion'),('fx_back','fx_back'),('fx','fx_front')]}
                if ls['body'] is None:ls['body']=image_at(d,[f'body_{i:02}.png'],True)
                # Air sources have the registered vertical offset baked into the canvas.
                if name.startswith('air_'):
                    root=[root[0],root[1]-f.get('air_height',0)]
                    if 'pelvis_world' in f:
                        root[1]=f['pelvis_world'][1]+fs[0]['root'][1]-fs[0]['pelvis_world'][1]
            elif hero=='ieyasu':
                root=f.get('root_world',f.get('root'));grip=f.get('grip_world');angle=f.get('blade_angle_deg',f.get('blade_angle',0))
                if grab:grasp=f.get('grasp_contact');grip=f.get('right_hand')
                ls={k:image_at(d,[f'{n}_{i:02}.png']) for k,n in [('body','body_canvas'),('weapon','sword'),('hands','hand_occlusion')]}
                if name=='charge_release':
                    ls['fx_back']=image_at(d,[f'fx_afterimage_{i:02}.png'])
                    ls['fx']=image_at(d,[f'fx_sword_wave_{i:02}.png'])
                if ls['body'] is None:ls['body']=image_at(d,[f'body_{i:02}.png'],True)
                if ls['weapon'] is None:ls['weapon']=image_at(d,[f'sheathed_weapon_{i:02}.png',f'weapon_{i:02}.png'])
                sheath=image_at(d,[f'sheath_{i:02}.png'])
                if sheath: sheath.alpha_composite(ls['body']);ls['body']=sheath
                if grip is None and 'grip' in f:
                    rect=f['source_rect'];s=f['body_scale'];foot=f['support_foot']
                    grip=[root[j]+(f['grip'][j]-foot[j])*s for j in range(2)]
                if grip is None and 'source_grip' in f and 'source_foot' in f:
                    grip=[root[j]+(f['source_grip'][j]-f['source_foot'][j])*f['body_scale'] for j in range(2)]
            else:
                root=f.get('world_root',f.get('root'));grip=f.get('grip_world',f.get('grip',f.get('weapon_main_grip')))
                if grip and isinstance(grip[0],list):grip=grip[0]
                angle=f.get('weapon_angle',f.get('weapon_angle_clockwise',0)) or 0
                if grab:
                    grasp=f.get('hands',[None])[0]
                    ls={k:image_at(d,[f'{n}/{i:02}.png']) for k,n in [('body','body'),('weapon','weapon_back'),('hands','fingers_front')]}
                elif name=='charge_hold':
                    q=d.parent/'charge_ready';ls={'body':image_at(q,['body_stow_07.png'],True),'weapon':rgba(d/'weapon_back_01.png')};behind=True
                elif name=='charge_ready':
                    duration=m['durations'][i];ls={k:image_at(d,[f'{n}_{one:02}.png']) for k,n in [('body','body_stow'),('weapon','weapon_stow'),('hands','hand_occlusion')]};behind=i>=4
                    ls['weapon']=rgba(d/f'weapon_front_{one:02}.png');ls['weapon_back']=rgba(d/f'weapon_back_{one:02}.png');behind=False
                else:
                    ls={k:image_at(d,[f'{n}_{one:02}.png']) for k,n in [('body','body_canvas'),('weapon','weapon'),('hands','hand_occlusion'),('fx','effect')]}
                    if ls['body'] is None:ls['body']=image_at(d,[f'body_{one:02}.png'],True)
                    if name=='charge_release':
                        behind=True;ls['weapon']=image_at(d,[f'weapon_back_{one:02}.png'])
                        for key,file in [('accessory_back','beads_back'),('accessory_front','beads_front')]:ls[key]=image_at(d,[f'{file}_{one:02}.png'])
                # world_root already includes the authored airborne displacement.
                if name.startswith('air_') and 'world_root' not in f:root=[root[0],root[1]-f.get('air_height',0)]
            assert ls.get('body') is not None,(hero,name,i,'body')
            assert root is not None and duration>0,(hero,name,i,'registration')
            if first_root is None:first_root=root[:]
            if not grab and name not in ['charge_ready','charge_hold','charge_release']:
                step=max(0,root[0]-first_root[0])*h/ruler
            if name.startswith('light_'):step=max(step,12*min(1,(i+1)/max(1,len(fs)*.5)))
            if hero=='ieyasu' and name=='charge_release':step=max(0,root[0]-first_root[0])
            if grip is None:grip=[root[0],root[1]-h*.6]
            if hero=='kennyo' and (grab or name in ['charge_hold','charge_release']):
                angle=17 if grab else -24
                grip=staff_socket(ls,angle)
            if hero=='tadakatsu' and grab:
                # Carry the spear clear of the floor while both hands hold the captive.
                weapon=ls['weapon'];box=weapon.getbbox();dy=min(0,round(root[1]-3-box[3]))
                shifted=Image.new('RGBA',weapon.size);shifted.alpha_composite(weapon,(0,dy));ls['weapon']=shifted
                box=shifted.getbbox();grip=[(box[0]+box[2])/2,(box[1]+box[3])/2];angle=-f['weapon_rotation_degrees']
            frames.append(frame(duration,ls,root,ruler,h,grip,angle,behind,step,grasp,
                weapon_visible=any(ls.get(k) is not None and ls[k].getbbox() for k in ['weapon','weapon_back']),
                fixed_weapon=((hero=='hideyoshi' and name.startswith('charge_')) or (hero in ['hideyoshi','ieyasu'] and (grab or name in ['charge_ready','charge_hold'])))))
            if hero=='tadakatsu' and grab:frames[-1].update(weapon_stowed=True,weapon_grip_fraction=.5)
            if hero=='kennyo':
                source_grip=f.get('weapon_source_pivot',f.get('weapon_source_grip',[64,178]))
                frames[-1]['weapon_grip_fraction']=(source_grip[1]-31)/215
                if name=='charge_ready': frames[-1]['weapon_behind']=i>=3
            tags=f.get('events',[]) or ([f['event']] if f.get('event') else [])
            if isinstance(tags,str):tags=[tags]
            if name.startswith('throw_') and any('release' in t for t in tags):events.append(dict(ms=time,event='throw_release'))
            elif name.startswith('grab_hit_') and any('contact' in t for t in tags):events.append(dict(ms=time,event='contact_normal_hit'))
            elif not grab and name not in ['charge_ready','charge_hold']:
                if any('contact' in t or t=='instant_draw_linear_hit_start' for t in tags):events.append(dict(ms=time,event='contact'))
                if hero=='tadakatsu' and name=='heavy' and 'withdraw_knockdown' in tags:events.append(dict(ms=time,event='withdraw_knockdown'))
            time+=duration
        if name=='charge_release' and hero=='kennyo':events=[dict(ms=x['start_ms'],event='contact') for x in m['strike_events']]
        if name=='charge_release' and hero=='tadakatsu':events=[dict(ms=sum(f['duration_ms'] for f in frames[:i]),event='contact') for i in [4,12]]
        # A sweep's extended contact poses are one hit window, not extra damage pulses.
        if name not in ['charge_release','heavy'] and not grab:events=events[:1]
        assert events or name in ['charge_ready','charge_hold','grab_start','grab_hold'],(hero,name,'missing event')
        clips[name]=clip(frames,events,name in ['charge_hold','grab_hold'])
    ident='mitsuhide' if hero=='kennyo' else hero
    assert len(clips)==16
    finish(ROOT/'game/assets/v33'/ident,ident,clips,h)

def nobunaga():
    src=PACKAGE/'nobunaga';patch=ROOT/'prototypes/nobunaga-repair-v36'
    overrides={(f['clip'],f['frame']):f for f in read(patch/'source-overrides.json')['frame_bindings']}
    old=builder.nobunaga();clips={}
    for entry in read(src/'delivery-manifest.json')['clips']:
        name=entry['key'];frames=[];records=read(src/entry['frames_manifest']);previous=old[name];elapsed=0
        for i,f in enumerate(records):
            feet=f.get('foot_art_native_px') or [];root=f['root_art_native_px']
            if len(feet)==2 and all(p is not None for p in feet):root=[sum(p[0] for p in feet)/2,max(p[1] for p in feet)]
            ls={('hands' if k in ['hand_occlusion','hand-foreground'] else 'weapon' if k=='weapon-visible' else k):rgba(src/v['path']) for k,v in f['layers'].items()}
            for k,fx in zip(['fx_back','fx'],f.get('fx_back_front',[])):ls[k]=rgba(src/fx['path'])
            fix=overrides.get((name,i));grip=f['grip_art_native_px'].get('primary',f['grip_art_native_px'].get('right'));axis=f.get('weapon_axis') or {};angle=float(axis.get('clockwise_angle_deg') or -90)+90
            if fix:
                ls['body']=rgba(patch/fix['body']);ls['hands']=rgba(patch/fix['hands']);ls.pop('weapon',None)
            normalized=elapsed/entry['duration_ms'];oldtime=normalized*previous['duration_ms'];acc=0;of=previous['frames'][-1]
            for candidate in previous['frames']:
                acc+=candidate['duration_ms']
                if oldtime<acc:of=candidate;break
            nf=frame(f['duration_ms'],ls,root,914,155,grip,angle, bool(fix and fix['weapon_behind_body']),of['root_step'])
            nf['grab_head']=of['grab_head'];nf['air_height']=of['air_height'];nf['authored_weapon']=not bool(fix)
            nf['weapon_longitudinal_scale']=fix.get('weapon_longitudinal_scale',1) if fix else 1
            nf['source_frame']=i;frames.append(nf);elapsed+=f['duration_ms']
        result=clip(frames,previous['events'],previous['loop'])
        result['animation_duration_ms']=result['duration_ms'];result['duration_ms']=previous['duration_ms']
        clips[name]=result
    finish(ROOT/'game/assets/v33/nobunaga','nobunaga',clips,155)

if __name__=='__main__':
    import sys
    selected=sys.argv[1:] or [*HEIGHTS,'nobunaga']
    for hero in selected:
        if hero=='nobunaga':nobunaga()
        else:
            if hero=='kennyo':staff_weapons()
            combat(hero);common(hero)
