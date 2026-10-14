from PIL import Image,ImageDraw
from pathlib import Path
import hashlib,json
P=Path(__file__).parent
# Source pixels retained. Only rectangular crop, uniform scale and layer composition.
seq=[('original_four.png',(0,0,768,512),(685,130),490,60,'hold'),('inbetweens_v2.png',(0,0,1086,724),(975,173),710,50,'early_lift_new'),('original_four.png',(768,0,1536,512),(462,130),490,80,'high_knee'),('original_four.png',(0,512,768,1024),(720,88),490,70,'knee_contact_1'),('inbetweens.png',(1086,0,2172,724),(730,173),710,60,'lower_knee_new'),('original_four.png',(768,512,1536,1024),(512,118),490,100,'return_hold')]
frames=[];records=[];contact=(218,88);elapsed=0
bow=Image.open(P/'bow_azusa.png').convert('RGBA');bow.thumbnail((44,133));bow=bow.rotate(18,expand=True,resample=Image.Resampling.BICUBIC)
for i,(file,rect,hand,ruler,ms,phase) in enumerate(seq):
 source=Image.open(P/file).convert('RGBA');body=source.crop(rect);body.save(P/f'body_{i:02}.png');s=148/ruler;small=body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS);off=(round(contact[0]-hand[0]*s),round(contact[1]-hand[1]*s));canvas=Image.new('RGBA',(400,240),'#313845')
 victim=Image.new('RGBA',canvas.size);d=ImageDraw.Draw(victim);hip=(227,145);abdomen=(227,119)
 if i==3:abdomen=(197,118);hip=(222,145)
 d.ellipse((225,59,242,77),fill='#8293a6');d.line([contact,abdomen,hip],fill='#8293a6',width=17);d.line([(220,92),(235,118)],fill='#a6b5c6',width=8);d.line([hip,(212,199)],fill='#8293a6',width=10);d.line([hip,(245,199)],fill='#8293a6',width=10);victim.save(P/f'victim_{i:02}.png')
 weapon=Image.new('RGBA',canvas.size);weapon.alpha_composite(bow,(145,65));weapon.save(P/f'weapon_{i:02}.png');canvas.alpha_composite(victim);canvas.alpha_composite(weapon);canvas.alpha_composite(small,off);d=ImageDraw.Draw(canvas);d.text((10,8),'grab_hit_1 | 6 keyframes | 148px | 420ms',fill='white');d.text((10,220),'Prototype / separate neutral preview victim',fill='#bdc8d8');frames.append(canvas.convert('RGB'))
 records.append(dict(frame=i,source=file,source_rect=list(rect),source_sha256=hashlib.sha256((P/file).read_bytes()).hexdigest(),body_crop_sha256=hashlib.sha256((P/f'body_{i:02}.png').read_bytes()).hexdigest(),body_height=ruler,grab_contact_cell=list(hand),grab_contact_preview=list(contact),preview_offset=list(off),scale=s,duration_ms=ms,start_ms=elapsed,phase=phase,events=['knee_contact_1'] if i==3 else ['return_hold'] if i==5 else [],weapon_behind=True,weapon_stowed=True,second_hand=None));elapsed+=ms
frames[0].save(P/'grab_hit_1_six_148px.gif',save_all=True,append_images=frames[1:],duration=[x[4] for x in seq],loop=0,disposal=2)
meta=dict(clip='grab_hit_1',revision='six_keyframes',prototype=True,runtime_modified=False,frame_count=6,total_ms=elapsed,contact_ms=190,contact_preserved_from_original_ms=190,new_frames=[1,4],original_frames_preserved=[0,2,3,5],layer_order=['neutral_victim','stowed_bow','body'],grip_note='Bow stowed behind, no string draw.',frames=records)
(P/'metadata.json').write_text(json.dumps(meta,indent=2))
qa={'gif_frames':Image.open(P/'grab_hit_1_six_148px.gif').n_frames,'unique_body_hashes':len(set(x['body_crop_sha256'] for x in records)),'fixed_grab_contact':len(set(tuple(x['grab_contact_preview']) for x in records))==1,'duration_ms':elapsed,'contact_ms':190,'native_alpha_zero':{f:sum(x==0 for x in Image.open(P/f).getchannel('A').getdata())/(Image.open(P/f).width*Image.open(P/f).height) for f in set(x[0] for x in seq)}}
(P/'verification.json').write_text(json.dumps(qa,indent=2));print(qa)
frames[3].save(P/'contact_preview.png')
