@tool
class_name DBCardLibrary
extends Resource
## Every card of your game, by id: rebuilds saved decks and draws card rewards
## ([method offer], weighted by rarity, never STARTER or SPECIAL cards).

@export var cards: Array[DBCardData] = []
## Reward odds by rarity (COMMON, UNCOMMON, RARE).
@export var rarity_weights: Dictionary[DBCardData.Rarity, float] = {
	DBCardData.Rarity.COMMON: 60.0, DBCardData.Rarity.UNCOMMON: 32.0, DBCardData.Rarity.RARE: 8.0}

var _by_id: Dictionary = {}


func add(data: DBCardData) -> void:
	cards.append(data)
	_by_id.clear()


func get_card(card_id: StringName) -> DBCardData:
	if _by_id.size() != cards.size():
		_by_id.clear()
		for data in cards:
			if data != null:
				_by_id[data.id] = data
	return _by_id.get(card_id)


## Cards that can show up in rewards, optionally of one rarity (-1 = any).
func get_reward_pool(rarity: int = -1) -> Array[DBCardData]:
	var pool: Array[DBCardData] = []
	for data in cards:
		if data == null or data.rarity == DBCardData.Rarity.STARTER or data.rarity == DBCardData.Rarity.SPECIAL:
			continue
		if data.type == DBCardData.Type.STATUS or data.type == DBCardData.Type.CURSE:
			continue
		if rarity < 0 or data.rarity == rarity:
			pool.append(data)
	return pool


## [param count] different reward cards. Each slot rolls a rarity from [member rarity_weights]
## (falling back to any rarity that has cards left), then a card of that rarity.
## [param rare_bonus] adds to the RARE weight (elites, bosses).
func offer(count: int, rng: RandomNumberGenerator, rare_bonus: float = 0.0) -> Array[DBCardData]:
	var picked: Array[DBCardData] = []
	var left := get_reward_pool()
	while picked.size() < count and not left.is_empty():
		var weights := rarity_weights.duplicate()
		weights[DBCardData.Rarity.RARE] = weights.get(DBCardData.Rarity.RARE, 0.0) + rare_bonus
		var total := 0.0
		for rarity in weights:
			if left.any(func(d: DBCardData) -> bool: return d.rarity == rarity):
				total += maxf(weights[rarity], 0.0)
		var chosen := -1
		if total > 0.0:
			var roll := rng.randf() * total
			for rarity in weights:
				if not left.any(func(d: DBCardData) -> bool: return d.rarity == rarity):
					continue
				roll -= maxf(weights[rarity], 0.0)
				if roll <= 0.0:
					chosen = rarity
					break
		var candidates := left.filter(func(d: DBCardData) -> bool: return chosen < 0 or d.rarity == chosen)
		if candidates.is_empty():
			candidates = left
		var card: DBCardData = candidates[rng.randi_range(0, candidates.size() - 1)]
		picked.append(card)
		left.erase(card)
	return picked


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var seen := {}
	for data in cards:
		if data == null:
			problems.append("empty card in the library")
			continue
		if seen.has(data.id):
			problems.append("two cards with the id %s" % data.id)
		seen[data.id] = true
		problems.append_array(data.validate())
	return problems
