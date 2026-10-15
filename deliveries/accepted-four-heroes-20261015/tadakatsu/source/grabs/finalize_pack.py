from pathlib import Path
import json,hashlib,zipfile
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parent
names=['grab_start','grab_hold','grab_hit_1','grab_hit_2','throw_forward','throw_reverse']
# Manually annotated visible glove centers in each original source sheet.
points={
'grab_start':[[[400,190],[332,260]],[[984,171],[866,235]],[[1478,162],[1450,250]],[[458,676],[441,698]],[[854,651],[801,673]],[[1366,696],[1348,715]]],
'grab_hold':[[[433,178],[388,231]],[[923,172],[879,225]],[[1458,169],[1401,222]],[[433,680],[390,738]],[[926,694],[886,747]],[[1455,682],[1406,734]]],
'grab_hit_1':[[[400,145],[369,168]],[[807,177],[771,201]],[[1193,162],[1167,189]],[[395,539],[371,565]],[[800,544],[774,570]],[[1210,562],[1191,586]],[[367,968],[343,989]],[[789,981],[767,1003]],[[1208,950],[1183,976]]],
'grab_hit_2':[[[441,139],[420,150]],[[790,189],[738,218]],[[1194,131],[1134,120]],[[382,556],[347,554]],[[747,556],[715,552]],[[1158,587],[1120,578]],[[326,975],[295,980]],[[767,1018],[723,1020]],[[1177,1071],[1126,1095]]],
 'throw_forward':[[[376,153],[346,162]],[[740,262],[695,268]],[[1151,121],[1120,140]],[[382,502],[350,481]],[[802,513],[774,529]],[[1220,483],[1229,540]],[[405,999],[379,1036]],[[777,1018],[752,1055]],[[1189,1017],[1110,1054]]],
 'throw_reverse':[[[391,137],[369,157]],[[767,135],[748,157]],[[1177,106],[1161,117]],[[272,508],[154,503]],[[556,501],[531,520]],[[876,575],[866,612]],[[56,1050],[103,1065]],[[509,1034],[545,1065]],[[957,951],[1010,978]]]
}
qa=[];manifest=[]
for n in names:
 d=ROOT/n;m=json.loads((d/'metadata.json').read_text());g=Image.open(d/f'{n}.gif');slow=Image.open(d/f'{n}-slow.gif')
 ds=[];ss=[]
 for i in range(g.n_frames):g.seek(i);ds.append(g.info['duration'])
 for i in range(slow.n_frames):slow.seek(i);ss.append(slow.info['duration'])
 assert ds==m['durations_ms'];assert ss==[x*3 for x in ds]
 digests=[];edges=[]
 for f,handpair in zip(m['frames'],points[n]):
  crop=f['source_rect'];s=f['scale'];dx,dy=f['translation']
  conv=lambda p:[round((p[0]-crop[0])*s+dx,2),round((p[1]-crop[1])*s+dy,2)]
  f['contacts']={'collar_glove':conv(handpair[0]),'upperarm_glove':conv(handpair[1]),'annotation':'manual visual estimate; no victim collision geometry baked into sprite'}
  if 'knee_contact_1' in f['events']:f['contacts']['knee_hit']=conv([779,605])
  if 'knee_contact_2' in f['events']:f['contacts']['knee_hit']=conv([754,606])
  if 'release_target_forward' in f['events']:f['contacts']['release_direction']=[1,-0.4]
  if 'release_target_reverse' in f['events']:f['contacts']['release_direction']=[-1,-0.25]
  arr=np.array(Image.open(d/'character'/f"{f['index']:02d}.png"));a=arr[:,:,3]
  edge=bool(a[0].any() or a[-1].any() or a[:,0].any() or a[:,-1].any());assert not edge
  edges.append(edge);digests.append(hashlib.sha256(arr.tobytes()).hexdigest())
 assert len(set(digests))==len(digests)
 m['contact_metadata']='Glove points manually annotated from full source sheets and transformed by the same registered scale/translation.'
 m['preview_review']='All source and registered contact-sheet poses visually inspected; normal/3x slow GIF frame counts, order and durations decoded and verified. Live cloud-browser playback unavailable for local files due URL protocol policy.'
 m['layer_limit']='Character pose is one RGBA layer, with separate complete spear. This is not an articulated per-limb rig.'
 m['target_events']='Target-on-target collision occurs after throw release; target ground impact must be emitted by downstream target simulation, not this fixed sprite timeline.'
 (d/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
 qa.append({'action':n,'normal_frames':g.n_frames,'slow_frames':slow.n_frames,'durations_verified':True,'source_keyframes_unique':True,'character_edge_clipping':False,'frame_count':len(m['frames']),'duration_ms':sum(ds)})
 manifest.append({'action':n,'frames':len(m['frames']),'duration_ms':sum(ds),'normal_gif':f'{n}/{n}.gif','slow_gif':f'{n}/{n}-slow.gif','metadata':f'{n}/metadata.json'})
(ROOT/'QA.json').write_text(json.dumps(qa,indent=2))
(ROOT/'manifest.json').write_text(json.dumps({'hero':'Honda Tadakatsu','generation':'cloud imagegen with approved v22 identity','actions':manifest,'runtime_modified':False,'optical_flow':False,'frame_reversal':False,'local_model_used':False},indent=2))
print(json.dumps({'qa':qa,'output_directory':str(ROOT),'packaging':'Parent combines all 16 actions into one package.'}))
