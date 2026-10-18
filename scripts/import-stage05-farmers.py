"""Import the approved farmer pack without altering the delivered PNGs or manifest."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'game/assets/stage5-farmers'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    actors = {}
    for folder, role, action in [('sickle','sickle_farmer','s05_sickle_farmer_attack'),('bow','hunting_bow_farmer','s05_hunting_bow_farmer_shot')]:
        source = args.source / folder
        meta = json.loads((source/'manifest.json').read_text('utf8'))
        (DEST/folder/'frames').mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source/'manifest.json',DEST/folder/'manifest.json')
        frames = {}
        for name, row in meta['frames'].items():
            path = source / row['path']; raw = path.read_bytes()
            assert hashlib.sha256(raw).hexdigest()==row['sha256'], path
            shutil.copyfile(path,DEST/folder/row['path'])
            with Image.open(path) as image:
                assert image.mode=='RGBA' and image.size==(1536,1536)
                x0,y0,x1,y1 = image.getbbox(alpha_only=True)
            frames[name] = {'path':f'../stage5-farmers/{folder}/{row["path"]}','anchor':meta['root'],'body_height':810,'canvas':meta['canvas'],'crop':[x0,y0,x1-x0,y1-y0],'duration_ms':1,'root_motion_px':0}
            for key in ['weapon_grip_estimate','weapon_tip_estimate','projectile_spawn_estimate','tip_estimate']:
                if key in row: frames[name][key]=row[key]
        actors[role] = {}
        for clip, spec in meta['clips'].items():
            rows = []
            for name, duration in zip(spec['frames'],spec['durations_ms'],strict=True):
                rows.append(dict(frames[name],duration_ms=duration))
            actors[role][action if clip=='attack' else clip] = {'frames':rows,'duration_ms':sum(spec['durations_ms']),'loop':spec['loop'],'events':spec.get('events',[]),'native_face':1}
        if folder=='bow':
            (DEST/'arrow.json').write_text(json.dumps(frames['arrow'],indent=2)+'\n',encoding='utf8')
    (DEST/'actors.json').write_text(json.dumps(actors,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (DEST/'source.json').write_text(json.dumps({'library_file_id':'libfile_cae067e6fb6c8191af9aa809ff566756','package_sha256':'2b802a7cf79af03f872316c76ece3172937e32681fd75cc54a85f371d73303c9','roles':list(actors),'body_ruler':810,'display_height':146},indent=2)+'\n',encoding='utf8')
    hashes = {p.relative_to(DEST).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(DEST.rglob('*')) if p.is_file() and p.name!='runtime-files.json'}
    (DEST/'runtime-files.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf8')
    print('Imported',len(hashes),'files;',sum(len(v) for v in actors.values()),'clips')


if __name__=='__main__':main()
