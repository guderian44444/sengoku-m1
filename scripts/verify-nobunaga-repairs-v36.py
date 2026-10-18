from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'artifacts/basic36-nobunaga16-git-20261016/deliveries/basic36-nobunaga16-hires-20261016/nobunaga'
OUT=ROOT/'prototypes/nobunaga-repair-v36'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    manifest=json.loads((OUT/'aligned-patches/manifest.json').read_text())
    bindings=json.loads((OUT/'source-overrides.json').read_text())
    known_feet=0
    missing_feet=0
    for record in manifest['frames']:
        clip,i=record['clip'],record['frame']
        frame=json.loads((SOURCE/clip/'delivery-frames.json').read_text())[i]
        original=Image.open(SOURCE/frame['layers']['body']['path']).convert('RGBA')
        original.alpha_composite(Image.open(SOURCE/frame['layers'].get('hand_occlusion',frame['layers'].get('hand-foreground'))['path']).convert('RGBA'))
        original=np.array(original);repaired=np.array(Image.open(OUT/record['body']).convert('RGBA'))
        assert original.shape==repaired.shape
        assert sha(OUT/record['body'])==record['sha256']
        assert sha(OUT/record['hands'])==record['hands_sha256']
        x,y,x2,y2=record['native_box']
        local_mask=np.array(Image.open(OUT/'aligned-patches'/clip/f'{i:03}-mask.png'))>0
        mask=np.zeros(original.shape[:2],dtype=bool);mask[y:y2,x:x2]=local_mask
        assert np.array_equal(original[~mask],repaired[~mask]),(clip,i,'outside mask')
        for foot in frame.get('foot_art_native_px',[]):
            if foot is None:
                missing_feet+=1
                continue
            fx,fy=map(round,foot)
            if 0<=fy<mask.shape[0] and 0<=fx<mask.shape[1]:
                assert not mask[fy,fx],(clip,i,'foot changed')
                known_feet+=1
    assert len(bindings['frame_bindings'])==42
    for binding in bindings['frame_bindings']:
        frame=json.loads((SOURCE/binding['clip']/'delivery-frames.json').read_text())[binding['frame']]
        for key in ['duration_ms','root_art_native_px','grip_art_native_px','weapon_axis']:assert binding[key]==frame[key]
        assert sha(SOURCE/frame['master']['path'])==binding['source_master_sha256']
        assert sha(OUT/binding['body'])==binding['body_sha256']
    report={'result':'PASS','unique_patches':len(manifest['frames']),'bound_frames':42,
        'outside_repair_masks_pixel_exact':True,'source_canvas_sizes_unchanged':True,'foot_samples_untouched':True,
        'verified_foot_samples':known_feet,'unavailable_source_foot_samples':missing_feet,
        'source_roots_grips_timings_preserved':True,'source_master_hashes_intact':True,
        'complete_sword_textures':len(bindings['complete_weapons']),'runtime_active':False,
        'runtime_visual_and_controller_acceptance':'not performed for these new source patches'}
    (OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))

if __name__=='__main__':main()
