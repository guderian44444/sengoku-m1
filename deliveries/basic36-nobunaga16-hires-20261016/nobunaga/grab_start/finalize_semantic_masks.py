from pathlib import Path
p=Path('nobunaga_final_approved/charge_release/repair_semantic_layers.py');s=p.read_text();ns={'__file__':str(p.resolve())};exec(s.split('# Original approved source layout')[0],ns);globals().update(ns)
k='grab_start';d=O/k;records=json.load(open(d/'layers-visible-manifest.json'));src=d/'frames-composite/009.png';a=np.array(Image.open(src).convert('RGBA'));old=np.array(Image.open(d/'layers-visible/masks/009-weapon.png'))>0
# Grip skin is allowed to reclaim pixels erroneously included by the old weapon detector.
box=(395,610,480,690);hm=skin_in_box(a,box,np.zeros(old.shape,bool));wm=old&~hm
# Remove inherited false weapon selections on adjacent arm cuff and skirt armor, while preserving visible hilt/guard/steel.
y,x=np.indices(old.shape);wm&=~((y>725)&(y<800)&(x>450));wm&=~((y<626)&(x>434))
m,q,_=partition(k,9,src,wm,hm,{'detector':'visible source partition with manually inspected grip/cuff/armor correction','duration_ms':records[9]['duration_ms'],'manual_hand_roi_native':box,'native_layer_based':False,'weapon_contents':'visible steel/guard/hilt source pixels; hand reclaimed from old detector, no hidden pixels invented','hidden_body_complete':False,'hidden_weapon_under_hands_complete':False});records[9]=m
thumbs=[]
for i,m in enumerate(records):
 src=O/m['source'];a=np.array(Image.open(src).convert('RGBA'));wm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-weapon.png'))>0;hm=np.array(Image.open(d/f'layers-visible/masks/{i:03}-hand.png'))>0
 yy,xx=np.nonzero(hm);m['grip_art_px']=[round(float(xx.mean()),2),round(float(yy.mean()),2)] if len(xx) else None;m['grip_measurement']='advisory visible hand-mask centroid, not a rig socket';m['native_layer_based']=i<8
 # PCA is used only to measure the already approved/extracted weapon mask, never to decide pixels.
 yy,xx=np.nonzero(wm);pts=np.column_stack([xx,yy]).astype(float);cen=pts.mean(0);val,vec=np.linalg.eigh(np.cov(pts,rowvar=False));u=vec[:,-1];proj=(pts-cen)@u;ends=[cen+u*np.quantile(proj,.005),cen+u*np.quantile(proj,.995)];grip=np.array(m['grip_art_px']) if m['grip_art_px'] else cen
 if np.linalg.norm(ends[1]-grip)<np.linalg.norm(ends[0]-grip):ends=ends[::-1]
 m['blade_base_art_px']=np.round(ends[0],2).tolist();m['blade_tip_art_px']=np.round(ends[1],2).tolist();m['blade_angle_deg']=round(float(np.degrees(np.arctan2(*(ends[1]-ends[0])[::-1]))),3);m['blade_measurement']='advisory PCA span of known visible weapon, oriented from hand centroid; not authored runtime socket'
 if i<8:m['coverage_gaps']=['Authored independent native weapon contains exposed steel only; hilt/guard remain partly fused in body.','Hidden body and under-hand blade pixels are not reconstructed.']
 if i==3:m.setdefault('coverage_gaps',[]).append('Inherited approved master has jagged transparent holes across brow/eye/nose beside blade from prior erase. Source preserved exactly; hidden-fill/source-art coverage is incomplete.')
 q=Image.new('RGBA',(a.shape[1],a.shape[0]),BG+(255,));q.alpha_composite(Image.fromarray(a));z=np.array(q);z[wm,:3]=(z[wm,:3]*.3+np.array([45,220,250])*.7).astype('uint8');z[hm,:3]=(z[hm,:3]*.3+np.array([240,70,190])*.7).astype('uint8');q=Image.fromarray(z).crop(Image.fromarray(a).getbbox());q.thumbnail((360,360));thumbs.append(q.convert('RGB'))
sheet(k,thumbs,records)
print('grab_start finalized:12 exact partitions;009 hand pixels',int(hm.sum()))
