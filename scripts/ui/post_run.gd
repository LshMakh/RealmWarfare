extends Control

# References — FavorManager is an autoload, DiscoveryTracker data is stashed
# in GameState._last_run_discoveries / _last_run_personal_bests before scene change.

@onready var scroll_container: ScrollContainer = $Panel/ScrollContainer
@onready var content: VBoxContainer = $Panel/ScrollContainer/Content
@onready var panel: PanelContainer = $Panel
@onready var overlay: ColorRect = $Overlay

const GOLD: Color = Color(1.0, 0.85, 0.3, 1.0)
const BRIGHT_GOLD: Color = Color(1.0, 0.95, 0.6, 1.0)
const DIM_TEXT: Color = Color(0.7, 0.7, 0.75, 1.0)
const VALUE_TEXT: Color = Color(1.0, 0.95, 0.8, 1.0)
const GREEN_TEXT: Color = Color(0.4, 1.0, 0.4, 1.0)
const DISCOVERY_TEXT: Color = Color(0.5, 0.8, 1.0, 1.0)
const PB_TEXT: Color = Color(1.0, 0.7, 0.3, 1.0)


func _ready() -> void:
	modulate.a = 0.0

	# Calculate favor and update profile
	var result: Dictionary = _build_run_result()
	var favor_breakdown: Dictionary = FavorManager.calculate_favor(result)
	GameState.favor += favor_breakdown.get("total", 0)

	# Check personal bests (using stashed data)
	var discoveries: Array = GameState.get_meta("last_run_discoveries", [])
	var personal_bests: Array = GameState.get_meta("last_run_personal_bests", [])

	# Update favor breakdown with discovery/PB info that was calculated during run
	if discoveries.size() > 0:
		favor_breakdown["discoveries"] = discoveries.size() * 10
		favor_breakdown["total"] = favor_breakdown.get("total", 0) + discoveries.size() * 10
		GameState.favor += discoveries.size() * 10
	if personal_bests.size() > 0:
		favor_breakdown["personal_bests"] = personal_bests.size() * 5
		favor_breakdown["total"] = favor_breakdown.get("total", 0) + personal_bests.size() * 5
		GameState.favor += personal_bests.size() * 5

	FavorManager.save_profile()

	_build_ui(favor_breakdown, discoveries, personal_bests)
	_style_panel()

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


func _build_run_result() -> Dictionary:
	return {
		"kills": GameState.kills,
		"time": GameState.run_time,
		"level": GameState.player_level,
		"wave": GameState.current_wave,
		"boss_killed": GameState.boss_killed,
		"mini_boss_kills": GameState.mini_boss_kills,
	}


func _build_ui(favor_breakdown: Dictionary, discoveries: Array, personal_bests: Array) -> void:
	# Title
	var title_text: String = "RUN COMPLETE" if GameState.current_wave >= 20 else "DEFEATED"
	_add_title(title_text)
	_add_separator()

	# Stats grid
	_add_stats_section()
	_add_separator()

	# Blessings
	if GameState.active_blessings.size() > 0:
		_add_blessings_section()
		_add_separator()

	# Favor breakdown
	_add_favor_section(favor_breakdown)

	# Almost there
	var closest: Dictionary = FavorManager.get_closest_upgrade()
	if not closest.is_empty():
		_add_separator()
		_add_almost_there_section(closest)

	# Discoveries
	if discoveries.size() > 0:
		_add_separator()
		_add_discoveries_section(discoveries)

	# Personal bests
	if personal_bests.size() > 0:
		_add_separator()
		_add_personal_bests_section(personal_bests)

	# Spacer + buttons
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)
	_add_buttons()


func _add_title(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", GOLD)
	content.add_child(label)


func _add_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	var line: StyleBoxLine = sep.get_theme_stylebox("separator") as StyleBoxLine
	if line:
		line.color = Color(0.6, 0.5, 0.2, 0.5)
		line.thickness = 1
	content.add_child(sep)


func _add_stats_section() -> void:
	var time_min: int = int(GameState.run_time) / 60
	var time_sec: int = int(GameState.run_time) % 60
	var time_str: String = "%d:%02d" % [time_min, time_sec]

	_add_stat_row("Time", time_str)
	_add_stat_row("Kills", str(GameState.kills))
	_add_stat_row("Level", str(GameState.player_level))
	_add_stat_row("Wave", str(GameState.current_wave))


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", DIM_TEXT)
	row.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", VALUE_TEXT)
	row.add_child(value)

	content.add_child(row)


func _add_blessings_section() -> void:
	var header: Label = Label.new()
	header.text = "Blessings"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", GOLD)
	content.add_child(header)

	for blessing: BlessingData in GameState.active_blessings:
		var row: Label = Label.new()
		row.text = "  %s" % blessing.name
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", VALUE_TEXT)
		content.add_child(row)


func _add_favor_section(breakdown: Dictionary) -> void:
	var total: int = breakdown.get("total", 0)

	var header: Label = Label.new()
	header.text = "Favor Earned: +%d" % total
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", GREEN_TEXT)
	content.add_child(header)

	# Build breakdown line
	var parts: Array[String] = []
	var base_val: int = breakdown.get("base", 0)
	if base_val > 0:
		parts.append("Base: %d" % base_val)
	var waves_val: int = breakdown.get("waves", 0)
	if waves_val > 0:
		parts.append("Waves: %d" % waves_val)
	var kills_val: int = breakdown.get("kills", 0)
	if kills_val > 0:
		parts.append("Kills: %d" % kills_val)
	var boss_val: int = breakdown.get("boss", 0)
	if boss_val > 0:
		parts.append("Boss: %d" % boss_val)
	var mini_val: int = breakdown.get("mini_boss", 0)
	if mini_val > 0:
		parts.append("Elites: %d" % mini_val)
	var level_val: int = breakdown.get("level", 0)
	if level_val > 0:
		parts.append("Level: %d" % level_val)
	var disc_val: int = breakdown.get("discoveries", 0)
	if disc_val > 0:
		parts.append("Discoveries: %d" % disc_val)
	var pb_val: int = breakdown.get("personal_bests", 0)
	if pb_val > 0:
		parts.append("PBs: %d" % pb_val)

	if parts.size() > 0:
		var detail: Label = Label.new()
		detail.text = " + ".join(parts)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_theme_font_size_override("font_size", 9)
		detail.add_theme_color_override("font_color", DIM_TEXT)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(detail)

	# Total favor display
	var total_label: Label = Label.new()
	total_label.text = "Total Favor: %d" % GameState.favor
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 10)
	total_label.add_theme_color_override("font_color", GOLD)
	content.add_child(total_label)


func _add_almost_there_section(closest: Dictionary) -> void:
	var header: Label = Label.new()
	header.text = "Almost There"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", GOLD)
	content.add_child(header)

	var uname: String = closest.get("name", "")
	var remaining: int = closest.get("remaining", 0) as int
	var level: int = FavorManager.get_upgrade_level(uname) + 1
	var display_name: String = uname.capitalize()

	var info: Label = Label.new()
	if remaining <= 0:
		info.text = "You can afford \"%s Lv.%d\"!" % [display_name, level]
		info.add_theme_color_override("font_color", GREEN_TEXT)
	else:
		info.text = "%d Favor until \"%s Lv.%d\"" % [remaining, display_name, level]
		info.add_theme_color_override("font_color", DIM_TEXT)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 10)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)


func _add_discoveries_section(discoveries: Array) -> void:
	var header: Label = Label.new()
	header.text = "New Discoveries"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", DISCOVERY_TEXT)
	content.add_child(header)

	for disc_name: Variant in discoveries:
		var row: Label = Label.new()
		row.text = "  NEW  %s" % str(disc_name)
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", DISCOVERY_TEXT)
		content.add_child(row)


func _add_personal_bests_section(personal_bests: Array) -> void:
	var header: Label = Label.new()
	header.text = "Personal Best!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", PB_TEXT)
	content.add_child(header)

	for pb: Variant in personal_bests:
		var row: Label = Label.new()
		row.text = "  %s" % str(pb)
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", PB_TEXT)
		content.add_child(row)


func _add_buttons() -> void:
	var container: HBoxContainer = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 16)

	var run_again: Button = Button.new()
	run_again.text = "RUN AGAIN"
	run_again.custom_minimum_size = Vector2(110, 0)
	run_again.pressed.connect(_on_run_again_pressed)
	_style_button(run_again)
	container.add_child(run_again)

	var main_menu: Button = Button.new()
	main_menu.text = "MAIN MENU"
	main_menu.custom_minimum_size = Vector2(110, 0)
	main_menu.pressed.connect(_on_main_menu_pressed)
	_style_button(main_menu)
	container.add_child(main_menu)

	content.add_child(container)


func _style_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	panel_style.border_color = Color(0.6, 0.5, 0.2, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)


func _style_button(button: Button) -> void:
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.18, 0.18, 0.25, 1.0)
	button_style.border_color = Color(0.6, 0.5, 0.2, 1.0)
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(4)
	button_style.set_content_margin_all(8)

	var button_hover := StyleBoxFlat.new()
	button_hover.bg_color = Color(0.25, 0.25, 0.35, 1.0)
	button_hover.border_color = Color(1.0, 0.85, 0.3, 1.0)
	button_hover.set_border_width_all(1)
	button_hover.set_corner_radius_all(4)
	button_hover.set_content_margin_all(8)

	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", BRIGHT_GOLD)
	button.add_theme_font_size_override("font_size", 14)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_run_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
