extends "res://tests/deckbuilder_kit/db_test_case.gd"
## The combat screen and the demo: they build, react to the combat and finish.


func _make_view(combat: DBCombat) -> DBCombatView:
	var view := DBCombatView.new()
	view.event_delay = 0.0
	view.size = Vector2(1280, 720)
	view.combat = combat
	add_to_tree(view)
	return view


func test_view_builds_hand_and_fighters() -> void:
	var combat := DBCombat.new()
	add_to_tree(combat)
	var view := _make_view(combat)
	combat.start(deck_of([strike(), guard()], 5), DBFighter.make_player("Hero", 50), [dummy(), dummy()], 1)
	await wait_frames(3)
	assert_eq(view.get_hand_views().size(), 5, "hand views")
	assert_true(view.get_fighter_view(combat.enemies[1]) != null, "enemy views")
	assert_true(view.get_fighter_view(combat.player) != null, "player view")


func test_view_plays_card_and_ends_turn() -> void:
	var combat := DBCombat.new()
	add_to_tree(combat)
	var view := _make_view(combat)
	combat.start(deck_of([strike()], 10), DBFighter.make_player("Hero", 50), [dummy(40, [DBEffect.damage(3)])], 1)
	await wait_frames(2)
	var result := view.play(combat.hand[0], combat.enemies[0])
	assert_done(result)
	await get_tree().create_timer(0.3).timeout
	assert_eq(view.get_hand_views().size(), 4)
	assert_eq(view.mode, DBCombatView.Mode.IDLE)
	view.end_turn()
	await get_tree().create_timer(1.0).timeout
	assert_eq(combat.turn, 2)
	assert_eq(view.mode, DBCombatView.Mode.IDLE, "back to the player")
	assert_eq(view.get_hand_views().size(), 5, "new hand drawn")
	assert_eq(combat.player.hp, 47)


func test_view_refuses_without_energy() -> void:
	var combat := DBCombat.new()
	add_to_tree(combat)
	var view := _make_view(combat)
	var refusals := []
	view.refused.connect(func(_r: DBResult, text: String) -> void: refusals.append(text))
	combat.start(deck_of([strike()], 10), DBFighter.make_player("Hero", 50), [dummy(99)], 1)
	await wait_frames(2)
	for i in 3:
		view.play(combat.hand[0], combat.enemies[0])
		await get_tree().create_timer(0.15).timeout
	view.play(combat.hand[0], combat.enemies[0])
	assert_eq(refusals, ["Not enough energy."])


func test_view_victory_offers_cards() -> void:
	var library := DBCardLibrary.new()
	for i in 4:
		library.add(DBCardData.make(StringName("c%d" % i), "C", 1, DBCardData.Type.SKILL, [DBEffect.block(3)]))
	var combat := DBCombat.new()
	combat.library = library
	add_to_tree(combat)
	var view := _make_view(combat)
	var done := []
	view.finished.connect(func(outcome: DBCombat.Outcome, picked: DBCardData) -> void: done.append([outcome, picked]))
	combat.start(deck_of([strike()], 10), DBFighter.make_player("Hero", 50), [dummy(5)], 1)
	await wait_frames(2)
	view.play(combat.hand[0], combat.enemies[0])
	await get_tree().create_timer(1.2).timeout
	assert_true(view.get_picker().is_open(), "card reward shown")
	assert_eq(view.get_picker().get_views().size(), 3)
	view.get_picker().pick(1)
	assert_eq(done.size(), 1)
	assert_eq(done[0][0], DBCombat.Outcome.VICTORY)
	assert_true(done[0][1] is DBCardData, "picked card")


func test_card_view_text() -> void:
	var view := DBCardView.new().setup(DBCard.new(strike(), true), null)
	add_to_tree(view)
	assert_eq(view.card.get_title(), "Strike+")
	assert_true(view._text.text.contains("Deal 9 damage."), view._text.text)


func test_demo_runs_a_fight() -> void:
	var demo: Control = load("res://demo/cards/cards_demo.tscn").instantiate()
	add_to_tree(demo)
	demo.size = Vector2(1280, 720)
	await wait_frames(3)
	demo.view.event_delay = 0.0
	demo.enter_step(0)
	await wait_frames(3)
	var combat: DBCombat = demo.combat
	assert_true(combat.is_running(), "first fight started")
	# Play every affordable card on the first living enemy, then end the turn, until it ends.
	for round in 30:
		if not combat.is_running():
			break
		for i in 10:
			var playable := combat.hand.filter(func(c: DBCard) -> bool: return c.is_playable() and c.get_cost() <= combat.energy)
			if playable.is_empty() or not combat.is_running():
				break
			var alive := combat.get_alive_enemies()
			demo.view.play(playable[0], alive[0] if not alive.is_empty() else null)
			await get_tree().create_timer(0.05).timeout
		if combat.is_running():
			demo.view.end_turn()
			await get_tree().create_timer(0.4).timeout
	assert_false(combat.is_running(), "the fight ended")
	await get_tree().create_timer(1.0).timeout
	if combat.outcome == DBCombat.Outcome.VICTORY:
		assert_true(demo.view.get_picker().is_open(), "reward picker")
		demo.view.get_picker().pick(0)
		assert_eq(demo.step, 1, "next step")
		assert_eq(demo.deck.size(), 11, "reward card added")
