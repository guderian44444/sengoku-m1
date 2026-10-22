extends RefCounted

# Legacy fighter timer retained for snapshot compatibility; achievements no longer drop equipment.
const REWARD_COOLDOWN := 1200
const RULES := [
	["cleave3","一刀三斬","單次攻擊命中 3 人","strike_hits",3],
	["cleave5","橫掃千軍","單次攻擊命中 5 人","strike_hits",5],
	["cleave8","八方破陣","單次攻擊命中 8 人","strike_hits",8],
	["kill2","一擊雙討","單次攻擊擊殺 2 人","strike_kills",2],
	["kill3","三人討取","單次攻擊擊殺 3 人","strike_kills",3],
	["kill5","五將同斬","單次攻擊擊殺 5 人","strike_kills",5],
	["kill8","修羅一閃","單次攻擊擊殺 8 人","strike_kills",8],
	["chain10","十連破","3 秒內銜接 10 次命中","chain",10],
	["chain20","連擊名手","3 秒內銜接 20 次命中","chain",20],
	["chain40","勢不可擋","3 秒內銜接 40 次命中","chain",40],
	["kills10","初陣之勇","一場出陣擊殺 10 人","kills",10],
	["kills30","戰場先鋒","一場出陣擊殺 30 人","kills",30],
	["kills60","六十人斬","一場出陣擊殺 60 人","kills",60],
	["kills100","百人斬","一場出陣擊殺 100 人","kills",100],
	["boss1","敵將討取","一場出陣擊敗 1 名敵將","bosses",1],
	["boss3","名將獵手","一場出陣擊敗 3 名敵將","bosses",3],
	["major1","大將首級","擊敗大將","majors",1],
	["heavy5","重手壓陣","一場出陣重擊擊殺 5 人","heavy_kills",5],
	["charge5","蓄勢必殺","一場出陣蓄力擊殺 5 人","charged_kills",5],
	["air5","飛燕討取","一場出陣空中攻擊擊殺 5 人","air_kills",5],
	["throw5","摔投豪傑","一場出陣投摔擊殺 5 人","throw_kills",5],
	["special10","無雙亂舞","一場出陣必殺擊殺 10 人","special_kills",10],
	["fire10","烈焰武者","一場出陣火焰命中 10 次","fire_hits",10],
	["ice10","冰華武者","一場出陣冰系命中 10 次","ice_hits",10],
	["shatter3","碎冰之刃","一場出陣碎冰 3 次","shatters",3],
	["guard5","銅牆鐵壁","一場出陣成功防禦 5 次","guards",5],
	["guard15","不動如山","一場出陣成功防禦 15 次","guards",15],
	["props5","破障先鋒","一場出陣破壞 5 件物品","props",5],
	["clutch3","背水之陣","生命低於 25% 時擊殺 3 人","clutch_kills",3],
	["flawless10","毫髮無傷","未損失生命連續擊殺 10 人","flawless_kills",10],
]

static func valid(ids: Variant) -> bool:
	if not ids is Array or ids.size() > RULES.size(): return false
	var known: Array = RULES.map(func(rule): return rule[0])
	var seen := {}
	for id in ids:
		if not id is String or id not in known or seen.has(id): return false
		seen[id] = true
	return true

static func increment(stats: Dictionary, key: String, amount: int = 1) -> void:
	stats[key] = mini(1000000,int(stats.get(key,0)) + amount)

static func damage(player: Dictionary, target: Dictionary, tick: int, action: String, attack: int, element: String, killed: bool) -> void:
	var stats: Dictionary = player.get("performance",{})
	if int(stats.get("attack",-1)) != attack:
		stats.attack = attack
		stats.strike_hits = 0
		stats.strike_kills = 0
		stats.hit_ids = []
	if target.id not in stats.hit_ids:
		stats.hit_ids.append(target.id)
		increment(stats,"strike_hits")
		if killed: increment(stats,"strike_kills")
	if tick - int(stats.get("last_hit",-1000)) > 180: stats.chain = 0
	stats.last_hit = tick
	increment(stats,"chain")
	if element in ["fire","ice"]: increment(stats,element + "_hits")
	if killed:
		increment(stats,"kills")
		increment(stats,"flawless_kills")
		if player.hp < player.max_hp * 0.25: increment(stats,"clutch_kills")
		if target.kind == "boss": increment(stats,"majors" if target.get("stage_boss",false) else "bosses")
		if action in ["heavy","dash_heavy","upper_heavy","ground_slam"]: increment(stats,"heavy_kills")
		if action in ["charged","charge_rain","charged_upper","charged_slam"]: increment(stats,"charged_kills")
		if action in ["air_light","air_heavy"]: increment(stats,"air_kills")
		if action in ["throw","thrown"]: increment(stats,"throw_kills")
		if action == "special": increment(stats,"special_kills")
	player.performance = stats

static func earned(player: Dictionary) -> Array:
	var stats: Dictionary = player.get("performance",{})
	var awards: Array = player.get("performance_awards",[])
	var result: Array = []
	for rule in RULES:
		if rule[0] in awards or int(stats.get(rule[3],0)) < int(rule[4]): continue
		awards.append(rule[0])
		if rule[0] not in player.achievements: player.achievements.append(rule[0])
		result.append(rule)
	player.performance_awards = awards
	return result
