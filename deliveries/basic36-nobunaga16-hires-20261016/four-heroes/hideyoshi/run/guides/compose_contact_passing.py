from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json
P=Path(__file__).resolve().parents[1];S=P/'source';k=.164/.115;pad=250;contact=Image.open(S/'contacts.png').convert('RGBA')
# All drawing pixels below are from native original generated PNGs. These masks only select artwork, not redraw it.
upper_boundaries=[[(0,0),(768,0),(768,450),(678,456),(665,543),(634,552),(574,523),(457,524),(420,517),(387,545),(357,527),(330,554),(235,520),(200,538),(0,510)],[(0,0),(768,0),(768,475),(644,478),(613,525),(620,563),(601,582),(572,567),(540,546),(411,540),(400,521),(352,532),(310,548),(275,577),(240,563),(190,545),(80,535),(0,510)]]
low_polys={
 'near':[(445,810),(640,810),(690,945),(755,1030),(745,1130),(725,1450),(385,1450),(375,1130),(345,950),(350,890),(395,850)],
 'far':[(448,815),(614,815),(650,946),(710,970),(758,1050),(705,1130),(690,1300),(550,1300),(550,1450),(350,1450),(345,1150),(285,1085),(290,1000),(350,944),(438,945)]}
cfg=json.loads((P/'build_config.json').read_text());info={}
for j,side in enumerate(['near','far']):
 lower=Image.open(S/('compact_passing_'+side+'.png')).convert('RGBA'); lm=Image.new('L',lower.size);ImageDraw.Draw(lm).polygon(low_polys[side],fill=255);a=np.array(lower);a[:,:,3]=a[:,:,3]*np.array(lm,dtype='float32')/255;lower=Image.fromarray(a)
 upper=contact.crop((j*768,0,(j+1)*768,1024));um=Image.new('L',upper.size);ImageDraw.Draw(um).polygon(upper_boundaries[j],fill=255);a=np.array(upper);a[:,:,3]=a[:,:,3]*np.array(um,dtype='float32')/255;upper=Image.fromarray(a)
 src_anchor=[475,450] if j==0 else [435,450];dst_anchor=[610,750] if j==0 else [585,735]
 tx=dst_anchor[0]-src_anchor[0]*k+pad;ty=dst_anchor[1]-src_anchor[1]*k
 high=Image.new('RGBA',(1400,1600));high.alpha_composite(lower,(pad,0));upper=upper.resize((round(768*k),round(1024*k)),Image.Resampling.LANCZOS);high.alpha_composite(upper,(round(tx),round(ty)));high.save(S/('assembled_passing_'+side+'.png'))
 bg=Image.new('RGBA',high.size,(42,48,56));bg.alpha_composite(high);bg.save(P/'qa'/('assembled_passing_'+side+'_native.png'))
 f=cfg['frames'][1 if j==0 else 4]; c=cfg['frames'][0 if j==0 else 3]
 f['src']='assembled_passing_'+side+'.png';f['side']=0;f['scale']=.115
 def pt(p):return [round((p[0]-j*768)*k+tx,3),round(p[1]*k+ty,3)]
 h=c['head'];f['head']=list(map(round,pt(h[:2])+pt(h[2:])));h=c['hands'];f['hands']=list(map(round,pt(h[:2])+pt(h[2:])));f['grip']=pt(c['grip']);basefeet={'near':[502,1260],'far':[615,1410]} if j==0 else {'near':[452,1417],'far':[596,1260]}; f['feet']={n:[v[0]+pad,v[1]] for n,v in basefeet.items()};f['origin']=[552+pad,1424] if j==0 else [524+pad,1426]
 info[side]={'upper_source':'contacts.png','upper_native_side':j,'upper_native_to_assembly_scale':k,'upper_native_to_assembly_translation':[tx,ty],'lower_source':'compact_passing_'+side+'.png','lower_translation':[pad,0],'lower_native_scale':1,'assembly_to_game_scale':.115,'contact_game_scale':.164,'upper_game_scale_identity':k*.115,'scale_basis':'Upper body exact contact artwork and exact game anatomical dimensions; lower unchanged compact passing anatomy. No bbox height equalization.','all_source_pngs_retained':True}
# Recompute root motion to plant the support foot between contact and passing.
def localfoot(f,n):return [(f['feet'][n][z]-f['origin'][z])*f['scale'] for z in (0,1)]
for a,b,n in [(0,1,'far'),(3,4,'near')]:
 ca,cb=cfg['frames'][a],cfg['frames'][b];pa=localfoot(ca,n);pb=localfoot(cb,n);cb['world']=[round(ca['world'][z]+pa[z]-pb[z],3) for z in (0,1)]
(P/'build_config.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2));(P/'qa/highres_assembly_provenance.json').write_text(json.dumps(info,indent=2))
