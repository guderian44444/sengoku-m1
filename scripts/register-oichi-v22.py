"""Register native generated sprites without recoloring, resizing or changing alpha."""
from pathlib import Path
import json, hashlib, argparse
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'game/assets/v22/oichi'

def measure(filename, count=6, columns=3):
    image=Image.open(ASSETS/filename).convert('RGBA')
    alpha=np.array(image)[:,:,3]
    labels,total=ndimage.label(alpha>100)
    objects=ndimage.find_objects(labels)
    sizes=np.bincount(labels.ravel())
    parts=[]
    for label in np.argsort(sizes[1:])[::-1][:count]+1:
        ys,xs=objects[label-1]
        parts.append((int(label),(xs.start,ys.start,xs.stop,ys.stop)))
    parts.sort(key=lambda p:(p[1][1]+p[1][3])/2)
    ordered=[]
    for i in range(0,count,columns): ordered.extend(sorted(parts[i:i+columns],key=lambda p:p[1][0]))
    return image,alpha,labels,ordered

# Author-measured full-sheet bow grips (or waist stow points), never image bounds.
POSES = {
 'idle':dict(file='idle-walk-source.png',height=470,back=True,hands=[(153,282),(416,282),(661,282),(910,282),(1164,282),(1410,282)],roots=[163,425,677,925,1179,1427]),
 'walk':dict(height=480,back=True,hands=[(294,291),(763,283),(1254,280),(294,788),(790,789),(1250,790)],roots=[322,798,1269,324,814,1276]),
 'run':dict(height=480,back=True,hands=[(300,278),(787,280),(1270,280),(307,782),(793,783),(1282,783)],roots=[330,816,1290,339,820,1300]),
 'light1':dict(height=480,back=True,hands=[(284,288),(767,283),(1270,279),(300,787),(801,786),(1279,785)],roots=[310,801,1290,330,835,1300]),
 'light2':dict(height=480,back=True,hands=[(280,283),(768,283),(1270,283),(300,783),(784,783),(1290,783)],roots=[305,795,1300,325,809,1315]),
 'light3':dict(height=480,back=True,hands=[(241,272),(773,270),(1272,265),(251,760),(789,760),(1294,772)],roots=[272,798,1297,261,785,1317],angles=[-25,25,25,-65,55,-25]),
 'heavy1':dict(height=480,hands=[(421,181),(972,134),(1474,132),(504,637),(988,645),(1407,776)],seconds=[(179,192),(735,107),(1238,111),None,None,None],angles=[15,0,0,0,0,-20],roots=[298,802,1298,297,803,1306]),
 'heavy2':dict(height=480,hands=[(484,218),(973,134),(1480,90),(490,598),(1000,659),(1428,780)],seconds=[(216,207),(709,136),(1240,103),None,None,None],angles=[5,-5,-15,-15,0,-20],roots=[317,804,1304,319,814,1314]),
 'charged_upper':dict(height=480,hands=[(480,26),(990,74),(1503,33),(478,554),(1001,565),(1474,548)],seconds=[None,(736,117),(1245,111),None,None,None],angles=[-40,-15,-30,-35,-30,-42],roots=[301,805,1305,299,805,1308]),
 'charged_slam':dict(height=480,hands=[(367,211),(956,133),(1475,137),(604,669),(1043,922),(1438,738)],seconds=[(329,205),(716,125),(1192,126),None,None,None],angles=[0,0,0,0,65,0],roots=[261,800,1304,350,878,1309]),
 'air_heavy':dict(height=520,hands=[(493,169),(1009,199),(1495,189),(532,738),(982,808),(1461,812)],seconds=[(246,127),(739,134),None,None,None,None],angles=[5,10,5,25,65,55],roots=[280,790,1297,300,837,1319]),
 'air_light':dict(height=520,back=True,hands=[(285,260),(790,263),(1294,265),(303,761),(809,774),(1300,763)],roots=[290,794,1300,310,818,1310]),
 'rising':dict(height=480,back=True,hands=[(282,293),(767,292),(1277,286),(310,786),(786,801),(1288,801)],roots=[310,795,1300,333,808,1310]),
 'low_sweep':dict(height=500,back=True,hands=[(295,272),(779,315),(1292,320),(306,812),(788,823),(1289,807)],roots=[314,804,1310,330,811,1311]),
 'dash_heavy':dict(height=480,hands=[(490,248),(898,218),(1485,165),(496,688),(877,743),(1455,793)],angles=[90,80,95,105,80,20],roots=[322,817,1318,325,815,1315]),
 'dash_strike':dict(height=480,back=True,hands=[(301,291),(801,290),(1230,257),(327,792),(803,778),(1292,777)],roots=[319,817,1310,349,825,1312]),
 'jump':dict(file='jump-spaced.png',height=540,back=True,hands=[(248,327),(773,277),(1289,276),(278,794),(789,791),(1303,810)],roots=[265,789,1304,301,805,1324]),
 'hurt':dict(height=510,back=True,hands=[(302,277),(785,289),(1287,309),(300,812),(802,806),(1321,798)],roots=[322,805,1322,320,825,1337],angles=[-35,-10,10,15,5,-10]),
 'down':dict(height=500,back=True,hands=[(260,324),(733,383),(1247,465),(273,829),(765,837),(1288,849)],roots=[300,790,1266,263,770,1283],angles=[-40,-55,15,-105,-90,-90]),
 'recovering':dict(height=530,back=True,hands=[(278,351),(772,349),(1268,321),(279,790),(779,752),(1290,727)],roots=[291,784,1290,300,797,1303],angles=[-90,-55,25,15,-10,-25]),
 'launched':dict(height=520,back=True,hands=[(281,303),(731,307),(1247,302),(307,793),(748,775),(1280,802)],roots=[307,780,1290,331,785,1310],angles=[-55,-65,-65,-80,-30,10]),
 'stunned':dict(height=500,back=True,hands=[(290,283),(785,279),(1274,280),(303,790),(786,783),(1289,789)],roots=[308,810,1301,325,815,1310]),
 'guard':dict(height=490,hands=[(485,103),(887,105),(1294,139),(338,650),(857,633),(1407,644)],angles=[55,25,-25,30,15,40],roots=[333,821,1328,323,816,1310]),
 'throw':dict(height=490,back=True,hands=[(291,284),(796,289),(1290,276),(304,786),(800,786),(1313,786)],roots=[317,810,1317,326,820,1330]),
 'special':dict(height=480,hands=[(292,215),(912,48),(1487,156),(515,679),(1014,660),(1490,603)],seconds=[(252,201),None,(1203,138),None,(771,630),None],angles=[0,-45,0,0,0,0],roots=[263,795,1301,342,816,1306]),
 'victory':dict(file='victory-boxed.png',height=480,back=True,hands=[(270,271),(779,271),(1275,271),(271,772),(777,772),(1290,768)],roots=[280,780,1280,280,780,1310],boxed=True)
}
ALIASES={'charge':'heavy1','charged':'heavy2','charge_upper':'charged_upper','charge_slam':'charged_slam','holding':'throw','grab':'throw',
 'dead':'down','defeated':'down','pulled':'hurt','grabbed':'hurt','frozen':'hurt','thrown':'launched',
 'upper_heavy':'charged_upper','ground_slam':'charged_slam','counter_cut':'light2'}

def register(check=False):
    registration={'version':'v22','hero':'oichi','portrait':{'file':'idle-walk-source.png','rect':[131,29,105,105]},'clips':{},'aliases':ALIASES,
        'source_notes':'Original imagegen RGBA preserved. Pure crop metadata and runtime silhouette polygons exclude neighboring figures. Hands and stow points measured in source pixels; standing anatomical rulers independent of pose bounds.'}
    for clip,pose in POSES.items():
        filename=pose.get('file',clip+'.png')
        if not (ASSETS/filename).exists(): continue
        im,alpha,labels,parts=measure(filename,12 if clip=='idle' else 6,6 if clip=='idle' else 3)
        if pose.get('boxed'):
            # Borders are layout guides outside the artwork; crops retain original RGBA.
            labels=np.zeros_like(alpha,dtype=np.int32);parts=[]
            for idx in range(6):
                cx,cy=(idx%3)*512,(idx//3)*512
                mask=(alpha[cy+10:cy+502,cx+10:cx+502]>100).astype('uint8')
                n,ll,stats,_=cv2.connectedComponentsWithStats(mask,8)
                largest=1+int(np.argmax(stats[1:,4])); selected=ll==largest
                local=labels[cy+10:cy+502,cx+10:cx+502];local[selected]=idx+1
                yy,xx=np.where(labels==idx+1)
                parts.append((idx+1,(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))))
        parts=parts[:6]
        assert len(parts)==6,(clip,'six complete figures required')
        frames=[]
        for idx,(label,box) in enumerate(parts):
            x0,y0,x1,y1=box
            assert (labels==label).sum()>7000,(clip,idx,'incomplete connected figure')
            mask=cv2.dilate((labels==label).astype('uint8'),np.ones((5,5),np.uint8))
            contours,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
            contour=max(contours,key=cv2.contourArea)
            polygon=cv2.approxPolyDP(contour,1,True).reshape(-1,2)
            x,y,w,h=cv2.boundingRect(contour)
            hx,hy=pose['hands'][idx]
            assert x<=hx<x+w and y<=hy<y+h,(clip,idx,'grip outside source crop',box,(hx,hy))
            hand=[hx-x,hy-y]
            frame={'file':filename,'rect':[x,y,w,h],'foot':[pose['roots'][idx]-x,y1-y],
                   'body_height':pose['height'],'hand':hand,'weapon_angle':pose.get('angles',[-25 if pose.get('back') else 0]*6)[idx],
                   'weapon_behind':bool(pose.get('back',False)),'weapon_visible':True,'clip_polygon':(polygon-[x,y]).tolist()}
            if not pose.get('back'):
                frame['hand_occluders']=[[max(0,hand[0]-13),max(0,hand[1]-14),26,28]]
                second=pose.get('seconds',[None]*6)[idx]
                if second:
                    frame['second_hand']=[second[0]-x,second[1]-y]
                    frame['hand_occluders'].append([max(0,second[0]-x-12),max(0,second[1]-y-12),24,24])
            frames.append(frame)
        registration['clips'][clip]={'frames':frames,'source_sha256':hashlib.sha256((ASSETS/filename).read_bytes()).hexdigest()}
    registration['aliases']={alias:target for alias,target in ALIASES.items() if target in registration['clips']}
    data=json.dumps(registration,ensure_ascii=False,indent=2)+'\n'
    if check:
        assert data==(ASSETS/'registration.json').read_text(encoding='utf-8'),'Registration/source drift; rebuild and review'
        assert set(registration['clips'])==set(POSES),'Missing authored action'
        for clip,item in registration['clips'].items():
            hashes=[]
            for index,frame in enumerate(item['frames']):
                source=Image.open(ASSETS/frame['file'])
                assert source.mode=='RGBA',(clip,'source must retain RGBA')
                x,y,w,h=frame['rect']
                assert 0<=x<x+w<=source.width and 0<=y<y+h<=source.height,(clip,index,'crop outside source')
                crop=source.crop((x,y,x+w,y+h))
                hashes.append(hashlib.sha256(crop.tobytes()).hexdigest())
                a=np.asarray(source)[:,:,3]
                if POSES[clip].get('boxed'):
                    # Layout guide lines reach the canvas edge, but registered figures must not.
                    assert x>0 and y>0 and x+w<source.width and y+h<source.height,(clip,index,'figure touches source edge')
                else:
                    assert not np.any(a[0,:]>100) and not np.any(a[-1,:]>100) and not np.any(a[:,0]>100) and not np.any(a[:,-1]>100),(clip,'figure touches source edge')
                hx,hy=frame['hand']
                assert a[y+hy,x+hx]>100,(clip,index,'grip not on figure')
            assert len(set(hashes))==6,(clip,'duplicate frame pixels')
    else: (ASSETS/'registration.json').write_text(data,encoding='utf-8')
    print(f"Oichi v22: {len(registration['clips'])} clips / {len(registration['clips'])*6} genuine frames, source RGBA untouched")

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--measure',action='store_true');parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.measure:
        for filename in sorted(ASSETS.glob('*.png')):
            image,alpha,labels,parts=measure(filename.name,12 if filename.name=='idle-walk-source.png' else 6,6 if filename.name=='idle-walk-source.png' else 3)
            print(filename.name,image.size,[box for _,box in parts])
    else: register(args.check)
