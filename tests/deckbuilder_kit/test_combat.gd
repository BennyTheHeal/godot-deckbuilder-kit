extends "res://tests/deckbuilder_kit/db_test_case.gd"


func test_start_draws_five_with_three_energy() -> void:
	var combat := make_combat()
	assert_eq(combat.hand.size(), 5, "hand")
	assert_eq(combat.draw_pile.size(), 5, "draw pile")
	assert_eq(combat.energy, 3, "energy")
	assert_eq(combat.turn, 1, "turn")
	assert_true(combat.enemies[0].intent != null, "the enemy announces an intent")


func test_strike_deals_damage_and_costs_energy() -> void:
	var combat := make_combat([], deck_of([strike()], 10))
	var enemy := combat.enemies[0]
	var result := combat.play_card(combat.hand[0], enemy)
	assert_done(result)
	assert_eq(enemy.hp, 34, "40 - 6")
	assert_eq(combat.energy, 2)
	assert_eq(combat.hand.size(), 4)
	assert_eq(combat.discard_pile.size(), 1)
	assert_eq(result.total_damage(enemy), 6)


func test_refusals() -> void:
	var combat := make_combat([], deck_of([strike()], 10))
	var enemy := combat.enemies[0]
	assert_combat(combat.play_card(combat.hand[0], null), DBResult.Code.INVALID_TARGET, "no target")
	for i in 3:
		combat.play_card(combat.hand[0], enemy)
	assert_combat(combat.play_card(combat.hand[0], enemy), DBResult.Code.NOT_ENOUGH_ENERGY, "4th strike")
	assert_combat(combat.play_card(combat.discard_pile[0], enemy), DBResult.Code.NOT_IN_HAND, "from the discard pile")
	var wound := DBCardData.make(&"wound", "Wound", 0, DBCardData.Type.STATUS)
	var card := DBCard.new(wound)
	combat.hand.append(card)
	assert_combat(combat.play_card(card), DBResult.Code.UNPLAYABLE, "wound")
	assert_eq(DBText.result_message(DBResult.failure(DBResult.Code.NOT_ENOUGH_ENERGY)), "Not enough energy.")


func test_block_absorbs_enemy_attack_then_resets() -> void:
	var combat := make_combat([dummy(40, [DBEffect.damage(8)])], deck_of([guard()], 10))
	combat.play_card(combat.hand[0])
	assert_eq(combat.player.block, 5)
	var result := combat.end_turn()
	assert_done(result)
	assert_eq(combat.player.hp, 47, "8 - 5 block")
	assert_eq(combat.player.block, 0, "block is gone at the start of the next turn")
	assert_eq(combat.turn, 2)
	assert_eq(combat.hand.size(), 5, "new hand")
	assert_eq(combat.energy, 3)


func test_discard_reshuffles_into_draw_pile() -> void:
	var combat := make_combat([dummy(999, [DBEffect.block(1)])], deck_of([guard()], 7))
	assert_eq(combat.draw_pile.size(), 2)
	var result := combat.end_turn()
	assert_eq(result.events_of("shuffle").size(), 1, "draw pile ran out")
	assert_eq(combat.hand.size(), 5)
	assert_eq(combat.draw_pile.size() + combat.discard_pile.size(), 2)


func test_victory_gives_gold_and_cards() -> void:
	var library := DBCardLibrary.new()
	for i in 5:
		library.add(DBCardData.make(StringName("c%d" % i), "C", 1, DBCardData.Type.SKILL, [DBEffect.block(3)]))
	var enemy_data := dummy(6)
	enemy_data.gold_min = 10
	enemy_data.gold_max = 10
	var combat := DBCombat.new()
	combat.library = library
	combat.bag = IKContainer.new(&"bag", 4, gold_db())
	add_to_tree(combat)
	var ended := []
	combat.combat_ended.connect(func(outcome: DBCombat.Outcome, rewards: Dictionary) -> void: ended.append([outcome, rewards]))
	combat.start(deck_of([strike()], 10), DBFighter.make_player("Hero", 50), [enemy_data], 3)
	combat.play_card(combat.hand[0], combat.enemies[0])
	assert_eq(combat.outcome, DBCombat.Outcome.VICTORY)
	assert_eq(combat.phase, DBCombat.Phase.ENDED)
	assert_eq(ended.size(), 1, "combat_ended once")
	assert_eq(combat.rewards.gold, 10)
	assert_eq(combat.bag.count(&"gold_coins"), 10, "gold paid into the bag")
	assert_eq((combat.rewards.cards as Array).size(), 3, "three card choices")
	assert_combat(combat.end_turn(), DBResult.Code.COMBAT_OVER)
	disconnect_all([combat])


func test_defeat() -> void:
	var combat := make_combat([dummy(40, [DBEffect.damage(30)])], deck_of([strike()], 10), 1, 20)
	combat.end_turn()
	assert_eq(combat.outcome, DBCombat.Outcome.DEFEAT)
	assert_eq(combat.player.hp, 0)
	assert_eq(combat.rewards, {})


func test_multi_hit_and_all_enemies() -> void:
	var twin := DBCardData.make(&"twin", "Twin", 1, DBCardData.Type.ATTACK, [DBEffect.damage(3, 1, 3)])
	var sweep := DBCardData.make(&"sweep", "Sweep", 1, DBCardData.Type.ATTACK, [DBEffect.damage(4, 0, 1, DBEffect.Target.ALL_OPPONENTS)])
	assert_eq(sweep.aim, DBCardData.Aim.NONE, "all-enemies cards need no target")
	var combat := make_combat([dummy(), dummy(), dummy()], deck_of([twin, sweep], 5))
	var a := combat.enemies[0]
	combat.play_card(force_in_hand(combat, twin), a)
	assert_eq(a.hp, 31, "3 hits of 3")
	combat.play_card(force_in_hand(combat, sweep))
	assert_eq(a.hp, 27)
	assert_eq(combat.enemies[1].hp, 36)
	assert_eq(combat.enemies[2].hp, 36)


func test_statuses_modify_damage() -> void:
	var might := DBStatus.make(&"might", "Might")
	might.damage_bonus = 1
	var weak := DBStatus.make(&"weak", "Weakened", true, true)
	weak.damage_dealt_mult = 0.75
	var exposed := DBStatus.make(&"exposed", "Exposed", true, true)
	exposed.damage_taken_mult = 1.5
	var combat := make_combat([], deck_of([strike()], 10))
	var enemy := combat.enemies[0]
	combat.player.add_status(might, 2)
	assert_eq(combat.compute_damage(combat.player, enemy, 6), 8, "6 + 2 might")
	enemy.add_status(exposed, 1)
	assert_eq(combat.compute_damage(combat.player, enemy, 6), 12, "(6+2) x 1.5")
	combat.player.add_status(weak, 1)
	assert_eq(combat.compute_damage(combat.player, enemy, 6), 9, "8 x 0.75 x 1.5 = 9")
	assert_eq(combat.get_card_amount(combat.hand[0], 0, enemy), 9, "card preview")
	assert_eq(combat.get_card_amount(combat.hand[0], 0), 6, "no target: 8 x 0.75")
	assert_true(DBText.describe_card(combat.hand[0], combat, enemy).contains("[color=%s]9[/color]" % DBText.BETTER), "boosted in green")


func test_decaying_status_lasts_its_stacks() -> void:
	var exposed := DBStatus.make(&"exposed", "Exposed", true, true)
	exposed.damage_taken_mult = 1.5
	var bash := DBCardData.make(&"bash", "Bash", 2, DBCardData.Type.ATTACK, [DBEffect.damage(8), DBEffect.apply(exposed, 2)])
	var combat := make_combat([dummy(99, [DBEffect.block(1)])], deck_of([bash], 10))
	var enemy := combat.enemies[0]
	combat.play_card(combat.hand[0], enemy)
	assert_eq(enemy.get_stacks(&"exposed"), 2)
	combat.end_turn()
	assert_eq(enemy.get_stacks(&"exposed"), 1, "one stack lost at the end of the enemy's turn")
	combat.end_turn()
	assert_false(enemy.has_status(&"exposed"), "gone")


func test_poison_ticks_and_decays() -> void:
	var poison := DBStatus.make(&"poison", "Poison", true, true)
	poison.damage_per_turn = 1
	var dart := DBCardData.make(&"dart", "Dart", 1, DBCardData.Type.SKILL, [DBEffect.apply(poison, 5)])
	var combat := make_combat([dummy(40, [DBEffect.block(10)])], deck_of([dart], 10))
	var enemy := combat.enemies[0]
	combat.play_card(combat.hand[0], enemy)
	var result := combat.end_turn()
	assert_eq(enemy.hp, 35, "5 poison ignores block")
	assert_eq(enemy.get_stacks(&"poison"), 4)
	assert_eq(result.events_of("lose_hp").size(), 1)


func test_poison_can_win_the_combat() -> void:
	var poison := DBStatus.make(&"poison", "Poison", true, true)
	poison.damage_per_turn = 1
	var dart := DBCardData.make(&"dart", "Dart", 0, DBCardData.Type.SKILL, [DBEffect.apply(poison, 9)])
	var combat := make_combat([dummy(8)], deck_of([dart], 10))
	combat.play_card(combat.hand[0], combat.enemies[0])
	combat.end_turn()
	assert_eq(combat.outcome, DBCombat.Outcome.VICTORY)
	assert_eq(combat.player.hp, 50, "the enemy died before attacking")


func test_thorns_hurt_attackers() -> void:
	var thorns := DBStatus.make(&"thorns", "Thorns")
	thorns.thorns = 3
	var combat := make_combat([dummy(40, [DBEffect.damage(2, 0, 2)])], deck_of([strike()], 10))
	combat.player.add_status(thorns, 1)
	combat.end_turn()
	assert_eq(combat.enemies[0].hp, 34, "two hits, 3 thorns each")
	assert_eq(combat.player.hp, 46)


func test_plating_and_fortress() -> void:
	var plating := DBStatus.make(&"plating", "Plating")
	plating.block_per_turn = 4
	var fortress := DBStatus.make(&"fortress", "Fortress")
	fortress.keeps_block = true
	var combat := make_combat([dummy(40, [DBEffect.damage(1)])], deck_of([guard()], 10))
	combat.player.add_status(plating, 1)
	combat.end_turn()
	assert_eq(combat.player.hp, 50, "4 block from plating took the hit")
	assert_eq(combat.player.block, 0, "block removed at the start of the turn")
	combat.player.add_status(fortress, 1)
	combat.play_card(combat.hand[0])
	combat.end_turn()
	assert_eq(combat.player.block, 5 + 4 - 1, "kept: 5 guard + 4 plating - 1 hit")


func test_agility_and_fragile() -> void:
	var agility := DBStatus.make(&"agility", "Agility")
	agility.block_bonus = 2
	var fragile := DBStatus.make(&"fragile", "Fragile", true, true)
	fragile.block_gain_mult = 0.75
	var combat := make_combat([], deck_of([guard()], 10))
	combat.player.add_status(agility, 1)
	combat.player.add_status(fragile, 1)
	combat.play_card(combat.hand[0])
	assert_eq(combat.player.block, 5, "(5 + 2) x 0.75 = 5.25")


func test_upgrade_changes_amount_cost_and_keywords() -> void:
	var data := DBCardData.make(&"focus", "Focus", 1, DBCardData.Type.SKILL, [DBEffect.draw(2, 1)])
	data.upgraded_cost = 0
	data.exhaust = true
	data.upgrade_removes_exhaust = true
	var card := DBCard.new(data)
	assert_eq(card.get_cost(), 1)
	assert_true(card.is_exhaust())
	assert_true(card.upgrade())
	assert_false(card.upgrade(), "only once")
	assert_eq(card.get_cost(), 0)
	assert_eq(card.get_amount(0), 3)
	assert_false(card.is_exhaust())
	assert_eq(card.get_title(), "Focus+")
	assert_eq(DBText.describe_card(card), "Draw 3 cards.")


func test_exhaust_ethereal_retain() -> void:
	var burst := DBCardData.make(&"burst", "Burst", 0, DBCardData.Type.SKILL, [DBEffect.energy(1)])
	burst.exhaust = true
	var ghost := DBCardData.make(&"ghost", "Ghost", 1, DBCardData.Type.SKILL, [DBEffect.block(1)])
	ghost.ethereal = true
	var aim := DBCardData.make(&"aim", "Aim", 1, DBCardData.Type.SKILL, [DBEffect.block(1)])
	aim.retain = true
	var deck := deck_of([burst, ghost, aim], 1)
	for i in 7:
		deck.add(guard())
	var combat := make_combat([dummy(99, [DBEffect.block(1)])], deck, 4)
	for data in [burst, ghost, aim]:
		force_in_hand(combat, data)
	combat.play_card(first_in_hand(combat, &"burst"))
	assert_eq(combat.energy, 4, "+1 energy")
	assert_eq(combat.exhaust_pile.size(), 1, "burst exhausted")
	combat.end_turn()
	assert_eq(combat.exhaust_pile.size(), 2, "ghost faded at the end of the turn")
	assert_true(first_in_hand(combat, &"aim") != null, "aim retained")
	assert_true(DBText.describe_card(first_in_hand(combat, &"aim")).contains("Retain"))


func test_innate_cards_are_in_the_opening_hand() -> void:
	var opener := DBCardData.make(&"opener", "Opener", 0, DBCardData.Type.SKILL, [DBEffect.draw(1)])
	opener.innate = true
	var deck := deck_of([guard()], 20)
	deck.add(opener)
	deck.add(opener)
	for seed_value in [1, 2, 3, 4, 5]:
		var combat := make_combat([], deck, seed_value)
		assert_eq(combat.hand.filter(func(c: DBCard) -> bool: return c.data.id == &"opener").size(), 2, "seed %d" % seed_value)


func test_hand_limit_burns_extra_draws() -> void:
	var study := DBCardData.make(&"study", "Study", 0, DBCardData.Type.SKILL, [DBEffect.draw(9)])
	var combat := make_combat([], deck_of([study], 20))
	combat.play_card(combat.hand[0])
	assert_eq(combat.hand.size(), 10, "hand limit")
	assert_true(combat.last_events.any(func(e: Dictionary) -> bool: return e.type == "burn"), "extra cards burned")


func test_powers_leave_the_piles_and_stay_in_effect() -> void:
	var might := DBStatus.make(&"might", "Might")
	might.damage_bonus = 1
	var rage := DBCardData.make(&"rage", "Rage", 1, DBCardData.Type.POWER, [DBEffect.apply(might, 2, DBEffect.Target.SELF)])
	assert_eq(rage.aim, DBCardData.Aim.NONE)
	var deck := deck_of([rage], 1)
	for i in 9:
		deck.add(strike())
	var combat := make_combat([], deck)
	combat.play_card(force_in_hand(combat, rage))
	assert_eq(combat.powers.size(), 1)
	assert_eq(combat.player.get_stacks(&"might"), 2)
	combat.play_card(first_in_hand(combat, &"strike"), combat.enemies[0])
	assert_eq(combat.enemies[0].hp, 32, "6 + 2")


func test_enemy_adds_wounds_to_discard() -> void:
	var wound := DBCardData.make(&"wound", "Wound", 0, DBCardData.Type.STATUS)
	var combat := make_combat([dummy(40, [DBEffect.add_card(wound, 2)])])
	combat.end_turn()
	var all: Array[DBCard] = []
	all.append_array(combat.hand)
	all.append_array(combat.draw_pile)
	all.append_array(combat.discard_pile)
	assert_eq(all.filter(func(c: DBCard) -> bool: return c.data == wound).size(), 2)


func test_intent_patterns() -> void:
	var a := DBIntent.make(&"a", "A", [DBEffect.damage(1)])
	var b := DBIntent.make(&"b", "B", [DBEffect.block(1)])
	var c := DBIntent.make(&"c", "C", [DBEffect.block(2)])
	var cycler := DBEnemyData.make(&"cycler", "Cycler", 99, [a, b, c])
	var combat := make_combat([cycler], deck_of([guard()], 10))
	var enemy := combat.enemies[0]
	var seen := []
	for i in 4:
		seen.append(enemy.intent.id)
		combat.end_turn()
	assert_eq(seen, [&"a", &"b", &"c", &"a"])
	var random := DBEnemyData.make(&"rng", "Rng", 99, [a, b], &"", DBEnemyData.Pattern.RANDOM_NO_REPEAT)
	combat = make_combat([random], deck_of([guard()], 10), 7)
	enemy = combat.enemies[0]
	for i in 6:
		var before := enemy.intent.id
		combat.end_turn()
		assert_true(enemy.intent.id != before, "never twice in a row")


func test_intent_kind_and_preview() -> void:
	var weak := DBStatus.make(&"weak", "Weakened", true, true)
	weak.damage_dealt_mult = 0.75
	var intent := DBIntent.make(&"slash", "Slash", [DBEffect.damage(4, 0, 2), DBEffect.apply(weak, 1)])
	assert_eq(intent.get_kind(), DBIntent.Kind.ATTACK_DEBUFF)
	assert_eq(DBIntent.make(&"x", "X", [DBEffect.block(3)]).get_kind(), DBIntent.Kind.DEFEND)
	var combat := make_combat([DBEnemyData.make(&"e", "E", 30, [intent])])
	var preview := combat.preview_intent(combat.enemies[0])
	assert_eq(preview.total, 8)
	assert_eq(DBText.intent_label(preview), "4×2")


func test_same_seed_same_combat() -> void:
	var a := make_combat([], null, 42)
	var b := make_combat([], null, 42)
	var ids_a := a.hand.map(func(c: DBCard) -> StringName: return c.data.id)
	var ids_b := b.hand.map(func(c: DBCard) -> StringName: return c.data.id)
	assert_eq(ids_a, ids_b)


func test_deck_is_not_changed_by_combat() -> void:
	var deck := deck_of([strike()], 10)
	var combat := make_combat([], deck)
	combat.hand[0].upgrade()
	assert_eq(deck.get_upgradable().size(), 10, "combat copies")
	assert_true(combat.hand[0].source != null)


func test_player_keeps_hp_between_combats() -> void:
	var player := DBFighter.make_player("Hero", 50)
	var combat := DBCombat.new()
	add_to_tree(combat)
	combat.start(deck_of([guard()], 10), player, [dummy(40, [DBEffect.damage(10)])], 1)
	combat.end_turn()
	assert_eq(player.hp, 40)
	combat.start(deck_of([guard()], 10), player, [dummy()], 1)
	assert_eq(player.hp, 40, "HP carries over")
