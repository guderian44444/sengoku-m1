"""Save measured atlas metadata, without modifying any raster image."""
import hashlib, json, shutil
from pathlib import Path
from PIL import Image

root = Path(__file__).parent
runtime = root.parents[1] / 'game/assets/v07'
measurements = json.loads((root/'alpha-foot-measurements.json').read_text(encoding='utf-8'))
for hero in ('nobunaga','oichi'):
    registration = {'version':'0.7','character':hero,'source_dimensions':[1536,1024],'default_facing':'right','sheets':{}}
    for path in sorted((root/hero).glob('*.png')):
        sheet = path.stem
        measured = measurements[str(path.relative_to(root))]
        height = {'motion':300,'combo':210,'attacks':230,'special':235,'physical':225}[sheet]
        if hero == 'oichi': height = 300
        spec = {'body_height':height,'row_starts':[0,341,682],'sha256':measured['sha256'],'feet':[],'left_support':[],'right_support':[]}
        for frame in measured['frames']:
            left,right = frame['sole_gold']
            spec['left_support'].append(left or [192,frame['bbox'][3]])
            spec['right_support'].append(right or [192,frame['bbox'][3]])
            spec['feet'].append(left or [192,frame['bbox'][3]])
        if sheet == 'motion':
            spec['ranges'] = {'idle':[0,3],'walk':[4,7],'hurt':[8,10],'down':[11,11]}
            spec['unplanted'] = [4,5,6,7,11]
            if hero == 'nobunaga':
                spec['feet'][:4] = [[81.5,329],[72.7,327.9],[70,326.9],[67.5,325.2]]
                spec['idle_body_alignment'] = [[0,0],[-8.8,-1.1],[-11.5,-2.1],[-14,-3.8]]
                spec['feet'][4:8] = [[204,329],[204,331],[205,327],[204,332]]
                spec['feet'][11] = [194,275]
                spec['regions'] = {'0':[0,0,395,341],'1':[395,0,373,341],'8':[0,682,404,342],'9':[404,682,364,342],'10':[768,682,370,342],'11':[1138,682,398,342]}
            else:
                spec['feet'][:4] = [[141,335]]*4
                spec['idle_body_alignment'] = [[0,0]]*4
                spec['feet'][4:8] = [[226,335],[226,343],[227,335],[226,343]]
                spec['feet'][11] = [194,286]
                spec['regions'] = {str(i):[(i%4)*384,341 if i<8 else 689,384,348 if i<8 else 335] for i in range(4,12)}
            spec['anchor_note'] = 'Idle uses first shoe layer and virtual support aligned to the face. Walking virtual floor follows pelvis; contact/passing/opposite contact/opposite passing are separate source drawings. Down uses virtual ground center and standing scale.'
        elif sheet == 'combo':
            spec['ranges'] = {'downcut':[0,3],'rising':[4,7],'sweep':[8,11]}
        elif sheet == 'attacks':
            spec['ranges'] = {'heavy':[0,7],'thrust':[8,11]}
            spec['regions'] = {'9':[384,682,408,342],'10':[792,682,360,342]}
        elif sheet == 'special':
            spec['ranges'] = {'special':[0,7],'charge':[8,11]}
            spec['regions'] = {'5':[384,341,414,341],'6':[798,341,354,341]}
            spec['blades'] = {'8':[[179,99],[323,100]],'9':[[190,94],[343,101]],'10':[[183,97],[334,101]],'11':[[180,91],[340,96]]}
        else:
            spec['ranges'] = {'jump':[0,3],'throw':[4,7],'victory':[8,11]}
            spec['unplanted'] = [0,1,2,3]
            spec['feet'][:4] = [[193,298],[199,298],[204,298],[210,298]]
            spec['hands'] = {'4':[300,149],'5':[322,131],'6':[318,127]}
        registration['sheets'][sheet] = spec
    (root/hero/'registration.json').write_text(json.dumps(registration,indent=2,ensure_ascii=False),encoding='utf-8')
    target = runtime/hero
    target.mkdir(parents=True,exist_ok=True)
    for path in (root/hero).glob('*.png'): shutil.copy2(path,target/path.name)
    shutil.copy2(root/hero/'registration.json',target/'registration.json')
    manifest = {'version':'0.7','character':hero,'generator':'built-in Imagegen edit','prompts':'../prompts.txt','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/hero).glob('*.png')},'verification':'Alpha zero/background and measured source cells; runtime visual QA handled by renderer test.'}
    (root/hero/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    shutil.copy2(root/hero/'manifest.json',target/'manifest.json')
    print(hero,list(registration['sheets']))
