"""Register the render-agent faction subset from full, separated source components."""
import json,statistics
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
measure={x['id']:x['measure'] for x in json.loads((ROOT/'assets/animation-v0.10/measurements.json').read_text(encoding='utf-8'))}
BODY={'asakura':{'a':[193,190],'b':[174,195,174]},'takeda':{'a':[190,182],'b':[188,190,176]},'ikko':{'b':[203,181,171]},'akechi':{'a':[174,160],'b':[178,193,203]},'hashiba':{'a':[199,177],'b':[217,215,204]}}
HANDS={'asakura':[[632,1214],[839,1264],[656,1640],[862,1651]],'hashiba':[[593,1214],[840,1244],[660,1602],[864,1678]],'akechi':[[638,1290],[810,1321],[679,1634],[878,1647]],'ikko':[[651,1245],[847,1248],[659,1637],[865,1669]],'takeda':[[635,1259],[821,1290],[660,1628],[864,1732]]}

def runs(a):
    x=np.flatnonzero(a)
    return np.split(x,np.where(np.diff(x)>1)[0]+1) if len(x) else []

actors={}
for faction,boards in BODY.items():
 for board,heights in boards.items():
    key=f'faction-{faction}-troops-{board}'
    m=measure[key];boxes=[c['bounds'] for c in m['components']]
    ordered=sorted(boxes,key=lambda b:b[1]+b[3])
    partial_ikko = faction=='ikko' and board=='b'
    partial_akechi = faction=='akechi' and board=='b'
    if partial_ikko: ordered=ordered[-16:]
    elif partial_akechi: ordered=ordered[:24]
    elif len(boxes)!=32:
        print('PENDING full separation',key,len(boxes));continue
    count=len(ordered);rows=count//4
    ordered=[b for row in range(rows) for b in sorted(ordered[row*4:row*4+4],key=lambda b:b[0])]
    image=np.array(Image.open(ROOT/'game/assets/v10'/f'{key}.png').getchannel('A'))>90
    groups={f'soldier-{faction}':list(range(16)),f'flag-{faction}':list(range(16,32))} if board=='a' else {f'commander-{faction}':list(range(16)),f'archer-{faction}':list(range(16,24)),f'gunner-{faction}':list(range(24,32))}
    walk=list(range(4))+list(range(16,20))+(list(range(24,28)) if board=='b' else [])
    body_heights=[heights[0]]*16+[heights[1]]*(16 if board=='a' else 8)+([heights[2]]*8 if board=='b' else [])
    if partial_ikko:
        groups={f'archer-{faction}':list(range(8)),f'gunner-{faction}':list(range(8,16))}
        walk=list(range(4))+list(range(8,12));body_heights=[heights[1]]*8+[heights[2]]*8
    elif partial_akechi:
        groups={f'commander-{faction}':list(range(16)),f'archer-{faction}':list(range(16,24))}
        walk=list(range(4))+list(range(16,20));body_heights=[heights[0]]*16+[heights[1]]*8
    spec={'target':'enemy','columns':4,'rows':rows,'body_height':heights[0],'body_heights':body_heights,'feet_global':True,'feet':[],'regions':{},'component_clip':True,'support_offset':.36,'unplanted':walk,'groups':groups,'registration_status':'Full separate alpha components; measured support soles and per-role standing body height; original PNG preserved.'}
    for cell,(x,y,w,h) in enumerate(ordered):
        endx,endy=min(m['width'],x+w+2),min(m['height'],y+h+2)
        x,y=max(0,x-2),max(0,y-2);w,h=endx-x,endy-y
        spec['regions'][str(cell)]=[x,y,w,h]
        crop=image[y:y+h,x:x+w];ys,xs=np.nonzero(crop)
        fy=int(ys.max());foot=None;options=[]
        for yy in range(fy,max(-1,fy-42),-1):
            solid=crop[max(0,yy-4):yy+1].sum(axis=0)>=4
            candidates=[r for r in runs(solid) if len(r)>=8 and np.median(r)<w*.73]
            for candidate in candidates: options.append((candidate,yy))
        if options:
            lowest=max(o[1] for o in options)
            foot,fy=min([o for o in options if o[1]>=lowest-6],key=lambda o:(int(o[0][0]),-o[1]))
        fx=float(np.median(foot)) if foot is not None else float(xs.mean())
        if cell in walk:
            # Keep the moving body centered while its source soles alternate naturally.
            body=crop[max(0,fy-int(body_heights[cell]*.9)):max(1,fy-int(body_heights[cell]*.25))]
            _,bx=np.nonzero(body)
            if len(bx):fx=float(np.median(bx))
        spec['feet'].append([round(x+fx,2),int(y+fy)])
    if board=='b':
        hand_cells=[6,7,14,15] if partial_ikko else ([22,23] if partial_akechi else [22,23,30,31])
        spec.update(hands_global=True,hands={str(i):p for i,p in zip(hand_cells,HANDS[faction])})
    if board=='a':
        fixed={
          'asakura':{22:[452,1344],26:[445,1516],30:[427,1766]},
          'takeda':{22:[444,1351],26:[441,1547],30:[451,1760]},
          'akechi':{22:[449,1375],26:[416.5,1547],30:[412,1757]},
          'hashiba':{22:[422,1410],26:[441,1544],30:[446,1766]}
        }.get(faction,{})
        for cell,point in fixed.items():spec['feet'][cell]=point
    actors[key]=spec
    print('REGISTERED',key,len(ordered))
result={'version':'0.10','actors':actors}
for p in [ROOT/'game/assets/v10/troop-registration-extra.json',ROOT/'assets/animation-v0.10/troop-registration-extra.json']:
 p.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
