extends IKInventoryUI
## Deckbuilder Kit demo: "The Crystal Mine". A short run down a mine: two fights, a camp
## (rest or upgrade a card), an elite that drops a relic, a merchant (cards, potions, card
## removal) and the boss. Potions come from the Inventory Kit bag, gold goes into it, and
## the four art styles change every icon.

const Content := preload("res://demo/cards/cards_content.gd")
const ART := "res://addons/inventory_kit/art/"
const DIRECTIONS := {"painted": "Hand-painted", "realistic": "Realistic", "cartoon": "Cartoon", "flat": "Flat"}
const SITE := "https://banc-essai.site-testeurs.workers.dev/?src=deckbuilder-demo"
const PLAYER_HP := 70
const PRICES := {DBCardData.Rarity.COMMON: 45, DBCardData.Rarity.UNCOMMON: 70, DBCardData.Rarity.RARE: 120}
const POTION_PRICE := 20
const REMOVE_PRICE := 60
const STEPS := [
	{"kind": "fight", "key": "fight1", "title": "Mine entrance"},
	{"kind": "fight", "key": "fight2", "title": "Coal tunnels"},
	{"kind": "rest", "title": "Miners' camp"},
	{"kind": "elite", "key": "elite", "title": "Granite hall (elite)"},
	{"kind": "shop", "title": "Wandering merchant"},
	{"kind": "boss", "key": "boss", "title": "The Obsidian Heart (boss)"},
]

var content: Content
var bag: IKInventory
var combat: DBCombat
var view: DBCombatView
var deck: DBDeck
var player: DBFighter
var relics: Array[DBRelic] = []
var step := 0
var art_direction := ""
var _picker: OptionButton
var _map: Control
var _path: HBoxContainer
var _info: RichTextLabel
var _actions: VBoxContainer
var _status: Label
var _deck_viewer := DBCardPicker.new()
var _pending := ""
var _shop_cards: Array[DBCardData] = []


static func available_directions() -> Array[String]:
	var result: Array[String] = []
	for da in DIRECTIONS:
		if ResourceLoader.exists(ART + "%s/%s_items.tres" % [da, da]):
			result.append(da)
	return result


func _ready() -> void:
	content = Content.new()
	var directions := available_directions()
	var database: IKItemDatabase = load(ART + "%s/%s_items.tres" % [directions[0], directions[0]])
	bag = IKInventory.new()
	bag.name = "Bag"
	bag.container_id = &"bag"
	bag.size = 10
	bag.database = database
	add_child(bag)
	combat = DBCombat.new()
	combat.name = "Combat"
	combat.library = content.library
	combat.item_cards = content.item_cards
	combat.relics = relics
	combat.custom_effect.connect(content.handle_custom)
	add_child(combat)
	_build_layout(directions)
	super._ready()
	combat.bag = bag.container
	view.combat = combat
	view.finished.connect(_on_combat_finished)
	view.refused.connect(func(_r: DBResult, text: String) -> void: _set_status(text, true))
	_deck_viewer.picked.connect(_on_deck_picked)
	interaction_failed.connect(func(result: IKResult) -> void: _set_status(IKText.result_message(result), true))
	apply_art_direction(directions[0])
	new_run()


func new_run() -> void:
	deck = DBDeck.from_cards(content.starter_deck)
	player = DBFighter.make_player("Miner", PLAYER_HP, &"iron_helmet")
	relics.clear()
	step = 0
	bag.container.resize(10)
	for slot in bag.container.size():
		bag.container.remove_at(slot)
	for pair in [[&"health_potion", 2], [&"stamina_potion", 1], [&"antidote", 1], [&"gold_coins", 40]]:
		bag.container.add(pair[0], pair[1])
	_show_map("A new run begins. Five Strikes, four Guards and a Mace Blow: find better cards on the way down.")


func apply_art_direction(da: String) -> void:
	art_direction = da
	var database: IKItemDatabase = load(ART + "%s/%s_items.tres" % [da, da])
	bag.container.database = database
	cursor.container.database = database
	theme = load(ART + "%s/%s_theme.tres" % [da, da])
	skin = load(ART + "%s/%s_skin.tres" % [da, da])
	view.database = database
	_deck_viewer.database = database
	if combat.is_running() and view.mode == DBCombatView.Mode.IDLE:
		view.rebuild()
	var index := available_directions().find(da)
	if _picker != null and index >= 0 and _picker.selected != index:
		_picker.select(index)


# --- Run -----------------------------------------------------------------------

func _gold() -> int:
	return bag.container.count(&"gold_coins")


func _show_map(message: String = "") -> void:
	view.visible = false
	_map.visible = true
	for child in _path.get_children():
		child.queue_free()
	for i in STEPS.size():
		var button := Button.new()
		var done := i < step
		button.text = ("✓ " if done else "") + STEPS[i].title
		button.disabled = i != step
		button.focus_mode = FOCUS_ALL
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(enter_step.bind(i))
		_path.add_child(button)
		if i == step:
			button.grab_focus.call_deferred()
	for child in _actions.get_children():
		child.queue_free()
	_refresh_info()
	if not message.is_empty():
		_set_status(message)


func _refresh_info() -> void:
	var names := PackedStringArray()
	for relic in relics:
		names.append(relic.get_title())
	_info.text = "[b]%s[/b]  HP %d / %d   ·   Gold %d   ·   Deck %d cards\n[color=#aab1bf]Relics: %s[/color]" % [
		player.get_title(), player.hp, player.max_hp, _gold(), deck.size(), ", ".join(names) if not names.is_empty() else "none yet"]


func enter_step(index: int) -> void:
	if index != step:
		return
	var current: Dictionary = STEPS[index]
	match current.kind:
		"fight", "elite", "boss":
			_start_combat(current)
		"rest":
			_show_camp()
		"shop":
			_show_shop()


func _start_combat(current: Dictionary) -> void:
	_map.visible = false
	view.visible = true
	combat.start(deck, player, content.encounters[current.key])
	_set_status("%s: fight!" % current.title)


func _on_combat_finished(outcome: DBCombat.Outcome, picked: DBCardData) -> void:
	if outcome != DBCombat.Outcome.VICTORY:
		_show_end("The mine claims another miner... Your run ends at %s." % STEPS[step].title)
		return
	var message := "Victory!"
	if picked != null:
		deck.add(picked)
		message += " %s joins your deck." % picked.get_title()
	var kind: String = STEPS[step].kind
	step += 1
	if kind == "boss":
		_show_end("You shattered the Obsidian Heart! The mine is safe. Deck: %d cards." % deck.size(), true)
		return
	_show_map(message)
	if kind == "elite":
		_offer_relics()


func _show_end(text: String, won: bool = false) -> void:
	_show_map(text)
	for child in _path.get_children():
		(child as Button).disabled = true
	var again := Button.new()
	again.text = "Play again" if won else "Try again"
	again.pressed.connect(new_run)
	_actions.add_child(again)
	again.grab_focus.call_deferred()
	_set_status(text, not won)


func _offer_relics() -> void:
	var left := content.relics.filter(func(r: DBRelic) -> bool: return not relics.has(r))
	left.shuffle()
	var label := Label.new()
	label.text = "The Sentinel guarded a relic. Choose one:"
	_actions.add_child(label)
	for relic: DBRelic in left.slice(0, 3):
		var button := Button.new()
		button.text = "%s — %s" % [relic.get_title(), relic.get_description()]
		button.icon = relic.get_icon(bag.container.database)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func() -> void:
			relics.append(relic)
			_show_map("%s is yours." % relic.get_title()))
		_actions.add_child(button)


func _show_camp() -> void:
	for child in _actions.get_children():
		child.queue_free()
	var heal := roundi(player.max_hp * 0.3)
	var rest := Button.new()
	rest.text = "Rest: heal %d HP" % heal
	rest.pressed.connect(func() -> void:
		player.heal(heal)
		step += 1
		_show_map("You rest by the fire."))
	_actions.add_child(rest)
	var smith := Button.new()
	smith.text = "Smith: upgrade a card"
	smith.disabled = deck.get_upgradable().is_empty()
	smith.pressed.connect(func() -> void:
		_pending = "upgrade"
		_deck_viewer.open("Upgrade a card (shown upgraded)", deck.get_upgradable(), true, "Cancel", true))
	_actions.add_child(smith)
	rest.grab_focus.call_deferred()
	_set_status("The miners' camp. Rest, or improve a card at the anvil.")


func _show_shop() -> void:
	for child in _actions.get_children():
		child.queue_free()
	if _shop_cards.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_shop_cards = content.library.offer(3, rng, 10.0)
	for data in _shop_cards:
		var price: int = PRICES.get(data.rarity, 60)
		var button := Button.new()
		button.text = "Buy %s (%s) — %d gold" % [data.get_title(), DBText.rarity_name(data.rarity), price]
		button.icon = data.get_icon(bag.container.database)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 40)
		button.tooltip_text = DBText.describe_card(DBCard.new(data)).replace("[b]", "").replace("[/b]", "")
		button.disabled = _gold() < price
		button.pressed.connect(func() -> void:
			if _pay(price):
				deck.add(data)
				_shop_cards.erase(data)
				_show_shop()
				_set_status("%s added to your deck." % data.get_title()))
		_actions.add_child(button)
	var potion := Button.new()
	potion.text = "Buy a Health Potion — %d gold" % POTION_PRICE
	potion.disabled = _gold() < POTION_PRICE
	potion.pressed.connect(func() -> void:
		if bag.container.add(&"health_potion", 1).ok and _pay(POTION_PRICE):
			_show_shop()
			_set_status("Potion in the bag."))
	_actions.add_child(potion)
	var remove := Button.new()
	remove.text = "Remove a card from your deck — %d gold" % REMOVE_PRICE
	remove.disabled = _gold() < REMOVE_PRICE or deck.size() <= 5
	remove.pressed.connect(func() -> void:
		_pending = "remove"
		_deck_viewer.open("Remove a card", deck.get_sorted(), true, "Cancel"))
	_actions.add_child(remove)
	var leave := Button.new()
	leave.text = "Leave the merchant"
	leave.pressed.connect(func() -> void:
		step += 1
		_shop_cards.clear()
		_show_map("On to the heart of the mine."))
	_actions.add_child(leave)
	_refresh_info()
	_set_status("The merchant shows you what they found down here.")


func _pay(amount: int) -> bool:
	return bag.container.remove(&"gold_coins", amount).ok


func _on_deck_picked(_index: int, card: DBCard) -> void:
	match _pending:
		"upgrade":
			deck.upgrade(card)
			step += 1
			_show_map("%s upgraded." % card.get_title())
		"remove":
			if _pay(REMOVE_PRICE):
				deck.remove(card)
				_show_shop()
				_set_status("%s removed from your deck." % card.data.get_title())
	_pending = ""


func show_deck() -> void:
	_pending = ""
	_deck_viewer.open("Your deck (%d cards)" % deck.size(), deck.get_sorted(), false)


# --- Layout ----------------------------------------------------------------------

func _build_layout(directions: Array[String]) -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.07, 0.10)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 10)
	column.add_child(header)
	var title := Label.new()
	title.text = "Deckbuilder Kit — The Crystal Mine"
	title.add_theme_font_size_override(&"font_size", 20)
	header.add_child(title)
	_picker = OptionButton.new()
	for da in directions:
		_picker.add_item(DIRECTIONS[da])
	_picker.item_selected.connect(func(index: int) -> void: apply_art_direction(directions[index]))
	_picker.focus_mode = FOCUS_NONE
	header.add_child(_picker)
	var deck_button := Button.new()
	deck_button.text = "Deck"
	deck_button.focus_mode = FOCUS_NONE
	deck_button.pressed.connect(show_deck)
	header.add_child(deck_button)
	var site := LinkButton.new()
	site.text = "More kits & our games »"
	site.uri = SITE
	site.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(site)

	var body := Control.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(body)

	_map = HBoxContainer.new()
	_map.add_theme_constant_override(&"separation", 18)
	body.add_child(_map)
	_map.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 10)
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	_map.add_child(left)
	var heading := Label.new()
	heading.text = "Your way down the mine"
	heading.add_theme_font_size_override(&"font_size", 18)
	left.add_child(heading)
	_path = HBoxContainer.new()
	_path.add_theme_constant_override(&"separation", 8)
	left.add_child(_path)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	left.add_child(_info)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override(&"separation", 6)
	left.add_child(_actions)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(1, 1, 1, 0.6)
	help.text = ("In combat: drag a card onto an enemy, or click it then click an enemy. Cards that need no target: "
		+ "click them or drag them up. Watch the intents above the enemies. Potions: the buttons above your energy. "
		+ "Keyboard / gamepad: arrows, Enter / A, Escape / B, E / Y ends the turn.")
	left.add_child(help)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	_map.add_child(right)
	var bag_label := Label.new()
	bag_label.text = "Bag (potions for combat, gold)"
	right.add_child(bag_label)
	var bag_view := IKContainerView.new()
	bag_view.name = "BagView"
	bag_view.columns = 5
	bag_view.inventory = bag
	right.add_child(bag_view)

	view = DBCombatView.new()
	view.name = "CombatView"
	view.visible = false
	body.add_child(view)
	view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_deck_viewer.z_index = 200
	add_child(_deck_viewer)
	_deck_viewer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _set_status(text: String, warning: bool = false) -> void:
	if _status == null:
		return
	_status.text = text
	_status.modulate = Color(1, 0.6, 0.5) if warning else Color(0.7, 1, 0.7)
