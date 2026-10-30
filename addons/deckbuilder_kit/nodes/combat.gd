class_name DBCombat
extends Node
## A card combat: the player against one or more enemies. Each turn the player gets
## energy and draws cards, plays them on the enemies, then ends the turn; every enemy
## plays the intent it announced and picks the next one. Draw pile, hand, discard pile and
## exhaust pile, statuses in stacks, relics, items from an Inventory Kit bag, and card
## and gold rewards. Same seed, same combat.
##
## Every action returns a [DBResult] whose [member DBResult.events] tell what happened, in
## order (the view plays them back). Event types and fields ("source" and "target" are
## [DBFighter]s, "card" a [DBCard]):
## [codeblock]
## turn {turn}                  enemy_turn {}
## draw {card}                  burn {card}        (hand full: straight to the discard pile)
## shuffle {count}              discard {card}     exhaust {card}    retain {card}
## play {card, target, cost}    item {item_id, target}               relic {relic}
## energy {amount, energy}      block {target, amount, block}        block_lost {target, amount}
## damage {source, target, amount, blocked, hp_loss, hp, block, thorns}
## lose_hp {target, amount, hp, status}                              heal {target, amount, hp}
## status {target, status, stacks, total}                            add_card {card, pile}
## intent {source, intent}      next_intent {source, intent}         defeated {target}
## victory {}                   defeat {}
## [/codeblock]

signal combat_started
## The player's turn begins (after the draw).
signal turn_started(turn: int)
signal enemy_turn_started
signal card_drawn(card: DBCard)
signal card_played(card: DBCard, target: DBFighter, result: DBResult)
signal item_used(item_id: StringName, target: DBFighter, result: DBResult)
## A pile or the hand changed.
signal piles_changed
signal energy_changed(energy: int)
## Enemies changed what they announce.
signal intents_changed
## A CUSTOM effect: do what it means, and append your own events to [param events] if the
## view should show something.
signal custom_effect(effect: DBEffect, source: DBFighter, targets: Array[DBFighter], card: DBCard, events: Array[Dictionary])
## Victory or defeat. [param rewards]: "gold" (paid into the bag if there is one),
## "gold_left_behind", "cards" (the card choices, Array[DBCardData]).
signal combat_ended(outcome: Outcome, rewards: Dictionary)

enum Phase { NONE, PLAYER, ENEMY, ENDED }
enum Outcome { NONE, VICTORY, DEFEAT }

@export_range(0, 20) var max_energy := 3
@export_range(0, 20) var draw_per_turn := 5
@export_range(1, 30) var hand_limit := 10
@export_group("Rewards")
## Card rewards come from here. Empty = no card reward.
@export var library: DBCardLibrary
@export_range(0, 10) var reward_card_count := 3
## Added to the RARE weight of the card reward when an enemy of the fight is an elite.
@export_range(0.0, 100.0, 1.0) var elite_rare_bonus := 20.0
## The item that holds the gold in [member bag].
@export var gold_item: StringName = &"gold_coins"

## The player's relics (keep the same array from fight to fight).
var relics: Array[DBRelic] = []
## Inventory Kit container: items for [method use_item], gold rewards go in.
var bag: IKContainer
## Which items can be used in combat, and what they do: item id -> a card (cost ignored,
## never in a pile). Its aim tells whether it needs an enemy.
var item_cards: Dictionary[StringName, DBCardData] = {}

var player: DBFighter
var enemies: Array[DBFighter] = []
var draw_pile: Array[DBCard] = []
var hand: Array[DBCard] = []
var discard_pile: Array[DBCard] = []
var exhaust_pile: Array[DBCard] = []
## Powers played this combat (they stay in effect, out of every pile).
var powers: Array[DBCard] = []
var energy := 0
var turn := 0
var phase: Phase = Phase.NONE
var outcome: Outcome = Outcome.NONE
var rewards: Dictionary = {}
var cards_played_this_turn := 0
var rng := RandomNumberGenerator.new()
## The events of the last start, card, item or end of turn.
var last_events: Array[Dictionary] = []

var _events: Array[Dictionary] = []
var _relic_counts: Dictionary = {}  # DBRelic -> int
var _ending := false


# --- Setup -------------------------------------------------------------------

## Starts a combat with a copy of [param deck] (the deck itself never changes). The
## player's HP carries over; block and statuses start from zero. [param seed_value] -1 =
## random.
func start(deck: DBDeck, p_player: DBFighter, enemy_datas: Array, seed_value: int = -1) -> DBResult:
	if p_player == null or enemy_datas.is_empty():
		return DBResult.failure(DBResult.Code.INVALID_ARGUMENT, "start() needs a player and at least one enemy")
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	_events = []
	player = p_player
	player.block = 0
	player.clear_statuses()
	enemies.clear()
	for i in enemy_datas.size():
		var enemy := DBFighter.from_enemy(enemy_datas[i], rng)
		enemy.slot = i
		enemies.append(enemy)
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	powers.clear()
	for card in deck.cards:
		draw_pile.append(card.copy())
	_shuffle(draw_pile)
	# Innate cards on top of the draw pile (the end of the array).
	var innate := draw_pile.filter(func(c: DBCard) -> bool: return c.is_innate())
	for card: DBCard in innate:
		draw_pile.erase(card)
		draw_pile.append(card)
	turn = 0
	energy = 0
	outcome = Outcome.NONE
	rewards = {}
	_relic_counts.clear()
	_ending = false
	phase = Phase.PLAYER
	for enemy in enemies:
		_choose_intent(enemy)
	combat_started.emit()
	_fire_relics(DBRelic.Trigger.COMBAT_START)
	if phase != Phase.ENDED:
		_start_player_turn(true, innate.size())
	return _finish()


func is_running() -> bool:
	return phase == Phase.PLAYER or phase == Phase.ENEMY


func get_alive_enemies() -> Array[DBFighter]:
	var alive: Array[DBFighter] = []
	for enemy in enemies:
		if enemy.is_alive():
			alive.append(enemy)
	return alive


# --- Player actions ----------------------------------------------------------

func can_play(card: DBCard, target: DBFighter = null) -> DBResult:
	var check := _check_turn()
	if not check.ok:
		return check
	if card == null or not hand.has(card):
		return DBResult.failure(DBResult.Code.NOT_IN_HAND)
	if not card.is_playable():
		return DBResult.failure(DBResult.Code.UNPLAYABLE)
	if card.get_cost() > energy:
		return DBResult.failure(DBResult.Code.NOT_ENOUGH_ENERGY)
	if card.needs_target() and not _is_valid_target(target):
		return DBResult.failure(DBResult.Code.INVALID_TARGET)
	return DBResult.success()


## Plays [param card] from the hand on [param target] (an enemy, for cards that aim at one;
## ignored otherwise).
func play_card(card: DBCard, target: DBFighter = null) -> DBResult:
	var check := can_play(card, target)
	if not check.ok:
		return check
	_events = []
	var aimed := target if card.needs_target() else null
	var cost := card.get_cost()
	energy -= cost
	hand.erase(card)
	cards_played_this_turn += 1
	_event("play", {"card": card, "target": aimed, "cost": cost})
	_resolve_all(card.data.effects, player, aimed, card.upgraded, card)
	if card.data.type == DBCardData.Type.POWER:
		powers.append(card)
	elif card.is_exhaust():
		exhaust_pile.append(card)
		_event("exhaust", {"card": card})
	else:
		discard_pile.append(card)
	if phase == Phase.PLAYER:
		_fire_relics(DBRelic.Trigger.CARD_PLAYED, card)
	var result := _finish()
	card_played.emit(card, aimed, result)
	return result


func can_use_item(item_id: StringName, target: DBFighter = null) -> DBResult:
	var check := _check_turn()
	if not check.ok:
		return check
	if not item_cards.has(item_id) or bag == null or not bag.has(item_id):
		return DBResult.failure(DBResult.Code.NO_ITEM)
	if item_cards[item_id].aim == DBCardData.Aim.ONE_ENEMY and not _is_valid_target(target):
		return DBResult.failure(DBResult.Code.INVALID_TARGET)
	return DBResult.success()


## Uses one [param item_id] from the bag: its card in [member item_cards] takes effect,
## free of energy. The item is taken only if it is used.
func use_item(item_id: StringName, target: DBFighter = null) -> DBResult:
	var check := can_use_item(item_id, target)
	if not check.ok:
		return check
	var removed := bag.remove(item_id, 1)
	if not removed.ok:
		var refused := DBResult.failure(DBResult.Code.NO_ITEM)
		refused.inventory_result = removed
		return refused
	_events = []
	var data := item_cards[item_id]
	var aimed := target if data.aim == DBCardData.Aim.ONE_ENEMY else null
	_event("item", {"item_id": item_id, "target": aimed})
	_resolve_all(data.effects, player, aimed, false, null)
	var result := _finish()
	item_used.emit(item_id, aimed, result)
	return result


## Ends the player's turn: end-of-turn effects, the hand is discarded (retained cards stay,
## ethereal ones are exhausted), every enemy plays its intent, then the next turn starts.
func end_turn() -> DBResult:
	var check := _check_turn()
	if not check.ok:
		return check
	_events = []
	_fire_relics(DBRelic.Trigger.TURN_END)
	_end_of_turn(player)
	for card in hand.duplicate():
		if card.is_ethereal():
			hand.erase(card)
			exhaust_pile.append(card)
			_event("exhaust", {"card": card})
		elif card.is_retain():
			_event("retain", {"card": card})
		else:
			hand.erase(card)
			discard_pile.append(card)
			_event("discard", {"card": card})
	if phase == Phase.PLAYER:
		_enemy_turn()
	if phase == Phase.ENEMY:
		_start_player_turn(false)
	return _finish()


## Draws [param count] cards (also used by DRAW effects). When the draw pile is empty, the
## discard pile is shuffled into it. A full hand sends drawn cards to the discard pile.
func draw(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			_shuffle(draw_pile)
			_event("shuffle", {"count": draw_pile.size()})
		var card: DBCard = draw_pile.pop_back()
		if hand.size() >= hand_limit:
			discard_pile.append(card)
			_event("burn", {"card": card})
		else:
			hand.append(card)
			_event("draw", {"card": card})
			card_drawn.emit(card)


# --- Previews ----------------------------------------------------------------

## Damage of one hit of [param base] from [param source] to [param target] (null = no
## target modifiers), before block.
func compute_damage(source: DBFighter, target: DBFighter, base: int) -> int:
	var value := float(base)
	if source != null:
		value = (value + source.get_damage_bonus()) * source.get_damage_dealt_mult()
	if target != null:
		value *= target.get_damage_taken_mult()
	return maxi(0, floori(value + 0.0001))


func compute_block(source: DBFighter, base: int) -> int:
	var value := float(base)
	if source != null:
		value = (value + source.get_block_bonus()) * source.get_block_gain_mult()
	return maxi(0, floori(value + 0.0001))


## The amount effect [param index] of [param card] has right now: damage and block with the
## player's statuses (and [param target]'s), other effects as written.
func get_card_amount(card: DBCard, index: int, target: DBFighter = null) -> int:
	if index < 0 or index >= card.data.effects.size():
		return 0
	var effect := card.data.effects[index]
	var base := effect.get_amount(card.upgraded)
	match effect.kind:
		DBEffect.Kind.DAMAGE:
			return compute_damage(player, target if effect.target == DBEffect.Target.AIMED else null, base)
		DBEffect.Kind.BLOCK:
			return compute_block(player, base)
	return base


## What an enemy's intent will do to the player: {"damage" (per hit), "hits", "total",
## "block"}. Empty when the enemy shows no intent.
func preview_intent(enemy: DBFighter) -> Dictionary:
	if enemy == null or enemy.intent == null:
		return {}
	var preview := {"damage": 0, "hits": 0, "total": 0, "block": 0}
	for effect in enemy.intent.effects:
		if effect.kind == DBEffect.Kind.DAMAGE:
			var each := compute_damage(enemy, player, effect.amount)
			preview.damage = each
			preview.hits += effect.hits
			preview.total += each * effect.hits
		elif effect.kind == DBEffect.Kind.BLOCK:
			preview.block += compute_block(enemy, effect.amount)
	return preview


## Cards in the piles in a stable order for display (the draw pile is not shown in draw
## order, so it gives nothing away).
func get_pile_for_display(pile: Array[DBCard]) -> Array[DBCard]:
	var sorted := pile.duplicate()
	if is_same(pile, draw_pile):
		sorted.sort_custom(func(a: DBCard, b: DBCard) -> bool: return a.get_title() < b.get_title())
	return sorted


# --- Turns -------------------------------------------------------------------

func _start_player_turn(first: bool, innate_count: int = 0) -> void:
	phase = Phase.PLAYER
	turn += 1
	cards_played_this_turn = 0
	_event("turn", {"turn": turn})
	if not first:
		_lose_block(player)
	_tick(player)
	if phase == Phase.ENDED:
		return
	energy = max_energy + player.get_energy_per_turn()
	_event("energy", {"amount": energy, "energy": energy})
	_fire_relics(DBRelic.Trigger.TURN_START)
	if phase == Phase.ENDED:
		return
	draw(maxi(draw_per_turn + player.get_draw_per_turn(), innate_count))
	turn_started.emit(turn)


func _enemy_turn() -> void:
	phase = Phase.ENEMY
	_event("enemy_turn", {})
	enemy_turn_started.emit()
	for enemy in enemies:
		if phase != Phase.ENEMY:
			return
		if not enemy.is_alive():
			continue
		_lose_block(enemy)
		_tick(enemy)
		if not enemy.is_alive() or phase != Phase.ENEMY:
			continue
		if enemy.intent != null:
			_event("intent", {"source": enemy, "intent": enemy.intent})
			enemy.intents_played += 1
			_resolve_all(enemy.intent.effects, enemy, player, false, null)
		if phase != Phase.ENEMY:
			return
		_end_of_turn(enemy)
		if enemy.is_alive():
			_choose_intent(enemy)
			_event("next_intent", {"source": enemy, "intent": enemy.intent})
	intents_changed.emit()


func _lose_block(fighter: DBFighter) -> void:
	if fighter.block > 0 and not fighter.keeps_block():
		_event("block_lost", {"target": fighter, "amount": fighter.block})
		fighter.block = 0


## Start of the bearer's turn: damage (or healing) per turn.
func _tick(fighter: DBFighter) -> void:
	for status in fighter.get_statuses():
		if status.damage_per_turn == 0:
			continue
		var amount := status.damage_per_turn * fighter.get_stacks(status.id)
		if amount > 0:
			_lose_hp(fighter, amount, status)
			if not fighter.is_alive():
				return
		else:
			var healed := fighter.heal(-amount)
			if healed > 0:
				_event("heal", {"target": fighter, "amount": healed, "hp": fighter.hp})


## End of the bearer's turn: block per turn, then decaying statuses lose a stack.
func _end_of_turn(fighter: DBFighter) -> void:
	var plating := fighter.get_block_per_turn()
	if plating > 0 and fighter.is_alive():
		fighter.block += plating
		_event("block", {"target": fighter, "amount": plating, "block": fighter.block})
	for status in fighter.get_statuses():
		if status.decays:
			fighter.add_status(status, -1)
			_event("status", {"target": fighter, "status": status, "stacks": -1, "total": fighter.get_stacks(status.id)})


func _choose_intent(enemy: DBFighter) -> void:
	var intents: Array = enemy.data.intents if enemy.data != null else []
	if intents.is_empty():
		enemy.intent = null
		return
	var index := 0
	match enemy.data.pattern:
		DBEnemyData.Pattern.CYCLE:
			if enemy.intent_index < 0:
				index = enemy.data.first_intent if enemy.data.first_intent >= 0 else rng.randi_range(0, intents.size() - 1)
				index = clampi(index, 0, intents.size() - 1)
			else:
				index = (enemy.intent_index + 1) % intents.size()
		_:
			var exclude := enemy.intent_index if enemy.data.pattern == DBEnemyData.Pattern.RANDOM_NO_REPEAT and intents.size() > 1 else -1
			index = _weighted_pick(intents, exclude)
	enemy.intent_index = index
	enemy.intent = intents[index]


func _weighted_pick(intents: Array, exclude: int) -> int:
	var total := 0.0
	for i in intents.size():
		if i != exclude:
			total += maxf((intents[i] as DBIntent).weight, 0.0)
	if total <= 0.0:
		return (exclude + 1) % intents.size() if exclude >= 0 else 0
	var roll := rng.randf() * total
	for i in intents.size():
		if i == exclude:
			continue
		roll -= maxf((intents[i] as DBIntent).weight, 0.0)
		if roll <= 0.0:
			return i
	return intents.size() - 1 if intents.size() - 1 != exclude else 0


# --- Effects -----------------------------------------------------------------

func _resolve_all(effects: Array[DBEffect], source: DBFighter, aimed: DBFighter, upgraded: bool, card: DBCard) -> void:
	for effect in effects:
		if phase == Phase.ENDED:
			return
		if effect != null:
			_resolve(effect, source, aimed, upgraded, card)


func _resolve(effect: DBEffect, source: DBFighter, aimed: DBFighter, upgraded: bool, card: DBCard) -> void:
	var amount := effect.get_amount(upgraded)
	var targets := _targets_of(effect, source, aimed)
	match effect.kind:
		DBEffect.Kind.DAMAGE:
			for hit in effect.hits:
				for target in targets:
					if phase == Phase.ENDED:
						return
					if target.is_alive():
						_deal(source, target, compute_damage(source, target, amount), true)
		DBEffect.Kind.BLOCK:
			for target in targets:
				var gained := compute_block(source, amount)
				target.block += gained
				_event("block", {"target": target, "amount": gained, "block": target.block})
		DBEffect.Kind.DRAW:
			if source == player:
				draw(amount)
		DBEffect.Kind.ENERGY:
			if source == player:
				energy = maxi(0, energy + amount)
				_event("energy", {"amount": amount, "energy": energy})
		DBEffect.Kind.STATUS:
			for target in targets:
				var change := target.add_status(effect.status, amount)
				if change != 0:
					_event("status", {"target": target, "status": effect.status, "stacks": change, "total": target.get_stacks(effect.status.id)})
		DBEffect.Kind.HEAL:
			for target in targets:
				var healed := target.heal(amount)
				_event("heal", {"target": target, "amount": healed, "hp": target.hp})
		DBEffect.Kind.LOSE_HP:
			for target in targets:
				_lose_hp(target, amount, null)
		DBEffect.Kind.ADD_CARD:
			for i in amount:
				_add_card(DBCard.new(effect.card), effect.pile)
		DBEffect.Kind.CLEANSE:
			for target in targets:
				for status in target.get_statuses():
					if (effect.status == null and status.is_debuff) or (effect.status != null and status.id == effect.status.id):
						var change := target.add_status(status, -amount if amount > 0 else -target.get_stacks(status.id))
						_event("status", {"target": target, "status": status, "stacks": change, "total": target.get_stacks(status.id)})
		DBEffect.Kind.CUSTOM:
			custom_effect.emit(effect, source, targets, card, _events)
			_check_end()


func _targets_of(effect: DBEffect, source: DBFighter, aimed: DBFighter) -> Array[DBFighter]:
	var opponents: Array[DBFighter] = []
	var allies: Array[DBFighter] = []
	if source == player:
		opponents = get_alive_enemies()
		allies.append(player)
	else:
		if player.is_alive():
			opponents.append(player)
		allies = get_alive_enemies()
	var list: Array[DBFighter] = []
	match effect.target:
		DBEffect.Target.AIMED:
			if aimed != null and aimed.is_alive():
				list.append(aimed)
			elif aimed == null and source == player and not opponents.is_empty() and effect.kind in [DBEffect.Kind.DAMAGE, DBEffect.Kind.STATUS]:
				# Relics and untargeted cards: a random enemy.
				list.append(opponents[rng.randi_range(0, opponents.size() - 1)])
		DBEffect.Target.SELF:
			list.append(source)
		DBEffect.Target.ALL_OPPONENTS:
			list = opponents
		DBEffect.Target.RANDOM_OPPONENT:
			if not opponents.is_empty():
				list.append(opponents[rng.randi_range(0, opponents.size() - 1)])
		DBEffect.Target.ALL_ALLIES:
			list = allies
	return list


func _deal(source: DBFighter, target: DBFighter, amount: int, is_attack: bool) -> void:
	var blocked := mini(target.block, amount)
	target.block -= blocked
	var loss := mini(amount - blocked, target.hp)
	target.hp -= loss
	_event("damage", {"source": source, "target": target, "amount": amount, "blocked": blocked, "hp_loss": loss,
		"hp": target.hp, "block": target.block, "thorns": not is_attack})
	if is_attack and source != null and source != target and source.is_alive():
		var thorns := target.get_thorns()
		if thorns > 0:
			_deal(target, source, thorns, false)
	if not target.is_alive():
		_on_defeated(target)


func _lose_hp(target: DBFighter, amount: int, status: DBStatus) -> void:
	var loss := mini(maxi(amount, 0), target.hp)
	target.hp -= loss
	_event("lose_hp", {"target": target, "amount": loss, "hp": target.hp, "status": status})
	if not target.is_alive():
		_on_defeated(target)


func _add_card(card: DBCard, pile: DBEffect.Pile) -> void:
	match pile:
		DBEffect.Pile.HAND:
			if hand.size() < hand_limit:
				hand.append(card)
			else:
				discard_pile.append(card)
		DBEffect.Pile.DRAW:
			draw_pile.insert(rng.randi_range(0, draw_pile.size()), card)
		DBEffect.Pile.DISCARD:
			discard_pile.append(card)
	_event("add_card", {"card": card, "pile": pile})


func _on_defeated(fighter: DBFighter) -> void:
	if phase == Phase.ENDED:
		return
	_event("defeated", {"target": fighter})
	if not fighter.is_player:
		fighter.intent = null
		fighter.block = 0
	_check_end()


func _check_end() -> void:
	if phase == Phase.ENDED or phase == Phase.NONE or _ending:
		return
	if not player.is_alive():
		_end(Outcome.DEFEAT)
	elif get_alive_enemies().is_empty():
		_end(Outcome.VICTORY)


func _end(p_outcome: Outcome) -> void:
	if _ending:
		return
	_ending = true
	outcome = p_outcome
	if p_outcome == Outcome.VICTORY:
		_fire_relics(DBRelic.Trigger.COMBAT_END)  # e.g. heal after the fight
	phase = Phase.ENDED
	player.block = 0
	rewards = _make_rewards() if p_outcome == Outcome.VICTORY else {}
	_event("victory" if p_outcome == Outcome.VICTORY else "defeat", {})
	combat_ended.emit(p_outcome, rewards)


func _make_rewards() -> Dictionary:
	var gold := 0
	var elite := false
	for enemy in enemies:
		if enemy.data != null:
			gold += rng.randi_range(enemy.data.gold_min, maxi(enemy.data.gold_min, enemy.data.gold_max))
			elite = elite or enemy.data.is_elite
	var left := 0
	if gold > 0 and bag != null and not gold_item.is_empty():
		var paid := bag.add(gold_item, gold, true)
		left = paid.remainder if paid.ok else gold
	var cards: Array[DBCardData] = []
	if library != null and reward_card_count > 0:
		cards = library.offer(reward_card_count, rng, elite_rare_bonus if elite else 0.0)
	return {"gold": gold, "gold_left_behind": left, "cards": cards, "elite": elite}


func _fire_relics(trigger: DBRelic.Trigger, card: DBCard = null) -> void:
	for relic in relics:
		if relic == null or relic.trigger != trigger or phase == Phase.ENDED:
			continue
		if trigger == DBRelic.Trigger.CARD_PLAYED and relic.card_type >= 0 and (card == null or card.data.type != relic.card_type):
			continue
		var count: int = _relic_counts.get(relic, 0) + 1
		_relic_counts[relic] = count
		if count % relic.every != 0:
			continue
		_event("relic", {"relic": relic})
		_resolve_all(relic.effects, player, null, false, null)


## How many times [param relic] triggered this combat (counts toward [member DBRelic.every]).
func get_relic_count(relic: DBRelic) -> int:
	return _relic_counts.get(relic, 0)


# --- Helpers -----------------------------------------------------------------

func _check_turn() -> DBResult:
	if phase == Phase.NONE or phase == Phase.ENDED:
		return DBResult.failure(DBResult.Code.COMBAT_OVER)
	if phase != Phase.PLAYER:
		return DBResult.failure(DBResult.Code.NOT_YOUR_TURN)
	return DBResult.success()


func _is_valid_target(target: DBFighter) -> bool:
	return target != null and enemies.has(target) and target.is_alive()


func _shuffle(pile: Array[DBCard]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pile[i]
		pile[i] = pile[j]
		pile[j] = swap


func _event(type: String, fields: Dictionary) -> void:
	fields["type"] = type
	_events.append(fields)


func _finish() -> DBResult:
	last_events = _events
	var result := DBResult.success(_events)
	_events = []
	piles_changed.emit()
	energy_changed.emit(energy)
	intents_changed.emit()
	return result
