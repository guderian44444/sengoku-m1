from pathlib import Path
import copy,json,sys,math
from PIL import Image
import build_staff_attacks as base
P=Path(__file__).parent

def tail_weapon(weapon,pivot,angle,projection=1):
 theta=math.radians(angle);co,si=math.cos(theta),math.sin(theta);a,b=co,si;d,e=-si/projection,co/projection;gx,gy=pivot
 return weapon.transform((base.W,base.H),Image.Transform.AFFINE,(a,b,64-a*gx-b*gy,d,e,234-d*gx-e*gy),Image.Resampling.BICUBIC)

def light2():
 c=copy.deepcopy(base.configs['light_2'])
 c[4]['angle']=-10;c[4]['event']='close_elbows_recover_upward'
 c[5]['angle']=-25;c[5]['event']='settle_near_body_guard'
 for f,d in zip(c,[110,100,60,60,70,100,180]):f['duration']=d
 base.configs['light_2_v2']=c;base.transform_weapon=tail_weapon;base.build('light_2_v2')
 p=P/'light_2_v2/metadata.json';m=json.loads(p.read_text());m['action']='light_2';m['revision']='v2-single-right-sweep';m['replaces']='light_2';m['change_reason']='User saw a second swing: previous recovery staff angles returned -45→65→-32 after contact, visibly re-extending toward the enemy. Recovery is now 76→-10→-25→-32, hands close to the body, exactly one contact event.';m['qa']['contact_response']='push_standing';m['total_duration_ms']=680;m['gif_duration_unit_ms']=10
 from PIL import Image
 im=Image.open(P/'light_2_v2/normal.gif');ds=[]
 for i in range(im.n_frames):im.seek(i);ds.append(im.info['duration'])
 m['weapon_main_source_grip']=[64,234];m['weapon_working_length_from_main_px']=203
 for f in m['frames']:
  f['weapon_source_grip']=[64,234]
  if f.get('contact'):
   a=math.radians(f['weapon_angle']);g=f['grip_world'][0];f['contact_point']=[g[0]+203*math.sin(a)*f['weapon_projection'],g[1]-203*math.cos(a)*f['weapon_projection']]
 m['actual_gif_durations_ms']=ds;m['actual_gif_total_ms']=sum(ds);assert len(ds)==7 and sum(ds)==680
 p.write_text(json.dumps(m,indent=2,ensure_ascii=False))
 (P/'light_2_v2/REVISION.md').write_text('Light 2 only: exactly one rightward sweep and one contact. Removed the second forward re-extension during recovery. Seven poses, actual GIF 680 ms; no changes to light 1, light 3, heavy or other actions. Body sources remain the verified v1 sources; weapon recovery angles now close upward into guard.\n')
def light1():
 base.SCALES['light_1_v2/source.png']=.408
 f=base.data_frame;common=copy.deepcopy(base.common)
 c=[dict(common,duration=80),
 f('light_1_v2/source.png',[0,0,426,426],{'left':[70,411],'right':[376,410]},[[154,209],[181,211]],94,75,'tail_grip_windup',anchor='right',root_dx=0,projection=.55,sweep_yaw=-57),
 f('light_1_v2/source.png',[426,0,842,426],{'left':[529,378],'right':[755,411]},[[568,210],[590,211]],93,70,'rear_foot_lift',anchor='right',root_dx=5,projection=.65,sweep_yaw=-49),
 f('light_1_v2/source.png',[842,0,1254,426],{'left':[904,412],'right':[1174,411]},[[1090,186],[1122,190]],97,55,'rear_foot_plant',anchor='right',root_dx=11,projection=.8,sweep_yaw=-37),
 f('light_1_v2/source.png',[0,426,426,824],{'left':[58,812],'right':[373,813]},[[285,551],[324,549]],87,40,'forward_sweep_accelerate',anchor='right',root_dx=14,projection=.92,sweep_yaw=-23),
 f('light_1_v2/source.png',[426,426,842,824],{'left':[475,803],'right':[791,813]},[[774,539],[819,537]],87,40,'single_forward_sweep_contact',anchor='right',root_dx=16,contact=True,sweep_yaw=0),
 f('light_1_v2/source.png',[842,426,1254,824],{'left':[876,814],'right':[1189,814]},[[1197,561]],100,50,'forward_low_followthrough',anchor='right',front_dx=8,root_dx=16,hidden_auxiliary_hand=True,sweep_yaw=12),
 f('light_1_v2/source.png',[0,824,426,1254],{'left':[81,1231],'right':[372,1230]},[[242,939],[272,945]],101,65,'pull_grip_back_to_chest',anchor='right',front_dx=16,root_dx=16,sweep_yaw=12),
 f('light_1_v2/source.png',[426,824,842,1254],{'left':[500,1230],'right':[784,1230]},[[702,1022],[669,1006]],-64,75,'compact_guard_recovery',anchor='right',front_dx=16,root_dx=16),
 dict(common,duration=120,event='settled_guard',front_dx=16,root_dx=16)]
 # Largest-remainder apportionment in centiseconds preserves the intended 670 ms exactly.
 raw=[x['duration'] for x in c];ticks=[int(v//10) for v in raw];remaining=67-sum(ticks)
 order=sorted(range(len(raw)),key=lambda i:(-(raw[i]/10-ticks[i]),i))
 for i in order[:remaining]:ticks[i]+=1
 for x,t in zip(c,ticks):x['duration']=t*10
 base.configs['light_1_v2']=c;base.transform_weapon=tail_weapon;base.build('light_1_v2')
 p=P/'light_1_v2/metadata.json';m=json.loads(p.read_text());m['action']='light_1';m['revision']='v2-tail-grip-forward-sweep-10-frames';m['replaces']='light_1';m['qa']['contact_response']='push_standing';m['requested_changes']='7 to 10 actual pose frames, tail-end two-hand grip, working shaft projects forward on the active swing, actual rear foot shuffle retained.';m['weapon_main_source_grip']=[64,234];m['weapon_working_length_from_main_px']=203;m['gif_quantization']={'unit_ms':10,'method':'largest remainder, stable frame-order tie break','requested_weights_ms':raw,'allocated_ms':[x['duration'] for x in c]}
 for x in m['frames']:
  x['weapon_source_grip']=[64,234];x['body_height_scale_basis']='Common guard at 0.337; all new 1254-square generated poses at one fixed 0.408 scale. No per-frame bbox equalization.'
  x['weapon_sweep_yaw_degrees']=x.get('sweep_yaw');x['weapon_spin_phase']=None
  if x.get('contact'):
   a=math.radians(x['weapon_angle']);g=x['grip_world'][0];x['contact_point']=[g[0]+203*math.sin(a)*x['weapon_projection'],g[1]-203*math.cos(a)*x['weapon_projection']]
 im=Image.open(P/'light_1_v2/normal.gif');ds=[]
 for i in range(im.n_frames):im.seek(i);ds.append(im.info['duration'])
 assert len(ds)==10 and sum(ds)==670 and all(v%10==0 for v in ds)
 m['actual_gif_durations_ms']=ds;m['actual_gif_total_ms']=sum(ds)
 p.write_text(json.dumps(m,indent=2,ensure_ascii=False))
 (P/'light_1_v2/REVISION.md').write_text('Light 1 revision: ten distinct pose frames at exactly 670 ms in the encoded GIF. New body-only poses were generated using imagegen. The active sweep uses the staff-tail pivot (64,234); 203 of 215 px of the weapon lies ahead of the main grip, with both hands measured on the same shaft. The visible hand-to-hand grip separation is retained while the weapon uses documented yaw projection during the preparatory sweep. Actual foot lift/landing and torso/shoulder changes are present. Original 7-frame action and other actions are untouched.\n')

if __name__=='__main__':
 if sys.argv[1]=='light2':light2()
 if sys.argv[1]=='light1':light1()
