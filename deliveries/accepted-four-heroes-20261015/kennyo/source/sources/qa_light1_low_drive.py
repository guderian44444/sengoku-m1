from pathlib import Path
from PIL import Image,ImageDraw
import json,math,hashlib
P=Path(__file__).parent;O=P/'light_1_v4';old=json.loads((P/'light_1_v3/metadata.json').read_text());new=json.loads((O/'metadata.json').read_text())
# Visible 2D joint / feature landmarks, manually checked on grid-enlarged source pixels.
# These are projected anatomy proxies, not an assertion of hidden 3D rig lengths.
landmarks={
 'v3':{'crown':[668,451],'brow':[685,481],'chin':[682,518],'neck':[662,530],'belt':[629,606],'elbow':[670,576],'wrist':[714,578],'knee':[726,751],'ankle':[751,787]},
 'v4':{'crown':[728,508],'brow':[751,544],'chin':[746,582],'neck':[712,590],'belt':[643,634],'elbow':[730,636],'wrist':[775,638],'knee':[730,750],'ankle':[752,789]}}
segments={'face_brow_chin':['brow','chin'],'torso_neck_belt':['neck','belt'],'visible_forearm':['elbow','wrist'],'support_shin':['knee','ankle']}
lengths={}
for name,(a,b) in segments.items():
 v=[math.dist(landmarks[k][a],landmarks[k][b])*.408 for k in ['v3','v4']]
 lengths[name]={'v3_projected_px':round(v[0],3),'v4_projected_px':round(v[1],3),'change_percent':round((v[1]/v[0]-1)*100,3)}
 assert abs(lengths[name]['change_percent'])<7
world={}
for version,meta in [('v3',old),('v4',new)]:
 r=meta['frames'][5];x0,y0,*_=r['rect'];ox,oy=r['render_origin'];s=r['uniform_source_scale'];world[version]={n:[ox+(p[0]-x0)*s,oy+(p[1]-y0)*s] for n,p in landmarks[version].items()}
drops={k:round(world['v4'][k][1]-world['v3'][k][1],3) for k in ['crown','neck','belt','knee','ankle']}
assert drops['crown']>15 and drops['crown']-drops['belt']>8
unchanged=[]
for f in [1,2,3,4,8,9,10]:
 a=(P/f'light_1_v3/body_canvas_{f:02}.png').read_bytes();b=(O/f'body_canvas_{f:02}.png').read_bytes();assert a==b;unchanged.append(f)
qa=json.loads((O/'QA.json').read_text());qa['anatomy_and_downward_drive']={'method':'Manual visible 2D landmarks measured on original raster at constant 0.408 source scale. Projected proxies only; hidden 3D bone lengths cannot be recovered exactly from sprites.','landmarks_source_xy':landmarks,'projected_length_comparison':lengths,'contact_landmark_world_y_delta_px':drops,'same_pixel_bodies':unchanged,'changed_pose_frames':[5,6,7],'not_whole_body_translation':True,'no_anisotropic_or_per_frame_scale':True}
timing={'previous_durations_ms':[80,80,70,60,40,40,50,60,70,120],'new_durations_ms':[80,80,70,30,20,40,20,90,100,140],'startup_frames_1_to_3_ms':{'before':230,'after':230},'active_frames_4_to_7_ms':{'before':190,'after':110},'entry_to_contact_frames_4_to_5_ms':{'before':100,'after':50},'contact_hold_ms':{'before':40,'after':40},'recovery_frames_8_to_10_ms':{'before':250,'after':330},'contact_start_ms':{'before':330,'after':280},'contact_window_ms':[280,320],'duration_ms':670}
qa['timing_comparison']=timing;new['timing_comparison']=timing;new['anatomy_qa']=qa['anatomy_and_downward_drive'];new['requested_changes']=['Deeper forward/down shoulder/chest drive from local imagegen articulation in frames 5–7.','Startup remains 230 ms; active swing accelerates from 190 to 110 ms, with 80 ms moved to recovery.','Same left pivot, ten frames, 670 ms, source-scale and staff swing/tail grip retained.']
assert new['frames'][5]['start_ms']==280 and new['frames'][5]['duration']==40
(O/'QA.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2));(O/'metadata.json').write_text(json.dumps(new,ensure_ascii=False,indent=2))
review=Image.new('RGB',(960,600),(37,43,52))
colors={'crown':(255,220,70),'neck':(255,120,60),'belt':(80,220,255),'knee':(130,220,110),'ankle':(130,220,110),'brow':(255,220,70),'chin':(255,220,70),'elbow':(220,130,255),'wrist':(220,130,255)}
for j,(ver,folder) in enumerate([('v3','light_1_v3'),('v4','light_1_v4')]):
 im=Image.open(P/f'{folder}/body_canvas_06.png').convert('RGBA');tile=Image.new('RGB',(480,600),(37,43,52));crop=im.crop((200,145,360,325)).resize((480,540));tile.paste(crop,(0,40),crop.getchannel('A'));d=ImageDraw.Draw(tile);d.text((10,10),f'{ver}: contact pose, same fixed source scale',fill='white')
 def q(n):x,y=world[ver][n];return ((x-200)*3,(y-145)*3+40)
 for name,(a,b) in segments.items():d.line((*q(a),*q(b)),fill=colors[a],width=2)
 for n in ['crown','neck','belt','knee','ankle']:
  x,y=q(n);d.ellipse((x-3,y-3,x+3,y+3),fill=colors[n]);d.text((x+5,y),n,fill=colors[n])
 review.paste(tile,(j*480,0))
review.save(O/'anatomy-comparison-QA.png')
print(json.dumps({'lengths':lengths,'drops':drops,'unchanged_body_frames':unchanged,'timing':timing}))
