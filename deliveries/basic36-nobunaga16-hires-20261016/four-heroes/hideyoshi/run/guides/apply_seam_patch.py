from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import json,numpy as np
P=Path(__file__).resolve().parents[1];S=P/'source';cfg=json.loads((P/'build_config.json').read_text());info={}
for side,idx in [('near',1),('far',4)]:
 base=Image.open(S/('assembled_passing_'+side+'.png')).convert('RGBA');gen=Image.open(S/('seam_passing_'+side+'_generated.png')).convert('RGBA');origsize=gen.size;gen=gen.resize(base.size,Image.Resampling.LANCZOS)
 mask=Image.new('L',base.size);box=[520,795,1120,980] if side=='near' else [520,785,1100,1010];ImageDraw.Draw(mask).rectangle(box,fill=255);mask=mask.filter(ImageFilter.GaussianBlur(6));out=Image.composite(gen,base,mask);out.save(S/('final_passing_'+side+'.png'))
 bg=Image.new('RGBA',base.size,(42,48,56));bg.alpha_composite(out);bg.save(P/'qa'/('final_passing_'+side+'_native.png'))
 a=np.array(base);b=np.array(out);m=np.array(mask);outside=m==0
 info[side]={'target':'assembled_passing_'+side+'.png','official_imagegen_patch_source':'seam_passing_'+side+'_generated.png','patch_generated_size':origsize,'assembly_canvas':base.size,'patch_rect':box,'feather_sigma':6,'outside_mask_pixel_exact':bool(np.array_equal(a[outside],b[outside])),'outside_mask_delta_max':int(np.abs(a[outside].astype(int)-b[outside].astype(int)).max()),'purpose':'Only repair high-resolution assembly seam below waist armor. Contact head/chest/arms, passing knees/shins/shoes remain original pixels outside the localized mask.'}
 cfg['frames'][idx]['src']='final_passing_'+side+'.png'
(P/'build_config.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2));(P/'qa/seam_patch_provenance.json').write_text(json.dumps(info,indent=2))
