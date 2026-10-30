@tool
class_name DBEffect
extends Resource
## One thing a card, an enemy intent, a relic or an item does: deal damage, gain block,
## draw, gain energy, apply a status, heal, lose HP, add cards to a pile, or a custom
## effect your game handles ([signal DBCombat.custom_effect]).

enum Kind {
	## [member amount] damage, [member hits] times. Modified by the source's and the
	## target's statuses (Might, Weakened, Exposed...), then absorbed by block.
	DAMAGE,
	## [member amount] block, modified by the source's statuses (Agility, Fragile...).
	BLOCK,
	## The player draws [member amount] cards.
	DRAW,
	## The player gains [member amount] energy this turn.
	ENERGY,
	## [member amount] stacks of [member status].
	STATUS,
	## Restores [member amount] HP, up to the max.
	HEAL,
	## Loses [member amount] HP. Block does not help.
	LOSE_HP,
	## Adds [member amount] copies of [member card] to [member pile] (wounds, dazes, tokens).
	ADD_CARD,
	## Removes [member amount] stacks of [member status] (or every debuff when it is empty).
	CLEANSE,
	## Nothing built in: [signal DBCombat.custom_effect] is emitted with [member custom_id].
	CUSTOM,
}

enum Target {
	## What the card or intent aims at: the chosen enemy for a card, the player for an enemy.
	AIMED,
	## The one who plays the card or the intent.
	SELF,
	## Every living opponent of the source (every enemy for the player).
	ALL_OPPONENTS,
	## One living opponent at random (from the combat's seed).
	RANDOM_OPPONENT,
	## The source and its allies (enemies buffing each other).
	ALL_ALLIES,
}

enum Pile { HAND, DRAW, DISCARD }

@export var kind: Kind = Kind.DAMAGE
@export var target: Target = Target.AIMED
@export var amount: int = 0
## Added to [member amount] when the card is upgraded.
@export var upgrade_amount: int = 0
## DAMAGE only: how many times it hits (each hit is modified and blocked on its own).
@export_range(1, 20) var hits: int = 1
@export var status: DBStatus
@export var card: DBCardData
@export var pile: Pile = Pile.DISCARD
@export var custom_id: StringName


static func make(p_kind: Kind, p_amount: int, p_target: Target = Target.AIMED, p_upgrade: int = 0) -> DBEffect:
	var effect := DBEffect.new()
	effect.kind = p_kind
	effect.amount = p_amount
	effect.target = p_target
	effect.upgrade_amount = p_upgrade
	return effect


static func damage(p_amount: int, p_upgrade: int = 0, p_hits: int = 1, p_target: Target = Target.AIMED) -> DBEffect:
	var effect := make(Kind.DAMAGE, p_amount, p_target, p_upgrade)
	effect.hits = p_hits
	return effect


static func block(p_amount: int, p_upgrade: int = 0) -> DBEffect:
	return make(Kind.BLOCK, p_amount, Target.SELF, p_upgrade)


static func draw(p_amount: int, p_upgrade: int = 0) -> DBEffect:
	return make(Kind.DRAW, p_amount, Target.SELF, p_upgrade)


static func energy(p_amount: int, p_upgrade: int = 0) -> DBEffect:
	return make(Kind.ENERGY, p_amount, Target.SELF, p_upgrade)


static func apply(p_status: DBStatus, p_stacks: int, p_target: Target = Target.AIMED, p_upgrade: int = 0) -> DBEffect:
	var effect := make(Kind.STATUS, p_stacks, p_target, p_upgrade)
	effect.status = p_status
	return effect


static func add_card(p_card: DBCardData, p_copies: int = 1, p_pile: Pile = Pile.DISCARD, p_target: Target = Target.AIMED) -> DBEffect:
	var effect := make(Kind.ADD_CARD, p_copies, p_target)
	effect.card = p_card
	effect.pile = p_pile
	return effect


static func custom(p_id: StringName, p_amount: int = 0, p_target: Target = Target.AIMED, p_upgrade: int = 0) -> DBEffect:
	var effect := make(Kind.CUSTOM, p_amount, p_target, p_upgrade)
	effect.custom_id = p_id
	return effect


func get_amount(upgraded: bool) -> int:
	return amount + (upgrade_amount if upgraded else 0)


## True when it touches the opponents (used to know if a card needs a target).
func aims_opponent() -> bool:
	return target == Target.AIMED
