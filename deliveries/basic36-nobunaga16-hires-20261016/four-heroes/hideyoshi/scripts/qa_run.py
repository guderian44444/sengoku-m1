from pathlib import Path
from PIL import Image,ImageDraw
import json,sys
from build_base import font
P=Path(__file__).resolve().parents[1];D=P/'run';m=json.loads((D/'metadata.json').read_text());fs=m['frames'];g=Image.open(D/'hideyoshi_run_review.gif');review=[]
for i in range(g.n_frames):g.seek(i);review.append(g.convert('RGB'))
review[0].save(D/'hideyoshi_run_slow_once.gif',save_all=True,append_images=review[1:],duration=[270,270,180,270,270,800],disposal=2,optimize=False)
strip=Image.new('RGB',(420*6,430),(42,48,56));dr=ImageDraw.Draw(strip)
for i,f in enumerate(fs):
 im=Image.open(D/'frames'/f'composite_{i:02}.png').convert('RGBA');crop=im.crop((125,175,365,350)).resize((384,280),Image.Resampling.NEAREST);tile=Image.new('RGBA',(384,280),(42,48,56,255));tile.alpha_composite(crop);strip.paste(tile.convert('RGB'),(i*420+18,80));dr.text((i*420+18,15),f'{i+1}/6  '+f['phase'].replace('_',' '),font=font(13),fill='white');dr.text((i*420+18,390),f'{f["duration_ms"]} ms | support: {f["support"]}',font=font(15),fill='white')
strip.save(D/'qa/run_six_frames_numbered.png')
world=[];dur=[]
for cycle in range(2):
 for i,f in enumerate(fs):
  bg=Image.new('RGBA',(760,380),(42,48,56));d=ImageDraw.Draw(bg);d.text((20,20),'RUN WORLD DEMO: two cycles; root track separate from sprites',font=font(16),fill='white');d.line((15,334,745,334),fill=(100,110,125));
  for gx in range(20,760,40):d.line((gx,334,gx,341),fill=(160,170,185))
  dx,dy=f['root_world'];im=Image.open(D/'frames'/f'composite_{i:02}.png').convert('RGBA');bg.alpha_composite(im,(round(dx+134*cycle-65),round(dy)));d.text((20,355),f'cycle {cycle+1}, frame {i+1}; world root {dx+134*cycle:.1f}px',font=font(14),fill='white');world.append(bg.convert('RGB'));dur.append(f['duration_ms'])
dur[-1]=600;world[0].save(D/'hideyoshi_run_world_once.gif',save_all=True,append_images=world[1:],duration=dur,disposal=2,optimize=False)
m['version']='run_v2_contact_torso_true_passing';m['world_motion']['cycle_displacement_px']=134;m['world_motion']['world_end_delta']=[134,0];m['world_motion']['end_delta_is_boundary_after_last_frame']=True;m['world_motion']['support_intervals']=[[0,1,'far'],[3,4,'near']];m['world_motion']['speed_average_px_s']=round(134/.48,3);m['preview_files']={'normal':'hideyoshi_run_review.gif','slow_once':'hideyoshi_run_slow_once.gif','world_two_cycles_once':'hideyoshi_run_world_once.gif','slow_preview_duration_ms':2060};m['loop_semantics']='One cycle consists of exactly one far step and one near step. Runtime repeats cycle; slow QA plays a single cycle only.';m['gait_qa']={'low_knee':True,'rejected_high_knee_sources':'../run_rejected_high_knee','actual_phases':'One contact, narrow under-hip passing, short flight in each half-cycle. Passing upper body uses native contact artwork at identical anatomical game scale. Independent parent strip review allows candidate motion review; user approval still pending.','independent_review_pending':False,'parent_strip_review':'2026-10-15: allowed to submit normal motion candidate; not user approval'}
errors=[]
for a,b,foot in [(0,1,'far'),(3,4,'near')]:errors.append(max(abs(fs[a]['feet_world'][foot][j]-fs[b]['feet_world'][foot][j]) for j in (0,1)))
m['gait_qa']['planted_foot_anchor_error_px']=errors
(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));print('anchors',errors)
