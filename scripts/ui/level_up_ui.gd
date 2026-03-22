extends CanvasLayer

@onready var container: HBoxContainer = $Panel/VBox/CardContainer
@onready var panel: PanelContainer = $Panel
@onready var overlay: ColorRect = $Overlay

var _current_choices: Array = []
var _blessing_manager: Node = null


func set_blessing_manager(bm: Node) -> void:
	_blessing_manager = bm


func _ready() -> void:
	panel.visible = false
	overlay.visible = false
	GameEvents.show_level_up_ui.connect(_on_show)
	GameEvents.hide_level_up_ui.connect(_on_hide)

	# Style the panel background to be transparent (overlay handles dimming)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Style the title
	var title: Label = $Panel/VBox/Title
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))


func _on_show(choices: Array) -> void:
	if choices.is_empty():
		# All blessings maxed — nothing to offer, auto-dismiss
		GameEvents.hide_level_up_ui.emit()
		return
	_current_choices = choices
	get_tree().paused = true
	overlay.visible = true
	panel.visible = true
	_build_cards(choices)


func _on_hide() -> void:
	get_tree().paused = false
	overlay.visible = false
	panel.visible = false
	_clear_cards()


func _build_cards(choices: Array) -> void:
	_clear_cards()
	for i in range(choices.size()):
		var blessing: BlessingData = choices[i]
		var card := _create_card(blessing, i)
		container.add_child(card)


func _create_card(blessing: BlessingData, index: int) -> PanelContainer:
	# Outer card container
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 180)

	# Card background style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	card_style.border_color = Color(0.6, 0.5, 0.2, 1.0)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)

	# Inner layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Determine current level from BlessingManager
	var current_level: int = 0
	if _blessing_manager:
		current_level = _blessing_manager.get_blessing_level(blessing.blessing_id)

	# Build display name and description based on level
	var name_text: String = blessing.name
	var desc_text: String = blessing.description
	var display_level: int = current_level + 1 if current_level > 0 else 1

	if current_level > 0:
		var next_level: int = mini(current_level + 1, blessing.max_level)
		name_text = "%s  Lv.%d -> Lv.%d" % [blessing.name, current_level, next_level]
		var desc_idx: int = next_level - 1
		if desc_idx < blessing.level_descriptions.size():
			desc_text = blessing.level_descriptions[desc_idx]
	else:
		name_text = "%s  NEW" % blessing.name
		if blessing.level_descriptions.size() > 0:
			desc_text = blessing.level_descriptions[0]

	# Blessing name (bold, larger)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# Separator line
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(sep)

	# Description
	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1.0))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	# Effect type tag
	var type_names := ["Projectile", "Aura", "Orbital", "Passive"]
	var type_label := Label.new()
	type_label.text = type_names[blessing.effect_type]
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 1.0))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Stats line — show next level's stats
	var display_damage: int = blessing.get_stat(display_level, "damage", blessing.damage) as int
	var display_cooldown: float = blessing.get_stat(display_level, "cooldown", blessing.cooldown) as float
	var stats_label := Label.new()
	stats_label.text = "DMG: %d  |  CD: %.1fs" % [display_damage, display_cooldown]
	stats_label.add_theme_font_size_override("font_size", 9)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9, 1.0))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	# Invisible button overlay for click handling
	var button := Button.new()
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.pressed.connect(_on_card_pressed.bind(index))

	# Hover style
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(1, 1, 1, 0.08)
	hover_style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", hover_style)

	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)

	card.add_child(button)

	return card


func _on_card_pressed(index: int) -> void:
	if index < _current_choices.size():
		_flash_gold()
		GameEvents.blessing_chosen.emit(_current_choices[index])


func _flash_gold() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.85, 0.2, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)


func _clear_cards() -> void:
	for child in container.get_children():
		child.queue_free()
