class_name DBCardPicker
extends Control
## A full-screen card list over a dimmed background: look at a pile or the deck, or pick
## one card (rewards, upgrades, removals). Mouse, keyboard and gamepad: arrows move,
## Enter / A picks, Escape / B closes (or skips).

## A card was chosen ([param index] in the list given to [method open]).
signal picked(index: int, card: DBCard)
## Closed or skipped without a choice.
signal closed

var database: IKItemDatabase
var combat: DBCombat
## Cards per row.
var columns := 5
var _dim := ColorRect.new()
var _title := Label.new()
var _grid := GridContainer.new()
var _scroll := ScrollContainer.new()
var _close := Button.new()
var _views: Array[DBCardView] = []
var _cards: Array[DBCard] = []
var _choosing := false
var _focus := 0
var _preview_upgrade := false


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.04, 0.82)
	_dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(column)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 24)
	_title.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_title.add_theme_constant_override(&"outline_size", 5)
	column.add_child(_title)
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.add_child(center)
	_grid.add_theme_constant_override(&"h_separation", 18)
	_grid.add_theme_constant_override(&"v_separation", 18)
	_grid.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(_grid)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_close.custom_minimum_size = Vector2(180, 40)
	_close.focus_mode = FOCUS_NONE
	_close.pressed.connect(close)
	buttons.add_child(_close)


## Shows [param cards] ([DBCard]s or [DBCardData]s). [param choose]: clicking a card picks
## it. [param close_text]: the button ("Close", "Skip"...). [param show_upgrade]: cards show
## their upgraded version (upgrade screens).
func open(title: String, cards: Array, choose: bool = false, close_text: String = "", show_upgrade: bool = false) -> void:
	_title.text = title
	_choosing = choose
	_preview_upgrade = show_upgrade
	_close.text = close_text if not close_text.is_empty() else (DBText.t("Skip") if choose else DBText.t("Close"))
	for view in _views:
		view.queue_free()
	_views.clear()
	_cards.clear()
	for entry in cards:
		var card: DBCard = entry if entry is DBCard else DBCard.new(entry as DBCardData)
		_cards.append(card)
		var shown := card
		if show_upgrade and card.can_upgrade():
			shown = DBCard.new(card.data, true)
		var view := DBCardView.new().setup(shown, database, combat)
		view.mouse_entered.connect(_set_focus.bind(_views.size()))
		view.pressed.connect(_on_card_pressed)
		_grid.add_child(view)
		_views.append(view)
	_grid.columns = clampi(cards.size(), 1, columns)
	_focus = 0
	visible = true
	_set_focus(0)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_views() -> Array[DBCardView]:
	return _views


func pick(index: int) -> void:
	if not _choosing or index < 0 or index >= _cards.size():
		return
	visible = false
	picked.emit(index, _cards[index])


func _on_card_pressed(view: DBCardView) -> void:
	pick(_views.find(view))


func _set_focus(index: int) -> void:
	if _views.is_empty():
		return
	_focus = clampi(index, 0, _views.size() - 1)
	for i in _views.size():
		var on := i == _focus and _choosing
		_views[i].set_highlight(on)
		_views[i].scale = Vector2.ONE * (1.06 if on else 1.0)
	_scroll.ensure_control_visible(_views[_focus])


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
	elif event.is_action_pressed(&"ui_right"):
		_set_focus(_focus + 1)
	elif event.is_action_pressed(&"ui_left"):
		_set_focus(_focus - 1)
	elif event.is_action_pressed(&"ui_down"):
		_set_focus(_focus + _grid.columns)
	elif event.is_action_pressed(&"ui_up"):
		_set_focus(_focus - _grid.columns)
	elif event.is_action_pressed(&"ui_accept"):
		if _choosing:
			pick(_focus)
		else:
			close()
	else:
		return
	get_viewport().set_input_as_handled()
