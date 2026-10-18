"""Compile the selected Mikawa handoff into explicit, byte-preserved runtime assets."""
import hashlib
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'deliveries/stage04-mikawa-20261017/stage04'
DEST = ROOT / 'game/assets/stage4'
FILES = {}
# Source body scale, measured without weapons; crouching never changes magnification.
MINIBOSS_HEIGHTS = {
    'tominaga_sweep': 340, 'tominaga_pursuit': 340, 'tominaga_heavy_chop': 340,
    'tominaga_locomotion': 420, 'tominaga_reactions': 330, 'tominaga_recovery': 400,
    'kira_arrow': 410, 'kira_command': 410, 'kira_counter': 400,
    'kira_locomotion': 430, 'kira_reactions': 330, 'kira_recovery': 430,
}


def miniboss_geometry(atlas_id, row):
    rect = list(row['source_rect'])
    foot = list(row['foot_anchor_source'])
    index = row['frame']
    # Authored poses cross the nominal row boundary: include feet/head, exclude the adjacent pose.
    if atlas_id.endswith('_reactions'):
        boundary = 374 if atlas_id.startswith('tominaga') else 384
        if index < 4:
            rect[3] = boundary
            foot[1] = 370 if atlas_id.startswith('tominaga') else 375
        elif index < 8:
            rect[1], rect[3] = boundary, 724-boundary
        if atlas_id.startswith('tominaga') and index % 4 < 2:
            end = rect[0]+rect[2]
            rect[0] = 0 if index % 4 == 0 else 360
            rect[2] = 360 if index % 4 == 0 else end-360
    elif atlas_id == 'tominaga_recovery' and index in (3,7):
        rect[1], rect[3] = (0,405) if index == 3 else (405,482)
        if index == 3: foot[1] = 370
    return rect, foot



def read(name):
    return json.loads((SOURCE / name).read_text('utf-8-sig'))


def copy(name):
    src = (SOURCE / name).resolve()
    assert src.is_relative_to(SOURCE.resolve()) and src.is_file(), name
    assert not any(s in src.parts for s in ('preview', 'raw', 'superseded')), name
    dst = DEST / name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    digest = hashlib.sha256(src.read_bytes()).hexdigest()
    assert hashlib.sha256(dst.read_bytes()).hexdigest() == digest
    FILES[name] = digest
    return name


def frame(path, anchor, height, ms, region=None):
    value = dict(path=copy(path), anchor=anchor, body_height=height, duration_ms=ms)
    if region is not None:
        value['region'] = region
    assert ms > 0 and height > 0
    return value


def keyed(folder, keys, duration, frames, height):
    result = []
    for i, key in enumerate(keys):
        row = frames[key['frame']]
        end = keys[i+1]['time_s'] if i+1 < len(keys) else duration
        result.append(frame(folder+'/'+row['file'], row['root'], height,
                            round((end-key['time_s'])*1000, 6)))
    assert abs(sum(f['duration_ms'] for f in result)-duration*1000) < .01
    return result


def build():
    manifest = read('manifest.json')
    for value in manifest['canonical_components'].values(): copy(value)
    actors = {}
    troops = read(manifest['canonical_components']['troop_base'])
    alert = read(manifest['canonical_components']['troop_walk_and_ready'])
    for side, role in [('kira','spear'),('udono','spear'),('kira','shield'),('udono','shield'),('kira','archer')]:
        folder = f'characters/troops/{role}_{side}'
        clips = {}
        for action, spec in troops['characters'][role]['animations'].items():
            clips[action] = dict(loop=spec['loop'], frames=[frame(f'{folder}/frames/{idx:02}.png', troops['pivot'], 210 if troops['characters'][role]['frame_metadata'][idx]['source']=='spear_reactions' else 180, ms)
                for idx, ms in zip(spec['frames'], spec['duration_ms'])])
        newer = f'characters/troops/alert/{role}_{side}'
        clips['idle'] = dict(loop=True, frames=[frame(newer+'/ready.png', alert['pivot'],180,520)])
        clips['walk'] = dict(loop=True, frames=[frame(newer+f'/walk_{i}.png',alert['pivot'],180,ms) for i,ms in enumerate(alert['duration_ms'])])
        clips['attack']['release_ms'] = sum(troops['characters'][role]['animations']['attack']['duration_ms'][:4])
        actors[f'{role}_{side}'] = clips
    upward = 'characters/minibosses/specials/assets/archer_upward'
    poses = read(upward+'/manifest.json')
    # These six authored upward poses are used by the existing archer, never a spawned helper.
    candidates = sorted((SOURCE/upward).glob('volley_*.png'))
    assert len(candidates) == 6, [p.name for p in candidates]
    actors['archer_kira']['rain'] = dict(loop=False,frames=[frame(p.relative_to(SOURCE).as_posix(),poses['pivot'],180,ms) for p,ms in zip(candidates,poses['durations_ms'])])

    gun = read('characters/gunner/manifest.json')
    def gunframe(path,row,ms,height):
        rect,foot = row['source_region'],row['source_foot']
        return frame('characters/gunner/'+path,[foot[0]-rect[0],foot[1]-rect[1]],height,ms,rect)
    clips = {'walk':dict(loop=True,frames=[gunframe('gunner-walk-cycle-udono.png',r,r['duration_ticks']*1000/60,465) for r in gun['frames']])}
    clips['idle'] = dict(loop=True, frames=[clips['walk']['frames'][0]])
    actions = read('characters/gunner/actions-manifest.json')
    for action,spec in actions['clips'].items():
        rows = spec['frames']; timing = actions['timing'][action]
        marks = timing.get('frame_ticks',[])
        holds = [(marks[i+1] if i+1 < len(marks) else timing['duration_ticks'])-v for i,v in enumerate(marks)] if marks else [timing.get('duration_ticks',24)/len(rows)]*len(rows)
        clips[action] = dict(loop=action=='struggle',frames=[gunframe('atlases/'+spec['source_file'],row,hold*1000/60,row['source_body_height']) for row,hold in zip(rows,holds)])
    clips['gun_shot']['release_ms'] = actions['timing']['gun_shot']['release_tick']*1000/60
    clips['down'] = dict(loop=False,frames=[clips['death']['frames'][-1]])
    clips['knockdown'] = clips['death']
    clips['recovery'] = dict(loop=False,frames=list(reversed(clips['death']['frames'])))
    clips['stunned'] = clips['hurt']
    actors['gunner'] = clips

    miniboss = read('characters/minibosses/animation_manifest.json')
    for who in ('kira','tominaga'):
        clips = {}
        for spec in miniboss['moves']+miniboss['supporting_atlases']:
            if not spec['id'].startswith(who+'_'): continue
            for action in sorted(set(row.get('action',spec['id']) for row in spec['frames'])):
                rows = [r for r in spec['frames'] if r.get('action',spec['id'])==action]
                # Fixed calibration per authored atlas, including crouched/fallen poses.
                height = MINIBOSS_HEIGHTS[spec['id']]
                frames = []
                for row in rows:
                    rect,foot = miniboss_geometry(spec['id'],row)
                    entry = frame('characters/minibosses/'+spec['atlas'],[foot[0]-rect[0],foot[1]-rect[1]],height,row['duration_ms'],rect)
                    if row.get('crest_visibility') == 'visible':
                        crest = row['crest_anchor_source']
                        entry['crest'] = dict(path=copy('characters/minibosses/crest/kira_crest_ivory.png'),anchor=[crest[0]-rect[0],crest[1]-rect[1]],width=row['crest_width_px'])
                    frames.append(entry)
                clips[action] = dict(loop=action in ('idle','walk','withdraw','stunned'),frames=frames)
        clips['down'] = dict(loop=False,frames=[clips['recovery']['frames'][0]])
        clips['knockdown'] = dict(loop=False,frames=list(reversed(clips['recovery']['frames'])))
        actors[who] = clips

    base = read('characters/udono/base/manifest_v4.json')
    clips = {}
    for action in base['actions']:
        clips[action['id']] = dict(loop=action['loop'],frames=keyed('characters/udono/base',action['keys'],action['duration_s'],base['frames'],320),events=action['events'])
    slam = read('characters/udono/slam/manifest_patch.json')
    rows = {r['frame']:r for r in slam['frames']}
    for key in ('single','triple'):
        action = slam[key]
        clips[action['id']] = dict(loop=False,frames=keyed('characters/udono/slam',action['keys'],action['duration_s'],rows,320))
    spin = read('characters/udono/spin/manifest_patch.json')
    clips['udono_melee_spin_counter'] = dict(loop=False,frames=keyed('characters/udono/spin',spin['keys'],spin['duration_s'],{r['id']:r for r in spin['frames']},320))
    rock = read('characters/udono/rock/manifest_patch.json')
    keys = [dict(time_s=start+k['time_s'],frame=k['frame']) for start in rock['cycle_starts_s'] for k in rock['cycle_keys']]
    clips[rock['id']] = dict(loop=False,frames=keyed('characters/udono/rock',keys,rock['duration_s'],{r['frame']:r for r in rock['frame_anchors']},341.7))
    for clip in clips.values():
        for row in clip['frames']:
            path = row['path']
            if '/walking/' in path or 'motion_correction_' in path: row['body_height'] = 400
            elif '/slam/' in path: row['body_height'] = 370
            elif '/spin/' in path: row['body_height'] = 350
            elif '/rock/' in path: row['body_height'] = 360
            elif '/base/' in path and 'base_states_' not in path: row['body_height'] = 350
    actors['udono'] = clips
    # Copy only the active layers. Bodies retain their original pixels and foot anchors.
    for pattern in ('characters/udono/base/radial_phase_*.png','characters/udono/base/other_vfx/*.png','characters/udono/spin/vfx/*.png','characters/udono/rock/vfx/*.png','characters/udono/rock/stone.png',
                    'backgrounds/*.png','backgrounds/crowd/frames/*.png','props/barricade/sprites/*.png','props/cheval/sprites/*.png','props/flags/frames/*.png','props/flags/damage/*_0?.png',
                    'props/flags/destroy/*_wood_crossfoot_break_0?.png','props/flags/sfx/*.ogg',
                    'characters/minibosses/specials/assets/tominaga_groundwave_8.png','audio/voices/processed/ogg/*.ogg',
                    'audio/weapons/processed/ogg/*.ogg','audio/shield/ogg/*.ogg','audio/stone_quake_v1/ogg/*.ogg','audio/objects/ogg/*.ogg',
                    'audio/music/assets/*.ogg','audio/music/assets/*.wav','audio/crowd/groups/*.ogg'):
        for path in SOURCE.glob(pattern): copy(path.relative_to(SOURCE).as_posix())
    for name in ('audio/music/CREDITS.txt','audio/music/external_dependency.json','audio/music/docs/LICENSE_AUDIT.txt','props/barricade/barricade_manifest.json','props/cheval/cheval_manifest.json'):
        copy(name)
    # Godot rejects WAVE_FORMAT_EXTENSIBLE; retain the exact 24-bit PCM samples.
    intro = 'audio/music/assets/s04_intro_oboro2_once.wav'
    wav = (DEST/intro).read_bytes()
    fmt = wav.index(b'fmt ')
    size = struct.unpack_from('<I',wav,fmt+4)[0]
    assert size == 40 and wav[fmt+8:fmt+10] == b'\xfe\xff' and wav[fmt+32:fmt+36] == b'\x01\x00\x00\x00'
    body = wav[12:fmt]+b'fmt '+struct.pack('<I',16)+b'\x01\x00'+wav[fmt+10:fmt+24]+wav[fmt+8+size:]
    pcm = b'RIFF'+struct.pack('<I',len(body)+4)+b'WAVE'+body
    derivative = intro.replace('_once.wav','_pcm.wav')
    (DEST/derivative).write_bytes(pcm)
    FILES[derivative] = hashlib.sha256(pcm).hexdigest()
    DEST.mkdir(parents=True,exist_ok=True)
    (DEST/'actors.json').write_text(json.dumps(actors,ensure_ascii=False,separators=(',',':'))+'\n','utf-8')
    nodes = read('layout/stage4_nodes_proposal.json')['nodes']
    stage = dict(id=4,title='三河歸途',faction='imagawa',year=1560,target_minutes=[10,18],segments=[])
    names = {'kira_spear':('soldier','spear_kira'),'udono_spear':('soldier','spear_udono'),
             'kira_shield':('soldier','shield_kira'),'udono_shield':('soldier','shield_udono'),
             'kira_archer':('archer','archer_kira'),'udono_matchlock_reinforcement':('gunner','gunner'),
             'miniboss_tominaga':('boss','tominaga'),'miniboss_kira':('boss','kira'),'boss_udono_nagateru':('boss','udono')}
    density_path = ROOT/'deliveries/stage04-mikawa-20261017/enemy-reinforcements-20261018/stage04_density_v2.json'
    density = json.loads(density_path.read_text('utf-8-sig'))['nodes']
    assert [n['id'] for n in density] == list(range(1,14))
    def roster(pool):
        result = []
        for design_id, count in pool.items():
            assert design_id in names and isinstance(count,int) and count > 0
            kind,role = names[design_id]
            result.extend(dict(kind=kind,role=role) for _ in range(count))
        return result
    for group in range(1,6):
        section = [n for n in nodes if n['section_id']==group]
        segment = dict(name=section[0]['section_name'],theme='road',weather='clear',music='s04_intro' if group==1 else 's04_hot',width=2172*len(section),civilians='none',props=[],encounters=[])
        for index,node in enumerate(section):
            offset = index*2172
            def position(anchor): return [round(offset+anchor[0],3),round(360+(anchor[1]-478)*240/202,3)]
            rule = density[node['id']-1]
            units=[]
            for row in node['combat_instances']:
                kind,role=names[row['archetype']];x,y=position(row['local_art_anchor'])
                if kind == 'boss' or (node['id']==10 and kind=='archer'):
                    units.append(dict(kind=kind,role=role,x=x,y=y,escort=node['id']==10 and kind=='archer'))
            for slot,unit in enumerate(roster(rule['initial_regular'])):
                units.append(dict(**unit,x=offset+720+(slot//3)*170,y=[390,480,570][slot%3],escort=False))
            assert len(units) == rule['initial_total_count']
            batches = [dict(left=roster(b['left']),right=roster(b['right'])) for b in rule['reinforcement_batches']]
            assert len(batches) in (2,3) and all(len(b['left'])==len(b['right']) and len(b['left']) in (3,4) for b in batches)
            assert len(units)+sum(len(b['left'])+len(b['right']) for b in batches)==rule['finite_scheduled_total_count']
            props=[]
            for row in node['props']:
                x,y=position(row['local_art_anchor']);key=row['asset_key']
                props.append(dict(asset=key,x=x,y=y))
            spec=dict(end=offset+2172,mode='mikawa',node=node['id'],name=node['name'],units=units,objects=props,waves=[[u['kind'] for u in units]],batches=batches,cap=rule['simultaneous_cap'],regular_cap=rule['regular_pool_cap'],scheduled_total=rule['finite_scheduled_total_count'])
            if node['mud']['enabled']: spec['mud']=[position(point) for point in node['mud']['polygon_art_px']]
            segment['encounters'].append(spec)
        stage['segments'].append(segment)
    (ROOT/'game/data/stage-04.json').write_text(json.dumps(stage,ensure_ascii=False,indent=2)+'\n','utf-8')
    FILES['actors.json']=hashlib.sha256((DEST/'actors.json').read_bytes()).hexdigest()
    (DEST/'runtime-files.json').write_text(json.dumps(FILES,indent=2,ensure_ascii=False)+'\n','utf-8')
    print(len(FILES),'runtime assets;',sum((DEST/p).stat().st_size for p in FILES),'bytes')


if __name__ == '__main__': build()
