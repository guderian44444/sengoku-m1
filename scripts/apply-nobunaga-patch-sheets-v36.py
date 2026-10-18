"""Align generated local fills to original motion frames, keeping unrelated pixels exact."""
from pathlib import Path
import json, hashlib
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'artifacts/basic36-nobunaga16-git-20261016/deliveries/basic36-nobunaga16-hires-20261016/nobunaga'
OUT=ROOT/'prototypes/nobunaga-repair-v36'

def read(p):return np.array(Image.open(p).convert('RGBA'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def patch(clip,row,donor):
    i=row['frame'];frames=json.loads((SOURCE/clip/'delivery-frames.json').read_text());spec=frames[i]
    layers=spec['layers'];body=Image.open(SOURCE/layers['body']['path']).convert('RGBA')
    hand=Image.open(SOURCE/layers.get('hand_occlusion',layers.get('hand-foreground'))['path']).convert('RGBA');body.alpha_composite(hand)
    base=np.array(body);original=base.copy();box=row['native_box'];x,y,x2,y2=box
    master=Image.open(SOURCE/row['source']).convert('RGBA').crop(box)
    reference=Image.new('RGBA',(400,400),(86,86,86,255));reference.alpha_composite(master)
    reference=np.array(reference)
    weapon=Image.open(SOURCE/layers.get('weapon',layers.get('weapon-visible'))['path']).convert('RGBA').crop(box)
    weapon=np.array(weapon)[:,:,3]>0
    original_crop=base[y:y2,x:x2]
    assert original_crop.shape[:2]==(400,400)
    valid=((original_crop[:,:,3]>240)&~cv2.dilate(weapon.astype('uint8'),np.ones((7,7),np.uint8)).astype(bool)).astype('uint8')*255
    # Exclude the fused handle/guard when matching intact armor and skin around it.
    valid[130:280,110:300]=0
    matrix=np.eye(2,3,dtype=np.float32)
    score,matrix=cv2.findTransformECC(cv2.cvtColor(reference[:,:,:3],cv2.COLOR_RGB2GRAY),
        cv2.cvtColor(donor,cv2.COLOR_RGB2GRAY),matrix,cv2.MOTION_EUCLIDEAN,
        (cv2.TERM_CRITERIA_COUNT|cv2.TERM_CRITERIA_EPS,150,1e-6),valid,5)
    assert score>.75,(clip,i,score)
    donor=cv2.warpAffine(donor,matrix,(400,400),flags=cv2.INTER_LINEAR|cv2.WARP_INVERSE_MAP,borderValue=(86,86,86))
    rgb=donor.astype(float)
    gray=rgb.mean(2).astype('float32');mean=cv2.blur(gray,(5,5));variation=np.maximum(0,cv2.blur(gray*gray,(5,5))-mean*mean)**.5
    foreground=((rgb.max(2)-rgb.min(2)>12)|(gray<48)|(gray>125)|(variation>2.5)).astype('uint8')*255
    contours,_=cv2.findContours(foreground,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    alpha=np.zeros((400,400),dtype='uint8');cv2.drawContours(alpha,contours,-1,255,cv2.FILLED)
    alpha=cv2.morphologyEx(alpha,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    yy,xx=np.indices((400,400))
    removal=(((xx-200)/180)**2+((yy-200)/115)**2<1)|weapon
    alpha[~removal]=np.maximum(alpha[~removal],original_crop[:,:,3][~removal])
    # Only the sword corridor and nearby inherited erasures may change.
    mask=cv2.dilate(weapon.astype('uint8'),cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(25,25)))>0
    mask[25:375,25:375]=True
    missing=(original_crop[:,:,3]==0)&(alpha>0)
    near=cv2.dilate((original_crop[:,:,3]>0).astype('uint8'),np.ones((41,41),np.uint8))>0
    mask|=missing&near
    old_hand=np.array(hand)[y:y2,x:x2]
    weight=np.minimum(1,cv2.distanceTransform(mask.astype('uint8'),cv2.DIST_L2,3)/12)
    weight[mask&(original_crop[:,:,3]==0)]=1
    a0=original_crop[:,:,3].astype(float)/255;a1=alpha.astype(float)/255
    a=a0*(1-weight)+a1*weight
    colors=(original_crop[:,:,:3]*a0[:,:,None]*(1-weight[:,:,None])+donor*a1[:,:,None]*weight[:,:,None])/np.maximum(a[:,:,None],1e-9)
    patched=original_crop.copy();patched[:,:,:3][mask]=np.clip(np.round(colors[mask]),0,255).astype('uint8');patched[:,:,3][mask]=np.round(a[mask]*255).astype('uint8')
    base[y:y2,x:x2]=patched
    outside=np.ones(base.shape[:2],dtype=bool);outside[y:y2,x:x2]=~mask
    assert np.array_equal(base[outside],original[outside])
    h=patched[:,:,:3].astype(float)
    hand_area=cv2.dilate((old_hand[:,:,3]>0).astype('uint8'),np.ones((25,25),np.uint8))>0
    skin=(h[:,:,0]>85)&(h[:,:,0]>h[:,:,1]*1.08)&(h[:,:,1]>h[:,:,2]*1.05)&(h[:,:,2]>h[:,:,1]*.42)&hand_area
    skin=cv2.dilate(skin.astype('uint8'),np.ones((3,3),np.uint8))>0
    final_hand=np.array(hand);final_hand[y:y2,x:x2]=0;final_hand[y:y2,x:x2][skin]=patched[skin]
    folder=OUT/'aligned-patches'/clip;folder.mkdir(parents=True,exist_ok=True)
    p=folder/f'{i:03}-body.png';Image.fromarray(base).save(p)
    hp=folder/f'{i:03}-hands.png';Image.fromarray(final_hand).save(hp)
    Image.fromarray((mask*255).astype('uint8')).save(folder/f'{i:03}-mask.png')
    record={'clip':clip,'frame':i,'body':str(p.relative_to(OUT)),'hands':str(hp.relative_to(OUT)),
        'sha256':sha(p),'hands_sha256':sha(hp),'source_master_sha256':spec['master']['sha256'],
        'native_box':box,'outside_mask_exact':True,'alignment_score':float(score),'alignment':matrix.tolist(),
        'status':'requires_visual_review'}
    preview=Image.fromarray(patched);canvas=Image.new('RGB',(400,400),'#565656');canvas.paste(preview,(0,0),preview)
    return record,canvas

def main():
    records=[]
    for clip in ['grab_start','charge_release','throw_reverse']:
        rows=json.loads((OUT/'patch-sheets'/f'{clip}-map.json').read_text())
        reference=Image.open(OUT/'patch-sheets'/f'{clip}-reference.png')
        generated=Image.open(OUT/'patch-sheets'/f'{clip}-repaired.png').convert('RGB').resize(reference.size,Image.Resampling.LANCZOS)
        review=Image.new('RGB',reference.size,'#565656');draw=ImageDraw.Draw(review)
        for row in rows:
            donor=np.array(generated.crop(row['canvas_box']))
            record,tile=patch(clip,row,donor);records.append(record)
            box=row['canvas_box'];review.paste(tile,(box[0],box[1]));draw.text((box[0]+8,box[3]+10),f'{clip} {row["frame"]:03} aligned',fill='white')
        review.save(OUT/'patch-sheets'/f'{clip}-aligned-review.png')
    (OUT/'aligned-patches/manifest.json').write_text(json.dumps({'runtime_active':False,'frames':records},indent=2)+'\n')
    def identity(frame):
        layers=frame['layers']
        return layers['body']['sha256'],layers.get('hand_occlusion',layers.get('hand-foreground'))['sha256']
    by_identity={}
    for record in records:
        frame=json.loads((SOURCE/record['clip']/'delivery-frames.json').read_text())[record['frame']]
        by_identity[identity(frame)]=record
    bindings=[]
    charge_frames=json.loads((SOURCE/'charge_release/delivery-frames.json').read_text())
    full_blade=max(float(np.linalg.norm(np.array(f['weapon_axis']['visible_tip'])-np.array(f['weapon_axis']['base']))) for f in charge_frames)
    for clip,indices in [('grab_start',range(8)),('charge_release',range(24)),('throw_forward',range(11,19)),('throw_reverse',[5,15])]:
        for i,frame in enumerate(json.loads((SOURCE/clip/'delivery-frames.json').read_text())):
            if i not in indices:continue
            record=by_identity[identity(frame)]
            assert sha(OUT/record['body'])==record['sha256']
            assert sha(OUT/record['hands'])==record['hands_sha256']
            bindings.append({'clip':clip,'frame':i,'body':record['body'],'hands':record['hands'],
                'body_sha256':record['sha256'],'hands_sha256':record['hands_sha256'],
                'duration_ms':frame['duration_ms'],'root_art_native_px':frame['root_art_native_px'],
                'grip_art_native_px':frame['grip_art_native_px'],'weapon_axis':frame['weapon_axis'],
                'weapon_behind_body':frame.get('weapon_depth') is True or (clip=='throw_reverse' and i==5),
                'weapon_longitudinal_scale':float(np.linalg.norm(np.array(frame['weapon_axis']['visible_tip'])-np.array(frame['weapon_axis']['base'])))/full_blade if clip=='charge_release' else 1.0,
                'source_master_sha256':frame['master']['sha256']})
    assert len(bindings)==42
    weapons=json.loads((ROOT/'game/assets/v22/weapons/registration.json').read_text())['items']
    complete_weapons={key:value for key,value in weapons.items() if key.startswith('sword_')}
    for weapon in complete_weapons.values():assert sha(ROOT/'game/assets/v22/weapons'/weapon['file'])==weapon['sha256']
    result={'source_commit':'5d7f308c456653e2ef190c6c0fd68d82264b9f53','runtime_active':False,
        'unique_repairs':len(records),'frame_bindings':bindings,'weapon_source':'game/assets/v22/weapons/',
        'complete_weapons':complete_weapons,'weapon_rendering':'Independent equipment texture; retain full image, do not crop to original actor canvas',
        'standing_native_ruler':914,'timing_policy':'Preserve gameplay input buffers and cancellation windows; art timings do not delay the next action',
        'limitations':['Source patches only; new runtime sockets and mirrored animation playback require integration validation',
            'Experimental swap-review batch is not an accepted repair source; use only the files explicitly bound here']}
    (OUT/'source-overrides.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'Aligned {len(records)} unique local patches')

if __name__=='__main__':main()
