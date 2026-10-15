from pathlib import Path
from PIL import Image
import copy,json,math,numpy as np
import build_staff_attacks as base
P=Path(__file__).parent
# Normal two-hand grip -> deliberate shaft slide near maximum reach -> normal guard.
PIVOTS=[178,184,202,234,218,194,178]
DURATIONS=[110,100,60,60,70,100,180]

def build():
 c=copy.deepcopy(base.configs['light_2'])
 c[4]['angle']=-10;c[4]['event']='close_elbows_slide_back_upward'
 c[5]['angle']=-25;c[5]['event']='restore_normal_near_body_grip'
 for f,t,g in zip(c,DURATIONS,PIVOTS):f['duration']=t;f['weapon_grip_source_y']=g
 c[0]['event']='normal_two_hand_guard';c[1]['event']='normal_grip_windup_rear_foot_lift';c[2]['event']='swing_and_slide_grip';c[3]['event']='tail_grip_single_contact';c[-1]['event']='normal_two_hand_guard_settled'
 it=iter(PIVOTS)
 def sliding_weapon(weapon,pivot,angle,projection=1):
  source_y=next(it);theta=math.radians(angle);co,si=math.cos(theta),math.sin(theta);a,b=co,si;d,e=-si/projection,co/projection;gx,gy=pivot
  return weapon.transform((base.W,base.H),Image.Transform.AFFINE,(a,b,64-a*gx-b*gy,d,e,source_y-d*gx-e*gy),Image.Resampling.BICUBIC)
 base.transform_weapon=sliding_weapon;base.configs['light_2_v3']=c;base.build('light_2_v3')
 out=P/'light_2_v3';m=json.loads((out/'metadata.json').read_text());m['action']='light_2';m['revision']='v3-normal-to-tail-sliding-grip';m['replaces']='light_2_v2';m['qa']['contact_response']='push_standing';m['change_reason']='User requested normal separated two-hand grip at the start; slide toward tail only near maximum outgoing reach; return to normal guard. No second rightward strike.';m['weapon_grip_track_source_y']=PIVOTS;m['grip_track_interpolation']='Linear in shaft-local source y during each intervening keyframe interval; both actual hand centers remain constrained to the same shaft. Main grasp transitions 178→184→202→234→218→194→178; do not teleport the grip.'
 qa=[]
 for f,g in zip(m['frames'],PIVOTS):
  f['weapon_source_grip']=[64,g];f['weapon_working_length_from_main_px']=g-31;f['grip_role']='near_tail' if g>=230 else 'sliding' if g>184 else 'normal'
  gs=f['grip_world'];aux=g-math.dist(*gs)/f['weapon_projection'] if len(gs)==2 else None;f['auxiliary_grip_source']=[64,aux] if aux is not None else None
  if f.get('contact'):
   a=math.radians(f['weapon_angle']);p=gs[0];f['contact_point']=[p[0]+(g-31)*math.sin(a)*f['weapon_projection'],p[1]-(g-31)*math.cos(a)*f['weapon_projection']]
  w=np.array(Image.open(out/f'weapon_{f["frame"]:02}.png'))[:,:,3]
  on=[bool(w[max(0,round(y)-2):round(y)+3,max(0,round(x)-2):round(x)+3].max()>24) for x,y in gs]
  qa.append({'frame':f['frame'],'main_source_grip_y':g,'aux_source_grip_y':aux,'visible_hands_touch_shaft':on,'weapon_clear_of_canvas_border':not np.any(np.r_[w[0],w[-1],w[:,0],w[:,-1]]>24)})
 im=Image.open(out/'normal.gif');ds=[]
 for i in range(im.n_frames):im.seek(i);ds.append(im.info['duration'])
 assert im.n_frames==7 and ds==DURATIONS and sum(ds)==680
 assert sum(bool(f.get('contact')) for f in m['frames'])==1
 assert all(all(q['visible_hands_touch_shaft']) and q['weapon_clear_of_canvas_border'] for q in qa)
 m['actual_gif_durations_ms']=ds;m['actual_gif_total_ms']=sum(ds);m['gif_duration_unit_ms']=10
 (out/'metadata.json').write_text(json.dumps(m,indent=2,ensure_ascii=False))
 (out/'QA.json').write_text(json.dumps({'actual_gif_frames':7,'actual_gif_total_ms':680,'actual_frame_durations_ms':ds,'contact_events':1,'start_and_end_grip_y':178,'maximum_reach_grip_y':234,'frames':qa,'other_actions_modified':False},indent=2))
 (out/'REVISION.md').write_text('Light 2 v3: starts with normal two-hand holding at shaft-local y178, progressively slides y184→202, reaches tail y234 only at maximum striking reach, then returns y218→194→178 to normal guard. All visible hands stay on the measured shaft axis. Same seven body poses, exactly one rightward contact and encoded 680 ms. Light 1 and all other action files are unchanged.\n')
 print('verified: 7 GIF frames, 680 ms, one contact, every visible hand on shaft')
if __name__=='__main__':build()
