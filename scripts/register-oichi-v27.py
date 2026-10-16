#!/usr/bin/env python3
"""Register original-approved Oichi production sheets with measured pose anchors.

Final RGB is deterministically graded before registration; raw imagegen alpha,
geometry and texture locations remain unchanged. This registration stage never
edits pixels, rescales, recolors, cleans alpha or masks source silhouettes.
Source alpha determines only a lossless crop, NEVER body scale.
Usage and the full authoring contract: docs/oichi-v27-registration.md.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import io
import json
import math
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'game/assets/v27/oichi'
PRODUCTION_ID = 'oichi-original-approved-20261013'
MIN_CANONICAL_PIXELS = 1_000_000
CLIPS = ('idle', 'walk', 'run', 'light1', 'light2', 'light3', 'heavy1', 'heavy2',
         'charged_upper', 'charged_slam', 'air_heavy', 'air_light', 'rising',
         'low_sweep', 'dash_heavy', 'dash_strike', 'jump', 'hurt', 'down',
         'recovering', 'launched', 'stunned', 'guard', 'throw', 'special', 'victory')
ALIASES = {'charge':'heavy1', 'charged':'heavy2', 'charge_upper':'charged_upper',
           'charge_slam':'charged_slam', 'holding':'throw', 'grab':'throw',
           'dead':'down', 'defeated':'down', 'pulled':'hurt', 'grabbed':'hurt',
           'frozen':'hurt', 'thrown':'launched', 'upper_heavy':'charged_upper',
           'ground_slam':'charged_slam', 'counter_cut':'light2'}
FRONT_BOW = {'heavy1', 'heavy2', 'charged_upper', 'charged_slam', 'air_heavy',
             'dash_heavy', 'guard', 'special'}
SEMANTICS = {
    'idle':'Six distinct breathing/ready poses, feet planted.',
    'walk':'Rightward heel-toe walk, wide/narrow/pass alternating legs.',
    'run':'Rightward run, alternating planted and airborne phases.',
    'light1':'Chest-height right-hand needle throw; projectiles are separate.',
    'light2':'Underhand-to-overhand backhand needle throw.',
    'light3':'Turning roundhouse kick: pivot, knee raise, high kick, follow-through, plant.',
    'heavy1':'Normal longbow shot: left grip, right-hand draw to cheek, release, recover.',
    'heavy2':'Forceful longbow volley, rising into a wide full-draw stance.',
    'charged_upper':'High-angle archery shot toward screen right.',
    'charged_slam':'Forward ice-wave/arrow shot, downward follow-through; effects separate.',
    'air_heavy':'Airborne archery shot aimed right/down, then landing preparation.',
    'air_light':'Airborne needle throw aimed right/down.',
    'rising':'Low coil into a rising needle throw/uppercut.',
    'low_sweep':'Low grounded needle sweep toward screen right.',
    'dash_heavy':'Two-handed horizontal longbow bash, NOT an archery draw.',
    'dash_strike':'Forward lunging empty-hand needle thrust.',
    'jump':'Squat, takeoff, rising, apex, descent, landing.',
    'hurt':'Impact flinch, abdominal bend, pain, partial recovery.',
    'down':'Fall from standing; final two poses horizontal prone, final eyes closed.',
    'recovering':'Start prone, elbow/seat, palm/knee, crouch, finish ready.',
    'launched':'Backward airborne knockback, rotate horizontal, brace to land.',
    'stunned':'Dizzy stagger and forehead clutch, feet on ground.',
    'guard':'Two-handed diagonal longbow guard and impact recoil.',
    'throw':'Reach/grab imaginary opponent, hip turn, shoulder throw, recovery.',
    'special':'Powerful repeated archery draws/releases, no baked effects.',
    'victory':'Relaxed turn, ponytail sweep, hand on hip, confident greeting.'
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def dump(data):
    return json.dumps(data, ensure_ascii=False, indent=2) + '\n'


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def point(value, label):
    require(isinstance(value, list) and len(value) == 2 and all(finite(v) for v in value),
            f'{label}: explicit measured [x, y] required')
    return value


def cell_rect(size, index):
    w, h = size
    require(w % 3 == 0 and h % 2 == 0, f'{size}: sheet must divide into exact 3 x 2 cells')
    cw, ch = w // 3, h // 2
    return [(index % 3) * cw, (index // 3) * ch, cw, ch]


def native_image(path, sheet=False):
    data = path.read_bytes()
    image = Image.open(io.BytesIO(data))
    image.load()
    image.info['_native_png_sha256'] = sha(data)
    require(image.mode == 'RGBA', f'{path.name}: native RGBA required; conversions prohibited')
    if sheet:
        require(image.width * image.height >= MIN_CANONICAL_PIXELS,
                f'{path.name}: expected at least {MIN_CANONICAL_PIXELS:,} canonical source pixels')
    alpha = np.asarray(image.getchannel('A'))
    require(np.count_nonzero(alpha == 0) > alpha.size * .15,
            f'{path.name}: genuine transparent background required')
    return image, alpha


def alpha_diagnostics(alpha):
    """Expose native residue without removing it or weakening acceptance gates."""
    return {'exact_zero_fraction':float(np.mean(alpha==0)),
            'alpha_at_most_8_fraction':float(np.mean(alpha<=8)),
            'alpha_at_most_32_fraction':float(np.mean(alpha<=32)),
            'global_edge_alpha_max':int(max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max()))}


def inspect_region(image, alpha, region, label, strict=True):
    require(isinstance(region,list) and len(region) == 4 and all(isinstance(v,int) for v in region)
            and region[0] >= 0 and region[1] >= 0 and region[2] > 0 and region[3] > 0
            and region[0]+region[2] <= image.width and region[1]+region[3] <= image.height,
            f'{label}: invalid source_region')
    x,y,w,h = region
    local = alpha[y:y+h,x:x+w]
    require(np.count_nonzero(local > 100) > 7000, f'{label}: missing or incomplete drawing')
    edge_max = int(max(local[0].max(),local[-1].max(),local[:,0].max(),local[:,-1].max()))
    if strict:
        require(edge_max <= 32, f'{label}: figure touches cell edge/source_region; review measured region or regenerate source')
    yy,xx = np.where(local > 0)
    left,top = int(xx.min())+x,int(yy.min())+y
    right,bottom = int(xx.max())+x+1,int(yy.max())+y+1
    return {'cell':region,'edge_alpha_max':edge_max,'alpha_bounds':[left,top,right-left,bottom-top],
            'opaque_pixels':int(np.count_nonzero(local>100)),'alpha_sha256':sha(local.tobytes())}


def inspect_sheet(path, authored_frames=None, strict=True):
    image,alpha = native_image(path,sheet=True)
    frames=[]
    for index in range(6):
        nominal=cell_rect(image.size,index) if image.width%3==0 and image.height%2==0 else None
        region=authored_frames[index].get('source_region',nominal) if authored_frames else nominal
        require(region is not None,f'{path.name} frame {index+1}: non-grid source requires explicit source_region')
        measured=inspect_region(image,alpha,region,f'{path.name} frame {index+1}',strict)
        measured['nominal_cell']=nominal
        frames.append(measured)
    return image,alpha,frames


def measure_sources(source, poses=None):
    """Read-only diagnostics for actual runtime regions, including native overrides."""
    authored=(poses or {}).get('clips',{})
    report={}
    for name in CLIPS:
        path=source/(name+'.png')
        if not path.exists():continue
        spec=authored.get(name,{})
        image,alpha=native_image(path,sheet=True)
        count=spec.get('source_figure_count',6)
        frames=[]
        if spec.get('frames'):
            for index,pose in enumerate(spec['frames']):
                file=pose.get('file',path.name)
                im,a=(image,alpha) if file==path.name else native_image(source/file)
                region=pose['source_region'] if 'source_region' in pose else cell_rect(im.size,index)
                frame=inspect_region(im,a,region,f'{name} frame {index+1}',strict=False)
                frame.update(source_file=file,source_size=list(im.size),source_sha256=im.info['_native_png_sha256'])
                frames.append(frame)
        else:
            _,_,frames=inspect_sheet(path,strict=False)
        report[name]={'source_size':list(image.size),'alpha_diagnostics':alpha_diagnostics(alpha),
                      'frames':frames,'component_review':component_review(image,alpha,count)}
    return report


def component_review(image, alpha, count=6):
    """Analysis suggestions only; never infer anatomy or hand/support anchors."""
    from scipy import ndimage
    labels,_ = ndimage.label(alpha > 32)
    require(isinstance(count,int) and 1<=count<=6 and labels.max()>=count,
            'Native source figure count must be 1..6 and cannot exceed its alpha components')
    objects = ndimage.find_objects(labels)
    sizes = np.bincount(labels.ravel())
    selected = np.argsort(sizes[1:])[-count:]+1
    parts=[]
    for identifier in selected:
        ys,xs = objects[identifier-1]
        parts.append({'label':int(identifier),'opaque_pixels':int(sizes[identifier]),
                      'body_bounds':[xs.start,ys.start,xs.stop-xs.start,ys.stop-ys.start]})
    parts.sort(key=lambda item:item['body_bounds'][1]+item['body_bounds'][3]/2)
    ordered=[part for row in [parts[:3],parts[3:]] for part in sorted(row,key=lambda item:item['body_bounds'][0])]
    for part in ordered:
        x,y,w,h = part['body_bounds']
        left,top=max(0,x-2),max(0,y-2)
        right,bottom=min(image.width,x+w+2),min(image.height,y+h+2)
        part['suggested_source_region']=[left,top,right-left,bottom-top]
        local=labels[top:bottom,left:right]
        part['foreign_major_body_pixels']=int(np.count_nonzero(np.isin(local,[v for v in selected if v != part['label']])))
    return {'global_edge_alpha_max':int(max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max())),
            'components':ordered}


def simplify_path(points, epsilon):
    if len(points) <= 2: return points
    values=np.asarray(points,dtype=float)
    start,end=values[0],values[-1]
    vector=end-start
    if np.linalg.norm(vector)==0: distances=np.linalg.norm(values-start,axis=1)
    else: distances=np.abs(vector[0]*(start[1]-values[:,1])-(start[0]-values[:,0])*vector[1])/np.linalg.norm(vector)
    index=int(distances.argmax())
    if distances[index]<=epsilon:return [points[0],points[-1]]
    return simplify_path(points[:index+1],epsilon)[:-1]+simplify_path(points[index:],epsilon)


def isolation_polygon(image, alpha, region, component_index, component_count=6):
    """Trace runtime crop metadata; source RGBA and alpha are never modified."""
    from scipy import ndimage
    review=component_review(image,alpha,component_count)
    require(isinstance(component_index,int) and 0<=component_index<component_count,'clip_component outside this native source figure count')
    selected=review['components'][component_index]['label']
    labels,_=ndimage.label(alpha>32)
    require(not any(np.any(edge==selected) for edge in [labels[0],labels[-1],labels[:,0],labels[:,-1]]),
            'Selected native figure touches global source edge; regenerate with complete padding')
    x,y,w,h=region
    own=labels[y:y+h,x:x+w]==selected
    foreign=np.isin(labels[y:y+h,x:x+w],[p['label'] for p in review['components'] if p['label']!=selected])
    require(int(own.sum())==int(np.count_nonzero(labels==selected)),'Authored source_region cuts selected component')
    # A one-pixel guard around the foreign component prevents polygon edge
    # rasterization from admitting its boundary pixels. Never remove own core.
    mask=(ndimage.binary_dilation(own,iterations=2)&~ndimage.binary_dilation(foreign,iterations=1))|own
    edges={}
    padded=np.pad(mask,1)
    def add(selected_edges,start,end):
        ys,xs=np.where(selected_edges)
        for xx,yy in zip(xs.tolist(),ys.tolist()):
            a=(xx+start[0],yy+start[1]);b=(xx+end[0],yy+end[1])
            edges.setdefault(a,[]).append(b)
    add(mask&~padded[:-2,1:-1],(0,0),(1,0))
    add(mask&~padded[1:-1,2:],(1,0),(1,1))
    add(mask&~padded[2:,1:-1],(1,1),(0,1))
    add(mask&~padded[1:-1,:-2],(0,1),(0,0))
    loops=[]
    while edges:
        start=next(iter(edges));current=start;loop=[]
        while True:
            loop.append(current)
            following=edges[current].pop()
            if not edges[current]:del edges[current]
            current=following
            if current==start:break
            require(current in edges,'Non-simple isolation boundary; author a polygon explicitly')
        loops.append(loop)
    area=lambda poly:abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))
    outer=max(loops,key=area)
    opposite=int(np.linalg.norm(np.asarray(outer)-np.asarray(outer[0]),axis=1).argmax())
    for epsilon in [1.0,.5,.1,0.0]:
        polygon=simplify_path(outer[:opposite+1],epsilon)[:-1]+simplify_path(outer[opposite:]+outer[:1],epsilon)[:-1]
        raster=Image.new('L',(w,h));ImageDraw.Draw(raster).polygon(polygon,fill=1)
        visible=np.asarray(raster)>0
        if not np.any(own&~visible) and not np.any(foreign&visible):
            return [[xx+x,yy+y] for xx,yy in polygon]
    raise ValueError('Isolation polygon cannot retain own body and exclude neighbors; manual contour review required')


def inside(value, rect, label):
    x, y = point(value, label)
    left, top, width, height = rect
    require(left <= x < left + width and top <= y < top + height,
            f'{label}: {value} outside cell {rect}')


def measured_hand(value, alpha, cell, label):
    inside(value, cell, label)
    x, y = map(lambda v: int(round(v)), value)
    require(0 <= y < alpha.shape[0] and 0 <= x < alpha.shape[1] and alpha[y,x] > 100,
            f'{label}: grip/stow point must be on the drawn body')


def template(source_dir):
    result = {'schema_version':1, 'version':'v27', 'hero':'oichi', 'grid':[3,2],
              'production_id':PRODUCTION_ID, 'provenance':{},
              'coordinate_space':'full_sheet_pixels',
              'portrait':{'file':'idle.png', 'rect':None}, 'clips':{}}
    for name in CLIPS:
        entry = {'file':name + '.png', 'source_sha256':None, 'body_height':None,
                 'anatomical_measurement':None, 'action_semantics':SEMANTICS[name], 'frames':[]}
        info = None
        if (source_dir / (name + '.png')).exists():
            image,_ = native_image(source_dir / (name + '.png'),sheet=True)
            if image.width%3==0 and image.height%2==0:
                _, _, info = inspect_sheet(source_dir / (name + '.png'), strict=False)
            entry['source_sha256'] = image.info['_native_png_sha256']
        for index in range(6):
            pose = {'foot':None, 'hand':None, 'weapon_angle':None,
                    'weapon_behind':name not in FRONT_BOW, 'weapon_visible':True}
            if name in FRONT_BOW:
                pose['hand_occluders'] = []
            if info:
                pose['measured_alpha_bounds_for_review_only'] = info[index]['alpha_bounds']
            entry['frames'].append(pose)
        result['clips'][name] = entry
    return result


def build(assets, poses, allow_partial=False):
    require(poses.get('schema_version') == 1 and poses.get('version') == 'v27' and poses.get('hero') == 'oichi',
            'Pose schema must declare schema_version=1, version=v27, hero=oichi')
    require(poses.get('production_id') == PRODUCTION_ID,
            f'Pose schema must declare production_id={PRODUCTION_ID}')
    require(isinstance(poses.get('provenance'),dict), 'Pose schema must include a provenance dictionary')
    require(poses.get('grid') == [3,2] and poses.get('coordinate_space') == 'full_sheet_pixels',
            'Use 3 x 2 grid and full_sheet_pixels authoring coordinates')
    selected = set(poses.get('clips', {}))
    require(bool(selected) and selected.issubset(CLIPS) and (allow_partial or selected == set(CLIPS)), 'Exactly the original 26 authored actions required')
    registration = {'version':'v27', 'runtime_schema':'v22', 'hero':'oichi',
                    'production_id':poses['production_id'], 'provenance':copy.deepcopy(poses['provenance']),
                    'identity_notes':'Original-approved Oichi identity, original long ponytail, costume and texture; separate production from the rejected earlier v27 artwork.',
                    'portrait':poses['portrait'], 'clips':{}, 'aliases':{k:v for k,v in ALIASES.items() if v in selected},
                    'complete':selected == set(CLIPS),
                    'source_notes':'Final RGB is deterministically graded from raw imagegen sources before registration; raw alpha, dimensions, geometry and texture locations are preserved. Raw/final hashes and grading inputs are recorded in provenance and verified by the grading workflow. Registration preserves the final graded PNG bytes and decoded RGBA. Lossless rectangular crops retain all source pixels in each authored isolated region, including original alpha and disconnected details. Foot, grip, angle and optional draw-hand/occluders are explicitly measured in source pixels. Anatomical rulers are authored independently of pose alpha bounds. No runtime palette filter, source-alpha cleanup or garment patch is applied.',
                    'pose_anchors_sha256':sha(dump(poses).encode('utf-8'))}
    source_images = {}
    for name in CLIPS:
        if name not in selected: continue
        spec = poses['clips'][name]
        filename = spec.get('file')
        require(filename == name + '.png', f'{name}: canonical source filename is {name}.png')
        require(spec.get('source_sha256') == sha((assets/filename).read_bytes()),
                f'{name}: anchor measurements must be bound to this exact source SHA256; remeasure changed art')
        require(len(spec.get('frames', [])) == 6, f'{name}: exactly six authored anchor sets required')
        base_image, base_alpha = native_image(assets / filename,sheet=True)
        require(base_image.info['_native_png_sha256']==spec['source_sha256'],f'{name}: source changed while reading; retry after generation settles')
        source_images[filename] = base_image
        measurement = spec.get('anatomical_measurement')
        require(isinstance(measurement, str) and len(measurement.strip()) >= 16,
                f'{name}: describe the manually measured anatomical ruler/reference (not alpha bounds)')
        frames, hashes = [], []
        for index, pose in enumerate(spec['frames']):
            label = f'{name} frame {index+1}'
            frame_file = pose.get('file',filename)
            require(Path(frame_file).name == frame_file and frame_file.endswith('.png'), f'{label}: unsafe source filename')
            if frame_file != filename:
                require(pose.get('source_sha256') == sha((assets/frame_file).read_bytes()), f'{label}: replacement anchors need exact source SHA256')
                require('source_region' in pose and 'body_height' in pose, f'{label}: native replacement requires explicit source_region and anatomical body_height')
                image,alpha = native_image(assets/frame_file)
                require(image.info['_native_png_sha256']==pose['source_sha256'],f'{label}: replacement changed while reading')
                source_images[frame_file] = image
                region = pose['source_region']
            else:
                image,alpha = base_image,base_alpha
                region = pose['source_region'] if 'source_region' in pose else cell_rect(image.size,index)
            measured = inspect_region(image,alpha,region,label,strict='clip_component' not in pose)
            polygon = isolation_polygon(image,alpha,region,pose['clip_component'],pose.get('component_count',6)) if 'clip_component' in pose else pose.get('clip_polygon')
            if polygon is not None:
                require(isinstance(polygon,list) and len(polygon)>=3,f'{label}: clipping polygon needs at least three measured vertices')
                for vertex in polygon:
                    vx,vy=point(vertex,f'{label} polygon vertex')
                    require(region[0]<=vx<=region[0]+region[2] and region[1]<=vy<=region[1]+region[3],f'{label}: polygon outside authored source region')
            cell = measured['cell']
            height = pose.get('body_height', spec.get('body_height'))
            require(finite(height) and height >= 280, f'{label}: explicit anatomical body_height >= 280 required')
            inside(pose.get('foot'), cell, label + ' foot')
            measured_hand(pose.get('hand'), alpha, cell, label + ' hand')
            require(finite(pose.get('weapon_angle')), f'{label}: explicit measured weapon_angle required')
            for flag in ['weapon_behind', 'weapon_visible']:
                require(isinstance(pose.get(flag), bool), f'{label}: explicit boolean {flag} required')
            x, y, w, h = measured['alpha_bounds']
            # Empty virtual support points may extend beyond opaque shoes (jump,
            # knockback and prone poses). Include them as empty crop pixels.
            fx, fy = pose['foot']
            left, top = min(x,math.floor(fx)), min(y,math.floor(fy))
            right, bottom = max(x+w,math.floor(fx)+1), max(y+h,math.floor(fy)+1)
            # An authored occluder may include a few transparent pixels around
            # the fist. Retain that native padding instead of rejecting a valid
            # hand rectangle merely because its border exceeds alpha bounds.
            for oc in pose.get('hand_occluders', []):
                require(isinstance(oc,list) and len(oc)==4 and all(finite(v) for v in oc)
                        and oc[2]>0 and oc[3]>0, f'{label}: invalid hand occluder')
                require(cell[0]<=oc[0] and cell[1]<=oc[1]
                        and oc[0]+oc[2]<=cell[0]+cell[2] and oc[1]+oc[3]<=cell[1]+cell[3],
                        f'{label}: hand occluder outside authored source region')
                left,top=min(left,math.floor(oc[0])),min(top,math.floor(oc[1]))
                right,bottom=max(right,math.ceil(oc[0]+oc[2])),max(bottom,math.ceil(oc[1]+oc[3]))
            rect = [left,top,right-left,bottom-top]
            local = lambda p: [p[0]-left,p[1]-top]
            frame = {'file':frame_file, 'source_sha256':image.info['_native_png_sha256'], 'rect':rect, 'foot':local(pose['foot']),
                     'body_height':height, 'hand':local(pose['hand']),
                     'weapon_angle':pose['weapon_angle'], 'weapon_behind':pose['weapon_behind'],
                     'weapon_visible':pose['weapon_visible'], 'source_cell':cell}
            if polygon:
                frame['clip_polygon']=[local(p) for p in polygon]
            if pose.get('second_hand') is not None:
                measured_hand(pose['second_hand'], alpha, cell, label + ' second_hand')
                frame['second_hand'] = local(pose['second_hand'])
            if not pose['weapon_behind'] and pose['weapon_visible']:
                require(pose.get('hand_occluders'), f'{label}: front-layer bow needs measured hand_occluders')
            if pose.get('hand_occluders'):
                frame['hand_occluders'] = []
                for oc in pose['hand_occluders']:
                    require(isinstance(oc,list) and len(oc) == 4 and all(finite(v) for v in oc)
                            and oc[2] > 0 and oc[3] > 0, f'{label}: invalid hand occluder')
                    require(left <= oc[0] and top <= oc[1] and oc[0]+oc[2] <= right and oc[1]+oc[3] <= bottom,
                            f'{label}: occluder extends outside native body crop')
                    frame['hand_occluders'].append([oc[0]-left,oc[1]-top,oc[2],oc[3]])
            crop = image.crop((left,top,right,bottom))
            frame['rgba_sha256'] = sha(crop.tobytes())
            frame['alpha_sha256'] = sha(crop.getchannel('A').tobytes())
            hashes.append(frame['rgba_sha256'])
            frames.append(frame)
        require(len(set(hashes)) == 6, f'{name}: duplicate drawn frames')
        registration['clips'][name] = {'frames':frames, 'source_sha256':base_image.info['_native_png_sha256'],
                                      'source_rgba_sha256':sha(base_image.tobytes()),
                                      'source_alpha_sha256':sha(base_image.getchannel('A').tobytes()),
                                      'source_size':list(base_image.size), 'anatomical_measurement':measurement,
                                      'source_figure_count':spec.get('source_figure_count',6),
                                      'action_semantics':SEMANTICS[name]}
    registration['sources'] = {filename:{'sha256':image.info['_native_png_sha256'],'rgba_sha256':sha(image.tobytes()),'alpha_sha256':sha(image.getchannel('A').tobytes()),'size':list(image.size),'alpha_diagnostics':alpha_diagnostics(np.asarray(image.getchannel('A')))} for filename,image in source_images.items()}
    pose_groups={}
    for clip_name,clip in registration['clips'].items():
        for index,frame in enumerate(clip['frames']):
            key=frame['rgba_sha256']
            pose_groups.setdefault(key,{'rgba_sha256':key,'source_file':frame['file'],'frames':[]})['frames'].append(f'{clip_name}/{index+1}')
    registration['registered_frame_count']=sum(len(c['frames']) for c in registration['clips'].values())
    registration['unique_drawn_pose_count']=len(pose_groups)
    registration['shared_drawn_poses']=[value for value in pose_groups.values() if len(value['frames'])>1]
    for filename,info in registration['sources'].items():
        require(sha((assets/filename).read_bytes())==info['sha256'],f'{filename}: source changed during registration; retry after generation settles')
    portrait = registration['portrait']
    require(isinstance(portrait,dict) and portrait.get('file') in source_images, 'Portrait must use a registered new source')
    r = portrait.get('rect')
    require(isinstance(r,list) and len(r) == 4 and all(isinstance(v,int) for v in r) and r[2] > 0 and r[3] > 0,
            'Portrait requires measured full-sheet integer rect [x,y,w,h]')
    image = source_images[portrait['file']]
    require(0 <= r[0] and 0 <= r[1] and r[0]+r[2] <= image.width and r[1]+r[3] <= image.height, 'Portrait outside source')
    return registration


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', type=Path, default=ASSETS)
    parser.add_argument('--source-dir', type=Path, help='Optional final RGB-graded RGBA sources; copy unchanged only after complete validation')
    parser.add_argument('--poses', type=Path, help='Measured full-sheet anchor JSON (default: assets/pose-anchors.json)')
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--measure', action='store_true', help='Report native cell/alpha bounds only; no guessed pose anchors')
    modes.add_argument('--init-poses', type=Path, help='Write a non-runtime template with deliberately blank manual measurements')
    modes.add_argument('--check', action='store_true', help='Verify registration/source/anchor drift without writing')
    modes.add_argument('--draft', type=Path, help='Validate supplied partial clips and write review metadata only; never activate or copy sources')
    args = parser.parse_args()
    source = args.source_dir or args.assets
    if args.measure:
        poses=json.loads(args.poses.read_text()) if args.poses else None
        report=measure_sources(source,poses)
        print(dump(report), end='')
        return
    if args.init_poses:
        require(not args.init_poses.exists(), f'{args.init_poses}: refusing to overwrite authored anchors')
        args.init_poses.parent.mkdir(parents=True, exist_ok=True)
        args.init_poses.write_text(dump(template(source)), encoding='utf-8')
        print(f'Wrote {args.init_poses}; fill all manual measurements before registration.')
        return
    pose_path = args.poses or args.assets/'pose-anchors.json'
    poses = json.loads(pose_path.read_text(encoding='utf-8'))
    result = build(source, poses,allow_partial=bool(args.draft))
    data = dump(result)
    if args.draft:
        require(args.draft.resolve() != (args.assets/'registration.json').resolve(), 'A draft cannot activate the runtime manifest')
        args.draft.parent.mkdir(parents=True,exist_ok=True)
        args.draft.write_text(data,encoding='utf-8')
        print(f'PASS draft only: {len(result["clips"])} clips / {sum(len(c["frames"]) for c in result["clips"].values())} measured frames; runtime unchanged.')
        return
    if args.check:
        require((args.assets/'registration.json').read_text(encoding='utf-8') == data,
                'Registration/source/anchor drift; rebuild and review')
        for filename,source_info in result['sources'].items():
            require(sha((args.assets/filename).read_bytes()) == source_info['sha256'],
                    f'{filename}: runtime source differs from original')
        require(json.loads((args.assets/'pose-anchors.json').read_text(encoding='utf-8')) == poses,
                'Runtime measured anchor source differs from supplied authoring file')
    else:
        args.assets.mkdir(parents=True, exist_ok=True)
        for filename,source_info in result['sources'].items():
            src, target = source/filename, args.assets/filename
            if src.resolve() != target.resolve():
                shutil.copyfile(src, target)
            require(sha(target.read_bytes()) == source_info['sha256'], f'{filename}: copy changed source bytes')
        (args.assets/'pose-anchors.json').write_text(dump(poses), encoding='utf-8')
        # Last operation activates the full revision. An incomplete generation
        # cannot accidentally replace only some old clips in the running game.
        temporary = args.assets/'registration.json.tmp'
        temporary.write_text(data, encoding='utf-8')
        temporary.replace(args.assets/'registration.json')
    print(f'PASS {result["production_id"]} (v27): 26 clips / 156 registered frames / {result["unique_drawn_pose_count"]} unique drawn poses; measured anatomy/anchors; final graded RGBA preserved by registration.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, FileNotFoundError, KeyError) as error:
        sys.exit(f'Oichi v27 registration blocked: {error}')
