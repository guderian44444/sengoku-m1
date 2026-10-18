"""Non-destructive source repairs. Keep approved pixels outside explicit repair masks."""
from pathlib import Path
import hashlib
import json
import numpy as np
import cv2
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts/basic36-nobunaga16-git-20261016/deliveries/basic36-nobunaga16-hires-20261016/nobunaga'
OUT = ROOT / 'prototypes/nobunaga-repair-v36'

def read(path):
    return np.array(Image.open(path).convert('RGBA'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    source = SOURCE / 'grab_start/frames-composite/003.png'
    original_hash = digest(source)
    master = read(source)
    donor = read(OUT / 'candidates/face-repair.png')
    # Register the repaired face to intact local features; never warp the source actor.
    x,y,w,h = 670,320,145,150
    reference = cv2.cvtColor(master[y:y+h,x:x+w,:3],cv2.COLOR_RGB2GRAY)
    candidate = cv2.cvtColor(donor[y:y+h,x:x+w,:3],cv2.COLOR_RGB2GRAY)
    valid = (master[y:y+h,x:x+w,3]>=250).astype('uint8')*255
    matrix = np.eye(2,3,dtype=np.float32)
    score,matrix = cv2.findTransformECC(reference,candidate,matrix,cv2.MOTION_EUCLIDEAN,
        (cv2.TERM_CRITERIA_COUNT|cv2.TERM_CRITERIA_EPS,100,1e-6),valid,3)
    assert score>.85, 'Face registration unreliable'
    global_matrix = matrix.copy()
    global_matrix[:,2] += np.array([x,y])-matrix[:,:2]@np.array([x,y])
    donor = cv2.warpAffine(donor,global_matrix,(master.shape[1],master.shape[0]),
        flags=cv2.INTER_LINEAR|cv2.WARP_INVERSE_MAP,borderMode=cv2.BORDER_CONSTANT)
    yy, xx = np.indices(master.shape[:2])
    face = (xx>=700)&(xx<800)&(yy>=330)&(yy<455)
    weapon_array = read(SOURCE / 'grab_start/layers-visible/weapon/003.png')
    hand_array = read(SOURCE / 'grab_start/layers-visible/hand_occlusion/003.png')
    mask = face & (donor[:,:,3]>master[:,:,3]) & (donor[:,:,3]>=240) & (weapon_array[:,:,3]==0) & (hand_array[:,:,3]==0)
    assert mask.any(), 'No face repair pixels'
    patch = np.zeros_like(master)
    patch[mask] = donor[mask]
    repaired = master.copy()
    repaired[mask] = donor[mask]
    body = read(SOURCE / 'grab_start/layers-visible/body/003.png')
    body[mask] = donor[mask]
    folder = OUT / 'repairs/shared-grab003-throw015'
    folder.mkdir(parents=True, exist_ok=True)
    for name, value in [('face-fill',patch),('master',repaired),('body',body)]:
        Image.fromarray(value).save(folder / (name+'.png'))
    assert np.array_equal(master[~mask],repaired[~mask])
    # The two animation frames use precisely the same source, not merely similar poses.
    assert digest(SOURCE / 'throw_forward/frames-composite/015.png') == original_hash
    assert np.array_equal(read(SOURCE / 'throw_forward/layers-visible/body/015.png')[~mask],body[~mask])
    weapon = Image.open(SOURCE / 'grab_start/layers-visible/weapon/003.png').convert('RGBA')
    hands = Image.open(SOURCE / 'grab_start/layers-visible/hand_occlusion/003.png').convert('RGBA')
    result = Image.fromarray(body)
    result.alpha_composite(weapon)
    result.alpha_composite(hands)
    result_array = np.array(result)
    assert np.array_equal(result_array[:,:,3],repaired[:,:,3])
    assert np.array_equal(result_array[repaired[:,:,3]>0],repaired[repaired[:,:,3]>0])
    assert digest(source)==original_hash
    report = {
        'source_sha256':original_hash, 'shared_frames':['grab_start/003','throw_forward/015'],
        'method':'Locally register generated face donor; fill only source transparency inside explicit face region',
        'registration_correlation':float(score),'donor_inverse_affine':global_matrix.tolist(),
        'changed_pixels':int(mask.sum()), 'outside_mask_pixel_exact':True,
        'layer_recomposition_visible_exact':True, 'source_unchanged':True,
        'weapon_swap_ready':False,
        'outputs':{p.name:digest(p) for p in sorted(folder.glob('*.png'))},
    }
    (folder/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    sheet=Image.new('RGB',(720,390),'#333333')
    draw=ImageDraw.Draw(sheet)
    for index,(label,array) in enumerate([('SOURCE',master),('REPAIRED',repaired),('ONLY FILLED PIXELS',patch)]):
        crop=Image.fromarray(array).crop((690,350,810,530)).resize((240,360),Image.Resampling.NEAREST)
        sheet.paste(crop,(index*240,25),crop)
        draw.text((index*240+8,6),label,fill='white')
    sheet.save(folder/'comparison.png')
    print(json.dumps(report))

if __name__ == '__main__':
    main()
