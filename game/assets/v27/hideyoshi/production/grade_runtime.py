#!/usr/bin/env python3
"""Deterministic bounded material CIELAB-lightness grading; alpha/geometry exact.
Run after native compilation; rerun compilers before applying again.
"""
from pathlib import Path
import os
import hashlib,json,sys
import numpy as np
from PIL import Image,ImageDraw
B=Path(os.environ.get("HIDEYOSHI_BUILD_ROOT",str(Path(__file__).resolve().parent)));R=B/'package/runtime'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rgb_lab(rgb):
 s=rgb/255.;lin=np.where(s<=.04045,s/12.92,((s+.055)/1.055)**2.4);xyz=lin@np.array([[.4124564,.3575761,.1804375],[.2126729,.7151522,.0721750],[.0193339,.1191920,.9503041]]).T/np.array([.95047,1,1.08883]);d=6/29;f=np.where(xyz>d**3,np.cbrt(xyz),xyz/(3*d*d)+4/29)
 return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],axis=-1)
def lab_rgb(l):
 f=np.stack([(l[...,0]+16)/116+l[...,1]/500,(l[...,0]+16)/116,(l[...,0]+16)/116-l[...,2]/200],axis=-1);d=6/29;xyz=np.where(f>d,f**3,3*d*d*(f-4/29))*[.95047,1,1.08883];lin=xyz@np.linalg.inv(np.array([[.4124564,.3575761,.1804375],[.2126729,.7151522,.0721750],[.0193339,.1191920,.9503041]])).T
 return np.clip(np.rint(np.where(lin<=.0031308,12.92*lin,1.055*np.maximum(lin,0)**(1/2.4)-.055)*255),0,255).astype('uint8')
def hsv(rgb):
 rgb=rgb/255.;mx=rgb.max(-1);mn=rgb.min(-1);df=mx-mn;h=np.zeros(mx.shape);safe=np.maximum(df,1e-9)
 for ch,v in enumerate([((rgb[...,1]-rgb[...,2])/safe)%6,(rgb[...,2]-rgb[...,0])/safe+2,(rgb[...,0]-rgb[...,1])/safe+4]):h=np.where((mx==rgb[...,ch])&(df>0),v,h)
 return h*60,df/np.maximum(mx,1e-9),mx

def smooth(a,b,x):t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def window(x,a,b,c,d):return smooth(a,b,x)*(1-smooth(c,d,x))
def weights(a):
 h,s,v=hsv(a[...,:3]);L=rgb_lab(a[...,:3])[...,0]
 return {'navy':window(h,200,220,260,275)*window(s,.08,.18,.65,.85)*window(L,5,12,45,55),'red':(1-smooth(12,25,np.minimum(h,360-h)))*smooth(.30,.50,s)*window(L,8,15,65,75),'skin':window(h,10,18,38,48)*window(s,.18,.28,.65,.82)*smooth(38,50,L),'gold':window(h,30,38,56,65)*smooth(.35,.55,s)*smooth(20,35,L)}
def apply(a,targets):
 lab=rgb_lab(a[...,:3]);L=lab[...,0];ww=weights(a);eligible=a[...,3]>245;out=lab.copy();profiles={};total=sum(ww.values());ww={k:v/np.maximum(total,1) for k,v in ww.items()}
 for n,w in ww.items():
  mask=(w>.55)&eligible;v=L[mask]
  if len(v)<15:delta=0;median=None
  else:median=float(np.median(v));delta=float(np.clip(targets[n]-median,-8,8))
  # Shadow and specular endpoints remain fixed; preserve local texture gradients.
  taper=smooth(5,20,L)*(1-smooth(80,97,L));out[...,0]+=w*delta*taper
  profiles[n]={'before_p50':median,'delta_L_bounded8':delta,'target_p50':targets[n],'samples':int(mask.sum())}
 rgb=lab_rgb(out);rgb[a[...,3]==0]=a[...,:3][a[...,3]==0];result=np.dstack([rgb,a[...,3]])
 return result,profiles

def main():
 selected=sys.argv[1:];previous=json.loads((R/'profiles/material-grade.json').read_text()) if selected else None
 regp=R/'registration.proposed.json';reg=json.loads(regp.read_text());master=np.array(Image.open(B/'reference/identity.png').convert('RGBA'));lab=rgb_lab(master[...,:3]);ww=weights(master)
 # Master body polygon excludes the painted gray background and steel blade.
 mask=Image.new('L',(512,1024));ImageDraw.Draw(mask).polygon([(240,99),(310,111),(322,218),(411,252),(432,384),(389,531),(457,903),(447,947),(332,951),(240,775),(189,910),(88,930),(120,705),(158,509),(105,391),(139,282),(209,213)],fill=255);inside=np.array(mask)>0
 targets={n:float(np.median(lab[...,0][inside&(w>.55)])) for n,w in ww.items()}
 targets.update({'skin':65.0,'gold':64.0,'red':36.0})
 profiles=previous['clips'] if previous else {};native=B/'qa/native_runtime_backup';native.mkdir(exist_ok=True)
 for n,c in reg['clips'].items():
  if selected and n not in selected:continue
  profiles[n]=[]
  for idx,f in enumerate(c['frames']):
   p=R/f['file'];a=np.array(Image.open(p).convert('RGBA'));out,pr=apply(a,targets);backup=native/f['file'];backup.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(a).save(backup);before=sha(p);Image.fromarray(out).save(p);f['body_sha256']=sha(p);f['color_grade']={'recipe':'profiles/material-grade.json','frame':idx+1,'native_body_sha256':before,'alpha_exact':True}
   hp=R/f['hand_foreground_file'];hand=np.array(Image.open(hp));hand[...,:3]=out[...,:3];hand[hand[...,3]==0,:3]=0;Image.fromarray(hand).save(hp)
   profiles[n].append({'frame':idx+1,'native_sha256':before,'graded_sha256':sha(p),'alpha_sha256':hashlib.sha256(a[...,3].tobytes()).hexdigest(),'alpha_exact':bool(np.array_equal(a[...,3],out[...,3])),'materials':pr})
  sh=c['native_sheet'];atlas=Image.new('RGBA',(sh['cell'][0]*3,sh['cell'][1]*2))
  for f,r in zip(c['frames'],sh['regions']):atlas.alpha_composite(Image.open(R/f['file']),tuple(r['rect'][:2]))
  atlas.save(R/sh['file'])
 if not selected:
  portrait_path=R/'ui/portrait.png';portrait=np.array(Image.open(portrait_path));portrait_out,portrait_profile=apply(portrait,targets);portrait_native_sha=sha(portrait_path);(native/'ui').mkdir(exist_ok=True);Image.fromarray(portrait).save(native/'ui/portrait.png');Image.fromarray(portrait_out).save(portrait_path)
  portrait_evidence={'native_sha256':portrait_native_sha,'graded_sha256':sha(portrait_path),'alpha_exact':bool(np.array_equal(portrait[...,3],portrait_out[...,3])),'materials':portrait_profile}
 else:portrait_evidence=previous['portrait']
 profile={'method':'Bounded ±8 CIELAB L shift with smooth material weights and shadow/highlight taper; no spatial repaint/blur; alpha exact','master':'reference/identity.png','master_sha256':sha(B/'reference/identity.png'),'targets':targets,'cross_style_references':['reference/nobunaga-v25-idle.png','reference/soldier-v19-walk-cycle.png'],'reference_material_medians':{'nobunaga_skin':62.5,'soldier_skin':68.8,'nobunaga_gold':66.0,'soldier_gold':64.1},'target_rationale':'Skin65 between approved identity63.6 and enemy68.8/nobunaga62.5; gold64 near enemy64.1; red36 preserves muted cloth rather than forcing lacquer armor24.9; navy matches approved identity22.3.','script_sha256':sha(__file__),'clips':profiles,'portrait':portrait_evidence};(R/'profiles').mkdir(exist_ok=True);(R/'profiles/material-grade.json').write_text(json.dumps(profile,indent=2)+'\n');regp.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n');print('Graded',sum(len(x) for x in profiles.values()),'frames',targets)
if __name__=='__main__':main()
