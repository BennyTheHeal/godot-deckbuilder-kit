class_name DBResult
extends RefCounted
## Outcome of playing a card, using an item or ending the turn: refused (see [member code])
## or done, with the list of what happened in [member events] (damage, block, draws,
## statuses, shuffles, enemy intents...).

enum Code {
	OK,
	INVALID_ARGUMENT,
	## The combat is over (or not started).
	COMBAT_OVER,
	## The enemies are playing.
	NOT_YOUR_TURN,
	## The card is not in the hand.
	NOT_IN_HAND,
	NOT_ENOUGH_ENERGY,
	## Wounds, curses and other unplayable cards.
	UNPLAYABLE,
	## Missing or defeated target, or a target given to a card that needs none.
	INVALID_TARGET,
	## Items: none left in the bag, or this item does nothing in combat.
	NO_ITEM,
}

var code: Code = Code.OK
var message: String = ""
## What happened, in order. Each event is a Dictionary with at least "type"; see
## [DBCombat] for the list of types and their fields.
var events: Array[Dictionary] = []
var inventory_result: IKResult

var ok: bool:
	get:
		return code == Code.OK


static func success(p_events: Array[Dictionary] = []) -> DBResult:
	var result := DBResult.new()
	result.events = p_events
	return result


static func failure(error_code: Code, error_message: String = "") -> DBResult:
	var result := DBResult.new()
	result.code = error_code
	result.message = error_message
	return result


func code_name() -> String:
	return Code.keys()[code]


## Events of one type ("damage", "block", "draw", "status"...).
func events_of(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event in events:
		if event.type == type:
			found.append(event)
	return found


## Total damage dealt to HP in [member events], optionally to one fighter.
func total_damage(target: DBFighter = null) -> int:
	var total := 0
	for event in events_of("damage"):
		if target == null or event.target == target:
			total += int(event.hp_loss)
	return total


func _to_string() -> String:
	return "DBResult(OK, %d events)" % events.size() if ok else "DBResult(%s: %s)" % [code_name(), message]
