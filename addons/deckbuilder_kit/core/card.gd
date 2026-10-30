class_name DBCard
extends RefCounted
## One card in a deck or a pile: a [DBCardData] plus its upgrade. A combat works on copies
## ([member source] = the deck card), so what happens in a fight never changes the deck.

static var _next_uid := 1

var data: DBCardData
var upgraded := false
## Unique per instance: lets the UI follow a card from pile to pile.
var uid := 0
## The deck card this combat copy comes from (null for cards created during the combat).
var source: DBCard
## This combat only: a cost set by an effect (-1 = normal cost).
var cost_override := -1


func _init(p_data: DBCardData = null, p_upgraded: bool = false) -> void:
	data = p_data
	upgraded = p_upgraded and p_data != null and p_data.can_upgrade
	uid = _next_uid
	_next_uid += 1


func copy() -> DBCard:
	var card := DBCard.new(data, upgraded)
	card.source = self
	return card


func get_title() -> String:
	return data.get_title() + ("+" if upgraded else "")


func get_cost() -> int:
	if cost_override >= 0:
		return cost_override
	if upgraded and data.upgraded_cost >= 0:
		return data.upgraded_cost
	return data.cost


func can_upgrade() -> bool:
	return data.can_upgrade and not upgraded


func upgrade() -> bool:
	if not can_upgrade():
		return false
	upgraded = true
	return true


func get_amount(effect_index: int) -> int:
	return data.effects[effect_index].get_amount(upgraded) if effect_index < data.effects.size() else 0


func is_exhaust() -> bool:
	return data.exhaust and not (upgraded and data.upgrade_removes_exhaust)


func is_retain() -> bool:
	return data.retain or (upgraded and data.upgrade_adds_retain)


func is_innate() -> bool:
	return data.innate or (upgraded and data.upgrade_adds_innate)


func is_ethereal() -> bool:
	return data.ethereal


func is_playable() -> bool:
	return not data.unplayable


func needs_target() -> bool:
	return data.aim == DBCardData.Aim.ONE_ENEMY


func to_save() -> Dictionary:
	return {"id": String(data.id), "upgraded": upgraded}


func _to_string() -> String:
	return "DBCard(%s%s #%d)" % [data.id if data != null else &"?", "+" if upgraded else "", uid]
