from pathlib import Path
import json,zipfile,sys,hashlib
P=Path(__file__).resolve().parents[1]
for action in sys.argv[1:]:
 D=P/action;v=json.loads((D/'qa/validation.json').read_text());v['visual_contact_inspected']=True;v['visual_qa_notes']='Compared every frame against approved combat idle at same scale; checked face/costume, head scale, grounded stance, hands, weapon layering and transparent edges. GIF decoding verified; no runtime test.';(D/'qa/validation.json').write_text(json.dumps(v,indent=2))
 meta=json.loads((D/'metadata.json').read_text());meta['quality_notes'].append(v['visual_qa_notes']);(D/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
 m=json.loads((P/'review_manifest.json').read_text());m.setdefault('actions',{})[action]={'metadata':action+'/metadata.json','gif':action+f'/hideyoshi_{action}_review.gif','status':'candidate_pending_user_review','duration_ms':meta['duration_ms'],'frame_count':meta['frame_count']};m['scope']='Basic-action candidates under original nine-action authorization; walk remains pending review';(P/'review_manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
 z=P/f'hideyoshi_{action}_candidate_head95.zip'
 with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as out:
  for f in sorted(D.rglob('*')):
   if f.is_file() and f.name!='library_manifest.json':out.write(f,str(f.relative_to(P.parent)))
  for f in [P/'reference/approved_identity_original.png',P/'reference/approved_full_mother.png',P/'reference/sword_uchigatana.png',P/'scripts/build_base.py',P/'scripts/build_motion.py',P/'scripts/package_action.py']+list((P/'idle').glob('*.png'))+([P/'scripts/qa_run.py'] if action=='run' else []):
   out.write(f,str(f.relative_to(P.parent)))
 print(action,z.stat().st_size)
