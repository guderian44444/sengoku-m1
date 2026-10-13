extends RefCounted

# Entries are kind, starting x, road depth, pace, body scale, work activity.
const LANES := {
	"supply_road":[["woman",330,401,25,1.0,"basket"],["child",385,409,25,.67,"walk"],["elder",980,393,-19,.97,"walk"],["cart_vendor",1420,411,22,1.02,"porter"],["woman",1920,397,0,.94,"basket"],["herb_vendor",2440,413,0,1.0,"vendor"]],
	"riverbank":[["herb_vendor",295,400,0,1.0,"vendor"],["elder",640,412,-22,1.0,"walk"],["woman",965,399,20,.96,"basket"],["child",1015,408,20,.64,"walk"],["cart_vendor",1520,406,26,1.04,"porter"],["produce_vendor",2140,403,0,1.0,"vendor"]],
	"granary":[["cart_vendor",320,413,29,1.04,"porter"],["produce_vendor",720,401,0,1.0,"vendor"],["elder",1010,400,-24,.98,"porter"],["woman",1310,403,0,1.0,"basket"],["cart_vendor",1780,420,-27,1.06,"porter"],["herb_vendor",2250,403,0,1.0,"vendor"],["cart_vendor",2640,413,25,1.03,"porter"]],
	"switchback":[["elder",420,401,19,.97,"walk"],["woman",820,405,23,.96,"basket"],["child",875,414,23,.65,"walk"],["cart_vendor",1440,411,-24,1.04,"porter"],["elder",2050,400,-18,.99,"walk"]],
	"marune_gate":[],
	"supply_court":[["cart_vendor",420,412,24,1.02,"porter"],["elder",840,401,0,.98,"porter"],["herb_vendor",1390,404,0,1.0,"vendor"],["cart_vendor",1950,411,-22,1.04,"porter"],["woman",2480,399,0,.97,"basket"]]
}
const DECOR := {
	"supply_road":["rice_bales","basket","fence","jar"],
	"riverbank":["basket","jar","cart","fence"],
	"granary":["rice_bales","large_crate","cart","basket","jar"],
	"switchback":["stone_lantern","basket","rice_bales"],
	"marune_gate":["barricade","large_crate","lantern","fence"],
	"supply_court":["rice_bales","lantern","cart","large_crate","basket"]
}
const HINTS := {
	"supply_road":"護糧加賞：靠近糧車前進，優先阻止搶糧兵。",
	"riverbank":"盾槍足輕擋正面輕擊；用重擊、繞背或摔技破陣。",
	"granary":"火矢先落紅圈，再燃燒地面；離開火圈後追擊弓兵。",
	"switchback":"山路夾擊：留意後方搶糧兵，別讓遠程兵分散陣形。",
	"marune_gate":"攻寨：重擊破盾，再穿過槍陣追擊火矢兵。",
	"supply_court":"佐久間盛重：長槍蓄勢時先錯開站位，收招時近身。"
}

static func lanes(theme: String) -> Array:
	var result := []
	for row in LANES.get(theme,[]):
		result.append({"kind":row[0],"origin":float(row[1]),"y":float(row[2]),"speed":float(row[3]),"scale":float(row[4]),"activity":row[5]})
	return result
