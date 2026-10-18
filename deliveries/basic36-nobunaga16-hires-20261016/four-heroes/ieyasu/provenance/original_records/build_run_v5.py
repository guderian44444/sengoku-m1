from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,json,sys,hashlib
B=Path(__file__).parent;sys.path.insert(0,str(B));import render_action as R
O=B/'run_v5';Q=O/'qa';Q.mkdir(parents=True,exist_ok=True);M=O/'masks';M.mkdir(exist_ok=True);s=152/920
old=json.load(open(B/'run_v4/metadata.json'))
# Original high-resolution contact head, one fixed anatomical scale for all six frames.
master=R.isolate({'source':'run_v2_contacts_raw.png','component':0});hm=Image.new('L',master.size);ImageDraw.Draw(hm).polygon([(450,0),(710,0),(710,210),(675,270),(545,270),(495,215),(450,170)],fill=255);ma=np.array(master);ma[:,:,3]=ma[:,:,3].astype('uint16')*np.array(hm)//255;head=Image.fromarray(ma);head.save(O/'head_master_native.png')
# Upper torso poses; all new raw figures retain original 920px standing-equivalent scale.
fs=[
 dict(source='run_v5_upper_contacts_raw.png',component=0,chest=[603,330],target=[221,175],hands=[[666,416],[736,423]],head_clear=[470,0,706,232],head_offset=[1,0],angle=-48),
 dict(source='run_v5_upper_passing_raw.png',component=0,chest=[565,330],target=[220,173],hands=[[518,462],[590,474]],head_clear=[455,0,685,234],head_offset=[0,-1],angle=-54),
 dict(source='run_v5_upper_flight_raw.png',component=0,chest=[555,327],target=[218,172],hands=[[508,410],[571,427]],head_clear=[445,0,665,235],head_offset=[-1,-2],angle=-61),
 dict(source='run_v5_upper_contacts_raw.png',component=1,chest=[1295,330],target=[218,175],hands=[[1250,407],[1310,415]],head_clear=[1160,0,1390,234],head_offset=[-1,0],angle=-64),
 dict(source='run_v5_upper_contacts_raw.png',component=0,chest=[603,330],target=[220,173],hands=[[666,416],[736,423]],head_clear=[470,0,706,232],head_offset=[0,-1],angle=-57),
 dict(source='run_v5_upper_flight_raw.png',component=1,chest=[1273,330],target=[222,172],hands=[[1353,420],[1404,414]],head_clear=[1134,0,1360,235],head_offset=[1,-2],angle=-50)
]
comps=[];recs=[];checks=[];maskviews=[]
for i,f in enumerate(fs,1):
 oldlays={k:Image.open(B/f'run_v4/{k}_{i:02}.png').convert('RGBA') for k in ['body','weapon','sheath','hand_occlusion']};oldco=Image.open(B/f'run_v4/composite_{i:02}.png').convert('RGBA');ba=np.array(oldlays['body'].getchannel('A'))
 cloth=Image.new('L',(480,320));cd=ImageDraw.Draw(cloth)
 poly=[(172,202),(184,195),(206,195),(204,203),(193,216),(179,210)] if i!=4 else [(170,204),(183,198),(202,198),(201,207),(190,218),(176,212)]
 cd.polygon(poly,fill=255);ca=np.array(cloth)>0;y=np.indices(ba.shape)[0]
 # Includes all leg pixels and a one-pixel antialias margin; everything below y222 is additionally frozen.
 protected=ndimage.binary_dilation((ba>0)&(y>=204)&(~ca),iterations=1)|(y>=222);edit=(~protected)&(y<222);bodyedit=(~protected)&((y<204)|ca);pm=Image.fromarray((protected*255).astype('uint8'));em=Image.fromarray((edit*255).astype('uint8'));pm.save(M/f'protected_legs_{i:02}.png');Image.fromarray((bodyedit*255).astype('uint8')).save(M/f'editable_upper_cloth_{i:02}.png');em.save(M/f'editable_weapon_hand_{i:02}.png');cloth.save(M/f'cloth_region_{i:02}.png')
 body=R.isolate(f);ar=np.array(body);bbox=body.getbbox();clr=Image.new('L',body.size);dc=ImageDraw.Draw(clr);hc=f['head_clear'];dc.rectangle([hc[0],0,hc[2],185],fill=255)
 necks=[[(540,180),(570,220),(615,252),(660,232),(706,190)],[(490,180),(530,220),(570,255),(620,235),(685,190)],[(500,180),(525,210),(570,245),(615,225),(665,190)],[(1210,180),(1245,220),(1285,250),(1330,230),(1390,190)],[(540,180),(570,220),(615,252),(660,232),(706,190)],[(1195,180),(1220,215),(1265,250),(1315,230),(1360,190)]];dc.polygon(necks[i-1],fill=255);ar[:,:,3]=np.where(np.array(clr)>0,0,ar[:,:,3]);body=Image.fromarray(ar)
 ox=f['target'][0]-f['chest'][0]*s;oy=f['target'][1]-f['chest'][1]*s;nb=R.place(body,s,ox,oy)
 hx,hy=f['head_offset'];nb.alpha_composite(R.place(head,s,127.47826086956522+hx,123.20869565217393+hy))
 # Keep all accepted lower pixels and joints. Clear the former upper silhouette before replacing it.
 nb=Image.composite(nb,oldlays['body'],Image.fromarray((bodyedit*255).astype('uint8')))
 hands=f['hands'];g=[sum(x for x,y in hands)/2,sum(y for x,y in hands)/2];gp=[ox+g[0]*s,oy+g[1]*s];sw=R.weapon(R.sw,[100,1080],gp,f['angle'],.085)
 hmask=Image.new('L',body.size);hd=ImageDraw.Draw(hmask)
 for x0,y0 in hands:hd.ellipse((x0-34,y0-34,x0+34,y0+34),fill=255)
 ar=np.array(R.isolate(f));ar[:,:,3]=ar[:,:,3].astype('uint16')*np.array(hmask)//255;nh=R.place(Image.fromarray(ar),s,ox,oy)
 lays={'body':nb,'weapon':Image.composite(sw,oldlays['weapon'],em),'sheath':oldlays['sheath'],'hand_occlusion':Image.composite(nh,oldlays['hand_occlusion'],em)};co=Image.new('RGBA',(480,320))
 for k in ['sheath','body','weapon','hand_occlusion']:lays[k].save(O/f'{k}_{i:02}.png');co.alpha_composite(lays[k])
 co.save(O/f'composite_{i:02}.png');comps.append(co);da=np.abs(np.array(co).astype(int)-np.array(oldco).astype(int));check={'frame':i,'protected_rgba_max_error':int(da[protected].max()),'protected_changed_pixel_count':int(np.any(da>0,axis=2)[protected].sum()),'rows_222_and_below_rgba_max_error':int(da[222:].max()),'editable_changed_pixel_count':int(np.any(da>0,axis=2)[edit].sum()),'root_foot_timing_preserved':True};checks.append(check)
 rec=dict(old['frames'][i-1]);rec.update(upper_source_file='../sources/'+f['source'],upper_source_sha256=hashlib.sha256((B/'sources'/f['source']).read_bytes()).hexdigest(),upper_source_component=f['component'],upper_source_bbox=list(bbox),upper_source_effective_height=bbox[3]-bbox[1],upper_source_standing_ruler=920,upper_scale=s,upper_render_origin=[ox,oy],upper_chest_source=f['chest'],upper_chest_canvas=f['target'],head_source='../sources/run_v2_contacts_raw.png',head_source_component=0,head_offset_canvas=f['head_offset'],hands_source=hands,hands_canvas=[[ox+x*s,oy+y*s] for x,y in hands],grip_canvas=gp,weapon_angle_degrees=f['angle'],protected_mask=f'masks/protected_legs_{i:02}.png',editable_mask=f'masks/editable_upper_cloth_{i:02}.png',lower_body_accepted_source=f'../run_v4/composite_{i:02}.png',upper_articulated=True);recs.append(rec)
 bg=Image.new('RGBA',(480,320),'#252b34');bg.alpha_composite(co);ov=Image.new('RGBA',(480,320));a=np.array(ov);a[protected]=[255,50,70,80];a[edit]=[20,190,240,45];bg.alpha_composite(Image.fromarray(a));maskviews.append(bg.convert('RGB'))
meta=dict(old);meta.update(revision='run_v5_candidate_01',approval='pending_user_review',lower_body_approval={'message_id':'Sentinel_744c8982451c8191ae661e4a33166c47','quote':'腳沒問題了，但上半身也要動阿','retained_revision':'run_v4'},frames=recs,notes=['Accepted leg pixels, foot points, root, six-frame order and 500ms timing retained exactly from run_v4.','New high-resolution articulated torso/shoulder/elbow poses; original high-resolution head preserved at fixed scale with 0 to 2px running bob.','Only explicit editable upper/cloth masks are replaced. Protected leg masks include antialias margins. No new worker or site change.']);(O/'metadata.json').write_text(json.dumps(meta,indent=2));(O/'QA.json').write_text(json.dumps({'status':'local_visual_review_pending','frame_checks':checks,'all_protected_leg_rgba_differences_zero':all(c['protected_rgba_max_error']==0 for c in checks),'no_lower_resample_or_shift':True,'minimum_new_full_figure_height':min(r['upper_source_effective_height'] for r in recs),'fixed_upper_scale':s},indent=2))
normal=[];compares=[]
for i,(co,r) in enumerate(zip(comps,recs)):
 im=Image.new('RGB',(480,320),'#252b34');im.paste(co,(0,0),co);d=ImageDraw.Draw(im);d.line((10,281,470,281),fill='#68717b');d.text((12,10),'IEYASU RUN v5 | upper revision, accepted legs locked',fill='white');d.text((12,298),f'{i+1}/6 {r["duration_ms"]}ms  152px ruler',fill='white');normal.append(im)
 left=Image.new('RGB',(480,320),'#252b34');left.paste(R.IDLE['composite'],(0,0),R.IDLE['composite']);ImageDraw.Draw(left).text((12,10),'APPROVED COMBAT IDLE | 152px ruler',fill='white');ImageDraw.Draw(left).line((10,281,470,281),fill='#68717b');cp=Image.new('RGB',(960,320));cp.paste(left,(0,0));cp.paste(im,(480,0));compares.append(cp)
for name,ims,factor,loop in [('normal.gif',normal,1,True),('idle-comparison.gif',compares,1,True),('slow-once.gif',normal,3,False)]:
 kw={'save_all':True,'append_images':ims[1:],'duration':[r['duration_ms']*factor for r in recs],'disposal':2}
 if loop:kw['loop']=0
 ims[0].save(O/name,**kw)
strip=Image.new('RGB',(1380,820),'#252b34');mv=Image.new('RGB',(1440,640))
for i,im in enumerate(normal):
 strip.paste(im.crop((100,105,330,290)).resize((460,370),Image.Resampling.NEAREST),(i%3*460,i//3*410+30));ImageDraw.Draw(strip).text((i%3*460+10,i//3*410+8),f'{i+1} {recs[i]["phase"]}',fill='white');mv.paste(maskviews[i],(i%3*480,i//3*320))
strip.save(O/'numbered-pose-strip.png');mv.save(Q/'protected_editable_masks.png');compares[1].save(O/'idle-comparison.png');print(json.dumps(checks,indent=2))
