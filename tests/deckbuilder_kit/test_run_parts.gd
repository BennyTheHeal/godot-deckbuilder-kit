extends "res://tests/deckbuilder_kit/db_test_case.gd"
## Relics, items, custom effects, the library and saving.


func test_relic_every_third_attack() -> void:
	var relic := DBRelic.make(&"ember", "Ember Stone", "", DBRelic.Trigger.CARD_PLAYED,
		[DBEffect.damage(4, 0, 1, DBEffect.Target.ALL_OPPONENTS)], &"coal")
	relic.card_type = DBCardData.Type.ATTACK
	relic.every = 3
	var combat := DBCombat.new()
	combat.relics.append(relic)
	add_to_tree(combat)
	combat.start(deck_of([strike()], 10), DBFighter.make_player("Hero", 50), [dummy(99)], 1)
	var enemy := combat.enemies[0]
	combat.play_card(combat.hand[0], enemy)
	combat.play_card(combat.hand[0], enemy)
	assert_eq(enemy.hp, 87)
	var result := combat.play_card(combat.hand[0], enemy)
	assert_eq(enemy.hp, 77, "6 + 4 from the relic")
	assert_eq(result.events_of("relic").size(), 1)
	assert_eq(combat.get_relic_count(relic), 3)


func test_relic_combat_start_and_end() -> void:
	var might := DBStatus.make(&"might", "Might")
	might.damage_bonus = 1
	var whetstone := DBRelic.make(&"whetstone", "Whetstone", "", DBRelic.Trigger.COMBAT_START, [DBEffect.apply(might, 1, DBEffect.Target.SELF)])
	var healing := DBRelic.make(&"pendant", "Pendant", "", DBRelic.Trigger.COMBAT_END, [DBEffect.make(DBEffect.Kind.HEAL, 6, DBEffect.Target.SELF)])
	var combat := DBCombat.new()
	combat.relics.assign([whetstone, healing])
	add_to_tree(combat)
	var player := DBFighter.make_player("Hero", 50)
	player.hp = 30
	combat.start(deck_of([strike()], 10), player, [dummy(7)], 1)
	assert_eq(player.get_stacks(&"might"), 1)
	combat.play_card(combat.hand[0], combat.enemies[0])
	assert_eq(combat.outcome, DBCombat.Outcome.VICTORY)
	assert_eq(player.hp, 36, "healed after the fight")


func test_relic_energy_each_turn() -> void:
	var lamp := DBRelic.make(&"lamp", "Lamp", "", DBRelic.Trigger.TURN_START, [DBEffect.energy(1)])
	var combat := DBCombat.new()
	combat.relics.append(lamp)
	add_to_tree(combat)
	combat.start(deck_of([guard()], 10), DBFighter.make_player("Hero", 50), [dummy()], 1)
	assert_eq(combat.energy, 4)
	combat.end_turn()
	assert_eq(combat.energy, 4)


func test_items_from_the_bag() -> void:
	var combat := DBCombat.new()
	var bag := IKContainer.new(&"bag", 4, gold_db())
	bag.add(&"health_potion", 1)
	bag.add(&"bomb", 1)
	combat.bag = bag
	combat.item_cards = {
		&"health_potion": DBCardData.make(&"potion", "Potion", 0, DBCardData.Type.SKILL, [DBEffect.make(DBEffect.Kind.HEAL, 15, DBEffect.Target.SELF)]),
		&"bomb": DBCardData.make(&"bomb", "Bomb", 0, DBCardData.Type.ATTACK, [DBEffect.damage(10, 0, 1, DBEffect.Target.ALL_OPPONENTS)]),
	}
	add_to_tree(combat)
	var player := DBFighter.make_player("Hero", 50)
	player.hp = 20
	combat.start(deck_of([guard()], 10), player, [dummy(), dummy()], 1)
	assert_done(combat.use_item(&"health_potion"))
	assert_eq(player.hp, 35)
	assert_eq(bag.count(&"health_potion"), 0, "taken from the bag")
	assert_eq(combat.energy, 3, "items cost no energy")
	assert_combat(combat.use_item(&"health_potion"), DBResult.Code.NO_ITEM, "none left")
	assert_combat(combat.use_item(&"gold_coins"), DBResult.Code.NO_ITEM, "not a combat item")
	assert_done(combat.use_item(&"bomb"))
	assert_eq(combat.enemies[1].hp, 30)


func test_item_needing_a_target_is_kept_when_refused() -> void:
	var combat := DBCombat.new()
	var bag := IKContainer.new(&"bag", 4, gold_db())
	bag.add(&"bomb", 1)
	combat.bag = bag
	combat.item_cards = {&"bomb": DBCardData.make(&"bomb", "Bomb", 0, DBCardData.Type.ATTACK, [DBEffect.damage(10)])}
	add_to_tree(combat)
	combat.start(deck_of([guard()], 10), DBFighter.make_player("Hero", 50), [dummy()], 1)
	assert_combat(combat.use_item(&"bomb"), DBResult.Code.INVALID_TARGET)
	assert_eq(bag.count(&"bomb"), 1)


func test_custom_effect() -> void:
	var poison := DBStatus.make(&"poison", "Poison", true, true)
	poison.damage_per_turn = 1
	var double := DBCardData.make(&"catalyst", "Catalyst", 1, DBCardData.Type.SKILL, [DBEffect.custom(&"double_poison")])
	assert_eq(double.aim, DBCardData.Aim.ONE_ENEMY, "custom AIMED effects need a target")
	var combat := make_combat([], deck_of([double], 10))
	combat.custom_effect.connect(func(effect: DBEffect, _source: DBFighter, targets: Array[DBFighter], _card: DBCard, events: Array[Dictionary]) -> void:
		if effect.custom_id == &"double_poison":
			for target in targets:
				var change := target.add_status(poison, target.get_stacks(&"poison"))
				events.append({"type": "status", "target": target, "status": poison, "stacks": change, "total": target.get_stacks(&"poison")}))
	var enemy := combat.enemies[0]
	enemy.add_status(poison, 4)
	var result := combat.play_card(combat.hand[0], enemy)
	assert_eq(enemy.get_stacks(&"poison"), 8)
	assert_eq(result.events_of("status").size(), 1, "custom events reach the result")
	disconnect_all([combat])


func test_cleanse_removes_debuffs() -> void:
	var weak := DBStatus.make(&"weak", "Weakened", true, true)
	var might := DBStatus.make(&"might", "Might")
	var purify := DBCardData.make(&"purify", "Purify", 1, DBCardData.Type.SKILL, [DBEffect.make(DBEffect.Kind.CLEANSE, 0, DBEffect.Target.SELF)])
	var combat := make_combat([], deck_of([purify], 10))
	combat.player.add_status(weak, 3)
	combat.player.add_status(might, 2)
	combat.play_card(combat.hand[0])
	assert_false(combat.player.has_status(&"weak"))
	assert_eq(combat.player.get_stacks(&"might"), 2, "buffs stay")


func test_library_offer() -> void:
	var library := DBCardLibrary.new()
	library.add(strike())
	for i in 4:
		library.add(DBCardData.make(StringName("common%d" % i), "C", 1, DBCardData.Type.SKILL, [DBEffect.block(1)]))
	var rare := DBCardData.make(&"rare", "R", 1, DBCardData.Type.SKILL, [DBEffect.block(9)], &"", DBCardData.Rarity.RARE)
	library.add(rare)
	library.add(DBCardData.make(&"wound", "Wound", 0, DBCardData.Type.STATUS, [], &"", DBCardData.Rarity.SPECIAL))
	assert_eq(library.get_reward_pool().size(), 5, "no starters, no wounds")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 20:
		var offer := library.offer(3, rng)
		assert_eq(offer.size(), 3)
		assert_false(offer[0] == offer[1] or offer[1] == offer[2] or offer[0] == offer[2], "all different")
		assert_false(offer.has(library.get_card(&"strike")), "no starter")
	var rares := 0
	for i in 200:
		if library.offer(1, rng, 1000.0).has(rare):
			rares += 1
	assert_true(rares > 150, "the rare bonus works (%d / 200)" % rares)
	assert_eq(library.validate(), PackedStringArray())


func test_deck_save_and_load() -> void:
	var library := DBCardLibrary.new()
	library.add(strike())
	library.add(guard())
	var deck := deck_of([strike(), guard()], 2)
	deck.cards.clear()
	deck.add(library.get_card(&"strike"))
	deck.add(library.get_card(&"guard"), true)
	var saved := deck.to_save()
	saved.append({"id": "gone", "upgraded": false})
	var loaded := DBDeck.new()
	var unknown := loaded.load_save(JSON.parse_string(JSON.stringify(saved)), library)
	assert_eq(loaded.size(), 2)
	assert_eq(unknown, PackedStringArray(["gone"]))
	assert_true(loaded.cards[1].upgraded)
	assert_eq(loaded.count(&"strike"), 1)


func test_deck_edits() -> void:
	var deck := deck_of([strike(), guard()], 3)
	var changes := [0]
	deck.changed.connect(func() -> void: changes[0] += 1)
	assert_true(deck.upgrade(deck.cards[0]))
	assert_false(deck.upgrade(deck.cards[0]), "already upgraded")
	assert_eq(deck.get_upgradable().size(), 5)
	assert_true(deck.remove(deck.cards[1]))
	assert_eq(deck.size(), 5)
	assert_eq(changes[0], 2)
	var sorted := deck.get_sorted()
	assert_eq(sorted[0].data.type, DBCardData.Type.ATTACK)
	disconnect_all([deck])


func test_card_validation() -> void:
	var broken := DBCardData.make(&"broken", "Broken", 1, DBCardData.Type.SKILL, [DBEffect.apply(null, 1)])
	assert_false(broken.validate().is_empty())


func test_status_descriptions() -> void:
	var poison := DBStatus.make(&"poison", "Poison", true, true)
	poison.damage_per_turn = 1
	assert_eq(poison.get_description(4), "Loses 4 HP at the start of its turn. Lasts 4 turns.")
	var custom := DBStatus.make(&"x", "X")
	custom.description = "Has {n} charges."
	assert_eq(custom.get_description(3), "Has 3 charges.")


func test_fighter_save() -> void:
	var player := DBFighter.make_player("Hero", 60)
	player.hp = 21
	var other := DBFighter.make_player("?", 1)
	other.load_save(player.to_save())
	assert_eq(other.hp, 21)
	assert_eq(other.max_hp, 60)
	assert_eq(other.title, "Hero")
