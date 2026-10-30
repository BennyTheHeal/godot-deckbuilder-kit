class_name DBCombatView
extends Control
## A ready-to-use combat screen for a [DBCombat]: the enemies with their intents, the
## player, the hand in a fan, energy, draw / discard / exhaust piles (click to look), items
## from the bag, relics, a combat log, floating numbers, and the victory screen with the
## card reward.
##
## Mouse: drag a card onto an enemy (or above the hand for cards that need no target), or
## click it, then click an enemy. Keyboard and gamepad: left / right pick a card, Enter / A
## plays it (then left / right pick the enemy, Enter / A again), Escape / B cancels,
## E / gamepad Y ends the turn (or the "db_end_turn" action if your project defines it).

## The player closed the end screen. [param picked]: the reward card chosen (null if skipped,
## lost or none).
signal finished(outcome: DBCombat.Outcome, picked: DBCardData)
signal refused(result: DBResult, text: String)

enum Mode { IDLE, DRAG, AIM, BUSY, ENDED }

const DEFAULT_HINT := "Drag a card onto an enemy, or click it. E ends the turn."

@export var combat: DBCombat:
	set(value):
		_disconnect_combat()
		combat = value
		_connect_combat()
## Item icons for cards, enemies, statuses, relics and intents. Empty = the bag's database.
@export var database: IKItemDatabase
## Seconds between enemy moves during the enemy turn, so the player can follow.
@export_range(0.0, 2.0, 0.05) var event_delay := 0.45
@export var enemy_portrait := 110.0
@export var player_portrait := 120.0
## Card size in the hand.
@export_range(0.5, 1.5, 0.05) var hand_scale := 1.0
@export var show_log := true
## Screen shake when the player loses at least this much HP in one hit. 0 = never.
@export_range(0, 99) var shake_threshold := 8
## Item shown for each intent kind.
@export var intent_icons: Dictionary = {
	DBIntent.Kind.ATTACK: &"sword", DBIntent.Kind.ATTACK_DEBUFF: &"dagger", DBIntent.Kind.ATTACK_DEFEND: &"mace",
	DBIntent.Kind.DEFEND: &"shield", DBIntent.Kind.BUFF: &"ring", DBIntent.Kind.DEBUFF: &"bone", DBIntent.Kind.UNKNOWN: &"scroll"}

var mode: Mode = Mode.IDLE
var _stage := Control.new()
var _player_box := CenterContainer.new()
var _enemy_row := HBoxContainer.new()
var _player_view: DBFighterView
var _enemy_views: Array[DBFighterView] = []
var _hand := Control.new()
var _hand_views: Array[DBCardView] = []
var _hover := -1
var _key_mode := false
var _drag_view: DBCardView
var _drag_start := Vector2.ZERO
var _drag_moved := false
var _pending_item: StringName
var _aim_index := 0
var _aimed: DBFighterView
var _energy := Label.new()
var _energy_orb := Panel.new()
var _draw_button := Button.new()
var _discard_button := Button.new()
var _exhaust_button := Button.new()
var _end_button := Button.new()
var _items := HBoxContainer.new()
var _relics := HBoxContainer.new()
var _relic_icons: Dictionary = {}  # DBRelic -> Control
var _hint := Label.new()
var _log := RichTextLabel.new()
var _lines: PackedStringArray = []
var _arrow := Control.new()
var _floats := Control.new()
var _flying := Control.new()
var _picker := DBCardPicker.new()
var _end_layer := CenterContainer.new()
var _end_box := VBoxContainer.new()
var _shake_left := 0.0
var _shake_power := 0.0
var _playback := 0
var _hint_serial := 0


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	_build()


func _ready() -> void:
	if combat != null and combat.is_running():
		rebuild()


## The view of [param fighter] (null if none).
func get_fighter_view(fighter: DBFighter) -> DBFighterView:
	if _player_view != null and _player_view.fighter == fighter:
		return _player_view
	for view in _enemy_views:
		if view.fighter == fighter:
			return view
	return null


func get_hand_views() -> Array[DBCardView]:
	return _hand_views


func get_picker() -> DBCardPicker:
	return _picker


## Rebuilds everything from the combat (call after [method DBCombat.start] if the view
## was not connected yet; it is done for you on [signal DBCombat.combat_started]).
func rebuild() -> void:
	if combat == null:
		return
	_playback += 1
	var db := _db()
	_picker.database = db
	_picker.combat = combat
	if _player_view != null:
		_player_view.queue_free()
	_player_view = DBFighterView.new()
	_player_view.intent_icons = intent_icons
	_player_view.setup(combat.player, combat, db, player_portrait)
	_player_box.add_child(_player_view)
	for view in _enemy_views:
		view.queue_free()
	_enemy_views.clear()
	for enemy in combat.enemies:
		var view := DBFighterView.new()
		view.intent_icons = intent_icons
		view.setup(enemy, combat, db, enemy_portrait * (1.25 if enemy.data != null and enemy.data.is_elite else 1.0))
		_enemy_row.add_child(view)
		_enemy_views.append(view)
	for view in _hand_views:
		view.queue_free()
	_hand_views.clear()
	for card in combat.hand:
		_spawn_card(card, false)
	_build_relics()
	_refresh_items()
	_lines.clear()
	_log.text = ""
	_end_layer.visible = false
	_picker.visible = false
	mode = Mode.ENDED if combat.phase == DBCombat.Phase.ENDED else Mode.IDLE
	_refresh_counters()
	_set_hint(DEFAULT_HINT)


# --- Building ----------------------------------------------------------------

func _build() -> void:
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	var arena := HBoxContainer.new()
	arena.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(arena)
	arena.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	arena.offset_top = 44
	arena.offset_bottom = -250
	arena.offset_left = 30
	arena.offset_right = -30
	_player_box.custom_minimum_size = Vector2(240, 0)
	_player_box.mouse_filter = MOUSE_FILTER_IGNORE
	arena.add_child(_player_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	arena.add_child(spacer)
	var enemy_center := CenterContainer.new()
	enemy_center.mouse_filter = MOUSE_FILTER_IGNORE
	enemy_center.size_flags_horizontal = SIZE_EXPAND_FILL
	enemy_center.size_flags_stretch_ratio = 2.2
	arena.add_child(enemy_center)
	_enemy_row.add_theme_constant_override(&"separation", 26)
	_enemy_row.mouse_filter = MOUSE_FILTER_IGNORE
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_center.add_child(_enemy_row)

	_relics.position = Vector2(14, 8)
	_relics.add_theme_constant_override(&"separation", 4)
	_stage.add_child(_relics)

	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.mouse_filter = MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override(&"normal_font_size", 12)
	_log.modulate = Color(1, 1, 1, 0.8)
	_stage.add_child(_log)
	_log.set_anchors_preset(PRESET_TOP_LEFT)
	_log.offset_left = 14
	_log.offset_right = 300
	_log.offset_top = 48
	_log.offset_bottom = 150

	_hand.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_hand)
	_hand.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_hand.offset_top = -240
	_hand.offset_bottom = 0
	_hand.offset_left = 210
	_hand.offset_right = -210

	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 8)
	left.alignment = BoxContainer.ALIGNMENT_END
	_stage.add_child(left)
	left.set_anchors_preset(PRESET_BOTTOM_LEFT)
	left.offset_left = 16
	left.offset_right = 196
	left.offset_top = -236
	left.offset_bottom = -14
	_items.add_theme_constant_override(&"separation", 4)
	left.add_child(_items)
	var orb_style := StyleBoxFlat.new()
	orb_style.bg_color = Color(0.85, 0.55, 0.15)
	orb_style.set_corner_radius_all(40)
	orb_style.set_border_width_all(4)
	orb_style.border_color = Color(1.0, 0.9, 0.55)
	orb_style.shadow_color = Color(1.0, 0.7, 0.2, 0.45)
	orb_style.shadow_size = 10
	_energy_orb.add_theme_stylebox_override(&"panel", orb_style)
	_energy_orb.custom_minimum_size = Vector2(80, 80)
	_energy_orb.size_flags_horizontal = SIZE_SHRINK_CENTER
	_energy_orb.tooltip_text = DBText.t("Energy: cards cost energy. It refills each turn.")
	left.add_child(_energy_orb)
	_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy.add_theme_font_size_override(&"font_size", 26)
	_energy.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_energy.add_theme_constant_override(&"outline_size", 6)
	_energy.mouse_filter = MOUSE_FILTER_IGNORE
	_energy_orb.add_child(_energy)
	_energy.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_draw_button.focus_mode = FOCUS_NONE
	_draw_button.pressed.connect(func() -> void: _show_pile(DBText.t("Draw pile (shown in no particular order)"), combat.draw_pile))
	left.add_child(_draw_button)

	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	_stage.add_child(right)
	right.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	right.offset_left = -196
	right.offset_right = -16
	right.offset_top = -236
	right.offset_bottom = -14
	_end_button.text = DBText.t("End turn")
	_end_button.custom_minimum_size = Vector2(0, 52)
	_end_button.add_theme_font_size_override(&"font_size", 20)
	_end_button.focus_mode = FOCUS_NONE
	_end_button.pressed.connect(end_turn)
	right.add_child(_end_button)
	for pair in [[_discard_button, "discard"], [_exhaust_button, "exhaust"]]:
		var button: Button = pair[0]
		button.focus_mode = FOCUS_NONE
		right.add_child(button)
	_discard_button.pressed.connect(func() -> void: _show_pile(DBText.t("Discard pile"), combat.discard_pile))
	_exhaust_button.pressed.connect(func() -> void: _show_pile(DBText.t("Exhausted (gone until the end of the combat)"), combat.exhaust_pile))

	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override(&"font_size", 15)
	_hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override(&"outline_size", 4)
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_hint)
	_hint.set_anchors_preset(PRESET_TOP_WIDE)
	_hint.offset_top = 10
	_hint.offset_bottom = 34

	_flying.mouse_filter = MOUSE_FILTER_IGNORE
	_flying.z_index = 80
	add_child(_flying)
	_flying.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_arrow.mouse_filter = MOUSE_FILTER_IGNORE
	_arrow.z_index = 90
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)
	_arrow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_floats.mouse_filter = MOUSE_FILTER_IGNORE
	_floats.z_index = 95
	add_child(_floats)
	_floats.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_picker)
	_picker.z_index = 200
	_picker.picked.connect(_on_reward_picked)
	_picker.closed.connect(_on_picker_closed)
	_end_layer.visible = false
	_end_layer.z_index = 200
	add_child(_end_layer)
	_end_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var end_panel := PanelContainer.new()
	_end_layer.add_child(end_panel)
	_end_box.add_theme_constant_override(&"separation", 12)
	_end_box.custom_minimum_size = Vector2(340, 0)
	end_panel.add_child(_end_box)


func _build_relics() -> void:
	for child in _relics.get_children():
		child.queue_free()
	_relic_icons.clear()
	for relic in combat.relics:
		if relic == null:
			continue
		var icon := TextureRect.new()
		icon.texture = relic.get_icon(_db())
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(34, 34)
		icon.pivot_offset = Vector2(17, 17)
		icon.tooltip_text = "%s\n%s" % [relic.get_title(), relic.get_description()]
		_relics.add_child(icon)
		_relic_icons[relic] = icon


func _refresh_items() -> void:
	for child in _items.get_children():
		child.queue_free()
	if combat == null or combat.bag == null:
		return
	var db := _db()
	for item_id: StringName in combat.item_cards:
		var amount := combat.bag.count(item_id)
		if amount <= 0:
			continue
		var data: DBCardData = combat.item_cards[item_id]
		var definition := db.get_item(item_id) if db != null else null
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.focus_mode = FOCUS_NONE
		var title := IKText.t(definition.display_name) if definition != null and not definition.display_name.is_empty() else data.get_title()
		slot.tooltip_text = "%s\n%s" % [title, DBText.describe_card(DBCard.new(data)).replace("[b]", "").replace("[/b]", "")]
		slot.pressed.connect(choose_item.bind(item_id))
		var icon := TextureRect.new()
		icon.texture = definition.icon if definition != null else null
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		icon.offset_left = 5
		icon.offset_top = 5
		icon.offset_right = -5
		icon.offset_bottom = -5
		if amount > 1:
			var count := Label.new()
			count.text = str(amount)
			count.add_theme_font_size_override(&"font_size", 13)
			count.add_theme_color_override(&"font_outline_color", Color.BLACK)
			count.add_theme_constant_override(&"outline_size", 4)
			count.mouse_filter = MOUSE_FILTER_IGNORE
			slot.add_child(count)
			count.position = Vector2(30, 26)
		_items.add_child(slot)


func _refresh_counters() -> void:
	if combat == null:
		return
	_energy.text = "%d/%d" % [combat.energy, combat.max_energy + (combat.player.get_energy_per_turn() if combat.player != null else 0)]
	_draw_button.text = DBText.t("Draw pile: %d") % combat.draw_pile.size()
	_discard_button.text = DBText.t("Discard: %d") % combat.discard_pile.size()
	_exhaust_button.text = DBText.t("Exhausted: %d") % combat.exhaust_pile.size()
	_exhaust_button.visible = not combat.exhaust_pile.is_empty()
	_end_button.disabled = mode != Mode.IDLE
	for view in _hand_views:
		view.set_playable(combat.phase == DBCombat.Phase.PLAYER and view.card.is_playable() and view.card.get_cost() <= combat.energy)
		view.refresh()


# --- Player actions ----------------------------------------------------------

## Plays [param card] (aiming at [param target] when it needs one). Same as dragging it.
func play(card: DBCard, target: DBFighter = null) -> DBResult:
	if combat == null or mode == Mode.BUSY or mode == Mode.ENDED:
		return DBResult.failure(DBResult.Code.NOT_YOUR_TURN)
	var view := _view_of(card)
	var result := combat.play_card(card, target)
	if not result.ok:
		_refuse(result)
		if view != null:
			_wiggle(view)
		_cancel_aim()
		return result
	if view != null:
		_hand_views.erase(view)
		var destination := _exhaust_button if combat.exhaust_pile.has(card) else (null if combat.powers.has(card) else _discard_button)
		_fly_away(view, destination)
	_cancel_aim()
	if target != null and card.data.type == DBCardData.Type.ATTACK:
		_player_view.lunge(get_fighter_view(target).get_portrait_center() - _player_view.get_portrait_center(), 26.0)
	_play_events(result.events, false)
	return result


## Uses an item from the bag (asks for a target first when it needs one).
func choose_item(item_id: StringName) -> void:
	if mode != Mode.IDLE or combat == null:
		return
	var data: DBCardData = combat.item_cards.get(item_id)
	if data == null:
		return
	if data.aim == DBCardData.Aim.ONE_ENEMY:
		_pending_item = item_id
		_start_aim(null)
		return
	use_item(item_id)


func use_item(item_id: StringName, target: DBFighter = null) -> DBResult:
	var result := combat.use_item(item_id, target)
	_pending_item = &""
	_cancel_aim()
	if not result.ok:
		_refuse(result)
		return result
	_refresh_items()
	_play_events(result.events, false)
	return result


func end_turn() -> void:
	if combat == null or mode != Mode.IDLE:
		return
	_cancel_aim()
	var result := combat.end_turn()
	if not result.ok:
		_refuse(result)
		return
	_play_events(result.events, true)


func _refuse(result: DBResult) -> void:
	var text := DBText.result_message(result)
	_set_hint(text, true)
	refused.emit(result, text)


# --- Event playback ----------------------------------------------------------

## Shows the events one by one: floating numbers, bars, cards drawn and discarded. The
## enemy turn is slowed down by [member event_delay].
func _play_events(events: Array[Dictionary], slow: bool) -> void:
	_playback += 1
	var serial := _playback
	mode = Mode.BUSY
	_refresh_counters()
	var ended := false
	for event in events:
		if serial != _playback or not is_inside_tree():
			return
		_show_event(event)
		var line := DBText.describe(event)
		if not line.is_empty():
			_add_log(line)
		var type := String(event.type)
		ended = ended or type == "victory" or type == "defeat"
		var wait := 0.0
		if slow and type == "intent":
			wait = event_delay
		elif type == "draw":
			wait = 0.06
		elif type in ["damage", "lose_hp"]:
			wait = 0.12 if slow else 0.05
		elif type == "defeated":
			wait = 0.3
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
	if serial != _playback:
		return
	_sync_hand()
	_refresh_all()
	if ended or combat.phase == DBCombat.Phase.ENDED:
		mode = Mode.ENDED
		_refresh_counters()
		await get_tree().create_timer(0.5).timeout
		if serial == _playback:
			_show_end()
		return
	mode = Mode.IDLE
	_refresh_counters()
	_set_hint(DEFAULT_HINT)


func _show_event(event: Dictionary) -> void:
	var target: DBFighter = event.get("target")
	var view := get_fighter_view(target) if target != null else null
	match String(event.type):
		"draw":
			_spawn_card(event.card, true)
		"discard", "exhaust":
			var card_view := _view_of(event.card)
			if card_view != null:
				_hand_views.erase(card_view)
				_fly_away(card_view, _discard_button if event.type == "discard" else _exhaust_button)
		"add_card":
			if event.pile == DBEffect.Pile.HAND:
				_spawn_card(event.card, true)
			else:
				_float(_player_view.get_portrait_center() + Vector2(0, -60), "+" + (event.card as DBCard).get_title(), Color(0.85, 0.7, 1.0))
		"intent":
			var source := get_fighter_view(event.source)
			if source != null:
				if (event.intent as DBIntent).get_kind() in [DBIntent.Kind.ATTACK, DBIntent.Kind.ATTACK_DEBUFF, DBIntent.Kind.ATTACK_DEFEND]:
					source.lunge(_player_view.get_portrait_center() - source.get_portrait_center(), 34.0)
				_float(source.get_portrait_center() + Vector2(0, -enemy_portrait * 0.7), (event.intent as DBIntent).get_title(), Color(1, 0.9, 0.7), 16)
		"damage":
			if view != null:
				view.show_hp(event.hp, event.block)
				if event.hp_loss > 0:
					view.flinch()
					_float(view.get_portrait_center(), "-%d" % event.hp_loss, Color(1.0, 0.4, 0.35), 30)
					if target.is_player and shake_threshold > 0 and event.hp_loss >= shake_threshold:
						shake(6.0)
				elif event.blocked > 0:
					_float(view.get_portrait_center(), DBText.t("Blocked"), DBFighterView.BLOCK_COLOR, 20)
		"lose_hp":
			if view != null:
				view.show_hp(event.hp, view.get_shown_block())
				if event.amount > 0:
					var color := (event.status as DBStatus).color if event.status != null else Color(1, 0.4, 0.35)
					_float(view.get_portrait_center(), "-%d" % event.amount, color, 26)
		"heal":
			if view != null and event.amount > 0:
				view.show_hp(event.hp, view.get_shown_block())
				_float(view.get_portrait_center(), "+%d" % event.amount, Color(0.5, 1.0, 0.5), 26)
		"block":
			if view != null and event.amount > 0:
				view.show_hp(view.get_shown_hp(), event.block)
				_float(view.get_portrait_center() + Vector2(0, 30), "+%d" % event.amount, DBFighterView.BLOCK_COLOR, 22)
		"block_lost":
			if view != null:
				view.show_hp(view.get_shown_hp(), 0)
		"status":
			if view != null:
				view.refresh_statuses()
				if event.stacks > 0:
					var status: DBStatus = event.status
					_float(view.get_portrait_center() + Vector2(0, -24), "+%d %s" % [event.stacks, status.get_title()], status.color, 17)
		"next_intent":
			var source := get_fighter_view(event.source)
			if source != null:
				source.refresh_intent()
		"defeated":
			if view != null and not target.is_player:
				view.fade_out()
		"energy":
			_energy.text = "%d/%d" % [event.energy, combat.max_energy + combat.player.get_energy_per_turn()]
		"relic":
			var icon: Control = _relic_icons.get(event.relic)
			if icon != null:
				var pop := create_tween()
				pop.tween_property(icon, ^"scale", Vector2.ONE * 1.5, 0.1)
				pop.tween_property(icon, ^"scale", Vector2.ONE, 0.2)
		"turn":
			for enemy_view in _enemy_views:
				enemy_view.refresh_intent()
			_set_hint(DBText.t("Your turn."))
		"enemy_turn":
			_set_hint(DBText.t("Enemy turn..."))


func _refresh_all() -> void:
	if _player_view != null:
		_player_view.refresh()
	for view in _enemy_views:
		view.refresh()
	_refresh_items()
	_refresh_counters()


## Makes the hand views match [member DBCombat.hand] (after custom effects, for example).
func _sync_hand() -> void:
	for view in _hand_views.duplicate():
		if not combat.hand.has(view.card):
			_hand_views.erase(view)
			_fly_away(view, _discard_button)
	for card in combat.hand:
		if _view_of(card) == null:
			_spawn_card(card, true)
	var ordered: Array[DBCardView] = []
	for card in combat.hand:
		ordered.append(_view_of(card))
	_hand_views = ordered


func _end_screen_title() -> String:
	return DBText.t("Victory!") if combat.outcome == DBCombat.Outcome.VICTORY else DBText.t("Defeat...")


func _show_end() -> void:
	var rewards := combat.rewards
	var cards: Array = rewards.get("cards", [])
	if combat.outcome == DBCombat.Outcome.VICTORY and not cards.is_empty():
		var title := _end_screen_title()
		if int(rewards.get("gold", 0)) > 0:
			title += "  " + DBText.t("+%d gold.") % rewards.gold
		_picker.open(title + "  " + DBText.t("Add a card to your deck:"), cards, true, DBText.t("Skip"))
		return
	for child in _end_box.get_children():
		child.queue_free()
	var title_label := Label.new()
	title_label.text = _end_screen_title()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override(&"font_size", 28)
	_end_box.add_child(title_label)
	if int(rewards.get("gold", 0)) > 0:
		var gold := Label.new()
		gold.text = DBText.t("+%d gold.") % rewards.gold
		gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_end_box.add_child(gold)
	var button := Button.new()
	button.text = DBText.t("Continue")
	button.pressed.connect(func() -> void:
		_end_layer.visible = false
		finished.emit(combat.outcome, null))
	_end_box.add_child(button)
	_end_layer.visible = true
	button.grab_focus.call_deferred()


func _on_reward_picked(_index: int, card: DBCard) -> void:
	if mode == Mode.ENDED:
		finished.emit(combat.outcome, card.data)


func _on_picker_closed() -> void:
	if mode == Mode.ENDED:
		finished.emit(combat.outcome, null)


func _show_pile(title: String, pile: Array[DBCard]) -> void:
	if mode != Mode.IDLE or combat == null:
		return
	_cancel_aim()
	_picker.open(title, combat.get_pile_for_display(pile), false)


# --- Hand ----------------------------------------------------------------------

func _view_of(card: DBCard) -> DBCardView:
	for view in _hand_views:
		if view.card == card:
			return view
	return null


func _spawn_card(card: DBCard, animate: bool) -> void:
	if _view_of(card) != null:
		return
	var view := DBCardView.new().setup(card, _db(), combat)
	view.scale = Vector2.ONE * hand_scale
	view.rest_scale = hand_scale
	_hand.add_child(view)
	if animate:
		view.position = _draw_button.global_position - _hand.global_position
		view.scale = Vector2.ONE * 0.2
		view.rotation = -0.6
	view.mouse_entered.connect(func() -> void:
		if mode == Mode.IDLE and not _key_mode:
			_hover = _hand_views.find(view))
	view.mouse_exited.connect(func() -> void:
		if mode == Mode.IDLE and _hover == _hand_views.find(view) and not _key_mode:
			_hover = -1)
	view.pressed.connect(_on_card_pressed)
	_hand_views.append(view)
	if mode == Mode.IDLE:
		_refresh_counters()


func _fly_away(view: DBCardView, destination: Control) -> void:
	var from := view.global_position
	view.get_parent().remove_child(view)
	_flying.add_child(view)
	view.global_position = from
	view.set_highlight(false)
	var tween := view.create_tween().set_parallel()
	if destination != null:
		tween.tween_property(view, ^"global_position", destination.global_position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(view, ^"scale", Vector2.ONE * 0.15, 0.3)
		tween.tween_property(view, ^"rotation", 0.8, 0.3)
	else:
		tween.tween_property(view, ^"position:y", view.position.y - 160.0, 0.4)
		tween.tween_property(view, ^"modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(view.queue_free)


func _layout_hand(delta: float) -> void:
	var count := _hand_views.size()
	if count == 0:
		return
	var card_size := DBCardView.BASE_SIZE * hand_scale
	var width := _hand.size.x
	var spacing := minf(card_size.x * 0.82, (width - card_size.x) / maxf(count - 1, 1))
	var total := spacing * (count - 1)
	var start := (width - total) * 0.5 - card_size.x * 0.5
	var lift := 1.0 - exp(-delta * 16.0)
	for i in count:
		var view := _hand_views[i]
		var t := i - (count - 1) * 0.5
		var x := start + i * spacing
		var y := 26.0 + absf(t) * absf(t) * 3.0
		var angle := clampf(t * 0.05, -0.35, 0.35)
		var scale_to := hand_scale
		view.z_index = i
		if _hover >= 0 and i != _hover:
			x += signf(i - _hover) * minf(card_size.x * 0.22, spacing * 0.3)
		if i == _hover:
			y = -46.0
			angle = 0.0
			scale_to = hand_scale * 1.18
			view.z_index = 50
		if view == _drag_view and mode == Mode.DRAG and _drag_moved and not view.card.needs_target():
			var mouse := _hand.get_local_mouse_position()
			view.position = view.position.lerp(mouse - Vector2(card_size.x * 0.5, card_size.y * 0.6), lift)
			view.rotation = lerpf(view.rotation, 0.0, lift)
			view.z_index = 60
			continue
		view.position = view.position.lerp(Vector2(x, y), lift)
		view.rotation = lerpf(view.rotation, angle, lift)
		view.scale = view.scale.lerp(Vector2.ONE * scale_to, lift)
		view.set_highlight(i == _hover and (mode == Mode.AIM or _key_mode or mode == Mode.DRAG))


func _on_card_pressed(view: DBCardView) -> void:
	if mode != Mode.IDLE or combat == null:
		return
	_key_mode = false
	_hover = _hand_views.find(view)
	_drag_view = view
	_drag_start = get_global_mouse_position()
	_drag_moved = false
	mode = Mode.DRAG


func _start_aim(view: DBCardView) -> void:
	mode = Mode.AIM
	_drag_view = view
	var alive := combat.get_alive_enemies()
	_aim_index = 0
	for enemy_view in _enemy_views:
		enemy_view.set_targetable(alive.has(enemy_view.fighter))
	if _key_mode and not alive.is_empty():
		_set_aimed(get_fighter_view(alive[0]))
	_set_hint(DBText.t("Choose an enemy. Right click or Escape cancels."))


func _cancel_aim() -> void:
	if mode == Mode.AIM or mode == Mode.DRAG:
		mode = Mode.IDLE
	_drag_view = null
	_pending_item = &""
	_set_aimed(null)
	for enemy_view in _enemy_views:
		enemy_view.set_targetable(false)
	if not _key_mode:
		_hover = -1
	_arrow.queue_redraw()


func _set_aimed(view: DBFighterView) -> void:
	if _aimed == view:
		return
	if _aimed != null and is_instance_valid(_aimed):
		_aimed.set_aimed(false)
	_aimed = view
	if _aimed != null:
		_aimed.set_aimed(true)
	if _drag_view != null:
		_drag_view.set_preview_target(view.fighter if view != null else null)


func _enemy_view_at(point: Vector2) -> DBFighterView:
	for view in _enemy_views:
		if view.fighter.is_alive() and view.get_aim_rect().has_point(point):
			return view
	return null


func _confirm_aim(view: DBFighterView) -> void:
	if view == null:
		_cancel_aim()
		return
	if not _pending_item.is_empty():
		use_item(_pending_item, view.fighter)
	elif _drag_view != null:
		play(_drag_view.card, view.fighter)


func _input(event: InputEvent) -> void:
	if combat == null or _picker.visible or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		_key_mode = false
		if mode == Mode.DRAG:
			if not _drag_moved and get_global_mouse_position().distance_to(_drag_start) > 14.0:
				_drag_moved = true
				if _drag_view.card.needs_target():
					_start_aim(_drag_view)
					mode = Mode.DRAG
					_drag_moved = true
		if mode == Mode.AIM or (mode == Mode.DRAG and _drag_moved and _drag_view.card.needs_target()):
			_set_aimed(_enemy_view_at(get_global_mouse_position()))
			_arrow.queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (mode == Mode.AIM or mode == Mode.DRAG):
			_cancel_aim()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and mode == Mode.DRAG:
			get_viewport().set_input_as_handled()
			var view := _drag_view
			if not _drag_moved:
				if view.card.needs_target():
					_start_aim(view)
				else:
					play(view.card)
			elif view.card.needs_target():
				_confirm_aim(_enemy_view_at(get_global_mouse_position()))
			elif get_global_mouse_position().y < _hand.global_position.y + 10.0:
				play(view.card)
			else:
				_cancel_aim()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and mode == Mode.AIM:
			get_viewport().set_input_as_handled()
			_confirm_aim(_enemy_view_at(get_global_mouse_position()))


func _unhandled_input(event: InputEvent) -> void:
	if combat == null or _picker.visible or not is_visible_in_tree() or event is InputEventMouse:
		return
	var handled := true
	if _is_end_turn(event) and mode == Mode.IDLE:
		end_turn()
	elif mode == Mode.AIM:
		var alive := combat.get_alive_enemies()
		if event.is_action_pressed(&"ui_cancel"):
			_cancel_aim()
		elif alive.is_empty():
			handled = false
		elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left"):
			_aim_index = wrapi(_aim_index + (1 if event.is_action_pressed(&"ui_right") else -1), 0, alive.size())
			_set_aimed(get_fighter_view(alive[_aim_index]))
			_arrow.queue_redraw()
		elif event.is_action_pressed(&"ui_accept"):
			_confirm_aim(_aimed if _aimed != null else get_fighter_view(alive[0]))
		else:
			handled = false
	elif mode == Mode.IDLE and not _hand_views.is_empty():
		if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left"):
			_key_mode = true
			var step := 1 if event.is_action_pressed(&"ui_right") else -1
			_hover = 0 if _hover < 0 else wrapi(_hover + step, 0, _hand_views.size())
		elif event.is_action_pressed(&"ui_accept") and _hover >= 0 and _hover < _hand_views.size():
			_key_mode = true
			var view := _hand_views[_hover]
			if view.card.needs_target():
				var check := combat.can_play(view.card, combat.get_alive_enemies()[0] if not combat.get_alive_enemies().is_empty() else null)
				if not check.ok:
					_refuse(check)
					_wiggle(view)
				else:
					_start_aim(view)
			else:
				play(view.card)
		elif event.is_action_pressed(&"ui_cancel"):
			_hover = -1
		else:
			handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _is_end_turn(event: InputEvent) -> bool:
	if InputMap.has_action(&"db_end_turn"):
		return event.is_action_pressed(&"db_end_turn")
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode == KEY_E
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_Y
	return false


func _draw_arrow() -> void:
	var aiming := mode == Mode.AIM or (mode == Mode.DRAG and _drag_moved and _drag_view != null and _drag_view.card.needs_target())
	if not aiming:
		return
	var from: Vector2
	if _drag_view != null and is_instance_valid(_drag_view):
		from = _drag_view.get_global_rect().get_center() - Vector2(0, DBCardView.BASE_SIZE.y * 0.3)
	else:
		from = _energy_orb.get_global_rect().get_center()
	var to := _aimed.get_portrait_center() if _aimed != null else get_global_mouse_position()
	from -= global_position
	to -= global_position
	var control := (from + to) * 0.5 + Vector2(0, -absf(to.x - from.x) * 0.35 - 80.0)
	var points := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	var color := Color(1.0, 0.85, 0.35) if _aimed != null else Color(0.9, 0.9, 0.9, 0.7)
	_arrow.draw_polyline(points, Color(0, 0, 0, 0.5), 9.0, true)
	_arrow.draw_polyline(points, color, 5.0, true)
	var direction := (points[20] - points[18]).normalized()
	var side := Vector2(-direction.y, direction.x)
	_arrow.draw_colored_polygon(PackedVector2Array([to + direction * 10.0, to - direction * 14.0 + side * 12.0, to - direction * 14.0 - side * 12.0]), color)


func _wiggle(view: DBCardView) -> void:
	var tween := view.create_tween()
	for i in 4:
		tween.tween_property(view, ^"rotation", 0.08 * (1 if i % 2 == 0 else -1), 0.04)
	tween.tween_property(view, ^"rotation", view.rest_rotation, 0.05)


# --- Feel ------------------------------------------------------------------------

func shake(strength: float = 6.0, time: float = 0.25) -> void:
	_shake_left = time
	_shake_power = strength


func _float(global_point: Vector2, text: String, color: Color, font_size: int = 24) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	_floats.add_child(label)
	label.position = global_point - _floats.global_position + Vector2(randf_range(-14, 14), -10)
	label.pivot_offset = Vector2(20, 12)
	label.scale = Vector2.ONE * 0.4
	var tween := label.create_tween()
	tween.tween_property(label, ^"scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, ^"scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(label, ^"position:y", label.position.y - 50.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _process(delta: float) -> void:
	_layout_hand(delta)
	if mode == Mode.AIM or mode == Mode.DRAG:
		_arrow.queue_redraw()
	if _shake_left > 0.0:
		_shake_left -= delta
		_stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_power if _shake_left > 0.0 else Vector2.ZERO


func _set_hint(text: String, warning: bool = false) -> void:
	_hint_serial += 1
	_hint.text = DBText.t(text)
	_hint.modulate = Color(1, 0.6, 0.5) if warning else Color(1, 1, 1, 0.85)


func _add_log(line: String) -> void:
	if not show_log:
		_log.visible = false
		return
	_lines.append(line)
	while _lines.size() > 40:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines.slice(maxi(0, _lines.size() - 8)))


func _db() -> IKItemDatabase:
	if database != null:
		return database
	return combat.bag.database if combat != null and combat.bag != null else null


func _connect_combat() -> void:
	if combat == null:
		return
	combat.combat_started.connect(_on_combat_started)


func _disconnect_combat() -> void:
	if combat != null and combat.combat_started.is_connected(_on_combat_started):
		combat.combat_started.disconnect(_on_combat_started)


func _on_combat_started() -> void:
	# start() finishes drawing after this signal: rebuild once it is done.
	_rebuild_after_start.call_deferred()


func _rebuild_after_start() -> void:
	rebuild()
	for card_view in _hand_views:
		card_view.position = _draw_button.global_position - _hand.global_position
		card_view.scale = Vector2.ONE * 0.2
	_add_log(DBText.t("Turn %d.") % combat.turn)
