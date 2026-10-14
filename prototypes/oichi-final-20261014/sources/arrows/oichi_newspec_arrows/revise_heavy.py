import render_v2 as b,json,copy,hashlib
from PIL import Image
P=b.P;O=b.OUT;src=P.parent/'generated_images/exec-f096f7cf-f176-4437-97c6-7fa011593e8c.png';im=Image.open(src).convert('RGBA')
scale=.70
for k in range(2):
 box=(k*887,0,(k+1)*887,887);crop=im.crop(box);crop=crop.resize((621,621),Image.Resampling.LANCZOS);can=Image.new('RGBA',(1024,1024));can.alpha_composite(crop,(182,296));path=O/f'heavy_added_{k}.png';can.save(path)
 f=copy.deepcopy(b.frames[3]);f.update(image=str(path),phase=['level_short_draw_transition','post_release_followthrough_transition'][k],grip=[767.2,481.5],draw_point=([507,488] if k==0 else [470,583]),is_drawing=k==0,arrow_nocked=k==0,release_event=False,arrow_flying=False,source_provenance={'kind':'cloud_imagegen','source':src.name,'region':box,'scale':scale,'translation':[182,296],'ruler':'head-size and standing leg segments matched, not alpha bbox normalization','native_alpha_preserved':True,'no_optical_flow':True});b.frames.append(f)
for idx in [10,11,12]:b.frames[idx]['arrow_direction']=[1,0]
b.frames[10]['arrow_tail_override']=[787.2,488]
r=b.render('heavy_horizontal_9keys',[0,1,2,3,11,10,12,9,0],[70,70,70,100,90,70,70,100,160])
m=json.load(open(r/'animation.json'));m.update(action='heavy',revision='two_added_cloud_key_poses_and_horizontal_arrow',projectile_direction=[1,0],projectile_spawn_anchor=[767.2,488],nocked_arrow_tail_final=[507,488],release_event_ms=400,unique_character_poses=8,playback_keys=9,preview_duration_ms=800,previous_preview_ms=800,unaffected_actions=['charge_ready','charge_hold','charge_rain','air_heavy'],notes='Two new effective transition poses. Final playback key returns to first ready pose. Existing six unique body drawings reused unchanged. Arrow launches from final nock height and continues horizontal.');json.dump(m,open(r/'animation.json','w'),indent=2)
