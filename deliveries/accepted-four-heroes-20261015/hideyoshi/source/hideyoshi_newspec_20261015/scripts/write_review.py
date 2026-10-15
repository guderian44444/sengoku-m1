from pathlib import Path
import json
P=Path(__file__).resolve().parents[1];m=json.loads((P/'review_manifest.json').read_text())
order=['light_1','light_2','light_3','heavy','charge_ready','charge_hold','charge_release','air_light','air_heavy','grab_start','grab_hold','grab_hit_1','grab_hit_2','throw_forward','throw_reverse','dash_heavy']
m['actions'].sort(key=lambda x:order.index(x['id']))
(P/'review_manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
s=['# 秀吉招式素材審閱','角色：原版頭95%，雙手持刀，腰前金葫蘆扇收納。','招式格數與時長以人物本體為準；有獨立特效尾段的 GIF 會延長待機顯示，並於各招註明。循環接回起始姿勢的位移不等同遊戲角色瞬移。']
for a in m['actions']:
 g=Path(a['gif']).relative_to(P.name);r=Path(a['representative']).relative_to(P.name)
 s += ['',f"## {a['id']}",f"{a['frame_count']} 格 / {a['duration_ms']} ms",a['description'],f"![代表圖]({r.as_posix()})",f"[遊戲速度動畫]({g.as_posix()})",f"版本：{a.get('revision','')}；狀態：{a.get('status','candidate')}"]
 if a.get('preview_duration_ms',a['duration_ms']) != a['duration_ms']:s += [f"預覽：{a['preview_frame_count']}格 / {a['preview_duration_ms']}ms；人物動作仍{a['frame_count']}格 / {a['duration_ms']}ms，額外時間僅顯示獨立FX尾段。"]
(P/'MOVE_REVIEW.md').write_text('\n\n'.join(s))
