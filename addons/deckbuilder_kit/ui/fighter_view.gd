class_name DBFighterView
extends VBoxContainer
## The player or an enemy on the combat screen: the intent it announces (enemies), its
## portrait, name, HP bar with block, and status icons with stacks (hover for details).
## It is also what the player clicks or drops a card on to aim.

signal chosen(view: DBFighterView)
signal hovered(view: DBFighterView, inside: bool)

const BLOCK_COLOR := Color(0.45, 0.7, 1.0)

var fighter: DBFighter
var combat: DBCombat
var database: IKItemDatabase
## Item icons for the intent kinds (see [member DBCombatView.intent_icons]).
var intent_icons: Dictionary = {}
var portrait := TextureRect.new()
## Extra portrait offset, animated by [method lunge] and [method flinch].
var portrait_offset := Vector2.ZERO
var _intent_row := HBoxContainer.new()
var _intent_icon := TextureRect.new()
var _intent_text := Label.new()
var _holder := Control.new()
var _shadow := Panel.new()
var _name := Label.new()
var _hp := ProgressBar.new()
var _hp_text := Label.new()
var _block := Label.new()
var _block_badge := Panel.new()
var _statuses := HBoxContainer.new()
var _button := Button.new()
var _targetable := false
var _aimed := false
var _time := 0.0
var _size := 96.0
var _tween: Tween
var _shown_hp := 0
var _shown_block := 0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = ALIGNMENT_END
	add_theme_constant_override(&"separation", 3)
	_intent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_intent_row.custom_minimum_size = Vector2(0, 38)
	_intent_row.mouse_filter = MOUSE_FILTER_IGNORE
	_intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_intent_icon.custom_minimum_size = Vector2(36, 36)
	_intent_icon.mouse_filter = MOUSE_FILTER_PASS
	_intent_row.add_child(_intent_icon)
	_intent_text.add_theme_font_size_override(&"font_size", 20)
	_intent_text.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_intent_text.add_theme_constant_override(&"outline_size", 5)
	_intent_text.mouse_filter = MOUSE_FILTER_IGNORE
	_intent_row.add_child(_intent_text)
	add_child(_intent_row)
	_holder.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_holder)
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.28)
	shadow_style.set_corner_radius_all(999)
	_shadow.add_theme_stylebox_override(&"panel", shadow_style)
	_shadow.mouse_filter = MOUSE_FILTER_IGNORE
	_holder.add_child(_shadow)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	_holder.add_child(portrait)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override(&"font_size", 15)
	_name.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_name.add_theme_constant_override(&"outline_size", 4)
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_name)
	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override(&"separation", 0)
	add_child(bar_row)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = BLOCK_COLOR.darkened(0.35)
	badge_style.set_corner_radius_all(9)
	badge_style.set_border_width_all(2)
	badge_style.border_color = BLOCK_COLOR
	_block_badge.add_theme_stylebox_override(&"panel", badge_style)
	_block_badge.custom_minimum_size = Vector2(30, 20)
	_block_badge.mouse_filter = MOUSE_FILTER_IGNORE
	bar_row.add_child(_block_badge)
	_block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_block.add_theme_font_size_override(&"font_size", 13)
	_block.mouse_filter = MOUSE_FILTER_IGNORE
	_block_badge.add_child(_block)
	_block.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hp.show_percentage = false
	_hp.custom_minimum_size = Vector2(0, 18)
	_hp.size_flags_horizontal = SIZE_EXPAND_FILL
	_hp.size_flags_vertical = SIZE_SHRINK_CENTER
	_hp.mouse_filter = MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.6)
	back.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.27, 0.25)
	fill.set_corner_radius_all(5)
	_hp.add_theme_stylebox_override(&"background", back)
	_hp.add_theme_stylebox_override(&"fill", fill)
	bar_row.add_child(_hp)
	_hp_text.add_theme_font_size_override(&"font_size", 12)
	_hp_text.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hp_text.add_theme_constant_override(&"outline_size", 3)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.mouse_filter = MOUSE_FILTER_IGNORE
	_hp.add_child(_hp_text)
	_hp_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_statuses.add_theme_constant_override(&"separation", 2)
	_statuses.custom_minimum_size = Vector2(0, 26)
	_statuses.alignment = BoxContainer.ALIGNMENT_CENTER
	_statuses.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_statuses)
	_button.flat = true
	_button.focus_mode = FOCUS_NONE
	_button.mouse_filter = MOUSE_FILTER_PASS
	_button.pressed.connect(func() -> void: chosen.emit(self))
	_button.mouse_entered.connect(func() -> void: hovered.emit(self, true))
	_button.mouse_exited.connect(func() -> void: hovered.emit(self, false))
	_holder.add_child(_button)


func setup(p_fighter: DBFighter, p_combat: DBCombat, p_database: IKItemDatabase, portrait_size: float) -> void:
	fighter = p_fighter
	combat = p_combat
	database = p_database
	_size = portrait_size
	custom_minimum_size = Vector2(maxf(portrait_size + 40.0, 130.0), 0)
	_holder.custom_minimum_size = Vector2(portrait_size, portrait_size)
	_intent_row.visible = not fighter.is_player
	_intent_row.modulate.a = 1.0 if not fighter.is_player else 0.0
	modulate = Color.WHITE
	refresh()


func refresh() -> void:
	if fighter == null:
		return
	show_hp(fighter.hp, fighter.block)
	_name.text = fighter.get_title()
	portrait.texture = fighter.get_icon(database)
	if fighter.data != null:
		portrait.self_modulate = fighter.data.tint
	_refresh_intent()
	_refresh_statuses()
	if not fighter.is_alive() and not fighter.is_player:
		modulate = Color(1, 1, 1, 0.25)


## Shows these values instead of the fighter's current ones (event playback).
func show_hp(hp: int, block: int) -> void:
	_shown_hp = hp
	_shown_block = block
	_hp.max_value = fighter.max_hp
	_hp.value = hp
	_hp_text.text = "%d / %d" % [hp, fighter.max_hp]
	_block.text = str(block)
	_block_badge.modulate.a = 1.0 if block > 0 else 0.0
	(_hp.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color = BLOCK_COLOR.darkened(0.15) if block > 0 else Color(0.82, 0.27, 0.25)


func get_shown_hp() -> int:
	return _shown_hp


func get_shown_block() -> int:
	return _shown_block


func refresh_statuses() -> void:
	if fighter != null:
		_refresh_statuses()


func refresh_intent() -> void:
	if fighter != null:
		_refresh_intent()


func _refresh_intent() -> void:
	if fighter.is_player:
		return
	var intent := fighter.intent if fighter.is_alive() else null
	_intent_row.modulate.a = 1.0 if intent != null else 0.0
	if intent == null:
		return
	var kind := intent.get_kind()
	var item: StringName = intent_icons.get(kind, &"")
	var definition := database.get_item(item) if database != null and not item.is_empty() else null
	_intent_icon.texture = definition.icon if definition != null else null
	var preview := combat.preview_intent(fighter) if combat != null else {}
	_intent_text.text = DBText.intent_label(preview) if kind != DBIntent.Kind.UNKNOWN else "?"
	if _intent_text.text.is_empty() and int(preview.get("block", 0)) > 0:
		_intent_text.text = str(preview.block)
	var color := Color(1.0, 0.55, 0.45)
	match kind:
		DBIntent.Kind.DEFEND:
			color = BLOCK_COLOR
		DBIntent.Kind.BUFF:
			color = Color(0.55, 0.95, 0.55)
		DBIntent.Kind.DEBUFF:
			color = Color(0.85, 0.6, 1.0)
	_intent_text.add_theme_color_override(&"font_color", color)
	var tip := "%s — %s" % [intent.get_title(), DBText.intent_kind_name(kind)]
	if not preview.is_empty() and int(preview.get("hits", 0)) > 0:
		tip += "\n" + DBText.t("Deals %d damage in total.") % preview.total
	if int(preview.get("block", 0)) > 0:
		tip += "\n" + DBText.t("Gains %d Block.") % preview.block
	_intent_icon.tooltip_text = tip


func _refresh_statuses() -> void:
	for child in _statuses.get_children():
		child.queue_free()
	for status in fighter.get_statuses():
		var stacks := fighter.get_stacks(status.id)
		var box := Control.new()
		box.custom_minimum_size = Vector2(24, 24)
		box.tooltip_text = "%s %d\n%s" % [status.get_title(), stacks, status.get_description(stacks)]
		var icon := TextureRect.new()
		icon.texture = status.get_icon(database)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.self_modulate = status.color.lerp(Color.WHITE, 0.35)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(icon)
		icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var count := Label.new()
		count.text = str(stacks)
		count.add_theme_font_size_override(&"font_size", 12)
		count.add_theme_color_override(&"font_color", status.color.lightened(0.2))
		count.add_theme_color_override(&"font_outline_color", Color.BLACK)
		count.add_theme_constant_override(&"outline_size", 4)
		count.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(count)
		count.position = Vector2(13, 9)
		_statuses.add_child(box)


## Pulsing outline: this fighter can be aimed at.
func set_targetable(on: bool) -> void:
	_targetable = on
	if not on:
		_aimed = false
	_update_look()


## Bright: the card or item would hit this fighter now.
func set_aimed(on: bool) -> void:
	_aimed = on
	_update_look()


func is_aimed() -> bool:
	return _aimed


## The portrait's center in global coordinates (floating numbers, arrows).
func get_portrait_center() -> Vector2:
	return _holder.global_position + _holder.size * 0.5


## Rect the player can drop a card on.
func get_aim_rect() -> Rect2:
	return get_global_rect()


func lunge(direction: Vector2, distance: float = 30.0) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"portrait_offset", direction.normalized() * distance, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"portrait_offset", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func flinch(strength: float = 8.0) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	for i in 3:
		_tween.tween_property(self, ^"portrait_offset", Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * strength, 0.04)
	_tween.tween_property(self, ^"portrait_offset", Vector2.ZERO, 0.08)
	var flash := create_tween()
	flash.tween_property(portrait, ^"modulate", Color(1.8, 0.6, 0.6), 0.05)
	flash.tween_property(portrait, ^"modulate", Color.WHITE, 0.2)


func fade_out() -> void:
	var fade := create_tween()
	fade.tween_property(self, ^"modulate", Color(1, 1, 1, 0.25), 0.4)


func _process(delta: float) -> void:
	_time += delta
	var bob := sin(_time * 2.2 + (fighter.slot if fighter != null else 0) * 1.3) * 3.0 if fighter != null and fighter.is_alive() else 0.0
	_shadow.size = Vector2(_size * 0.8, _size * 0.16)
	_shadow.position = Vector2(_size * 0.1, _size * 0.84)
	portrait.size = Vector2(_size, _size)
	portrait.position = portrait_offset + Vector2(0, bob)
	_button.position = Vector2.ZERO
	_button.size = _holder.size
	if _targetable and not _aimed:
		portrait.self_modulate.a = 0.8 + 0.2 * sin(_time * 6.0)


func _update_look() -> void:
	var base := fighter.data.tint if fighter != null and fighter.data != null else Color.WHITE
	if _aimed:
		portrait.self_modulate = base * Color(1.35, 1.25, 0.9)
	else:
		portrait.self_modulate = base
	_name.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.45) if _aimed else Color.WHITE)
