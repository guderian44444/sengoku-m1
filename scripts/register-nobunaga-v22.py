"""Register original generated six-frame sprites; crop metadata only, no paint/alpha edits."""
import json, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import ConvexHull

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'game/assets/v22/nobunaga'
# Coordinates measured on the full original sheet. Angles: vertical up=0, right=90.
POSES={
 'idle': {'height':445,'hands':[(258,80),(770,80),(1280,80),(262,592),(773,592),(1285,592)], 'angles':[0]*6,'roots':[295,807,1319,295,807,1319]},
 'walk': {'height':435,'hands':[(260,87),(747,82),(1259,87),(250,592),(750,592),(1259,592)], 'angles':[0]*6,'roots':[290,780,1275,290,780,1275], 'boxed':True},
 'run': {'height':405,'hands':[(304,127),(795,125),(1370,128),(308,634),(798,635),(1377,633)], 'angles':[0]*6,'roots':[290,789,1350,290,789,1350]},
 'light1': {'height':438,'hands':[(289,139),(742,47),(1442,270),(329,780),(778,800),(1322,602)], 'angles':[0,-35,55,125,205,0],'roots':[280,788,1318,280,788,1318]},
 'light2': {'height':438,'hands':[(243,349),(751,277),(1444,151),(321,600),(820,540),(1330,610)], 'angles':[205,145,70,15,-35,0],'roots':[280,788,1318,310,820,1340]},
 'light3': {'height':438,'hands':[(225,286),(831,270),(1419,214),(473,655),(992,671),(1284,600)], 'angles':[-95,-50,35,90,125,0],'roots':[280,788,1318,280,788,1318]},
 'heavy1': {'height':440,'hands':[(252,151),(724,29),(1333,352),(415,870),(867,903),(1333,780)],'angles':[0,-30,90,150,175,120],'roots':[280,780,1310,300,820,1310]},
 'heavy2': {'height':440,'hands':[(234,287),(714,130),(1447,244),(535,643),(730,640),(1292,593)],'angles':[-95,-145,25,90,170,0],'roots':[280,785,1318,300,820,1320],'behind':[False,True,False,False,True,False]},
 'dash_strike': {'height':445,'hands':[(319,327),(837,312),(1458,277),(531,702),(953,807),(1302,631)],'angles':[45,65,85,90,120,0],'roots':[300,825,1320,320,825,1320]},
 'rising': {'height':440,'hands':[(316,367),(813,345),(1350,152),(343,521),(854,542),(1370,560)],'angles':[205,160,75,0,-25,0],'roots':[290,788,1315,320,835,1360]},
 'low_sweep': {'height':440,'hands':[(264,319),(671,384),(1444,408),(529,853),(1028,756),(1320,601)],'angles':[-70,-100,75,105,165,0],'roots':[280,795,1320,310,825,1320],'behind':[False,False,False,False,True,False]},
 'charged_upper': {'height':440,'hands':[(239,304),(727,275),(1354,394),(442,562),(779,503),(1322,558)],'angles':[200,225,200,60,0,0],'roots':[280,790,1315,285,790,1315]},
 'charged_slam': {'height':440,'hands':[(290,166),(727,60),(1266,29),(393,925),(866,918),(1320,763)],'angles':[0,-20,0,175,180,120],'roots':[290,790,1315,310,810,1315]},
 'air_light': {'height':440,'hands':[(300,100),(777,63),(1445,221),(259,750),(843,754),(1337,571)],'angles':[0,-30,75,180,130,0],'roots':[300,790,1320,300,815,1330]},
 'air_heavy': {'height':440,'hands':[(372,62),(833,37),(1355,67),(418,840),(806,827),(1378,905)],'angles':[-20,-10,0,130,175,180],'roots':[320,815,1320,310,810,1320]},
 'special': {'height':440,'hands':[(276,148),(758,41),(1265,164),(502,699),(805,816),(1300,600)],'angles':[0,-20,-145,90,140,0],'roots':[280,790,1320,300,825,1320],'behind':[False,False,True,False,False,False]},
 'jump': {'height':410,'hands':[(335,205),(820,111),(1312,73),(314,585),(830,593),(1352,709)],'angles':[0]*6,'roots':[305,790,1305,305,815,1330]},
 'guard': {'height':440,'hands':[(290,133),(887,181),(1442,170),(340,600),(931,670),(1308,611)],'angles':[0,-25,-35,-45,-30,0],'roots':[280,790,1320,300,810,1320]},
 'throw': {'height':440,'hands':[(220,274),(714,265),(1236,295),(216,730),(730,766),(1294,530)],'angles':[175,175,160,180,185,0],'roots':[280,790,1320,300,820,1340]},
 'victory': {'height':[415,395,395,395,395,395],'hands':[(233,107),(742,43),(1253,28),(226,523),(741,532),(1241,533)],'angles':[0]*6,'roots':[290,795,1310,300,810,1320]},
 'hurt': {'height':445,'hands':[(196,300),(716,302),(1210,335),(194,775),(730,808),(1427,666)],'angles':[125,125,125,225,125,0],'roots':[310,820,1310,305,815,1315]},
 'stunned': {'height':445,'hands':[(200,280),(692,282),(1193,295),(154,783),(699,782),(1212,779)],'angles':[140,140,135,225,140,140],'roots':[290,800,1310,285,805,1310]},
 'down': {'height':445,'hands':[(209,371),(659,414),(1228,462),(258,852),(761,870),(1286,869)],'angles':[125,105,90,270,270,270],'roots':[280,755,1270,270,780,1290]},
 'recovering': {'height':445,'hands':[(267,279),(834,333),(1280,295),(268,799),(800,619),(1284,556)],'angles':[270,130,155,180,0,0],'roots':[285,800,1305,280,810,1325]},
 'launched': {'height':445,'hands':[(153,308),(692,325),(1158,357),(289,776),(682,765),(1266,872)],'angles':[170,140,130,60,270,270],'roots':[280,795,1320,285,800,1320]},
}

def cut_at(proj,lo,hi):
    values=proj[lo:hi]
    best=np.where(values==values.min())[0]+lo
    return int(best[len(best)//2]),int(values.min())

def build():
    data={'version':'v22','hero':'nobunaga','angle_convention':'tip up 0 degrees, clockwise positive, source facing right','clips':{},'aliases':{'dash_heavy':'light3'},'portrait':{'file':'idle.png','rect':[255,26,110,110]},'source_notes':'Built-in imagegen originals. Source pixels and alpha preserved. Crop-local hand/foot/occluder coordinates. Height is upright anatomical ruler, not crouched bounding box.'}
    for name,p in POSES.items():
        path=BASE/(name+'.png')
        if not path.exists():continue
        im=Image.open(path).convert('RGBA'); a=np.asarray(im)[:,:,3]; h,w=a.shape
        labels, count=ndimage.label(a>32)
        sizes=np.bincount(labels.ravel())
        large_ids=sorted(np.argsort(sizes[1:])[-6:]+1,key=lambda i:ndimage.center_of_mass(a,labels,int(i))[0])
        ordered=[]
        for group in [large_ids[:3],large_ids[3:]]:
            ordered.extend(sorted(group,key=lambda i:ndimage.center_of_mass(a,labels,int(i))[1]))
        regions=ndimage.find_objects(labels)
        ycut,ycost=cut_at((a>32).sum(1),int(h*.46),int(h*.55))
        ys=[0,ycut,h]
        frames=[]
        for row in range(2):
            y0,y1=ys[row:row+2]
            proj=(a[y0:y1]>32).sum(0)
            c1,n1=cut_at(proj,int(w*.28),int(w*.40)); c2,n2=cut_at(proj,int(w*.61),int(w*.74))
            xs=[0,c1,c2,w]
            for col in range(3):
                idx=row*3+col
                if p.get('boxed'):
                    x0=col*512+10; x1=(col+1)*512-8; fy0=row*512+10;fy1=(row+1)*512-8
                else:
                    region=regions[int(ordered[idx])-1]
                    fy0=max(0,region[0].start-4);fy1=min(h,region[0].stop+4)
                    x0=max(0,region[1].start-4);x1=min(w,region[1].stop+4)
                mask=a[fy0:fy1,x0:x1]>32
                py,px=np.where(mask)
                # Cut actual sprite bounds with two clear pixels, then runtime adds independent padding.
                left=max(x0,x0+int(px.min())-2);right=min(x1,x0+int(px.max())+3)
                top=max(fy0,fy0+int(py.min())-2);bottom=min(fy1,fy0+int(py.max())+3)
                hx,hy=p['hands'][idx]; hand=[hx-left,hy-top]
                foot=[p['roots'][idx]-left,bottom-top-2]
                behind=p.get('behind',[False]*6)[idx]
                height=p['height'][idx] if isinstance(p['height'],list) else p['height']
                frame={'file':name+'.png','rect':[left,top,right-left,bottom-top],'foot':foot,'body_height':height,'hand':hand,'weapon_angle':p['angles'][idx],'weapon_behind':behind,'weapon_visible':True,'hand_occluder':[hand[0]-19,hand[1]-22,38,44]}
                if not p.get('boxed'):
                    local_labels=labels[top:bottom,left:right]
                    foreign=np.isin(local_labels,[v for v in ordered if v!=ordered[idx]])
                    if np.count_nonzero(foreign)>8:
                        mask=(local_labels==ordered[idx]);boundary=mask & ~ndimage.binary_erosion(mask)
                        by,bx=np.where(boundary);points=np.column_stack((bx,by));hull=points[ConvexHull(points).vertices].astype(float)
                        center=hull.mean(0);delta=hull-center;norm=np.linalg.norm(delta,axis=1)[:,None]
                        hull+=delta/np.maximum(norm,1)*3
                        frame['clip_polygon']=np.round(hull,2).tolist()
                frames.append(frame)
        data['clips'][name]={'frames':frames,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (BASE/'registration.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"Registered {len(data['clips'])} clips, {sum(len(c['frames']) for c in data['clips'].values())} frames")
if __name__=='__main__':build()
