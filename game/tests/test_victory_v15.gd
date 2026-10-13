extends SceneTree

const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func arena(heroes: Array = ["nobunaga", "oichi"]):
	var battle := Battle.new()
	battle.reset("normal", 2, heroes)
	battle.state.props = []
	battle.state.intro = {}
	battle.state.wave = 3
	for fighter in battle.state.fighters:
		if fighter.team == 1: battle._damage(fighter, 10000, battle.state.fighters[0].id, false)
	return battle

func advance(battle, count: int) -> void:
	for tick in range(count):
		battle.step([{"dx":1,"dy":1,"buttons":Battle.LIGHT|Battle.HEAVY|Battle.SPECIAL|Battle.JUMP}])
		check(Wire.valid_snapshot(battle.get_state()), "Celebration remains a valid network snapshot")

func _initialize() -> void:
	var battle = arena()
	battle.step([])
	check(battle.state.phase == "won", "Real final wave clear enters victory")
	var player: Dictionary = battle.state.fighters[0]
	var position := Vector2(player.x, player.y)
	advance(battle, 130)
	for fighter in battle.state.fighters:
		if fighter.team == 0:
			check(fighter.action == "victory" and fighter.action_tick == 120, "Both living focused heroes finish their celebration once")
		else: check(fighter.action == "defeated" and fighter.action_tick == 24, "Enemies remain flat corpses during celebration")
	check(position.is_equal_approx(Vector2(player.x,player.y)), "Held movement and attacks cannot move the winner")
	check(battle.state.effects.is_empty(), "Combat effects cannot remain active on the victory pose")
	var stopped_tick: int = battle.state.tick
	advance(battle, 30)
	check(battle.state.tick == stopped_tick, "Settled final pose holds without restarting the animation")

	var landing = arena()
	var airborne: Dictionary = landing.state.fighters[1]
	airborne.stun = 65
	landing._launch(airborne, 1, 9, 8)
	landing.step([])
	advance(landing, 1)
	check(airborne.z > 0 and airborne.action != "victory", "An airborne survivor does not celebrate in midair")
	advance(landing, 300)
	check(airborne.z == 0 and airborne.action == "victory" and airborne.action_tick == 120, "Winner lands, gets up, then finishes a complete celebration")
	check(airborne.stun == 0, "Victory cannot retain a permanent stun indicator")

	var dead_partner = arena()
	dead_partner.state.fighters[1].lives = 1
	dead_partner._damage(dead_partner.state.fighters[1], 10000, dead_partner.state.fighters[2].id, false)
	dead_partner.step([])
	advance(dead_partner, 130)
	check(dead_partner.state.fighters[1].action == "defeated", "A defeated partner never plays a victory pose")
	var lost = arena()
	lost.state.phase = "lost"
	advance(lost, 130)
	check(lost.state.fighters[0].action != "victory", "A defeat never triggers celebration")
	var deferred = arena(["hideyoshi", "ieyasu"])
	deferred.step([])
	advance(deferred, 30)
	check(deferred.state.fighters[0].action == "victory" and deferred.state.fighters[1].action == "victory", "The remaining living heroes enter victory for their own dialogue")

	for hero in ["nobunaga", "oichi"]:
		for tick in range(141):
			var sample := Frames.hero_v12_sample({"kind":hero,"action":"victory","action_tick":tick},0,155,{"v15_victory":range(12),"v12_victory":range(12)})
			check(sample.source == "v15" and sample.sheet == "v15_victory" and sample.frame == mini(11,tick / 10), "New celebration takes priority, advances evenly, then holds")
	print("V15 VICTORY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
