extends Control

@onready var stats_container: VBoxContainer = $Panel/VBox/StatsContainer
@onready var panel: PanelContainer = $Panel
@onready var overlay: ColorRect = $Overlay


func _ready() -> void:
	modulate.a = 0.0
	_populate_stats()
	_style_ui()

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


func _populate_stats() -> void:
	var time_min: int = int(GameState.run_time) / 60
	var time_sec: int = int(GameState.run_time) % 60
	var time_str: String = "%d:%02d" % [time_min, time_sec]

	_set_stat("TimeValue", time_str)
	_set_stat("KillsValue", str(GameState.kills))
	_set_stat("LevelValue", str(GameState.player_level))
	_set_stat("BlessingsValue", str(GameState.active_blessings.size()))


func _set_stat(node_name: String, value: String) -> void:
	var label: Label = stats_container.find_child(node_name, true, false)
	if label:
		label.text = value


func _style_ui() -> void:
	# Panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	panel_style.border_color = Color(0.6, 0.5, 0.2, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Style buttons
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

	for button: Button in [%RunAgainButton, %MainMenuButton]:
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("hover", button_hover)
		button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6, 1.0))
		button.add_theme_font_size_override("font_size", 14)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_run_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
