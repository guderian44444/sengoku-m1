#!/usr/bin/env python3
"""Add researched 30 designs without changing the approved 18 item records.

The existing game's additive stats are authoritative. Research-only ideas such
as speed, charge windows and durability are not silently advertised as features.
"""
from pathlib import Path
import json
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'game/assets/v24/weapons'
OUT = ROOT / 'game/assets/v22/weapons'
research = json.loads((DATA / 'research-30.json').read_text())
old = json.loads((DATA / 'encyclopedia-18-before.json').read_text())
base_catalog = (DATA / 'catalog-18-before.txt').read_text()
stats = {
 'sword': [(3,5,12,1),(5,9,24,3),(2,4,8,0),(3,6,-8,0),(4,7,2,2),(3,6,3,1),(3,5,-2,1),(4,8,-6,4),(4,7,13,2),(5,10,18,3)],
 'spear': [(5,10,32,3),(4,8,20,2),(2,4,0,1),(1,2,-12,0),(3,6,3,0),(3,6,4,3),(4,7,8,3),(2,3,-18,0),(2,4,-5,1),(1,1,-22,0)],
 'bow': [(1,2,20,0),(2,4,45,1),(4,8,65,2),(5,9,85,1),(2,3,35,0),(2,4,55,0),(3,5,60,2),(4,7,90,0),(5,10,70,3),(3,6,100,1)]
}
roles = {
 'sword': ['均衡長刃','長刃重斬','輕推力長刃','短距高傷','均衡破陣','中距均衡','緊湊刀身','短距強擊退','長距橫掃','高傷長斬'],
 'spear': ['最長延伸刺擊','長刃重刺','中距均衡','近距入門','精準低擊退','側刃強擊退','錯位側刃控制','近距擾敵','中近距均衡','短距基礎'],
 'bow': ['入門單箭','均衡單箭','高傷推力','遠距高傷','輕推力單箭','平穩射程','均衡推力','遠距低擊退','高傷重箭','最遠距均衡']
}

def facts_for(w):
 h = w['history']
 if isinstance(h,list): return h.copy()
 if isinstance(h,str): return [h]
 f = [h['documented']]
 if h.get('traditional'): f.append('傳承／傳說：' + h['traditional'])
 return f

def attribution(w):
 notes = ['可裝備角色是遊戲安排，並非該角色持有館藏原件的證據。']
 h = w['history']
 if isinstance(h,dict): notes += h.get('uncertainties',[])
 d = w.get('physical_dimensions') or {}
 if d.get('measurement_note'): notes.append(d['measurement_note'])
 if w['family'] == 'sword': notes.append('未核實的柄、鐔及裝具為遊戲復原設計。後世刀裝不倒推為戰國原裝。')
 elif w['family'] == 'spear': notes.append('原裝槍柄長未核實；槍穗、茎與含柄總長分開，畫面中木桿與石突為遊戲復原。')
 else:
  notes += ['本項為形制／工藝復原；合弓子結構與卷束分類可以重疊，並非十種互斥弓制或十把傳世名弓。',w.get('physical_dimensions_note','')]
  notes += w.get('morphology',{}).get('unknown',[])
 return '\n'.join(x for x in notes if x)

counts = dict.fromkeys(stats,0)
lines=[]; entries=old.copy(); implemented=[]
for w in research['weapons']:
 family=w['family']; i=counts[family]; counts[family]+=1
 tier,damage,reach,kb=stats[family][i]
 entry={'name':w['name'],'family':family,'tier':tier,'damage_bonus':damage,'reach_bonus':float(reach),'knockback':float(kb),'element':'','history':w['catalog_intro'],'source':w['source_urls'][0]}
 lines.append('\t'+json.dumps(w['id'])+':'+json.dumps(entry,ensure_ascii=False,separators=(',',':'))+',')
 era=w['era']; period=era if isinstance(era,str) else era.get('blade',era.get('label','年代見來源'))
 dimensions={}; d=w.get('physical_dimensions') or {}
 for key,out in [('blade_length','blade_cm'),('blade_length_cm','blade_cm'),('assembled_length','total_cm'),('overall_length_cm','total_cm'),('curvature','curvature_cm'),('catalogue_length_cm','catalogue_length_cm'),('tang_length','tang_cm'),('tang_length_cm','tang_cm'),('base_width','base_width_cm'),('blade_length_lower_bound_cm','blade_lower_bound_cm')]:
  if d.get(key) is not None: dimensions[out]=d[key]
 ref=w.get('reference_image',{}); reference_url=next((ref[k] for k in ['landing_page','page_url','url'] if ref.get(k)),None)
 sources=[{'title':next((n['supports'] for n in w.get('source_notes',[]) if n['url']==url),'館藏／工藝資料 '+str(n+1)),'url':url,'institution':w.get('collection',urlparse(url).netloc)} for n,url in enumerate(w['source_urls'])]
 if reference_url and reference_url not in w['source_urls']: sources.append({'title':'形制照片參考入口（非遊戲美術）','url':reference_url,'institution':urlparse(reference_url).netloc})
 morphology=w['morphology']
 form=w.get('subtype',morphology.get('historical_form','和弓工藝復原') if isinstance(morphology,dict) else '太刀／刀')
 note='定位：'+roles[family][i]+'。此版實際效果為上列傷害、距離與擊退加成；元素為無。數值屬遊戲平衡，不代表史實性能。'
 note+=' 攻速、蓄力窗口、耐久與穿透沒有武器個別加成。'
 note+=' 握點沿用已校色角色動作；武器顯示長度與招式碰撞距離各自設定，PNG尖端不直接充作命中框。'
 if family=='bow': note+=' 弓身按阿市148身高基準採約172世界單位；上長下短，弓弦由握弓／拉弦手動態連接。'
 gaps='照片僅供來源頁研究；未取得可嵌入遊戲的重製授權，不打包或熱連結原照。原創遊戲武器圖不是實物照片。'
 if w['id']=='spear_sasaho_kanesada': gaps+=' 此件同物照片仍缺，依官方文字作型制復原。'
 if w['id']=='sword_magoroku_kanemoto': gaps+=' 本次館方同件圖片端點無法讀取；未宣稱已實看該件照片，刀身依館方文字與美濃刀形制作遊戲改編。'
 if family=='bow': gaps+=' 尚未核定每件近照、內芯與卷束位置；具體外形是明示復原設計。'
 entries[w['id']]={'display_name':w['name'],'historical_type':form,'period':period,'facts':facts_for(w),'dimensions':dimensions,'attribution_note':attribution(w),'game_note':note,'sources':sources,'reference_images':[],'photo_status':gaps,'research_id':w['id'],'implemented_role':roles[family][i]}
 implemented.append({'id':w['id'],**entry,'role':roles[family][i],'not_implemented_from_research':['attack_speed','charge_window','durability','weapon_specific_piercing']})
assert counts=={'sword':10,'spear':10,'bow':10}
assert len(entries)==48
catalog=base_catalog.replace('\n}\n','\n\t# v24: Original artwork and gameplay interpretations; no ownership claim.\n'+'\n'.join(lines)+'\n}\n',1)
(ROOT/'game/core/weapon_catalog.gd').write_text(catalog)
(OUT/'encyclopedia.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
(DATA/'implemented-stats.json').write_text(json.dumps(implemented,ensure_ascii=False,indent=2)+'\n')
print('30 new records; all 18 original definitions and encyclopedia entries retained')
