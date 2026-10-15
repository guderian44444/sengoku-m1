from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np
from scipy.ndimage import label,find_objects,binary_dilation
R=Path(__file__).parent
for n in ['grab_start_rgba','knee','throw_forward','throw_reverse','victim']:
 im=Image.open(R/'sources'/f'{n}.png').convert('RGBA');a=np.array(im);lab,num=label(a[:,:,3]>30);items=[]
 for i,s in enumerate(find_objects(lab)):
  if s and (lab[s]==i+1).sum()>5000:
   b=[s[1].start,s[0].start,s[1].stop,s[0].stop];items.append((b,i+1))
 items.sort(key=lambda q:(q[0][1]//512,q[0][0]));print(n,[b for b,i in items])
