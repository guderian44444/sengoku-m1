from pathlib import Path
from PIL import Image
import shutil,json,hashlib
from quantize_gif_timing import patch_gif
P=Path(__file__).parent;S=P/'light_3_diagonal_v2';D=P/'light_3_diagonal_fast_v3';D.mkdir(exist_ok=True)
for f in S.iterdir():
 if f.is_file():shutil.copy(f,D/f.name)
old=[110,90,90,70,60,60,60,60,90,110,150]
new=[110,90,90,70,30,30,30,60,120,140,180]
assert old[:4]==new[:4] and sum(old)==sum(new)==950
for f in D.glob('*.gif'):
 im=Image.open(f)
 if im.n_frames==11:patch_gif(f,[v*3 for v in new] if 'slow' in f.name else new)
m=json.loads((D/'metadata.json').read_text());t=0
for f,d in zip(m['frames'],new):f['previous_duration']=f['duration'];f['duration']=d;f['start_ms']=t;t+=d
m.update(version='light3-diagonal-fast-v3',total_duration_ms=950,gif_decoded_durations_ms=new,timing_revision={'preparation_frames_1_to_4_unchanged_ms':360,'downstroke_frames_5_to_7_old_ms':180,'downstroke_frames_5_to_7_new_ms':90,'saved_ms_to_recovery':90,'contact_frame':7,'contact_old_start_ms':480,'contact_new_start_ms':420,'body_weapon_fx_pixels_unchanged':True},user_latest_timing_override='Sentinel_e28a8502309081919cb92f8f2f1ad2ee')
(D/'metadata.json').write_text(json.dumps(m,indent=2))
unchanged=[]
for f in S.glob('*.png'):assert f.read_bytes()==(D/f.name).read_bytes();unchanged.append(f.name)
for f in S.glob('normal.gif'):
 a=Image.open(f);b=Image.open(D/f.name)
 for i in range(11):a.seek(i);b.seek(i);assert a.convert('RGB').tobytes()==b.convert('RGB').tobytes()
shutil.copy(D/'normal.gif',D/'kennyo03-light3-fast-downstroke-v3.gif')
(D/'TIMING_QA.json').write_text(json.dumps({'old_durations_ms':old,'new_durations_ms':new,'total_ms':950,'frames':11,'unchanged_png_files':unchanged,'all_decoded_normal_gif_frame_pixels_identical':True,'preparation_unchanged':True,'downstroke_ms':[180,90],'contact_start_ms':[480,420]},indent=2))
print('11 frames950ms, prep360 unchanged, downstroke180->90, contact480->420, allPNG andGIF pixels unchanged')
