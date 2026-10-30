extends RefCounted
## Deckbuilder Kit demo content: "The Crystal Mine". Statuses, 30 cards, 6 enemies, relics
## and the combat items, all built in code so you can read every number. In your game,
## the same objects can be .tres resources made in the inspector.

const CATALYST := &"double_poison"

var statuses := {}
var library := DBCardLibrary.new()
var starter_deck: Array[DBCardData] = []
var relics: Array[DBRelic] = []
var item_cards: Dictionary[StringName, DBCardData] = {}
var encounters := {}
var wound: DBCardData
var daze: DBCardData


func _init() -> void:
	_make_statuses()
	_make_cards()
	_make_enemies()
	_make_relics()
	_make_items()


func _status(id: StringName, title: String, debuff: bool, decays: bool, icon: StringName, color: Color, fields: Dictionary) -> DBStatus:
	var status := DBStatus.make(id, title, debuff, decays, icon)
	status.color = color
	for field: String in fields:
		status.set(field, fields[field])
	statuses[id] = status
	return status


func _make_statuses() -> void:
	_status(&"might", "Might", false, false, &"gold_ingot", Color(1.0, 0.55, 0.35), {"damage_bonus": 1})
	_status(&"agility", "Agility", false, false, &"feather", Color(0.55, 0.85, 1.0), {"block_bonus": 1})
	_status(&"weakened", "Weakened", true, true, &"rawhide", Color(0.75, 0.6, 1.0), {"damage_dealt_mult": 0.75})
	_status(&"exposed", "Exposed", true, true, &"clay", Color(1.0, 0.45, 0.4), {"damage_taken_mult": 1.5})
	_status(&"fragile", "Fragile", true, true, &"sand", Color(0.9, 0.8, 0.5), {"block_gain_mult": 0.75})
	_status(&"poison", "Poison", true, true, &"herb", Color(0.55, 0.95, 0.35), {"damage_per_turn": 1})
	_status(&"thorns", "Thorns", false, false, &"plant_fiber", Color(0.7, 0.9, 0.5), {"thorns": 1})
	_status(&"plating", "Plating", false, false, &"steel_ingot", Color(0.6, 0.75, 0.95), {"block_per_turn": 1})
	_status(&"fortress", "Fortress", false, false, &"marble", Color(0.85, 0.85, 0.95), {"keeps_block": true})


func _card(id: StringName, title: String, cost: int, type: DBCardData.Type, rarity: DBCardData.Rarity,
		icon: StringName, effects: Array) -> DBCardData:
	var card := DBCardData.make(id, title, cost, type, effects, icon, rarity)
	library.add(card)
	return card


func _make_cards() -> void:
	var s := statuses
	var A := DBCardData.Type.ATTACK
	var S := DBCardData.Type.SKILL
	var P := DBCardData.Type.POWER
	var ALL := DBEffect.Target.ALL_OPPONENTS
	var ME := DBEffect.Target.SELF
	var starter := DBCardData.Rarity.STARTER
	var common := DBCardData.Rarity.COMMON
	var uncommon := DBCardData.Rarity.UNCOMMON
	var rare := DBCardData.Rarity.RARE

	var strike := _card(&"strike", "Strike", 1, A, starter, &"sword", [DBEffect.damage(6, 3)])
	var guard := _card(&"guard", "Guard", 1, S, starter, &"shield", [DBEffect.block(5, 3)])
	var mace := _card(&"mace_blow", "Mace Blow", 2, A, starter, &"mace", [DBEffect.damage(8, 2), DBEffect.apply(s.exposed, 2, DBEffect.Target.AIMED, 1)])
	for i in 5:
		starter_deck.append(strike)
	for i in 4:
		starter_deck.append(guard)
	starter_deck.append(mace)

	_card(&"twin_daggers", "Twin Daggers", 1, A, common, &"dagger", [DBEffect.damage(4, 1, 2)])
	_card(&"spear_thrust", "Spear Thrust", 1, A, common, &"spear", [DBEffect.damage(9, 3)])
	_card(&"arrow_volley", "Arrow Volley", 1, A, common, &"arrows", [DBEffect.damage(5, 3, 1, ALL)])
	_card(&"bone_toss", "Bone Toss", 0, A, common, &"bone", [DBEffect.damage(4, 3)])
	_card(&"bow_shot", "Bow Shot", 1, A, common, &"bow", [DBEffect.damage(7, 3), DBEffect.draw(1)])
	_card(&"torch_sweep", "Torch Sweep", 1, A, common, &"torch", [DBEffect.damage(4, 2, 1, ALL), DBEffect.apply(s.weakened, 1, ALL)])
	_card(&"iron_skin", "Iron Skin", 1, S, common, &"iron_chest", [DBEffect.block(8, 3)])
	_card(&"quick_step", "Quick Step", 1, S, common, &"boots", [DBEffect.block(5, 2), DBEffect.draw(1)])
	_card(&"rotten_cheese", "Rotten Cheese", 1, S, common, &"cheese", [DBEffect.apply(s.poison, 5, DBEffect.Target.AIMED, 3)])
	var reading := _card(&"map_reading", "Map Reading", 1, S, common, &"map", [DBEffect.draw(3)])
	reading.upgraded_cost = 0

	_card(&"axe_cleave", "Axe Cleave", 2, A, uncommon, &"axe", [DBEffect.damage(14, 4), DBEffect.apply(s.exposed, 1)])
	var phantom := _card(&"phantom_blade", "Phantom Blade", 1, A, uncommon, &"silver_ingot", [DBEffect.damage(12, 4)])
	phantom.ethereal = true
	var patient := _card(&"patient_strike", "Patient Strike", 1, A, uncommon, &"staff", [DBEffect.damage(10, 4)])
	patient.retain = true
	_card(&"brace", "Brace", 1, S, uncommon, &"iron_helmet", [DBEffect.block(5, 3), DBEffect.apply(s.might, 1, ME)])
	_card(&"toxic_herb", "Toxic Herb", 1, S, uncommon, &"herb", [DBEffect.apply(s.poison, 3, ALL, 1)])
	_card(&"sapphire_chill", "Sapphire Chill", 1, S, uncommon, &"sapphire", [DBEffect.apply(s.weakened, 2, ALL, 1)])
	_card(&"crystal_shield", "Crystal Shield", 2, S, uncommon, &"crystal", [DBEffect.block(15, 5)])
	var catalyst := _card(&"obsidian_catalyst", "Obsidian Catalyst", 1, S, uncommon, &"obsidian", [DBEffect.custom(CATALYST)])
	catalyst.description = "Double the enemy's Poison."
	catalyst.exhaust = true
	catalyst.upgrade_removes_exhaust = true
	var focus := _card(&"scroll_of_focus", "Scroll of Focus", 0, S, uncommon, &"scroll", [DBEffect.energy(2, 1)])
	focus.exhaust = true
	var wind := _card(&"second_wind", "Second Wind", 0, S, uncommon, &"feather", [DBEffect.draw(2)])
	wind.exhaust = true
	wind.upgrade_removes_exhaust = true
	var gambit := _card(&"opening_gambit", "Opening Gambit", 0, S, uncommon, &"key", [DBEffect.draw(2, 1)])
	gambit.innate = true
	gambit.exhaust = true
	_card(&"ring_of_might", "Ring of Might", 1, P, uncommon, &"ring", [DBEffect.apply(s.might, 2, ME, 1)])
	_card(&"hooded_cloak", "Hooded Cloak", 1, P, uncommon, &"cloak", [DBEffect.apply(s.agility, 2, ME, 1)])
	_card(&"thorn_mail", "Thorn Mail", 1, P, uncommon, &"mithril_chest", [DBEffect.apply(s.thorns, 3, ME, 2)])

	_card(&"ruby_blast", "Ruby Blast", 2, A, rare, &"ruby", [DBEffect.damage(22, 8)])
	_card(&"diamond_edge", "Diamond Edge", 1, A, rare, &"diamond", [DBEffect.damage(5, 2, 3)])
	_card(&"living_armor", "Living Armor", 2, P, rare, &"amulet", [DBEffect.apply(s.plating, 4, ME, 2)])
	var fortress := _card(&"fortress", "Fortress", 3, P, rare, &"dragon_chest", [DBEffect.apply(s.fortress, 1, ME)])
	fortress.upgraded_cost = 2
	var mend := _card(&"emerald_mend", "Emerald Mend", 1, S, rare, &"emerald", [DBEffect.make(DBEffect.Kind.HEAL, 8, ME, 4)])
	mend.exhaust = true

	wound = _card(&"wound", "Wound", 0, DBCardData.Type.STATUS, DBCardData.Rarity.SPECIAL, &"rawhide", [])
	wound.description = "A wound slows you down."
	daze = _card(&"daze", "Daze", 0, DBCardData.Type.STATUS, DBCardData.Rarity.SPECIAL, &"sand", [])
	daze.description = "Smoke in your eyes."
	daze.ethereal = true


func _intent(id: StringName, title: String, effects: Array, weight: float = 1.0) -> DBIntent:
	return DBIntent.make(id, title, effects, weight)


func _enemy(id: StringName, title: String, hp: int, variance: int, icon: StringName, intents: Array,
		pattern: DBEnemyData.Pattern, gold: Vector2i) -> DBEnemyData:
	var enemy := DBEnemyData.make(id, title, hp, intents, icon, pattern)
	enemy.hp_variance = variance
	enemy.gold_min = gold.x
	enemy.gold_max = gold.y
	enemy.first_intent = 0
	return enemy


func _make_enemies() -> void:
	var s := statuses
	var ME := DBEffect.Target.SELF
	var random := DBEnemyData.Pattern.RANDOM_NO_REPEAT
	var cycle := DBEnemyData.Pattern.CYCLE
	var ore := _enemy(&"living_ore", "Living Ore", 34, 3, &"iron_ore", [
		_intent(&"rock_throw", "Rock Throw", [DBEffect.damage(8)], 2.0),
		_intent(&"harden", "Harden", [DBEffect.block(7), DBEffect.apply(s.might, 1, ME)]),
		_intent(&"crush", "Crush", [DBEffect.damage(5), DBEffect.apply(s.fragile, 1)]),
	], random, Vector2i(10, 16))
	var crawler := _enemy(&"copper_crawler", "Copper Crawler", 24, 2, &"copper_ore", [
		_intent(&"bite", "Bite", [DBEffect.damage(6), DBEffect.apply(s.weakened, 1)]),
		_intent(&"scuttle", "Scuttle", [DBEffect.damage(3, 0, 2)], 1.5),
		_intent(&"skitter", "Skitter", [DBEffect.block(5)], 0.7),
	], random, Vector2i(6, 10))
	var sprite := _enemy(&"coal_sprite", "Coal Sprite", 28, 2, &"coal", [
		_intent(&"smoke", "Smoke", [DBEffect.apply(s.weakened, 2), DBEffect.add_card(daze, 1)]),
		_intent(&"ember", "Ember", [DBEffect.damage(7)]),
		_intent(&"flare", "Flare", [DBEffect.damage(4, 0, 2)]),
	], cycle, Vector2i(8, 12))
	var sentinel := _enemy(&"granite_sentinel", "Granite Sentinel", 78, 0, &"granite", [
		_intent(&"slam", "Slam", [DBEffect.damage(15)]),
		_intent(&"fortify", "Fortify", [DBEffect.block(12), DBEffect.apply(s.might, 2, ME)]),
		_intent(&"rubble", "Rubble", [DBEffect.damage(7), DBEffect.apply(s.exposed, 2)]),
	], cycle, Vector2i(30, 40))
	sentinel.start_statuses = {s.plating: 3}
	sentinel.is_elite = true
	var heart := _enemy(&"obsidian_heart", "The Obsidian Heart", 150, 0, &"obsidian", [
		_intent(&"gather", "Gather Darkness", [DBEffect.block(12), DBEffect.apply(s.might, 3, ME)]),
		_intent(&"shatter", "Shatter", [DBEffect.damage(6, 0, 3)]),
		_intent(&"curse", "Cursed Shards", [DBEffect.add_card(wound, 2), DBEffect.apply(s.fragile, 2)]),
		_intent(&"smash", "Smash", [DBEffect.damage(22)]),
	], cycle, Vector2i(80, 90))
	heart.is_elite = true
	heart.tint = Color(0.85, 0.75, 1.0)
	var wisp := _enemy(&"gem_wisp", "Gem Wisp", 22, 2, &"magic_essence", [
		_intent(&"mend", "Mend", [DBEffect.make(DBEffect.Kind.HEAL, 8, DBEffect.Target.ALL_ALLIES)]),
		_intent(&"zap", "Zap", [DBEffect.damage(5)]),
	], cycle, Vector2i(5, 8))
	encounters = {
		"fight1": [ore, crawler],
		"fight2": [sprite, crawler],
		"elite": [sentinel],
		"boss": [wisp, heart],
	}


func _make_relics() -> void:
	var s := statuses
	var ME := DBEffect.Target.SELF
	var whetstone := DBRelic.make(&"whetstone", "Whetstone", "Start each combat with 1 Might.", DBRelic.Trigger.COMBAT_START, [DBEffect.apply(s.might, 1, ME)], &"stone")
	var ember := DBRelic.make(&"ember_stone", "Ember Stone", "Every 3rd Attack you play deals 5 damage to ALL enemies.", DBRelic.Trigger.CARD_PLAYED,
		[DBEffect.damage(5, 0, 1, DBEffect.Target.ALL_OPPONENTS)], &"coal")
	ember.card_type = DBCardData.Type.ATTACK
	ember.every = 3
	var lamp := DBRelic.make(&"miners_lamp", "Miner's Lamp", "Every other turn, gain 1 energy.", DBRelic.Trigger.TURN_START, [DBEffect.energy(1)], &"torch")
	lamp.every = 2
	var amethyst := DBRelic.make(&"healing_stone", "Healing Stone", "Heal 6 HP after each victory.", DBRelic.Trigger.COMBAT_END,
		[DBEffect.make(DBEffect.Kind.HEAL, 6, ME)], &"amethyst")
	var topaz := DBRelic.make(&"topaz_charm", "Topaz Charm", "Gain 3 Block at the start of each turn.", DBRelic.Trigger.TURN_START, [DBEffect.block(3)], &"topaz")
	relics.assign([whetstone, ember, lamp, amethyst, topaz])


func _make_items() -> void:
	var ME := DBEffect.Target.SELF
	item_cards = {
		&"health_potion": DBCardData.make(&"use_health_potion", "Health Potion", 0, DBCardData.Type.SKILL, [DBEffect.make(DBEffect.Kind.HEAL, 15, ME)]),
		&"stamina_potion": DBCardData.make(&"use_stamina_potion", "Stamina Potion", 0, DBCardData.Type.SKILL, [DBEffect.energy(2)]),
		&"mana_potion": DBCardData.make(&"use_mana_potion", "Mana Potion", 0, DBCardData.Type.SKILL, [DBEffect.draw(3)]),
		&"antidote": DBCardData.make(&"use_antidote", "Antidote", 0, DBCardData.Type.SKILL, [DBEffect.make(DBEffect.Kind.CLEANSE, 0, ME)]),
		&"magic_essence": DBCardData.make(&"use_magic_essence", "Magic Essence", 0, DBCardData.Type.ATTACK, [DBEffect.damage(10, 0, 1, DBEffect.Target.ALL_OPPONENTS)]),
	}


## The CUSTOM effect of Obsidian Catalyst: doubles the target's Poison.
func handle_custom(effect: DBEffect, _source: DBFighter, targets: Array[DBFighter], _card: DBCard, events: Array[Dictionary]) -> void:
	if effect.custom_id != CATALYST:
		return
	var poison: DBStatus = statuses.poison
	for target in targets:
		var change := target.add_status(poison, target.get_stacks(&"poison"))
		if change > 0:
			events.append({"type": "status", "target": target, "status": poison, "stacks": change, "total": target.get_stacks(&"poison")})
