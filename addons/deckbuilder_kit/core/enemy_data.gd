@tool
class_name DBEnemyData
extends Resource
## An enemy as designed: HP, look, the intents it picks from and in which order, the
## statuses it starts with and the gold it gives.

enum Pattern {
	## Intents in order, then from the start again.
	CYCLE,
	## Weighted random each turn.
	RANDOM,
	## Weighted random, never the same intent twice in a row.
	RANDOM_NO_REPEAT,
}

@export var id: StringName
@export var title: String = ""
@export_range(1, 9999) var max_hp: int = 30
## Each copy rolls its max HP in max_hp ± this.
@export_range(0, 999) var hp_variance: int = 0
@export var intents: Array[DBIntent] = []
@export var pattern: Pattern = Pattern.CYCLE
## CYCLE: the intent of the first turn. -1 = random.
@export var first_intent: int = 0
## Statuses at the start of the combat: {status: stacks}.
@export var start_statuses: Dictionary[DBStatus, int] = {}
@export_range(0, 9999) var gold_min: int = 0
@export_range(0, 9999) var gold_max: int = 0
## Elites and bosses give rarer card rewards (see [member DBCombat.elite_rare_bonus]).
@export var is_elite: bool = false
@export_group("Look")
@export var icon: Texture2D
## Empty icon = the icon of this item in the item database.
@export var icon_item: StringName
@export var tint := Color(1, 1, 1)


static func make(p_id: StringName, p_title: String, p_max_hp: int, p_intents: Array = [],
		p_icon_item: StringName = &"", p_pattern: Pattern = Pattern.CYCLE) -> DBEnemyData:
	var data := DBEnemyData.new()
	data.id = p_id
	data.title = p_title
	data.max_hp = p_max_hp
	data.icon_item = p_icon_item
	data.pattern = p_pattern
	for intent: DBIntent in p_intents:
		data.intents.append(intent)
	return data


func get_title() -> String:
	return DBText.t(title) if not title.is_empty() else String(id).capitalize()


func get_icon(database: IKItemDatabase) -> Texture2D:
	if icon != null:
		return icon
	var definition := database.get_item(icon_item) if database != null and not icon_item.is_empty() else null
	return definition.icon if definition != null else null
