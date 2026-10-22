extends RefCounted

const STAGES := [7,8,9,10]
const SOLDIERS := ["spear","archer","gunner","shield","raider"]
const BOSSES := {
	"ujie":{"name":"氏家直元（卜全）","stage":7,"hp":660,"variant":"cross_spear","line":"槍先を見切れるか。来い！","actions":["s07_ujie_cross","s07_ujie_hook","s07_ujie_lunge"]},
	"inaba":{"name":"稻葉良通（一鐵）","stage":7,"hp":1140,"variant":"nodachi","line":"美濃の道、力で示してみよ！","actions":["s07_inaba_low","s07_inaba_split","s07_inaba_counter"]},
	"nagai":{"name":"長井道利","stage":8,"hp":720,"variant":"matchlock","line":"城門を渡すものか。撃て！","actions":["s08_nagai_burst","s08_nagai_draw","s08_nagai_powder"]},
	"tatsuoki":{"name":"齋藤龍興","stage":8,"hp":1260,"variant":"fan_sword","line":"稲葉山は斎藤の城だ！","actions":["s08_tatsuoki_draw","s08_tatsuoki_rain","s08_tatsuoki_counter"]},
	"nagayasu":{"name":"三好長逸","stage":9,"hp":760,"variant":"fan_sword","line":"街道を閉じよ。退路はない！","actions":["s09_nagayasu_cross","s09_nagayasu_fire","s09_nagayasu_flank"]},
	"iwanari":{"name":"岩成友通","stage":9,"hp":1320,"variant":"naginata","line":"勝龍寺への道、ここで止める！","actions":["s09_iwanari_hook","s09_iwanari_triple","s09_iwanari_volley"]},
	"kagetsune":{"name":"朝倉景恒","stage":10,"hp":820,"variant":"long_yari","line":"退く者を追え。陣を崩すな！","actions":["s10_kagetsune_charge","s10_kagetsune_turn","s10_kagetsune_brace"]},
	"yoshikage":{"name":"朝倉義景","stage":10,"hp":1440,"variant":"nodachi","line":"越前の兵よ、退路を断て！","actions":["s10_yoshikage_triple","s10_yoshikage_rain","s10_yoshikage_guard"]}
}
# Durations include the recovery window. The target lane is locked at the start of a move.
const ACTIONS := {
	"s07_ujie_cross":{"art_clip":"attack_a","pose":"boss_double","hits":[32,53],"duration":94,"reach":245.0,"depth":34.0,"damage":16,"kind":"cross"},
	"s07_ujie_hook":{"art_clip":"attack_b","pose":"boss_hook","hits":[45],"duration":100,"reach":220.0,"depth":85.0,"damage":22,"kind":"hook"},
	"s07_ujie_lunge":{"art_clip":"attack_c","pose":"boss_dash","hits":[46],"duration":105,"reach":255.0,"depth":35.0,"damage":28,"kind":"charge"},
	"s07_inaba_low":{"art_clip":"attack_a","pose":"boss_sweep","hits":[48],"duration":112,"reach":300.0,"depth":96.0,"damage":29,"kind":"low"},
	"s07_inaba_split":{"art_clip":"attack_b","pose":"boss_smash","hits":[62],"duration":132,"reach":230.0,"depth":55.0,"damage":34,"kind":"quake"},
	"s07_inaba_counter":{"art_clip":"attack_c","pose":"boss_counter","hits":[70],"duration":125,"reach":235.0,"depth":80.0,"damage":27,"kind":"counter"},
	"s08_nagai_burst":{"art_clip":"attack_a","pose":"boss_volley","hits":[45,69,93],"duration":144,"reach":900.0,"depth":36.0,"damage":15,"kind":"burst"},
	"s08_nagai_draw":{"art_clip":"attack_b","pose":"boss_double","hits":[32,55],"duration":108,"reach":170.0,"depth":65.0,"damage":20,"kind":"withdraw"},
	"s08_nagai_powder":{"art_clip":"attack_c","pose":"boss_smash","hits":[42],"duration":116,"reach":600.0,"depth":80.0,"damage":25,"kind":"powder"},
	"s08_tatsuoki_draw":{"art_clip":"attack_a","pose":"boss_dash","hits":[43,63],"duration":116,"reach":205.0,"depth":65.0,"damage":24,"kind":"draw"},
	"s08_tatsuoki_rain":{"art_clip":"attack_b","pose":"boss_volley","hits":[45,80,115],"duration":165,"reach":1000.0,"depth":100.0,"damage":17,"kind":"rain"},
	"s08_tatsuoki_counter":{"art_clip":"attack_c","pose":"boss_counter","hits":[68],"duration":116,"reach":205.0,"depth":75.0,"damage":30,"kind":"counter"},
	"s09_nagayasu_cross":{"art_clip":"attack_a","pose":"boss_double","hits":[30,48],"duration":96,"reach":185.0,"depth":65.0,"damage":19,"kind":"cross"},
	"s09_nagayasu_fire":{"art_clip":"attack_b","pose":"boss_volley","hits":[42,78],"duration":128,"reach":1000.0,"depth":60.0,"damage":17,"kind":"crossfire"},
	"s09_nagayasu_flank":{"art_clip":"attack_c","pose":"boss_dash","hits":[49],"duration":106,"reach":210.0,"depth":50.0,"damage":27,"kind":"flank"},
	"s09_iwanari_hook":{"art_clip":"attack_a","pose":"boss_hook","hits":[43,68],"duration":112,"reach":300.0,"depth":48.0,"damage":20,"kind":"hook"},
	"s09_iwanari_triple":{"art_clip":"attack_b","pose":"boss_double","hits":[38,66,96],"duration":152,"reach":265.0,"depth":85.0,"damage":20,"kind":"advance"},
	"s09_iwanari_volley":{"art_clip":"attack_c","pose":"boss_volley","hits":[48,84,120],"duration":174,"reach":1000.0,"depth":65.0,"damage":18,"kind":"crossfire"},
	"s10_kagetsune_charge":{"art_clip":"attack_a","pose":"boss_dash","hits":[49],"duration":116,"reach":255.0,"depth":55.0,"damage":28,"kind":"charge"},
	"s10_kagetsune_turn":{"art_clip":"attack_b","pose":"boss_thrust","hits":[60],"duration":124,"reach":290.0,"depth":35.0,"damage":32,"kind":"turn"},
	"s10_kagetsune_brace":{"art_clip":"attack_c","pose":"boss_counter","hits":[72],"duration":130,"reach":230.0,"depth":58.0,"damage":27,"kind":"counter"},
	"s10_yoshikage_triple":{"art_clip":"attack_a","pose":"boss_double","hits":[42,74,108],"duration":164,"reach":280.0,"depth":88.0,"damage":23,"kind":"advance"},
	"s10_yoshikage_rain":{"art_clip":"attack_b","pose":"boss_volley","hits":[48,86,124],"duration":178,"reach":1000.0,"depth":100.0,"damage":19,"kind":"rain"},
	"s10_yoshikage_guard":{"art_clip":"attack_c","pose":"boss_smash","hits":[56],"duration":138,"reach":600.0,"depth":65.0,"damage":24,"kind":"reinforce"}
}
const OBJECTIVES := ["rockfall","gate","evacuate","rearguard"]
const OBJECTS := ["rock_support","gate","signal","barricade","supplies"]
const HAZARDS := ["rock","arrows","fireline","powder","quake"]

static func timing(fighter: Dictionary) -> Array:
	var action: Dictionary = ACTIONS.get(str(fighter.action),{})
	return [int(action.hits[0]),int(action.duration)] if not action.is_empty() else [30,60]

static func valid_spec(spec: Dictionary, start: float, width: float, stage: int) -> bool:
	if spec.get("mode")!="campaign_challenge" or int(spec.get("node",0)) not in range(1,11): return false
	if float(spec.get("end",0))<start+1000 or float(spec.end)>width: return false
	if spec.get("objective") not in OBJECTIVES or spec.objective!=OBJECTIVES[stage-7]: return false
	if not spec.get("waves") is Array or spec.waves.size()!=2: return false
	for wave in spec.waves:
		if not wave is Array or wave.size()<4 or wave.size()>10: return false
		for role in wave:
			if role not in SOLDIERS: return false
	var boss := str(spec.get("boss",""))
	if boss!="" and (not BOSSES.has(boss) or int(BOSSES[boss].stage)!=stage): return false
	if not spec.get("objects") is Array or spec.objects.size()<1 or spec.objects.size()>6: return false
	for item in spec.objects:
		if not item is Dictionary or item.get("asset") not in OBJECTS: return false
		if float(item.get("x",0))<start+100 or float(item.x)>float(spec.end)-120 or float(item.get("y",0))<360 or float(item.y)>600: return false
		if int(item.get("hp",0))<1 or int(item.hp)>500 or not item.get("mandatory") is bool: return false
	return int(spec.get("hold_ticks",0))>=0 and int(spec.hold_ticks)<=1800 and int(spec.get("hazard_interval",0))>=150 and int(spec.hazard_interval)<=600

static func valid_world(box: Variant) -> bool:
	if not box is Dictionary or box.get("stage") not in STAGES or box.get("node") not in range(1,11): return false
	if box.get("phase") not in ["combat","evacuating","complete"] or box.get("objective") not in OBJECTIVES: return false
	if box.objective!=OBJECTIVES[int(box.stage)-7]: return false
	for field in ["elapsed","admit_tick","next_hazard","entry_seq","boss","hold_ticks","rescued","civilian_total","next_reinforce","reinforcement_calls"]:
		if not box.get(field) is int or int(box[field])<0 or int(box[field])>1000000000: return false
	if box.hold_ticks>1800 or box.civilian_total!=(3 if box.stage==9 else 0) or box.rescued>box.civilian_total: return false
	if not box.get("wave") is int or int(box.wave)<1 or int(box.wave)>2: return false
	if not box.get("pending") is Array or box.pending.size()>32: return false
	for unit in box.pending:
		if not unit is Dictionary or unit.get("role") not in SOLDIERS or not unit.get("left") is bool: return false
	if not box.get("hazards") is Array or box.hazards.size()>24: return false
	for h in box.hazards:
		if not h is Dictionary or h.get("kind") not in HAZARDS: return false
		for field in ["x","y","radius","depth","from_x"]:
			if not h.get(field) is float and not h.get(field) is int: return false
			if not is_finite(float(h[field])) or absf(float(h[field]))>100000: return false
		for field in ["age","warning","life","owner","damage"]:
			if not h.get(field) is int or int(h[field])<0 or int(h[field])>(1000000000 if field=="owner" else 10000): return false
		if not h.get("hit") is bool or h.radius<1 or h.radius>1300 or h.depth<1 or h.depth>250 or h.y<360 or h.y>600: return false
		if h.warning<1 or h.warning>180 or h.life!=h.warning+30 or h.age>=h.life or h.damage<1 or h.damage>100: return false
	if not box.get("civilians") is Array or box.civilians.size()!=box.civilian_total: return false
	for c in box.civilians:
		if not c is Dictionary or not c.get("safe") is bool or not c.get("walking") is bool: return false
		for field in ["x","y"]:
			if not c.get(field) is float and not c.get(field) is int: return false
			if not is_finite(float(c[field])) or absf(float(c[field]))>100000: return false
		if c.y<360 or c.y>600: return false
	if box.civilians.filter(func(c):return c.safe).size()!=box.rescued: return false
	return box.get("hint") is String and box.hint.length()<=160

static func valid_fighter(fighter: Dictionary) -> bool:
	if not fighter.has("expedition_role"): return true
	var role := str(fighter.expedition_role)
	if role not in SOLDIERS and not BOSSES.has(role): return false
	if fighter.get("expedition_stage") not in STAGES or fighter.get("team")!=1: return false
	if BOSSES.has(role) and (int(BOSSES[role].stage)!=fighter.expedition_stage or fighter.get("kind")!="boss"): return false
	if role in SOLDIERS and fighter.get("kind")!={"spear":"soldier","archer":"archer","gunner":"gunner","shield":"soldier","raider":"commander"}[role]: return false
	if role=="shield" and fighter.get("role")!="shield_spear": return false
	if role=="raider" and fighter.get("role")!="raider": return false
	if ACTIONS.has(str(fighter.get("action",""))) and (not BOSSES.has(role) or fighter.action not in BOSSES[role].actions): return false
	for key in ["expedition_sequence","expedition_cooldown","expedition_target"]:
		if not fighter.get(key) is int or int(fighter[key])<0 or int(fighter[key])>1000000000: return false
	if not fighter.get("expedition_events") is Array or fighter.expedition_events.size()>12: return false
	for event in fighter.expedition_events:
		if not event is int or event<0 or event>10: return false
	return true
