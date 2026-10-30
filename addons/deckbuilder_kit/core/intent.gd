@tool
class_name DBIntent
extends Resource
## One move of an enemy, announced a turn ahead: its effects (from the enemy's point of
## view: AIMED = the player, SELF = the enemy) and how often it is picked.

enum Kind { ATTACK, ATTACK_DEBUFF, ATTACK_DEFEND, DEFEND, BUFF, DEBUFF, UNKNOWN }

@export var id: StringName
@export var title: String = ""
@export var effects: Array[DBEffect] = []
## Pick chance for the RANDOM patterns of [DBEnemyData].
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
## Show "?" instead of what is coming.
@export var hidden: bool = false


static func make(p_id: StringName, p_title: String, p_effects: Array = [], p_weight: float = 1.0) -> DBIntent:
	var intent := DBIntent.new()
	intent.id = p_id
	intent.title = p_title
	intent.weight = p_weight
	for effect: DBEffect in p_effects:
		intent.effects.append(effect)
	return intent


func get_title() -> String:
	return DBText.t(title) if not title.is_empty() else String(id).capitalize()


## What the intent icon shows, read from the effects.
func get_kind() -> Kind:
	if hidden:
		return Kind.UNKNOWN
	var attack := false
	var defend := false
	var buff := false
	var debuff := false
	for effect in effects:
		match effect.kind:
			DBEffect.Kind.DAMAGE:
				attack = true
			DBEffect.Kind.BLOCK:
				defend = true
			DBEffect.Kind.STATUS:
				if effect.status != null and effect.status.is_debuff and effect.target in [DBEffect.Target.AIMED, DBEffect.Target.ALL_OPPONENTS, DBEffect.Target.RANDOM_OPPONENT]:
					debuff = true
				else:
					buff = true
			DBEffect.Kind.ADD_CARD:
				debuff = true
			DBEffect.Kind.HEAL:
				buff = true
	if attack and debuff:
		return Kind.ATTACK_DEBUFF
	if attack and defend:
		return Kind.ATTACK_DEFEND
	if attack:
		return Kind.ATTACK
	if defend:
		return Kind.DEFEND
	if debuff:
		return Kind.DEBUFF
	if buff:
		return Kind.BUFF
	return Kind.UNKNOWN
