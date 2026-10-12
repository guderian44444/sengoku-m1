extends RefCounted

# Names and forms are historical; tiers, colours and magical properties are game design.
const ITEMS := {
	"sword_uchigatana":{"name":"打刀","family":"sword","tier":1,"damage_bonus":0,"reach_bonus":0.0,"knockback":0.0,"element":"","history":"室町以後常見的打刀形制；裝具為遊戲重繪。","source":"https://museum.city.fukuoka.jp/about/news/20200904.pdf"},
	"sword_nagamitsu":{"name":"大般若長光","family":"sword","tier":2,"damage_bonus":3,"reach_bonus":8.0,"knockback":0.0,"element":"","history":"東京國立博物館藏，鎌倉時代長船長光作太刀。","source":"https://webarchives.tnm.jp/imgsearch/show/E0137927"},
	"sword_samonnji":{"name":"宗三左文字","family":"sword","tier":3,"damage_bonus":5,"reach_bonus":16.0,"knockback":1.0,"element":"","history":"亦稱義元左文字，刀莖有桶狹間與織田信長的金象嵌銘。","source":"https://online.bunka.go.jp/db/heritages/detail/165145"},
	"sword_heshikiri":{"name":"壓切長谷部","family":"sword","tier":4,"damage_bonus":7,"reach_bonus":22.0,"knockback":2.0,"element":"fire","history":"福岡市博物館藏，信長授予黑田孝高的名刀。火焰效果屬遊戲創作。","source":"https://museum.city.fukuoka.jp/sp/exhibition/566/"},
	"sword_dojigiri":{"name":"童子切安綱","family":"sword","tier":5,"damage_bonus":10,"reach_bonus":30.0,"knockback":3.0,"element":"blade","history":"東京國立博物館藏伯耆安綱作太刀；不宣稱是信長佩刀。","source":"https://www.tnm.jp/uploads/r_db/publication_news/news2009-12_43_2.pdf"},
	"sword_kanesada_mino":{"name":"美濃兼定","family":"sword","tier":2,"damage_bonus":4,"reach_bonus":-12.0,"knockback":1.0,"element":"","history":"參照土浦市立博物館室町刀兼定：刃60.1公分、反2.1公分。刀裝與信長可裝備為遊戲安排，非信長持有證明。","source":"https://online.bunka.go.jp/heritages/detail/588130"},
	"spear_suyari":{"name":"直槍","family":"spear","tier":2,"damage_bonus":3,"reach_bonus":6.0,"knockback":1.0,"element":"","history":"直刃槍形；室町後期合戰常見的長柄武器。","source":"https://api.online.bunka.go.jp/heritages/detail/603453"},
	"spear_kamayari":{"name":"片鐮槍","family":"spear","tier":3,"damage_bonus":5,"reach_bonus":12.0,"knockback":2.0,"element":"","history":"取材大都會博物館的 Kama Yari，側邊帶鐮刃。","source":"https://www.metmuseum.org/art/collection/search/23031"},
	"spear_jumonji":{"name":"十文字槍","family":"spear","tier":4,"damage_bonus":7,"reach_bonus":20.0,"knockback":3.0,"element":"earth","history":"直槍兩側加鐮刃，形成十字；採歷史形制而非特定武將私物。","source":"https://api.online.bunka.go.jp/heritages/detail/603453"},
	"spear_nihongo":{"name":"日本號","family":"spear","tier":5,"damage_bonus":10,"reach_bonus":28.0,"knockback":4.0,"element":"earth","history":"福岡市博物館藏名槍日本號；震地效果為遊戲創作。","source":"https://museum.city.fukuoka.jp/about/news/20161222.pdf"},
	"spear_tonbokiri":{"name":"蜻蛉切","family":"spear","tier":1,"damage_bonus":0,"reach_bonus":0.0,"knockback":0.0,"element":"","history":"本多忠勝愛槍，天下三名槍之一；遊戲預設為初品，保留忠勝的代表武器。","source":"https://sanobi.stores.jp/items/68184920c99ac7297304b1df"},
	"spear_fukuro_yari":{"name":"袋槍","family":"spear","tier":2,"damage_bonus":4,"reach_bonus":2.0,"knockback":1.0,"element":"","history":"參照岐阜縣博物館室町無銘袋槍：刃13.8公分，短頸接中空套筒。180公分裝柄長與忠勝可裝備為遊戲改編。","source":"https://jmapps.ne.jp/gifuhaku/det.html?data_id=1617"},
	"bow_azusa":{"name":"梓丸木弓","family":"bow","tier":1,"damage_bonus":0,"reach_bonus":0.0,"knockback":0.0,"element":"","history":"法隆寺獻納寶物有漆飾梓丸木弓；此為古代形制的遊戲改編。","source":"https://www.tnm.jp/common/fckeditor/editor/filemanager/connectors/php/transfer.php?file=%2Fexhibition%2FThe_Gallery_Horyuji_Treasures%2Fuid000276_32303232303931335F526F6F6D345F6A702E706466"},
	"bow_bamboo":{"name":"竹藤弓","family":"bow","tier":2,"damage_bonus":3,"reach_bonus":40.0,"knockback":0.0,"element":"","history":"竹、藤、漆製日本長弓，取材大都會博物館約1700年藏品。","source":"https://www.metmuseum.org/art/collection/search/22127"},
	"bow_black_lacquer":{"name":"黑漆弓","family":"bow","tier":3,"damage_bonus":5,"reach_bonus":65.0,"knockback":1.0,"element":"","history":"春日大社藏黑漆重藤弓；漆與藤卷配置取其歷史形制。","source":"https://www.kasugataisha.or.jp/wp-content/uploads/2024/12/20241221_%E5%87%BA%E5%93%81%E7%9B%AE%E9%8C%B2%EF%BC%88%E7%9B%AE%E9%8C%B2%EF%BC%89%E6%97%A5%E6%9C%AC%E8%AA%9E.pdf"},
	"bow_red_lacquer":{"name":"朱漆弓","family":"bow","tier":4,"damage_bonus":7,"reach_bonus":85.0,"knockback":2.0,"element":"ice","history":"春日大社藏朱漆側白木弓；冰凍效果為遊戲創作。","source":"https://www.kasugataisha.or.jp/wp-content/uploads/2024/12/20241221_%E5%87%BA%E5%93%81%E7%9B%AE%E9%8C%B2%EF%BC%88%E7%9B%AE%E9%8C%B2%EF%BC%89%E6%97%A5%E6%9C%AC%E8%AA%9E.pdf"},
	"bow_shigeto":{"name":"重藤弓","family":"bow","tier":5,"damage_bonus":10,"reach_bonus":110.0,"knockback":3.0,"element":"ice","history":"竹木複合、藤卷與漆保護的非對稱長弓；參照王室收藏說明，不宣稱阿市持有過。","source":"https://www.rct.uk/collection/79906/bow-yumi"},
	"bow_awase_yumi":{"name":"竹木合弓","family":"bow","tier":3,"damage_bonus":6,"reach_bonus":50.0,"knockback":1.0,"element":"","history":"參照彥根城博物館桃山合弓：總長231.2公分，內外竹片與側木；內芯構造未確定。阿市可裝備為遊戲安排。","source":"https://hikone-castle-museum.jp/collection/1397.html"},
	# v24: Original artwork and gameplay interpretations; no ownership claim.
	"sword_mikazuki_munechika":{"name":"三日月宗近","family":"sword","tier":3,"damage_bonus":5,"reach_bonus":12.0,"knockback":1.0,"element":"","history":"平安時代三條宗近的太刀，以刃文中的月牙形紋理得名，現藏東京國立博物館。","source":"https://emuseum.nich.go.jp/detail?content_base_id=100192&content_part_id=0&content_pict_id=0&langId=ja&webView=0"},
	"sword_okanehira":{"name":"大包平","family":"sword","tier":5,"damage_bonus":9,"reach_bonus":24.0,"knockback":3.0,"element":"","history":"古備前包平製作的長大太刀，寬闊刀身、較短的豬首鋒與深腰反形成厚實輪廓。","source":"https://emuseum.nich.go.jp/detail?content_base_id=100187&content_part_id=0&content_pict_id=0&langId=ja&webView=0"},
	"sword_shishio":{"name":"獅子王","family":"sword","tier":2,"damage_bonus":4,"reach_bonus":8.0,"knockback":0.0,"element":"","history":"獅子王的細身古式太刀配黑漆刀裝，鞘上青絲渡卷具有清楚的視覺辨識度。","source":"https://emuseum.nich.go.jp/detail?content_base_id=100467&content_part_id=0&content_pict_id=0&langId=ja&webView=0"},
	"sword_kanze_masamune":{"name":"觀世正宗","family":"sword","tier":3,"damage_bonus":6,"reach_bonus":-8.0,"knockback":0.0,"element":"","history":"觀世正宗是鎌倉末期相州刀的名品，刀身偏窄，地鐵與沸的細緻光澤是重點。","source":"https://emuseum.nich.go.jp/detail?content_base_id=100185&content_part_id=0&content_pict_id=0&langId=ja&webView=0"},
	"sword_yamanbagiri_kunihiro":{"name":"山姥切國廣","family":"sword","tier":4,"damage_bonus":7,"reach_bonus":2.0,"knockback":2.0,"element":"","history":"1590年為長尾顯長作的國廣刀，傳以本作長義為範本，豪壯刀姿及複雜刃文最具特色。","source":"https://www.city.ashikaga.tochigi.jp/category/000000/p006371.html"},
	"sword_himetsuru_ichimonji":{"name":"姬鶴一文字","family":"sword","tier":3,"damage_bonus":6,"reach_bonus":3.0,"knockback":1.0,"element":"","history":"姬鶴一文字是上杉家傳來的太刀，華麗丁子刃與無刀鐔的合口式黑漆刀裝可與普通打刀區分。","source":"https://www.denkoku-no-mori.yonezawa.yamagata.jp/togodb/capt.php?ID=17039"},
	"sword_magoroku_kanemoto":{"name":"孫六兼元","family":"sword","tier":3,"damage_bonus":5,"reach_bonus":-2.0,"knockback":1.0,"element":"","history":"孫六兼元的美濃刀，以成群尖互之目構成的三本杉刃文辨認，與兼定為不同刀工。","source":"https://jmapps.ne.jp/gifuhaku/det.html?data_id=1686"},
	"sword_odenta_mitsuyo":{"name":"大典太光世","family":"sword","tier":4,"damage_bonus":8,"reach_bonus":-6.0,"knockback":4.0,"element":"","history":"大典太以偏短卻寬闊的太刀身、豬首鋒與寬淺棒樋形成厚實輪廓，為前田家傳世名刀。","source":"https://www.ishibi.pref.ishikawa.jp/exhibition/exhibition-16305/"},
	"sword_kosetsu_samonji":{"name":"江雪左文字","family":"sword","tier":4,"damage_bonus":7,"reach_bonus":13.0,"knockback":2.0,"element":"","history":"江雪左文字是南北朝時代左文字的太刀，長刀身與起伏刃文可作大弧斬擊造型。","source":"https://fukubun.net/collection/479"},
	"sword_okanemitsu":{"name":"大兼光","family":"sword","tier":5,"damage_bonus":10,"reach_bonus":18.0,"knockback":3.0,"element":"","history":"大兼光原是更長大的南北朝太刀，現存83.5公分刃長仍顯豪壯，長鋒與平緩灣刃是辨識重點。","source":"https://sanobi.or.jp/about/japanese_sword/"},
	"spear_otegine":{"name":"御手杵（復原）","family":"spear","tier":5,"damage_bonus":10,"reach_bonus":32.0,"knockback":3.0,"element":"","history":"結城市資料記錄結城晴朝命島田刀工五條義助製作；後傳結城秀康及松平大和守家。原物於東京大空襲燒失，結城蔵美館現展示現代復元品。","source":"https://www.city.yuki.lg.jp/data/doc/1713334887_doc_181_0.pdf"},
	"spear_omi_sukesada_1504":{"name":"大身槍・長船祐定","family":"spear","tier":4,"damage_bonus":8,"reach_bonus":20.0,"knockback":2.0,"element":"","history":"東京國立博物館藏F-15922，銘備州長船祐定／永正元年三月日；館方描述其刃身超過70cm，丁子亂刃文。","source":"https://online.bunka.go.jp/heritages/detail/553506"},
	"spear_sasaho_kanesada":{"name":"笹穗槍・兼貞型（復原）","family":"spear","tier":2,"damage_bonus":4,"reach_bonus":0.0,"knockback":1.0,"element":"","history":"東京國立博物館F-20253，關兼貞作。國立文化財機構年報記錄平三角造、穗身較長而先部展寬，平面有太樋，茎有兩目釘孔；刃長32.5cm。","source":"https://online.bunka.go.jp/db/heritages/detail/552570"},
	"spear_kikuchi_kunikiyo":{"name":"菊池千本槍・國清","family":"spear","tier":1,"damage_bonus":2,"reach_bonus":-12.0,"knockback":0.0,"element":"","history":"菊池神社藏菊池市指定文化財，國清銘一口記刃長18.5cm、茎27cm。另有一口延壽國吉刃24cm，曾改裝短刀，本件不混用那口的尺寸。","source":"https://www.city.kikuchi.lg.jp/d?q=ee85710e9ea7f647aab7e8950018e9c5.pdf"},
	"spear_hirasankaku_hidesada":{"name":"平三角槍・英定","family":"spear","tier":3,"damage_bonus":6,"reach_bonus":3.0,"knockback":0.0,"element":"","history":"刀劍ワールド財團藏，銘常州高田住英定作／永祿八天乙丑九月日。館方記平三角槍、長さ28.0cm，太樋中有富士大權現銘。","source":"https://www.touken-world.jp/search/36882/"},
	"spear_gyukaku_jumonji":{"name":"牛角十文字槍","family":"spear","tier":3,"damage_bonus":6,"reach_bonus":4.0,"knockback":3.0,"element":"","history":"刀劍ワールド財團藏無銘牛角十文字槍，館方歸於室町末期美濃關作，長さ20.6cm。兩側刃略彎成牛角形。","source":"https://www.touken-world.jp/search/45820/"},
	"spear_techigai_jumonji":{"name":"手違十文字槍","family":"spear","tier":4,"damage_bonus":7,"reach_bonus":8.0,"knockback":3.0,"element":"","history":"刀劍ワールド財團無銘手違十文字槍，長さ24.7cm。實物照片顯示中央直穗及左右直條式、末端斜切的側刃。","source":"https://www.touken-world.jp/search/45844/"},
	"spear_sagara_yari":{"name":"傳相良槍","family":"spear","tier":2,"damage_bonus":3,"reach_bonus":-18.0,"knockback":0.0,"element":"","history":"刀劍ワールド財團藏無銘槍，長さ17.0cm、反0。館方以相良槍名稱收錄，實物是小型非對稱刃。","source":"https://www.touken-world.jp/search/42979/"},
	"spear_takebera_yari":{"name":"竹篦槍","family":"spear","tier":2,"damage_bonus":4,"reach_bonus":-5.0,"knockback":1.0,"element":"","history":"刀劍ワールド財團藏無銘竹べら槍，長さ20.9cm。館方描述其穗如竹篦，且螻蛄首較長。","source":"https://www.touken-world.jp/search/30387/"},
	"spear_inji_yari":{"name":"印地槍型（復原）","family":"spear","tier":1,"damage_bonus":1,"reach_bonus":-22.0,"knockback":0.0,"element":"","history":"刀劍ワールド財團藏無銘槍，長さ15.8cm。形制為鐵棒末端形成簡單尖刃，館方認為是印地槍一種。","source":"https://www.touken-world.jp/search/42883/"},
	"bow_todake_reconstruction":{"name":"外竹伏竹弓（復原）","family":"bow","tier":1,"damage_bonus":2,"reach_bonus":20.0,"knockback":0.0,"element":"","history":"近藤好和把外竹弓列為最早的伏竹弓，約12世紀初成立；弓道具協會的通史則上溯平安中期。本案採較保守的中世型制，不指定發明年份。","source":"https://www.city.kobe.lg.jp/documents/60534/tokusyu-genpei-2.pdf"},
	"bow_sanmaiuchi_reconstruction":{"name":"三枚打弓（復原）","family":"bow","tier":2,"damage_bonus":4,"reach_bonus":45.0,"knockback":1.0,"element":"","history":"近藤好和指出木芯腹背貼竹的三枚打弓是中世常見形式，但不能確定其是否已在源平合戰期成立。本案不把「平安末發明」當成已定論。","source":"https://www.city.kobe.lg.jp/documents/60534/tokusyu-genpei-2.pdf"},
	"bow_shihochiku_reconstruction":{"name":"四方竹弓（復原）","family":"bow","tier":4,"damage_bonus":8,"reach_bonus":65.0,"knockback":2.0,"element":"","history":"近藤好和將其視為中世後期成立的特殊形式；弓道具協會亦列入戰國的發展。不能據此聲稱它在所有戰國軍隊中普遍取代三枚打。","source":"https://www.city.kobe.lg.jp/documents/60534/tokusyu-genpei-2.pdf"},
	"bow_odawara_higo_reconstruction":{"name":"小田原弓胎弓（復原）","family":"bow","tier":5,"damage_bonus":9,"reach_bonus":85.0,"knockback":1.0,"element":"","history":"小田原城三之丸幸田口跡出土的漆塗弓，由市方公告及2023年郷土文化館展示確認來自戰國堀跡；足以支持戰國後期已有弓胎形式，不能冠為織田信長所用。","source":"https://www.city.odawara.kanagawa.jp/public-i/facilities/kyodo/topics/exhibition2023-1.html"},
	"bow_fukiyose_tou_reconstruction":{"name":"吹寄籐弓（復原）","family":"bow","tier":2,"damage_bonus":3,"reach_bonus":35.0,"knockback":0.0,"element":"","history":"大山祇神社「三島明神奉納武器類」中的實存吹寄藤弓／吹寄籐弓；文化廳與愛媛縣皆有編目。名稱是形制／表面工藝描述，並非虛構名弓。","source":"https://kunishitei.bunka.go.jp/heritage/detail/201/6935"},
	"bow_tokoroito_reconstruction":{"name":"所糸卷弓（復原）","family":"bow","tier":2,"damage_bonus":4,"reach_bonus":55.0,"knockback":0.0,"element":"","history":"大山祇神社「三島明神奉納武器類」中的實存塗籠所糸巻弓；文化廳與愛媛縣皆有編目。名稱是形制／表面工藝描述，並非虛構名弓。","source":"https://kunishitei.bunka.go.jp/heritage/detail/201/6935"},
	"bow_shigeito_reconstruction":{"name":"重糸卷弓（復原）","family":"bow","tier":3,"damage_bonus":5,"reach_bonus":60.0,"knockback":2.0,"element":"","history":"大山祇神社「三島明神奉納武器類」中的實存塗籠重糸巻弓；文化廳與愛媛縣皆有編目。名稱是形制／表面工藝描述，並非虛構名弓。","source":"https://kunishitei.bunka.go.jp/heritage/detail/201/6935"},
	"bow_nioiito_reconstruction":{"name":"匂糸卷弓（復原）","family":"bow","tier":4,"damage_bonus":7,"reach_bonus":90.0,"knockback":0.0,"element":"","history":"大山祇神社「三島明神奉納武器類」中的實存塗籠匂糸巻弓；文化廳與愛媛縣皆有編目。名稱是形制／表面工藝描述，並非虛構名弓。","source":"https://kunishitei.bunka.go.jp/heritage/detail/201/6935"},
	"bow_nibiki_shigeito_reconstruction":{"name":"二引重糸卷弓（復原）","family":"bow","tier":5,"damage_bonus":10,"reach_bonus":70.0,"knockback":3.0,"element":"","history":"大山祇神社「三島明神奉納武器類」中的實存黒漆塗二引重糸巻弓；文化廳與愛媛縣皆有編目。名稱是形制／表面工藝描述，並非虛構名弓。","source":"https://kunishitei.bunka.go.jp/heritage/detail/201/6935"},
	"bow_nibiki_kaba_reconstruction":{"name":"二引樺卷弓（復原）","family":"bow","tier":3,"damage_bonus":6,"reach_bonus":100.0,"knockback":1.0,"element":"","history":"大山祇神社「三島明神奉納武器類」中的實存塗籠二引樺巻弓；文化廳與愛媛縣皆有編目。名稱是形制／表面工藝描述，並非虛構名弓。","source":"https://kunishitei.bunka.go.jp/heritage/detail/201/6935"},
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
	if not equipped is String or not compatible(hero,equipped) or not owned is Array or owned.is_empty() or owned.size() > ids_for(hero).size(): return false
	var seen := {}
	for id in owned:
		if not id is String or not compatible(hero,id) or seen.has(id): return false
		seen[id] = true
	return equipped in owned

static func upgrades(hero: String, current: String) -> Array:
	return ITEMS.keys().filter(func(id): return compatible(hero,id) and ITEMS[id].tier > item(current).get("tier",1))

# Counts follow the catalog, not a save-format-specific five-item ceiling.
static func ids_for(hero: String) -> Array:
	return ITEMS.keys().filter(func(id): return compatible(hero,id))

# Missing sidegrades and earlier designs stay collectible after a high-tier
# weapon is equipped. Keep the existing higher-tier step cap for balance.
static func loot_candidates(hero: String, current: String, owned: Array, max_tier_step: int) -> Array:
	var tier := int(item(current).get("tier",1))
	return ids_for(hero).filter(func(id): return id not in owned and int(ITEMS[id].tier) <= tier + max_tier_step)
