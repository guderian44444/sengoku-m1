"""Calibrate candidate metadata only; retain raw PNGs and the approved-scale candidate."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont

def calibrate(base):
    base=Path(base)
    def write(name,data):(base/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    rows=json.loads((base/'alignment/all-actions.json').read_text('utf-8'))['rows']
    reference=next(r for r in rows if r['key']=='combat-v33/light_1/00')
    x,y,w,h=reference['source_rect_xywh']
    old=Image.open(base/'baseline'/reference['source_path']).convert('RGBA').crop((x,y,x+w,y+h))
    def sole_spans(im,root_y):
        alpha=np.array(im)[:,:,3];y=int(root_y)
        columns=np.any(alpha[max(0,y-8):min(alpha.shape[0],y+9)]>=128,axis=0)
        spans=[];start=None
        for i,v in enumerate(list(columns)+[False]):
            if v and start is None:start=i
            if not v and start is not None:
                if i-start>=6:spans.append([start,i-1,(start+i-1)/2])
                start=None
        return spans
    landmarks=[]
    for i,roi in [(0,[80,20,240,120]),(7,[100,155,300,270])]:
        row=next(r for r in rows if r['key']==f'approved-B/light_3/{i:02d}')
        im=Image.open(base/row['source_path']).convert('RGBA');alpha=np.array(im)[:,:,3]
        x0,y0,x1,y1=roi;yy,_=np.where(alpha[y0:y1,x0:x1]>=128);top=int(yy.min()+y0)
        landmarks.append({'pose':i,'head_roi_xyxy':roi,'alpha_threshold':128,'head_top_px':top,
             'source_hair_to_sole_height_px':row['visible_bbox_px'][3]-top,
             'estimated_head_landmark_uncertainty_source_px':3})
    ref_height=reference['visible_size_world'][1]
    ruler=sum(l['source_hair_to_sole_height_px'] for l in landmarks)/2*148/ref_height
    ref_bottom=reference['visible_bbox_relative_to_ground_world'][3]
    old_sole=sole_spans(old,reference['anchor_in_crop_px'][1])[-1]
    ref_ahead=(reference['anchor_in_crop_px'][0]-old_sole[2])*reference['scale_to_world']
    approved=base/'ready-assets/light_3.approved-scale.json'
    if not approved.exists():approved.write_bytes((base/'ready-assets/light_3.candidate.json').read_bytes())
    candidate=json.loads(approved.read_text('utf-8'))
    candidate['status']='asset-only candidate; standing size and planted-foot anchors calibrated; not integrated or game-tested'
    result=[]
    for i in range(8):
        row=next(r for r in rows if r['key']==f'approved-B/light_3/{i:02d}')
        im=Image.open(base/row['source_path']).convert('RGBA');spans=sole_spans(im,row['anchor_in_crop_px'][1]);sole=spans[-1]
        scale=148/ruler;anchor=[sole[2]+ref_ahead/scale,row['visible_bbox_px'][3]-ref_bottom/scale]
        delta=[anchor[j]-row['anchor_in_crop_px'][j] for j in [0,1]]
        result.append({'pose':i,'approved_anchor_px':row['anchor_in_crop_px'],'calibrated_anchor_px':anchor,
            'approved_ruler_px':380,'calibrated_ruler_px':ruler,'anchor_delta_px':delta,
            'sole_x_spans_px':spans,'sole_alpha_threshold':128,'sole_band_y_px':[int(row['anchor_in_crop_px'][1])-8,int(row['anchor_in_crop_px'][1])+9],
            'selected_sole':sole,'sole_bottom_world':ref_bottom,'canvas_size_px':list(im.size),
            'canvas_top_left_world_right':[-anchor[0]*scale,-anchor[1]*scale],
            'canvas_top_left_world_left':[(anchor[0]-im.width)*scale,-anchor[1]*scale]})
        for f in candidate['frames']:
            if f['approved_pose']!=i:continue
            f['layers']['body']['anchor']=anchor;f['layers']['body']['body_height']=ruler
            if 'fx_back' in f['layers']:
                fx=f['layers']['fx_back'];fx['anchor']=[fx['anchor'][j]+delta[j]*296/380 for j in [0,1]]
                fx['body_height']=296*ruler/380
    write('ready-assets/light_3.candidate.json',candidate)
    write('alignment/calibrated-anchors.json',result)
    heights=[l['source_hair_to_sole_height_px']*148/ruler for l in landmarks]
    calibration={'status':'applied to candidate metadata only; original pixels and approved 380-ruler candidate retained',
      'reference':reference['key'],'reference_hair_to_sole_world':ref_height,'B_head_landmarks':landmarks,
      'calibrated_common_ruler':ruler,'uniform_scale_relative_to_approved':380/ruler,'paired_fx_ruler':296*ruler/380,
      'calibrated_standing_heights_world':heights,'max_standing_height_relative_error':max(abs(h/ref_height-1) for h in heights),
      'reference_sole_bottom_world':ref_bottom,'reference_anchor_ahead_of_sole_center_world':ref_ahead,
      'origin_method':'frontmost support-sole center in the root-height band, plus existing light1 anchor offset; sole bottom offset also matches current light1',
      'pixel_changes':False,'runtime_transitions_tested':False,
      'uncertainty':'Head ROI selection +/-3 source px; source-resolution sole measurement +/-1 px. Bodies retain pose variation; size match uses one common scale, never per-frame alpha bbox normalization.'}
    write('alignment/standing-calibration.json',calibration)
    try:font=ImageFont.truetype('C:/Windows/Fonts/msjh.ttc',18)
    except OSError:font=ImageFont.load_default(size=18)
    panel=Image.new('RGBA',(2160,530),(20,29,37,255));draw=ImageDraw.Draw(panel)
    items=[('Current light1 / 0',old,reference['anchor_in_crop_px'],315)]
    for i in [0,4,7]:items.append((f'B calibrated / {i}',Image.open(base/f'original-approved-B/poses/{i:02d}.png').convert('RGBA'),result[i]['calibrated_anchor_px'],ruler))
    for n,(label,im,anchor,r) in enumerate(items):
        factor=296/r;origin=[n*540+315,430]
        scaled=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.LANCZOS)
        panel.alpha_composite(scaled,(round(origin[0]-anchor[0]*factor),round(origin[1]-anchor[1]*factor)))
        draw.text((n*540+12,12),label,font=font,fill='white')
        draw.text((n*540+12,40),f'148 world / ruler {r:.4f}, zoom 2x',font=font,fill=(180,207,217))
        draw.line((n*540+10,430,(n+1)*540-10,430),fill=(110,160,170))
        draw.line((origin[0]-6,430,origin[0]+6,430),fill=(255,209,70),width=2)
        draw.line((origin[0],424,origin[0],436),fill=(255,209,70),width=2)
        draw.text((n*540+12,478),f'root {anchor[0]:.2f}, {anchor[1]:.2f}',font=font,fill=(255,209,70))
    panel.convert('RGB').save(base/'alignment/calibrated-standing-comparison.jpg',quality=94)
    manifest=json.loads((base/'handoff-manifest.json').read_text('utf-8'))
    manifest.update({'B_calibrated_ruler':ruler,'B_world_scale':148/ruler,'size_and_anchor_calibration':'candidate metadata only; source pixels unchanged',
                     'publication_authorized':'user approved original repository, separate material branch; no runtime integration or merge'})
    write('handoff-manifest.json',manifest)
    return calibration

if __name__=='__main__':
    import sys
    print(json.dumps(calibrate(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]),indent=2))
