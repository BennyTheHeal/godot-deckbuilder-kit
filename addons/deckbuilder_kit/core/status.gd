@tool
class_name DBStatus
extends Resource
## A buff or a debuff counted in stacks: Might (+damage), Agility (+block), Weakened (deal
## less), Exposed (take more), Fragile (less block), Poison (damage each turn), Thorns,
## Plating (block each turn), Fortress (block stays)... Every field is per stack except the
## multipliers, which apply as long as the bearer has at least one stack.

@export var id: StringName
@export var title: String = ""
## Shown in the tooltip. Empty = built from the fields below.
@export_multiline var description: String = ""
## Debuffs are red in the UI and are what a CLEANSE with no status removes.
@export var is_debuff: bool = false
## Loses one stack at the end of each of the bearer's turns (durations: Weakened 2 = two turns).
@export var decays: bool = false
@export_range(1, 999) var max_stacks: int = 999
@export_group("Per stack")
## Added to each hit of the bearer's attacks.
@export var damage_bonus: int = 0
## Added to each block the bearer gains from cards and intents.
@export var block_bonus: int = 0
## At the start of the bearer's turn: lose this much HP (block does not help). Negative heals.
@export var damage_per_turn: int = 0
## At the end of the bearer's turn: gain this much block.
@export var block_per_turn: int = 0
## Attackers that hit the bearer take this much damage back.
@export var thorns: int = 0
## Player only: extra energy and extra cards at the start of each turn.
@export var energy_per_turn: int = 0
@export var draw_per_turn: int = 0
@export_group("While active")
## The bearer's attacks deal this much: 0.75 = 25 % less.
@export var damage_dealt_mult: float = 1.0
## Attacks against the bearer deal this much: 1.5 = 50 % more.
@export var damage_taken_mult: float = 1.0
## Block the bearer gains is multiplied: 0.75 = 25 % less.
@export var block_gain_mult: float = 1.0
## The bearer's block is not removed at the start of its turn.
@export var keeps_block: bool = false
@export_group("Look")
@export var icon: Texture2D
## Empty icon = the icon of this item in the item database.
@export var icon_item: StringName
@export var color := Color(1, 1, 1)


static func make(p_id: StringName, p_title: String, p_debuff: bool = false, p_decays: bool = false,
		p_icon_item: StringName = &"") -> DBStatus:
	var status := DBStatus.new()
	status.id = p_id
	status.title = p_title
	status.is_debuff = p_debuff
	status.decays = p_decays
	status.icon_item = p_icon_item
	status.color = Color(1.0, 0.45, 0.4) if p_debuff else Color(0.5, 0.95, 0.55)
	return status


func get_title() -> String:
	return DBText.t(title) if not title.is_empty() else String(id).capitalize()


func get_description(stacks: int = 1) -> String:
	if not description.is_empty():
		return DBText.t(description).replace("{n}", str(stacks))
	return DBText.describe_status(self, stacks)


func get_icon(database: IKItemDatabase) -> Texture2D:
	if icon != null:
		return icon
	var definition := database.get_item(icon_item) if database != null and not icon_item.is_empty() else null
	return definition.icon if definition != null else null
