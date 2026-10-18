from pathlib import Path
from PIL import Image
import json,hashlib,numpy as np
O=Path('nobunaga_final_approved');R=Path('nobunaga_impact_v4');BG=(37,39,43)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def metrics(a,b):
 d=np.abs(np.asarray(a.convert('RGB')).astype('int16')-np.asarray(b.convert('RGB')).astype('int16'));return dict(pixel_exact=not bool(d.max()),max_channel_difference=int(d.max()),mean_absolute_channel_difference=round(float(d.mean()),8),different_pixel_count=int(np.any(d,2).sum()),compared_pixel_count=d.shape[0]*d.shape[1])
p=O/'charge_release/source-mapping.json';x=json.load(open(p));d=R/'charge_release_hires_range150'
for i,r in enumerate(x['frames']):
 if i==0:
  r['layer_completeness']={'actor':str(O/'charge_release/frames-composite/000.png'),'separate_body_weapon':False,'fx_front':'known empty','fx_back':'known empty'}
  recipe=json.load(open(O/'charge_hold/source-mapping.json'))['frames'][8]['approved_layer_render_recipe'].copy();recipe['body_offset']=[recipe['body_offset'][0]+480,recipe['body_offset'][1]];recipe['output_canvas']=[2400,1200];aff=recipe['weapon_template_to_review_inverse_affine'].copy();aff[2]-=aff[0]*480;aff[5]-=aff[3]*480;recipe['weapon_template_to_review_inverse_affine']=aff;body=Image.open(recipe['body_rgb']).convert('RGB');scale=recipe['body_scale'];out=Image.new('RGBA',(2400,1200),BG+(255,));out.paste(body.resize((round(body.width*scale),round(body.height*scale)),Image.Resampling.LANCZOS),recipe['body_offset']);template=Image.open(recipe['weapon_template']).convert('RGBA');out.alpha_composite(template.transform(out.size,Image.Transform.AFFINE,aff,Image.Resampling.BICUBIC));r['exact_approved_recipe_reconstruction_vs_review']=metrics(out,Image.open(d/'frames-review/000.png'));r['approved_layer_render_recipe']=recipe
  continue
 back=Image.open(d/f'layers/fx_back/{i:03}.png').convert('RGBA');actor=Image.open(d/f'layers/actor/{i:03}.png').convert('RGBA');front=Image.open(d/f'layers/fx_front/{i:03}.png').convert('RGBA');comp=back.copy();comp.alpha_composite(actor);comp.alpha_composite(front);out=Image.new('RGB',comp.size,BG);out.paste(comp,mask=comp.getchannel('A'));r['exact_approved_recipe_reconstruction_vs_review']=metrics(out,Image.open(d/f'frames-review/{i:03}.png'));r['approved_layer_render_recipe']={'layers_in_order':[str(d/f'layers/fx_back/{i:03}.png'),str(d/f'layers/actor/{i:03}.png'),str(d/f'layers/fx_front/{i:03}.png')],'background_rgb':BG,'canvas':[2400,1200],'independent_weapon_and_body_available':True,'warning':'Existing review layers are not original native masters. Native rebuilt layers are in layers-native.'}
p.write_text(json.dumps(x,indent=2))
a=json.load(open(O/'inventory.json'));summ=[];allok=True
for c in a['clips']:
 assert sha(c['approved_preview']['gif_path'])==c['approved_preview']['expected_sha256'],c['key']
 for src in c['original_resolution_sources']:
  assert sha(src['path'])==src['sha256'],src['path']
 k=c['key'];p=O/k/'source-mapping.json'
 if k=='throw_reverse':continue
 x=json.load(open(p));rs=x['frames'];assert len(rs)==c['approved_preview']['frames'],k
 for r in rs:
  z=r['output'];assert sha(z['path'])==z['sha256'],z['path'];im=Image.open(z['path']);assert im.mode=='RGBA';assert list(im.size)==z['dimensions']
 summary={'key':k,'frames':len(rs),'all_native_reconstruction_exact_on_approved_background':all(r['native_reconstruction_on_approved_background']['pixel_exact'] for r in rs),'exact_review_recipe_frames':sum(r.get('exact_approved_recipe_reconstruction_vs_review',{}).get('pixel_exact',False) for r in rs),'rgba_master_resize_exact_review_frames':sum(r.get('transparent_master_render_vs_approved_review',{}).get('pixel_exact',False) for r in rs),'max_rgba_master_resize_review_mean_abs_channel_diff':max(r['transparent_master_render_vs_approved_review']['mean_absolute_channel_difference'] for r in rs),'max_rgba_master_resize_review_channel_diff':max(r['transparent_master_render_vs_approved_review']['max_channel_difference'] for r in rs)}
 summ.append(summary);c['transparent_materialization']['verification']=summary
summary={'approved_clips':16,'approved_frames':a['total_frames'],'approved_duration_ms':a['total_duration_ms'],'all_16_gif_hashes_still_match':True,'all_selected_original_source_hashes_still_match':True,'materialized_clips':len(summ),'materialized_frames':sum(s['frames'] for s in summ),'all_216_native_bg_reconstructions_pixel_exact':all(s['all_native_reconstruction_exact_on_approved_background'] for s in summ),'clips':summ}
(O/'verification-summary.json').write_text(json.dumps(summary,indent=2));a['verification']['materialization_summary']=str(O/'verification-summary.json');(O/'inventory.json').write_text(json.dumps(a,ensure_ascii=False,indent=2))
(O/'gaps.txt').write_text('''Final approved audit: 16 clips, 232 frames, 10,520 ms. All16 GIF SHA-256 hashes match; every selected review PNG quantizes pixel-exact to its approved GIF. The old delivery manifest top-level 248/10840 totals and candidate statuses are stale. Reverse is planted_v2,16x50ms.

Materialized15 non-reverse clips:216 original-resolution transparent PNG masters. No review/game PNG was upscaled. All216 reconstruct the approved native/cleaned native/composited source pixel-exact on background RGB(37,39,43). This does not mean every RGBA resize is pixel-exact to the review, because original reviews often resized RGB or independently transformed body and weapon layers. Every measured difference is in the per-clip source-mapping and verification-summary.

Source hazards resolved:
- light_2 uses only candidate-f-selected-sources; earlier candidates are excluded.
- light_3 uses only15 selected review.json measurement paths, not all25 files in frames-native.
- heavy candidate-review-c uses matching parent native/review files; older candidate-review is excluded.
- grab_start first8 use candidate-b corrected canonical-blade recipe; old native004/005 are not authoritative. Exact body/template render recipes and original-sized layers are included.
- throw_forward native000..008 plus original-native grab_start recovery009..000; no review upscaling.

Remaining integration gaps:
- Most original melee/air/charge native sources were RGB. Transparency was derived from the same approved background cleanup and exact flat background key. Color-edge/alpha resampling differences are quantified, not hidden; arbitrary-background edge quality has not been visually signed off.
- Grab-start first8 and corresponding forward recovery, plus charge-ready/hold, need the supplied separate-layer recipes to reproduce review pixels exactly. A single precomposed-native resize is close but not bit-exact.
- Charge-release has existing review-sized actor/body/weapon/front-FX/back-FX001..023, copied unchanged, plus rebuilt original-scale native layers001..023. Frame000 has complete actor-composite, no FX, and no independent body/weapon separation. Existing native body donors and canonical blade are retained.
- No dedicated hand-occlusion PNG tracks were found. Most swords/hands remain fused into actors. Some local canonical-steel templates and approved layer ordering are available, but they are not full per-frame socket/occlusion rigs.
- Art landmarks, root/feet/scale transforms and terminal/FX timings are advisory. Runtime start/end events, hitboxes/hurtboxes, weapon sockets, victim attachment and world-scale contract must be preserved/verified by integration; this audit invents none.
- Reverse master preparation is owned by the other worker; its final16 approved RGBA sources and current metadata are inventoried here without modification.

Source visuals, runtime, site and Git were not changed by this audit/materialization task.
''')
print(json.dumps(summary,indent=2))
