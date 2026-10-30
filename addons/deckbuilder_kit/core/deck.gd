class_name DBDeck
extends RefCounted
## The player's deck between fights: add, remove and upgrade cards, save and load.

signal changed

var cards: Array[DBCard] = []


static func from_cards(datas: Array, upgraded: bool = false) -> DBDeck:
	var deck := DBDeck.new()
	for data: DBCardData in datas:
		deck.cards.append(DBCard.new(data, upgraded))
	return deck


func add(data: DBCardData, upgraded: bool = false) -> DBCard:
	var card := DBCard.new(data, upgraded)
	cards.append(card)
	changed.emit()
	return card


func remove(card: DBCard) -> bool:
	if not cards.has(card):
		return false
	cards.erase(card)
	changed.emit()
	return true


func upgrade(card: DBCard) -> bool:
	if not cards.has(card) or not card.upgrade():
		return false
	changed.emit()
	return true


func get_upgradable() -> Array[DBCard]:
	return cards.filter(func(c: DBCard) -> bool: return c.can_upgrade())


func count(card_id: StringName) -> int:
	return cards.filter(func(c: DBCard) -> bool: return c.data.id == card_id).size()


func size() -> int:
	return cards.size()


## Sorted for display: by type, then cost, then title.
func get_sorted() -> Array[DBCard]:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a: DBCard, b: DBCard) -> bool:
		if a.data.type != b.data.type:
			return a.data.type < b.data.type
		if a.get_cost() != b.get_cost():
			return a.get_cost() < b.get_cost()
		return a.get_title() < b.get_title())
	return sorted


func to_save() -> Array:
	var saved := []
	for card in cards:
		saved.append(card.to_save())
	return saved


## Rebuilds the deck from [method to_save]. Unknown ids are skipped and returned.
func load_save(saved: Array, library: DBCardLibrary) -> PackedStringArray:
	var unknown := PackedStringArray()
	cards.clear()
	for entry in saved:
		if not entry is Dictionary:
			continue
		var data := library.get_card(StringName(entry.get("id", "")))
		if data == null:
			unknown.append(str(entry.get("id", "")))
			continue
		cards.append(DBCard.new(data, bool(entry.get("upgraded", false))))
	changed.emit()
	return unknown
