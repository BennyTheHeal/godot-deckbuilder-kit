class_name DBCardView
extends Control
## One card on screen: cost gem, title, art (an item icon or your texture), type and
## rarity, and the card text with live numbers. Colored by type, edged by rarity. Used by
## the hand, the pile viewer, rewards and the deck screen.

signal pressed(view: DBCardView)

const BASE_SIZE := Vector2(150, 212)

var card: DBCard
## For live numbers (damage and block with statuses). Null = numbers as written.
var combat: DBCombat
## Target of the live numbers (the enemy being aimed at).
var preview_target: DBFighter
var database: IKItemDatabase
## Hand layout: where the card rests and how it is turned (the hand tweens toward it).
var rest_position := Vector2.ZERO
var rest_rotation := 0.0
var rest_scale := 1.0

var _body := Panel.new()
var _style := StyleBoxFlat.new()
var _art_frame := Panel.new()
var _art := TextureRect.new()
var _title := Label.new()
var _type := Label.new()
var _text := RichTextLabel.new()
var _cost_gem := Panel.new()
var _cost := Label.new()
var _gem_style := StyleBoxFlat.new()
var _glow := StyleBoxFlat.new()
var _glow_panel := Panel.new()
var _playable := true
var _highlight := false


func _init() -> void:
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	pivot_offset = Vector2(BASE_SIZE.x * 0.5, BASE_SIZE.y)
	mouse_filter = MOUSE_FILTER_STOP
	_glow.bg_color = Color(0, 0, 0, 0)
	_glow.set_corner_radius_all(14)
	_glow.set_border_width_all(4)
	_glow.border_color = Color(1.0, 0.92, 0.5, 0.95)
	_glow.set_expand_margin_all(4)
	_glow_panel.add_theme_stylebox_override(&"panel", _glow)
	_glow_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_glow_panel.visible = false
	add_child(_glow_panel)
	_glow_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style.set_corner_radius_all(10)
	_style.set_border_width_all(3)
	_style.shadow_color = Color(0, 0, 0, 0.45)
	_style.shadow_size = 6
	_style.shadow_offset = Vector2(0, 3)
	_body.add_theme_stylebox_override(&"panel", _style)
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_body)
	_body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.add_theme_font_size_override(&"font_size", 15)
	_title.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override(&"outline_size", 4)
	_title.position = Vector2(26, 8)
	_title.size = Vector2(BASE_SIZE.x - 34, 22)
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_title)

	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0.35)
	frame_style.set_corner_radius_all(6)
	_art_frame.add_theme_stylebox_override(&"panel", frame_style)
	_art_frame.position = Vector2(12, 34)
	_art_frame.size = Vector2(BASE_SIZE.x - 24, 70)
	_art_frame.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_art_frame)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = MOUSE_FILTER_IGNORE
	_art_frame.add_child(_art)
	_art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_art.offset_top = 4
	_art.offset_bottom = -4

	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type.add_theme_font_size_override(&"font_size", 11)
	_type.modulate = Color(1, 1, 1, 0.75)
	_type.position = Vector2(8, 105)
	_type.size = Vector2(BASE_SIZE.x - 16, 16)
	_type.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_type)

	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.fit_content = false
	_text.add_theme_font_size_override(&"normal_font_size", 13)
	_text.add_theme_font_size_override(&"bold_font_size", 13)
	_text.add_theme_color_override(&"default_color", Color(0.95, 0.94, 0.9))
	_text.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	_text.add_theme_constant_override(&"outline_size", 2)
	_text.position = Vector2(10, 123)
	_text.size = Vector2(BASE_SIZE.x - 20, BASE_SIZE.y - 130)
	_text.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_text)

	_gem_style.set_corner_radius_all(16)
	_gem_style.set_border_width_all(2)
	_gem_style.border_color = Color(1, 1, 1, 0.85)
	_cost_gem.add_theme_stylebox_override(&"panel", _gem_style)
	_cost_gem.position = Vector2(-8, -8)
	_cost_gem.size = Vector2(32, 32)
	_cost_gem.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_cost_gem)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost.add_theme_font_size_override(&"font_size", 18)
	_cost.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_cost.add_theme_constant_override(&"outline_size", 4)
	_cost.mouse_filter = MOUSE_FILTER_IGNORE
	_cost_gem.add_child(_cost)
	_cost.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func setup(p_card: DBCard, p_database: IKItemDatabase, p_combat: DBCombat = null) -> DBCardView:
	card = p_card
	database = p_database
	combat = p_combat
	refresh()
	return self


func refresh() -> void:
	if card == null:
		return
	var data := card.data
	var tint := data.get_color()
	_style.bg_color = tint.darkened(0.55)
	_style.border_color = DBText.rarity_color(data.rarity) if data.rarity != DBCardData.Rarity.STARTER else tint.lightened(0.15)
	_title.text = card.get_title()
	_title.add_theme_font_size_override(&"font_size", 15 if _title.text.length() <= 14 else (13 if _title.text.length() <= 17 else 11))
	_title.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6) if card.upgraded else Color.WHITE)
	_art.texture = data.get_icon(database)
	var kind := DBText.type_name(data.type)
	if data.rarity != DBCardData.Rarity.STARTER and data.rarity != DBCardData.Rarity.SPECIAL:
		kind += " · " + DBText.rarity_name(data.rarity)
	_type.text = kind
	_text.text = "[center]%s[/center]" % DBText.describe_card(card, combat, preview_target)
	_cost_gem.visible = card.is_playable()
	_cost.text = str(card.get_cost())
	_gem_style.bg_color = tint.darkened(0.15)
	_cost.add_theme_color_override(&"font_color", Color.WHITE if _playable else Color(1.0, 0.45, 0.4))
	tooltip_text = ""


## Dims the cost when the player cannot afford it.
func set_playable(playable: bool) -> void:
	if _playable == playable:
		return
	_playable = playable
	_body.self_modulate = Color.WHITE if playable else Color(0.7, 0.7, 0.72)
	refresh()


func is_playable_look() -> bool:
	return _playable


## The golden outline: selected, aimed, or playable highlight.
func set_highlight(on: bool) -> void:
	_highlight = on
	_glow_panel.visible = on


func set_preview_target(target: DBFighter) -> void:
	if preview_target == target:
		return
	preview_target = target
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		pressed.emit(self)
		accept_event()
