@tool
class_name DBCardData
extends Resource
## A card as designed: cost, type, rarity, what it aims at, its effects, its keywords and
## what upgrading changes. The cards in a deck are [DBCard] instances of it.

enum Type { ATTACK, SKILL, POWER, STATUS, CURSE }
## STARTER and SPECIAL cards never show up in rewards.
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SPECIAL }
enum Aim {
	## Needs an enemy: the effects with target AIMED hit it.
	ONE_ENEMY,
	## No choice to make (all enemies, self, draw...).
	NONE,
}

@export var id: StringName
@export var title: String = ""
## Card text. Empty = written from the effects. {0}, {1}... = the live amount of effect 0,
## 1... (damage and block with the player's statuses and, once aimed, the target's).
@export_multiline var description: String = ""
## Card text once upgraded. Empty = [member description].
@export_multiline var upgraded_description: String = ""
@export_range(0, 9) var cost: int = 1
## Cost once upgraded. -1 = same cost.
@export_range(-1, 9) var upgraded_cost: int = -1
@export var type: Type = Type.ATTACK
@export var rarity: Rarity = Rarity.COMMON
@export var aim: Aim = Aim.ONE_ENEMY
@export var effects: Array[DBEffect] = []
@export_group("Keywords")
## Goes to the exhaust pile when played: gone until the end of the combat.
@export var exhaust: bool = false
## Exhausted if it is still in hand at the end of the turn.
@export var ethereal: bool = false
## Stays in hand at the end of the turn.
@export var retain: bool = false
## Always in the opening hand.
@export var innate: bool = false
## Cannot be played (wounds, curses).
@export var unplayable: bool = false
@export_group("Upgrade")
## False for cards that cannot be upgraded (curses, tokens).
@export var can_upgrade: bool = true
@export var upgrade_removes_exhaust: bool = false
@export var upgrade_adds_retain: bool = false
@export var upgrade_adds_innate: bool = false
@export_group("Look")
@export var icon: Texture2D
## Empty icon = the icon of this item in the item database.
@export var icon_item: StringName
## Empty (alpha 0) = the color of the card type.
@export var color := Color(0, 0, 0, 0)


static func make(p_id: StringName, p_title: String, p_cost: int, p_type: Type, p_effects: Array = [],
		p_icon_item: StringName = &"", p_rarity: Rarity = Rarity.COMMON) -> DBCardData:
	var data := DBCardData.new()
	data.id = p_id
	data.title = p_title
	data.cost = p_cost
	data.type = p_type
	data.rarity = p_rarity
	data.icon_item = p_icon_item
	for effect: DBEffect in p_effects:
		data.effects.append(effect)
	data.aim = Aim.ONE_ENEMY if data.effects.any(func(e: DBEffect) -> bool: return e.aims_opponent()) else Aim.NONE
	if p_type == Type.STATUS or p_type == Type.CURSE:
		data.unplayable = true
		data.can_upgrade = false
	return data


func get_title() -> String:
	return DBText.t(title) if not title.is_empty() else String(id).capitalize()


func get_icon(database: IKItemDatabase) -> Texture2D:
	if icon != null:
		return icon
	var definition := database.get_item(icon_item) if database != null and not icon_item.is_empty() else null
	return definition.icon if definition != null else null


func get_color() -> Color:
	if color.a > 0.0:
		return color
	return DBText.type_color(type)


## Problems with this card's setup (empty when fine). The editor plugin and the tests use it.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id.is_empty():
		problems.append("a card has no id")
	for effect in effects:
		if effect == null:
			problems.append("%s: empty effect" % id)
		elif effect.kind == DBEffect.Kind.STATUS and effect.status == null:
			problems.append("%s: STATUS effect with no status" % id)
		elif effect.kind == DBEffect.Kind.ADD_CARD and effect.card == null:
			problems.append("%s: ADD_CARD effect with no card" % id)
	if aim == Aim.NONE and effects.any(func(e: DBEffect) -> bool: return e != null and e.aims_opponent()):
		problems.append("%s: aims at no one but has AIMED effects" % id)
	return problems
