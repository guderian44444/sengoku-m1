extends RefCounted
## Scalar keyframes [[normalized_phase, value], ...], linear interpolation.
## Integral is analytical piecewise-linear, so angular speed changes never jump.
static func value(keys: Array, phase: float, fallback: float = 1.0) -> float:
	if keys.is_empty(): return fallback
	if phase <= float(keys[0][0]): return float(keys[0][1])
	for i in range(1,keys.size()):
		if phase <= float(keys[i][0]):
			var width := float(keys[i][0])-float(keys[i-1][0])
			if width <= 0.0: return float(keys[i][1])
			return lerpf(float(keys[i-1][1]),float(keys[i][1]),(phase-float(keys[i-1][0]))/width)
	return float(keys[-1][1])

static func integral(keys: Array, phase: float, fallback: float = 1.0) -> float:
	if phase <= 0: return 0.0
	if keys.is_empty(): return phase*fallback
	var result := 0.0
	var previous := 0.0
	var previous_value := value(keys,0.0,fallback)
	for point: Array in keys:
		var end := minf(phase,float(point[0]))
		if end > previous:
			var end_value := value(keys,end,fallback)
			result += (previous_value+end_value)*.5*(end-previous)
			previous = end
			previous_value = end_value
		if previous >= phase: return result
	if phase > previous: result += (phase-previous)*previous_value
	return result

static func valid(keys: Array) -> bool:
	var previous := -1.0
	for point: Variant in keys:
		if not point is Array or point.size()!=2: return false
		if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int): return false
		if not is_finite(float(point[0])) or not is_finite(float(point[1])): return false
		if float(point[0]) < 0 or float(point[0]) > 1 or float(point[0]) <= previous: return false
		previous = float(point[0])
	return true
