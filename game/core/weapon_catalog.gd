extends RefCounted

# Names and forms are historical; tiers, colours and magical properties are game design.
const ITEMS := {
	"sword_uchigatana":{"name":"打刀","family":"sword","tier":1,"damage_bonus":0,"reach_bonus":0.0,"knockback":0.0,"element":"","history":"室町以後常見的打刀形制；裝具為遊戲重繪。","source":"https://museum.city.fukuoka.jp/about/news/20200904.pdf"},
	"sword_nagamitsu":{"name":"大般若長光","family":"sword","tier":2,"damage_bonus":3,"reach_bonus":8.0,"knockback":0.0,"element":"","history":"東京國立博物館藏，鎌倉時代長船長光作太刀。","source":"https://webarchives.tnm.jp/imgsearch/show/E0137927"},
	"sword_samonnji":{"name":"宗三左文字","family":"sword","tier":3,"damage_bonus":5,"reach_bonus":16.0,"knockback":1.0,"element":"","history":"亦稱義元左文字，刀莖有桶狹間與織田信長的金象嵌銘。","source":"https://online.bunka.go.jp/db/heritages/detail/165145"},
	"sword_heshikiri":{"name":"壓切長谷部","family":"sword","tier":4,"damage_bonus":7,"reach_bonus":22.0,"knockback":2.0,"element":"fire","history":"福岡市博物館藏，信長授予黑田孝高的名刀。火焰效果屬遊戲創作。","source":"https://museum.city.fukuoka.jp/sp/exhibition/566/"},
	"sword_dojigiri":{"name":"童子切安綱","family":"sword","tier":5,"damage_bonus":10,"reach_bonus":30.0,"knockback":3.0,"element":"blade","history":"東京國立博物館藏伯耆安綱作太刀；不宣稱是信長佩刀。","source":"https://www.tnm.jp/uploads/r_db/publication_news/news2009-12_43_2.pdf"},
	"spear_suyari":{"name":"直槍","family":"spear","tier":2,"damage_bonus":3,"reach_bonus":6.0,"knockback":1.0,"element":"","history":"直刃槍形；室町後期合戰常見的長柄武器。","source":"https://api.online.bunka.go.jp/heritages/detail/603453"},
	"spear_kamayari":{"name":"片鐮槍","family":"spear","tier":3,"damage_bonus":5,"reach_bonus":12.0,"knockback":2.0,"element":"","history":"取材大都會博物館的 Kama Yari，側邊帶鐮刃。","source":"https://www.metmuseum.org/art/collection/search/23031"},
	"spear_jumonji":{"name":"十文字槍","family":"spear","tier":4,"damage_bonus":7,"reach_bonus":20.0,"knockback":3.0,"element":"earth","history":"直槍兩側加鐮刃，形成十字；採歷史形制而非特定武將私物。","source":"https://api.online.bunka.go.jp/heritages/detail/603453"},
	"spear_nihongo":{"name":"日本號","family":"spear","tier":5,"damage_bonus":10,"reach_bonus":28.0,"knockback":4.0,"element":"earth","history":"福岡市博物館藏名槍日本號；震地效果為遊戲創作。","source":"https://museum.city.fukuoka.jp/about/news/20161222.pdf"},
	"spear_tonbokiri":{"name":"蜻蛉切","family":"spear","tier":1,"damage_bonus":0,"reach_bonus":0.0,"knockback":0.0,"element":"","history":"本多忠勝愛槍，天下三名槍之一；遊戲預設為初品，保留忠勝的代表武器。","source":"https://sanobi.stores.jp/items/68184920c99ac7297304b1df"},
	"bow_azusa":{"name":"梓丸木弓","family":"bow","tier":1,"damage_bonus":0,"reach_bonus":0.0,"knockback":0.0,"element":"","history":"法隆寺獻納寶物有漆飾梓丸木弓；此為古代形制的遊戲改編。","source":"https://www.tnm.jp/common/fckeditor/editor/filemanager/connectors/php/transfer.php?file=%2Fexhibition%2FThe_Gallery_Horyuji_Treasures%2Fuid000276_32303232303931335F526F6F6D345F6A702E706466"},
	"bow_bamboo":{"name":"竹藤弓","family":"bow","tier":2,"damage_bonus":3,"reach_bonus":40.0,"knockback":0.0,"element":"","history":"竹、藤、漆製日本長弓，取材大都會博物館約1700年藏品。","source":"https://www.metmuseum.org/art/collection/search/22127"},
	"bow_black_lacquer":{"name":"黑漆弓","family":"bow","tier":3,"damage_bonus":5,"reach_bonus":65.0,"knockback":1.0,"element":"","history":"春日大社藏黑漆重藤弓；漆與藤卷配置取其歷史形制。","source":"https://www.kasugataisha.or.jp/wp-content/uploads/2024/12/20241221_%E5%87%BA%E5%93%81%E7%9B%AE%E9%8C%B2%EF%BC%88%E7%9B%AE%E9%8C%B2%EF%BC%89%E6%97%A5%E6%9C%AC%E8%AA%9E.pdf"},
	"bow_red_lacquer":{"name":"朱漆弓","family":"bow","tier":4,"damage_bonus":7,"reach_bonus":85.0,"knockback":2.0,"element":"ice","history":"春日大社藏朱漆側白木弓；冰凍效果為遊戲創作。","source":"https://www.kasugataisha.or.jp/wp-content/uploads/2024/12/20241221_%E5%87%BA%E5%93%81%E7%9B%AE%E9%8C%B2%EF%BC%88%E7%9B%AE%E9%8C%B2%EF%BC%89%E6%97%A5%E6%9C%AC%E8%AA%9E.pdf"},
	"bow_shigeto":{"name":"重藤弓","family":"bow","tier":5,"damage_bonus":10,"reach_bonus":110.0,"knockback":3.0,"element":"ice","history":"竹木複合、藤卷與漆保護的非對稱長弓；參照王室收藏說明，不宣稱阿市持有過。","source":"https://www.rct.uk/collection/79906/bow-yumi"},
}

static func family_for(hero: String) -> String:
	return "bow" if hero == "oichi" else ("spear" if hero in ["tadakatsu", "hideyoshi"] else "sword")

static func default_for(hero: String) -> String:
	return {"sword":"sword_uchigatana", "spear":"spear_tonbokiri", "bow":"bow_azusa"}[family_for(hero)]

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func compatible(hero: String, id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].family == family_for(hero)

static func name_for(fighter: Dictionary) -> String:
	return str(item(str(fighter.get("weapon_id",default_for(str(fighter.get("kind","nobunaga")))))).get("name","打刀"))

static func valid_inventory(hero: String, equipped: Variant, owned: Variant) -> bool:
	if not equipped is String or not compatible(hero,equipped) or not owned is Array or owned.is_empty() or owned.size() > 5: return false
	var seen := {}
	for id in owned:
		if not id is String or not compatible(hero,id) or seen.has(id): return false
		seen[id] = true
	return equipped in owned

static func upgrades(hero: String, current: String) -> Array:
	return ITEMS.keys().filter(func(id): return compatible(hero,id) and ITEMS[id].tier > item(current).get("tier",1))
