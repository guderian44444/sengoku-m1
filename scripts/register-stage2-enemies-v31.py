"""Register new source PNGs using the existing alpha component reader; source pixels stay intact."""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'game/assets/v31/enemies'
spec = importlib.util.spec_from_file_location('enemy_registration', ROOT / 'scripts/register-enemies-v19.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
RULERS = {'cross_spear': (545, 758), 'short_yari': (505, 719), 'long_yari': (515, 687)}
REACTION_RULERS = {'cross_spear':500,'short_yari':490,'long_yari':490}
# Body contacts exclude spear tips below the shoe/elbow line.
REACTION_SUPPORT = {
    'cross_spear':[[293,565],[739,561],[1227,560],[227,949],[754,949],[1293,977]],
    'short_yari':[[280,593],[780,587],[1230,594],[241,941],[795,930],[1290,968]],
    'long_yari':[[260,592],[772,587],[1227,590],[248,967],[800,959],[1270,976]],
}

def frame(part, labels, image, ruler):
    x0,y0,x1,y1 = part['box']
    ys,xs = np.where((labels == part['label']) & (np.indices(labels.shape)[0] >= y1-40))
    foot = [float((xs.min()+xs.max())/2), y1-1]
    return [max(0,x0-2),max(0,y0-2),min(image.width,x1+2)-max(0,x0-2),min(image.height,y1+2)-max(0,y0-2)], foot, ruler

def main():
    actors = {}
    reaches = {}
    for variant,(standing_ruler,attack_ruler) in RULERS.items():
        filename = variant+'.png'
        image,_,labels,parts = reader.components(ASSETS/filename,3,6)
        upright = [frame(p,labels,image,standing_ruler) for p in parts[:3]]
        attack_file = variant+'-attacks.png'
        attack_image,_,attack_labels,attacks = reader.components(ASSETS/attack_file,2,2)
        hits = [frame(p,attack_labels,attack_image,attack_ruler) for p in attacks]
        reaction_file = variant+'-reactions.png'
        reaction_image,_,reaction_labels,reactions = reader.components(ASSETS/reaction_file,3,6)
        pain = [frame(p,reaction_labels,reaction_image,REACTION_RULERS[variant]) for p in reactions]
        pain = [(p[0],support,p[2]) for p,support in zip(pain,REACTION_SUPPORT[variant])]
        # The original short-shaft attack/death candidates remain source evidence only.
        frames = upright+hits+[pain[4]]
        files = [filename]*3+[attack_file]*2+[reaction_file]
        actors[variant] = {'file':filename,'target':'enemy_clip','kind':'boss','key':'oda:'+variant+':poses',
            'columns':6,'rows':1,'feet_global':True,'feet':[f[1] for f in frames],
            'body_height':standing_ruler,'body_heights':[f[2] for f in frames],
            'regions':{str(i):f[0] for i,f in enumerate(frames)},'frame_files':{str(i):p for i,p in enumerate(files)},
            'component_clip':True,'component_alpha_threshold':.25,'sha256':{f:hashlib.sha256((ASSETS/f).read_bytes()).hexdigest() for f in set(files)},
            'scale_policy':'standing anatomical height; attack ruler follows measured face-height ratio, not crouched bounding box'}
        actors[variant+'-reactions'] = {'file':reaction_file,'target':'enemy_clip','kind':'boss',
            'key':'oda:'+variant+':reactions','columns':6,'rows':1,'feet_global':True,
            'feet':[p[1] for p in pain],'body_height':REACTION_RULERS[variant],
            'regions':{str(i):p[0] for i,p in enumerate(pain)},
            'component_clip':True,'component_alpha_threshold':.25,
            'sha256':{reaction_file:hashlib.sha256((ASSETS/reaction_file).read_bytes()).hexdigest()},
            'poses':['hurt_recoil','hurt_fold','kneeling','falling','prone','rising'],
            'scale_policy':'fixed anatomical ruler through hurt, fall, prone and rising; never normalize crouch bounds'}
        reaches[variant] = {'reach_thrust':round((attacks[0]['box'][2]-hits[0][1][0])*155/attack_ruler,2),
                            'reach_sweep':round((attacks[1]['box'][2]-hits[1][1][0])*155/attack_ruler,2)}
        assert standing_ruler >= 500 and attack_ruler >= 600
        assert all(90 < r < 300 for r in reaches[variant].values()), reaches[variant]
        assert len(reactions) == 6 and reactions[4]['box'][3]-reactions[4]['box'][1] < REACTION_RULERS[variant]*.36
        assert all(p['pixels'] > 40000 for p in reactions), 'Missing or joined reaction figure'
    (ASSETS/'registration.json').write_text(json.dumps({'version':'v31','actors':actors},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    stage_path = ROOT/'game/data/stage-02.json'
    stage = json.loads(stage_path.read_text(encoding='utf-8'))
    for scene in stage['segments']:
        for encounter in scene['encounters']:
            if 'boss' in encounter: encounter['boss'].update(reaches[encounter['boss']['variant']])
    stage_path.write_text(json.dumps(stage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('V31 ENEMY REGISTRATION PASS', reaches)

if __name__ == '__main__': main()
