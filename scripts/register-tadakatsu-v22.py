"""Register original RGBA artwork. Pixels are never edited; polygons only delimit atlas figures."""
from pathlib import Path
import json, hashlib, math
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'game/assets/v22/tadakatsu'
# Visible grip centers, measured on the original full-resolution sheets.
HANDS = {
 'idle': [[398,170],[889,169],[1388,180],[422,676],[910,676],[1397,668]],
 'walk': [[420,177],[895,184],[1353,170],[438,681],[916,690],[1392,680]],
 'run': [[491,230],[995,224],[1479,209],[519,739],[1033,734],[1503,728]],
 'jump': [[445,253],[973,81],[1395,84],[438,623],[936,635],[1444,742]],
 'light1': [[412,213],[849,187],[1478,169],[582,661],[1088,672],[1430,691]],
 'light2': [[205,268],[786,312],[1388,199],[438,525],[906,514],[1406,647]],
 'light3': [[167,266],[623,170],[1418,232],[520,685],[1020,700],[1447,738]],
 'heavy1': [[256,79],[741,27],[1395,318],[483,842],[932,900],[1433,788]],
 'heavy2': [[220,259],[686,340],[1365,244],[568,705],[1078,703],[1445,771]],
 'slam_charge': [[396,190],[835,115],[1338,98],[356,501],[826,499],[1318,495]],
 'charged_slam': [[396,51],[894,132],[1422,254],[411,810],[882,875],[1418,714]],
 'charge_forward': [[450,197],[973,210],[1477,236],[492,720],[979,775],[1496,715]],
 'dash': [[429,254],[948,222],[1499,199],[461,699],[978,699],[1411,715]],
 'upper': [[460,323],[865,309],[1377,124],[409,492],[758,524],[1417,613]],
 'low_sweep': [[225,300],[755,368],[1467,336],[502,827],[993,794],[1397,750]],
 'air_light': [[414,191],[757,232],[1485,195],[523,768],[1019,767],[1392,645]],
 'air_heavy': [[397,108],[753,35],[1438,382],[409,830],[895,795],[1408,920]],
 'hurt': [[269,272],[765,308],[1280,355],[219,779],[760,809],[1262,818]],
 'guard': [[449,165],[925,170],[1394,152],[303,610],[986,673],[1430,663]],
 'death': [[175,324],[663,372],[1142,471],[185,909],[772,900],[1300,885]],
 'recover': [[218,437],[839,375],[1340,337],[357,785],[931,728],[1430,645]],
 'holding': [[300,225],[829,229],[1260,270],[299,737],[824,758],[1260,758]],
 'throw': [[330,248],[833,264],[1346,266],[381,737],[907,797],[1355,766]],
 'launched': [[282,216],[855,177],[1201,358],[190,877],[762,855],[1318,891]],
 'special': [[175,230],[705,54],[1454,155],[494,643],[741,746],[1460,540]],
 'victory': [[252,293],[730,101],[1287,25],[241,513],[785,710],[1251,764]],
}
ANGLES = {
 'idle':[38]*6,'walk':[38]*6,'run':[90]*6,'jump':[40,45,40,70,65,55],
 'light1':[55,55,90,90,90,38],'light2':[225,220,50,40,35,25],
 'light3':[260,270,80,90,100,70],'heavy1':[350,0,115,130,145,110],
 'heavy2':[260,245,70,90,100,80],'slam_charge':[30,3,0,0,0,0],
 'charged_slam':[0,0,0,0,0,0],'charge_forward':[90]*6,'dash':[90]*6,
 'upper':[120,100,40,20,330,30],'low_sweep':[260,250,100,105,115,70],
 'air_light':[70,260,90,125,130,60],'air_heavy':[0,0,140,140,125,130],
 'hurt':[60]*6,'guard':[90,90,55,60,75,90],
 'death':[75,80,85,90,90,90],'recover':[90,80,50,45,60,38],
 'holding':[25]*6,'throw':[25]*6,'launched':[65,70,80,85,90,90],
 'special':[260,320,100,90,260,90],'victory':[0]*6
}
ALIASES = {'down':'death','dead':'death','defeated':'death','recovering':'recover',
 'stunned':'hurt','grabbed':'hurt','pulled':'hurt','frozen':'hurt','thrown':'launched',
 'rising':'upper','upper_heavy':'upper','charged_upper':'upper','ground_slam':'charged_slam',
 'dash_strike':'dash','dash_heavy':'dash','charged':'dash','charge':'charge_forward',
 'charge_slam':'slam_charge','charge_upper':'upper','counter_cut':'light2','grab':'holding'}

def register():
 clips={}
 sources=[]
 for clip,hands in HANDS.items():
  path=BASE/(clip+'.png')
  if not path.exists(): continue
  im=np.array(Image.open(path).convert('RGBA'))
  count,labels,stats,centroids=cv2.connectedComponentsWithStats((im[:,:,3]>100).astype('uint8'),8)
  ids=[i for i in range(1,count) if stats[i,4]>7000]
  assert len(ids)==6,(clip,'expected six distinct drawn bodies',len(ids))
  ids.sort(key=lambda i:(int(centroids[i,1]//(im.shape[0]/2)),centroids[i,0]))
  frames=[]
  for index,i in enumerate(ids):
   # Runtime polygon adds a small transparent gutter around the original alpha outline.
   mask=cv2.dilate((labels==i).astype('uint8'),np.ones((9,9),np.uint8))
   contours,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
   contour=max(contours,key=cv2.contourArea)
   polygon=cv2.approxPolyDP(contour,1.5,True).reshape(-1,2)
   x,y,w,h=cv2.boundingRect(contour)
   opaque=np.argwhere((labels==i)&(np.indices(labels.shape)[0]>=stats[i,1]+stats[i,3]-18))
   # Two planted boots may have unequal pixel area; a median would jump to one boot.
   foot_x=float((opaque[:,1].min()+opaque[:,1].max())*.5)
   if clip=='run': foot_x=float([350,855,1335,380,895,1365][index])
   if clip=='launched' or (clip=='death' and index>=3) or (clip=='recover' and index<=2):
    foot_x=float(stats[i,0]+stats[i,2]*.5)
   foot_y=float(stats[i,1]+stats[i,3])
   hx,hy=hands[index]
   assert x<=hx<x+w and y<=hy<y+h,(clip,index,'hand outside body crop')
   hand=[hx-x,hy-y]
   occluder=[max(0,hand[0]-14),max(0,hand[1]-15),28,30]
   occluder[2]=min(occluder[2],w-occluder[0]);occluder[3]=min(occluder[3],h-occluder[1])
   frames.append({'file':path.name,'rect':[x,y,w,h],'foot':[round(foot_x-x,1),round(foot_y-y,1)],
    'body_height':390,'hand':hand,'weapon_angle':ANGLES.get(clip,[40]*6)[index],
    'weapon_behind':clip in ['holding','throw','launched','death'],
    'weapon_visible':True,'hand_occluders':[] if clip in ['holding','throw'] else [occluder],
    'weapon_grounded':clip=='charged_slam' and index in [3,4],
    'clip_polygon':(polygon-[x,y]).tolist()})
  clips[clip]={'frames':frames}
  sources.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[im.shape[1],im.shape[0]],'alpha_preserved':True})
 aliases={k:v for k,v in ALIASES.items() if v in clips}
 reg={'version':'v22','hero':'tadakatsu','portrait':{'file':'idle.png','rect':[228,24,185,185]},
  'clips':clips,'aliases':aliases,'sources':sources,
  'notes':'Built-in imagegen; all six poses individually drawn. Original RGBA files unchanged. Polygon clipping separates neighboring atlas silhouettes. body_height excludes antlers.'}
 (BASE/'registration.json').write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(f'Tadakatsu v22: {len(clips)} clips, {len(clips)*6} frames, {len(aliases)} aliases registered; original PNG hashes retained.')

if __name__=='__main__': register()
