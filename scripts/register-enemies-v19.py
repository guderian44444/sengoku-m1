"""Register original Imagawa drawings without repainting, resampling or flattening alpha.

Regions follow whole alpha-connected sprites, not nominal grid boundaries. Anatomical
scale is measured from helmet/head to sole in an upright pose; a single scale stays
fixed through each attack/reaction/death atlas so a crouch or corpse stays shorter.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from scipy import ndimage
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'game/assets/v19/enemies'
ROLES = ['soldier','flag','commander','archer','gunner','boss','matsui']
ATTACKS = {
    'soldier':['spear_thrust','spear_sweep','spear_butt'],
    'flag':['flag_poke','flag_sweep','flag_slam'],
    'commander':['commander_cut','commander_rise','commander_dash'],
    'archer':['bow_shot'], 'gunner':['gun_shot'],
    'boss':['boss_sweep','boss_thrust','boss_counter','boss_dash'],
    'matsui':['boss_sweep','boss_thrust','boss_counter','boss_earth'],
}
# Source-pixel anatomical standing height, excluding held weapons/flags. These are
# atlas-wide rulers, never the current pose's alpha height. Death keeps this ruler.
RULERS = {
    'soldier':{'walk':310,'reactions':480,'death':535,'spear_thrust':395,'spear_sweep':285,'spear_butt':280},
    'flag':{'walk':438,'reactions':457,'death':350,'flag_poke':375,'flag_sweep':292,'flag_slam':255},
    'commander':{'walk':565,'reactions':535,'death':545,'commander_cut':475,'commander_rise':300,'commander_dash':295},
    'archer':{'walk':503,'reactions':500,'death':490,'bow_shot':354},
    'gunner':{'walk':460,'reactions':450,'death':465,'gun_shot':448},
    'boss':{'walk':506,'reactions':500,'death':485,'boss_sweep':270,'boss_thrust':280,'boss_counter':255,'boss_dash':270},
    'matsui':{'walk':508,'reactions':510,'death':495,'boss_sweep':278,'boss_thrust':302,'boss_counter':245,'boss_earth':230},
}
# Standalone atlas layout repairs use wide columns. Metadata can override this.
WIDE = {'commander-death','boss-death','matsui-death','flag-flag_poke',
        'commander-commander_cut','commander-reactions','flag-death'}
PROJECTILES = {
    # Source-space muzzle / arrow release, one hand point per actual drawing.
    'archer-bow_shot':[[364,326],[791,279],[1183,278],[358,856],[783,874],[1178,874]],
    'gunner-gun_shot':[[465,294],[851,208],[1241,245],[426,716],[819,790],[1238,861]],
}
# Where hanging cloth/tassels lie below the body, support is a manually measured
# shoe/body contact rather than the lowest colored pixel.
SUPPORT = {
    'flag-flag_sweep':{4:[255,1151]},
    'matsui-death':{4:[320,1178],5:[925,1187]},
}

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def source_metadata():
    recipes={}
    for name in ['generation-journal.json','attack-generation-journal.json','troop-attack-generation-journal.json']:
        path=ASSETS/name
        if path.exists():
            for recipe in read_json(path).get('recipes',[]): recipes[recipe['file']]=recipe
    return recipes

def components(path, columns, count):
    image=Image.open(path).convert('RGBA')
    alpha=np.asarray(image)[:,:,3]
    labels,n=ndimage.label(alpha>64)
    sizes=np.bincount(labels.ravel());sizes[0]=0
    indices=np.argsort(sizes)[::-1][:count]
    objects=ndimage.find_objects(labels)
    result=[]
    for label in indices:
        ys,xs=objects[label-1]
        x0,y0,x1,y1=xs.start,ys.start,xs.stop,ys.stop
        mask=labels==label
        # Ground-contact center uses the sole band; the weapon never sets support.
        yy,xx=np.where(mask & (np.indices(mask.shape)[0]>=y1-14))
        foot=[round(float((xx.min()+xx.max())/2),2),y1-1]
        result.append({'label':int(label),'box':[x0,y0,x1,y1], 'feet':foot,
                       'pixels':int(sizes[label]),'center':[(x0+x1)/2,(y0+y1)/2]})
    result.sort(key=lambda c:c['center'][1])
    ordered=[]
    for start in range(0,count,columns):
        ordered.extend(sorted(result[start:start+columns],key=lambda c:c['center'][0]))
    return image,alpha,labels,ordered

def register(role,clip,recipes):
    filename=f'{role}-{"walk-cycle" if clip=="walk" else clip}.png'
    path=ASSETS/filename
    if not path.exists(): return None
    recipe=recipes.get(filename,{})
    columns=4 if role=='soldier' and clip=='walk' else (2 if path.stem in WIDE or clip in ATTACKS.get(role,[]) and role in ['boss','matsui'] else 3)
    columns=int(recipe.get('grid',[columns])[0])
    total=12 if role=='soldier' and clip=='walk' else 6
    image,alpha,labels,parts=components(path,columns,total)
    # Six distinct wide -> narrow -> passing phases from the twelve-pose source.
    selected=[0,2,3,5,8,9] if total==12 else list(range(6))
    ruler=RULERS[role].get(clip)
    if ruler is None:
        # A new primary atlas must carry an explicit anatomical ruler before release.
        raise ValueError(f'Missing anatomical ruler: {role}/{clip}')
    feet=[];regions={};foot_spans=[];body_heights=[]
    for index,source_index in enumerate(selected):
        part=parts[source_index]
        x0,y0,x1,y1=part['box']
        x0=max(0,x0-3);y0=max(0,y0-3);x1=min(image.width,x1+3);y1=min(image.height,y1+3)
        regions[str(index)]=[x0,y0,x1-x0,y1-y0]
        feet.append(SUPPORT.get(path.stem,{}).get(source_index,part['feet']))
        body_heights.append(ruler)
        bottom=part['box'][3]
        ys,xs=np.where((labels==part['label']) & (np.indices(labels.shape)[0]>=bottom-22))
        foot_spans.append(int(xs.max()-xs.min()+1))
    spec={'file':filename,'target':'enemy_clip','faction':'imagawa','kind':role,
          'sheet':clip,'key':f'imagawa:{role}:{clip}','columns':len(selected),'rows':1,
          'source_columns':columns,'source_rows':total//columns,'source_indices':selected,
          'feet_global':True,'feet':feet,'body_height':ruler,'body_heights':body_heights,
          'regions':regions,'component_clip':True,'component_alpha_threshold':0.25,
          'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'source_size':list(image.size),'foot_spans':foot_spans,
          'scale_policy':'fixed anatomical ruler, never current pose bbox height'}
    if path.stem in PROJECTILES:
        spec['hands_global']=True
        spec['hands']={str(i):PROJECTILES[path.stem][source_index] for i,source_index in enumerate(selected)}
    return spec

def subset(spec,clip,indices):
    copy=json.loads(json.dumps(spec))
    copy.update(sheet=clip,key=f'imagawa:{spec["kind"]}:{clip}',columns=len(indices),rows=1)
    for key in ['feet','body_heights','source_indices','foot_spans']: copy[key]=[spec[key][i] for i in indices]
    copy['regions']={str(n):spec['regions'][str(i)] for n,i in enumerate(indices)}
    return copy

def build():
    recipes=source_metadata(); actors={}; missing=[]
    for role in ROLES:
        for clip in ['walk','reactions','death']+ATTACKS[role]:
            spec=register(role,clip,recipes)
            if spec is None:
                missing.append(f'{role}:{clip}');continue
            if clip=='reactions':
                for name,indices in [('hurt',[0,1,2]),('struggle',[3,4,5])]:
                    actors[f'{role}-{name}']=subset(spec,name,indices)
            else:
                actors[f'{role}-{clip}']=spec
                if clip=='walk': actors[f'{role}-idle']=subset(spec,'idle',[0])
    return {'version':'v19','notes':'True hand-redrawn generated sprites; originals retained. Source body rulers exclude weapons. Independent padded runtime textures prevent atlas bleed.','actors':actors,'missing':missing}

def verify(registration):
    assert not registration['missing'],registration['missing']
    for name,spec in registration['actors'].items():
        im=Image.open(ASSETS/spec['file'])
        assert im.mode=='RGBA',name
        a=np.array(im)[:,:,3]
        assert (a==0).mean()>0.35,name
        assert spec['body_height']>=201.5 if spec['kind']=='matsui' else spec['body_height']>=146,name
        assert len(spec['feet'])==spec['columns']*spec['rows'],name
        assert hashlib.sha256((ASSETS/spec['file']).read_bytes()).hexdigest()==spec['sha256'],name
        for rect in spec['regions'].values():
            x,y,w,h=rect
            assert 0<=x<x+w<=im.width and 0<=y<y+h<=im.height,(name,rect)
        if spec['sheet']=='walk':
            assert len(spec['source_indices'])==6,name
            assert max(spec['foot_spans'])>min(spec['foot_spans'])*1.7,(name,spec['foot_spans'])
    return len(registration['actors'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    result=build()
    if args.check:
        saved=read_json(ASSETS/'registration.json')
        assert saved==result,'Registration differs: rerun script'
        print(f'ENEMY_ART_V19_PASS clips={verify(result)}')
    else:
        (ASSETS/'registration.json').write_text(json.dumps(result,indent=2),encoding='utf8')
        print(f'Registered {len(result["actors"])} clips; missing={result["missing"]}')
