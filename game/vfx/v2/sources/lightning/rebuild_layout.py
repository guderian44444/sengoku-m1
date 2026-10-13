"""Layout-only resize/pad and alpha validation. Never paints/removes background."""
from pathlib import Path
from PIL import Image
import json, math

ROOT = Path(__file__).resolve().parent
manifest, validation = {}, {}
for name, ticks, size in [('lightning_arc',18,280),('lightning_ring',28,420),('lightning_wave',24,300),('lightning_hit',12,160)]:
    source = Image.open(ROOT / (name+'_source.png'))
    assert source.mode == 'RGBA', 'Generated source must already have alpha'
    source_size = list(source.size)
    source.thumbnail((896,896), Image.Resampling.LANCZOS)
    output = Image.new('RGBA',(1024,1024))
    offset = ((1024-source.width)//2,(1024-source.height)//2)
    output.paste(source, offset)
    output.save(ROOT / (name+'.png'))
    a=output.getchannel('A'); h=a.histogram(); bbox=a.getbbox()
    gutter=all(a.crop(b).getextrema()==(0,0) for b in [(0,0,1024,64),(0,960,1024,1024),(0,0,64,1024),(960,0,1024,1024)])
    assert gutter
    visible=a.point(lambda v:255 if v>=16 else 0).getbbox()
    validation[name]={'mode':output.mode,'size':list(output.size),'source_size':source_size,'alpha_extrema':list(a.getextrema()),'alpha_bbox':list(bbox),'alpha16_bbox':list(visible),'zero_alpha_fraction':h[0]/1024**2,'partial_alpha_fraction':sum(h[1:255])/1024**2,'outer_64px_gutter_clear':gutter}
    manifest[name]={'texture':'res://vfx/v2/art/'+name+'.png','cell':[1024,1024],'columns':1,'rows':1,'row':0,'frames':1,'frame_count':1,'pivot':[.5,.5],'split_depth':name=='lightning_ring','seam':.5,'duration_ticks':ticks,'loop':False,'world_size':size,'animation_source':'single_generated_texture_plus_runtime_procedural_motion','blend':'mix','optional_blend':'add_with_reduced_intensity_after_scene_QA','source_art':name+'_source.png','layout_operation':'Uniform Lanczos fit source within 896x896, centered on 1024x1024 transparent canvas. Original generated alpha preserved; no effect painting or background removal.','bounds_px':list(bbox),'visible_bounds_alpha16_px':list(visible),'transparent_gutter_px':64,'render_padding':.30,'limitations':['One generated authored frame only, not a hand-animated flipbook.','Violet-blue halo is baked into source; isolate motion with mesh, UV flow and localized sparks.','Do not use high-frequency full-screen flashes; use small localized low-amplitude intensity changes.','Runtime distortion and elliptical UV rotation require overscan validation; texture gutter alone is not sufficient.']}
    if name=='lightning_ring':
        manifest[name].update({'flow_center':[.5,.5],'flow_radius':[.36,.125],'ringmetric':{'ellipse_center_uv':[.5,.5],'ellipse_radius_uv':[.36,.125],'basis':'Visual centerline estimate after layout, excluding branching sparks; validate during scene integration.','seam_uv_y':.5,'front_half':'y >= 0.5','back_half':'y < 0.5'},'overscan_note':'0.30 is initial render expansion for integrator QA, not proof of arbitrary full rotations. Keep ellipse-aware ring flow; full UV-plane rotation can clip or distort thin ellipse. Prefer mesh phase flow or larger padded render quad.'})
    else:
        manifest[name]['flow_center']=[.5,.5]
        manifest[name]['flow_radius']=[.4,.4]
if __name__=='__main__':
    (ROOT/'alpha_validation.json').write_text(json.dumps(validation,indent=2))
    (ROOT/'lightning_manifest.json').write_text(json.dumps(manifest,indent=2))
    print(json.dumps(validation,indent=2))
