class_name DBFighter
extends RefCounted
## The player or an enemy during a combat: HP, block, statuses (in stacks) and, for an
## enemy, the intent it shows. The player's fighter keeps its HP from fight to fight.

var title := ""
var icon: Texture2D
var icon_item: StringName
var max_hp := 1
var hp := 1
var block := 0
var is_player := false
## Enemies: what they are, the intent they will play next and how many they played.
var data: DBEnemyData
var intent: DBIntent
var intent_index := -1
var intents_played := 0
## Slot in the enemy row (0 for the player).
var slot := 0
var _stacks: Dictionary = {}  # StringName -> int
var _statuses: Dictionary = {}  # StringName -> DBStatus


static func make_player(p_title: String, p_max_hp: int, p_icon_item: StringName = &"") -> DBFighter:
	var fighter := DBFighter.new()
	fighter.title = p_title
	fighter.max_hp = p_max_hp
	fighter.hp = p_max_hp
	fighter.icon_item = p_icon_item
	fighter.is_player = true
	return fighter


static func from_enemy(p_data: DBEnemyData, rng: RandomNumberGenerator = null) -> DBFighter:
	var fighter := DBFighter.new()
	fighter.data = p_data
	fighter.title = p_data.get_title()
	fighter.icon = p_data.icon
	fighter.icon_item = p_data.icon_item
	var variance := p_data.hp_variance
	fighter.max_hp = maxi(1, p_data.max_hp + (rng.randi_range(-variance, variance) if rng != null and variance > 0 else 0))
	fighter.hp = fighter.max_hp
	for status in p_data.start_statuses:
		fighter.add_status(status, p_data.start_statuses[status])
	return fighter


func get_title() -> String:
	return title


func get_icon(database: IKItemDatabase) -> Texture2D:
	if icon != null:
		return icon
	var definition := database.get_item(icon_item) if database != null and not icon_item.is_empty() else null
	return definition.icon if definition != null else null


func is_alive() -> bool:
	return hp > 0


func get_stacks(status_id: StringName) -> int:
	return _stacks.get(status_id, 0)


func has_status(status_id: StringName) -> bool:
	return get_stacks(status_id) > 0


func get_status(status_id: StringName) -> DBStatus:
	return _statuses.get(status_id)


## The statuses it has, in the order they were first applied.
func get_statuses() -> Array[DBStatus]:
	var list: Array[DBStatus] = []
	for status_id in _stacks:
		if _stacks[status_id] > 0:
			list.append(_statuses[status_id])
	return list


## Adds (or removes, if negative) stacks, within 0 and [member DBStatus.max_stacks]. Returns
## the change actually made.
func add_status(status: DBStatus, stacks: int) -> int:
	if status == null or stacks == 0:
		return 0
	var before := get_stacks(status.id)
	var after := clampi(before + stacks, 0, status.max_stacks)
	if after == 0:
		_stacks.erase(status.id)
	else:
		_stacks[status.id] = after
		_statuses[status.id] = status
	return after - before


func clear_statuses() -> void:
	_stacks.clear()
	_statuses.clear()


func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + maxi(amount, 0))
	return hp - before


# --- Modifiers ---------------------------------------------------------------

func _sum(field: StringName) -> int:
	var total := 0
	for status_id in _stacks:
		total += int(_statuses[status_id].get(field)) * _stacks[status_id]
	return total


func _product(field: StringName) -> float:
	var total := 1.0
	for status_id in _stacks:
		total *= float(_statuses[status_id].get(field))
	return total


func get_damage_bonus() -> int:
	return _sum(&"damage_bonus")


func get_block_bonus() -> int:
	return _sum(&"block_bonus")


func get_thorns() -> int:
	return _sum(&"thorns")


func get_damage_per_turn() -> int:
	return _sum(&"damage_per_turn")


func get_block_per_turn() -> int:
	return _sum(&"block_per_turn")


func get_energy_per_turn() -> int:
	return _sum(&"energy_per_turn")


func get_draw_per_turn() -> int:
	return _sum(&"draw_per_turn")


func get_damage_dealt_mult() -> float:
	return _product(&"damage_dealt_mult")


func get_damage_taken_mult() -> float:
	return _product(&"damage_taken_mult")


func get_block_gain_mult() -> float:
	return _product(&"block_gain_mult")


func keeps_block() -> bool:
	for status_id in _stacks:
		if _statuses[status_id].keeps_block:
			return true
	return false


## Player between fights: back to full HP, no block, no status.
func restore() -> void:
	hp = max_hp
	block = 0
	clear_statuses()


func to_save() -> Dictionary:
	return {"title": title, "max_hp": max_hp, "hp": hp}


func load_save(saved: Dictionary) -> void:
	title = saved.get("title", title)
	max_hp = int(saved.get("max_hp", max_hp))
	hp = clampi(int(saved.get("hp", max_hp)), 0, max_hp)
