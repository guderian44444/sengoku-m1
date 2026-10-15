from PIL import Image
from pathlib import Path
import math
WPN=Image.open(Path(__file__).parent/'weapons/ornate_shakujo.png').convert('RGBA')
def weapon_layer(size,grip,angle):
 # Pivot exactly around source main_grip (64,178), no weapon stretch.
 tile=Image.new('RGBA',(600,600));tile.alpha_composite(WPN,(300-64,300-178));tile=tile.rotate(-angle,resample=Image.Resampling.BICUBIC,center=(300,300))
 out=Image.new('RGBA',size);out.alpha_composite(tile,(round(grip[0]-300),round(grip[1]-300)));return out
