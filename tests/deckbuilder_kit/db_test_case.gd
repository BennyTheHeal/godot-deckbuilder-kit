extends RefCounted
## Base class for Deckbuilder Kit tests: assertions and shared fixtures.

var _failures := PackedStringArray()
var _nodes: Array[Node] = []


func get_failures() -> PackedStringArray:
	return _failures


func get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Adds [param node] to the scene root; it is freed after the test.
func add_to_tree(node: Node) -> Node:
	get_tree().root.add_child(node)
	_nodes.append(node)
	return node


func wait_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame


## Called by the runner after each test.
func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	await get_tree().process_frame


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%sexpected <%s> but got <%s>" % [message + ": " if message else "", expected, actual])


func assert_ok(result: IKResult, message: String = "") -> void:
	if result == null or not result.ok:
		fail("%sexpected OK, got %s" % [message + ": " if message else "", result])


func assert_code(result: IKResult, code: IKResult.Code, message: String = "") -> void:
	if result == null or result.code != code:
		fail("%sexpected %s, got %s" % [message + ": " if message else "", IKResult.Code.keys()[code], result])


## Disconnects every signal of [param objects]. Call at the end of tests whose
## lambdas capture the emitter, otherwise the reference cycle leaks.
func disconnect_all(objects: Array) -> void:
	for object: Object in objects:
		for info in object.get_signal_list():
			for connection in object.get_signal_connection_list(info.name):
				object.disconnect(info.name, connection.callable)


# --- Fixtures ----------------------------------------------------------------

func assert_combat(result: DBResult, code: DBResult.Code, message: String = "") -> void:
	if result == null or result.code != code:
		fail("%sexpected %s, got %s" % [message + ": " if message else "", DBResult.Code.keys()[code], result])


func assert_done(result: DBResult, message: String = "") -> void:
	if result == null or not result.ok:
		fail("%sexpected OK, got %s" % [message + ": " if message else "", result])


func strike(amount: int = 6, upgrade: int = 3) -> DBCardData:
	return DBCardData.make(&"strike", "Strike", 1, DBCardData.Type.ATTACK, [DBEffect.damage(amount, upgrade)], &"sword", DBCardData.Rarity.STARTER)


func guard(amount: int = 5) -> DBCardData:
	return DBCardData.make(&"guard", "Guard", 1, DBCardData.Type.SKILL, [DBEffect.block(amount, 3)], &"shield", DBCardData.Rarity.STARTER)


## An enemy that always plays the same intent.
func dummy(hp: int = 40, intent_effects: Array = [], id: StringName = &"dummy") -> DBEnemyData:
	var effects := intent_effects if not intent_effects.is_empty() else [DBEffect.damage(5)]
	return DBEnemyData.make(id, String(id).capitalize(), hp, [DBIntent.make(&"hit", "Hit", effects)])


func deck_of(datas: Array, copies: int = 1) -> DBDeck:
	var deck := DBDeck.new()
	for data: DBCardData in datas:
		for i in copies:
			deck.add(data)
	return deck


## A started combat: 5 Strikes and 5 Guards against [param enemy_datas] (one dummy by default).
func make_combat(enemy_datas: Array = [], deck: DBDeck = null, seed_value: int = 1, hp: int = 50) -> DBCombat:
	var combat := DBCombat.new()
	add_to_tree(combat)
	var player := DBFighter.make_player("Hero", hp)
	combat.start(deck if deck != null else deck_of([strike(), guard()], 5), player,
		enemy_datas if not enemy_datas.is_empty() else [dummy()], seed_value)
	return combat


func first_in_hand(combat: DBCombat, card_id: StringName) -> DBCard:
	for card in combat.hand:
		if card.data.id == card_id:
			return card
	return null


## Moves the first card made from [param data] into the hand (tests that need a given card).
func force_in_hand(combat: DBCombat, data: DBCardData) -> DBCard:
	var card := first_in_hand(combat, data.id)
	if card != null:
		return card
	for pile: Array[DBCard] in [combat.draw_pile, combat.discard_pile]:
		for candidate in pile:
			if candidate.data == data:
				pile.erase(candidate)
				combat.hand.append(candidate)
				return candidate
	return null


func gold_db() -> IKItemDatabase:
	var db := IKItemDatabase.new()
	for id: StringName in [&"gold_coins", &"health_potion", &"bomb"]:
		var item := IKItemDefinition.new()
		item.id = id
		item.max_stack = 999
		db.add_item(item)
	return db

