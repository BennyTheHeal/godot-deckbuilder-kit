@tool
class_name DBRelic
extends Resource
## A passive bonus the player carries from fight to fight: its effects fire on a trigger
## (start of combat, start or end of each turn, every Nth card of a type, end of combat).

enum Trigger { COMBAT_START, TURN_START, TURN_END, CARD_PLAYED, COMBAT_END }

@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export var trigger: Trigger = Trigger.COMBAT_START
## CARD_PLAYED: only cards of this type count (-1 = any card).
@export_range(-1, 4) var card_type: int = -1
## Fires every Nth time (3 = on the 3rd, 6th, 9th... trigger of the combat).
@export_range(1, 99) var every: int = 1
## From the player's point of view (AIMED = a random enemy).
@export var effects: Array[DBEffect] = []
@export_group("Look")
@export var icon: Texture2D
@export var icon_item: StringName


static func make(p_id: StringName, p_title: String, p_description: String, p_trigger: Trigger, p_effects: Array = [],
		p_icon_item: StringName = &"") -> DBRelic:
	var relic := DBRelic.new()
	relic.id = p_id
	relic.title = p_title
	relic.description = p_description
	relic.trigger = p_trigger
	relic.icon_item = p_icon_item
	for effect: DBEffect in p_effects:
		relic.effects.append(effect)
	return relic


func get_title() -> String:
	return DBText.t(title) if not title.is_empty() else String(id).capitalize()


func get_description() -> String:
	return DBText.t(description)


func get_icon(database: IKItemDatabase) -> Texture2D:
	if icon != null:
		return icon
	var definition := database.get_item(icon_item) if database != null and not icon_item.is_empty() else null
	return definition.icon if definition != null else null
