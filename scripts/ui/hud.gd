extends CanvasLayer

signal ability_button_pressed

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var xp_bar: ProgressBar = $TopLeft/XPBar
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var timer_label: Label = $TopLeft/TimerLabel
@onready var kill_label: Label = $TopRight/KillLabel
@onready var wave_label: Label = $TopRight/WaveLabel
@onready var blessing_bar: HBoxContainer = $BlessingBar
@onready var boss_bar_container: VBoxContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $BossBarContainer/BossHPBar

var _boss_health_component: HealthComponent = null

# --- Ability button UI ---
var _ability_container: PanelContainer
var _ability_fill: ColorRect
var _ability_label: Label
var _ability_pulse_tween: Tween = null
var _ability_was_full: bool = false


func _ready() -> void:
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.level_up.connect(_on_level_up)
	GameEvents.xp_collected.connect(_on_xp_collected)
	GameEvents.blessing_chosen.connect(_on_blessing_chosen)
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_died.connect(_on_boss_died)
	GameEvents.wave_started.connect(_on_wave_started)
	_setup_ability_button()


func _process(_delta: float) -> void:
	if GameState.is_run_active:
		var mins := int(GameState.run_time) / 60
		var secs := int(GameState.run_time) % 60
		timer_label.text = "%d:%02d" % [mins, secs]
		kill_label.text = "Kills: %d" % GameState.kills
		xp_bar.max_value = GameState.xp_to_next_level
		xp_bar.value = GameState.player_xp
		_update_ability_button()


func set_player_health(health_component: HealthComponent) -> void:
	hp_bar.max_value = health_component.max_health
	hp_bar.value = health_component.current_health
	health_component.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: int, max_health: int) -> void:
	hp_bar.max_value = max_health
	hp_bar.value = new_health


func _on_player_damaged(_amount: int) -> void:
	pass


func _on_xp_collected(_amount: int) -> void:
	xp_bar.max_value = GameState.xp_to_next_level
	xp_bar.value = GameState.player_xp


func _on_level_up(new_level: int) -> void:
	level_label.text = "Lv. %d" % new_level
	xp_bar.value = 0
	xp_bar.max_value = GameState.xp_to_next_level


func _on_blessing_chosen(blessing: BlessingData) -> void:
	var tag := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	style.border_color = Color(0.6, 0.5, 0.2, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	tag.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = blessing.name
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	tag.add_child(label)

	blessing_bar.add_child(tag)


func _on_boss_spawned(enemy: Node2D) -> void:
	if enemy is EnemyBase:
		var boss: EnemyBase = enemy as EnemyBase
		_boss_health_component = boss.health_component
		boss_name_label.text = boss.data.name
		boss_hp_bar.max_value = _boss_health_component.max_health
		boss_hp_bar.value = _boss_health_component.current_health
		_boss_health_component.health_changed.connect(_on_boss_health_changed)
		boss_bar_container.visible = true


func _on_boss_died(_pos: Vector2) -> void:
	if _boss_health_component and _boss_health_component.health_changed.is_connected(_on_boss_health_changed):
		_boss_health_component.health_changed.disconnect(_on_boss_health_changed)
	_boss_health_component = null
	boss_bar_container.visible = false


func _on_boss_health_changed(new_health: int, max_health: int) -> void:
	boss_hp_bar.max_value = max_health
	boss_hp_bar.value = new_health


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave %d" % wave_number


# --- Ability Button ---

func _setup_ability_button() -> void:
	# Container panel styled as circular-ish button in bottom-right
	_ability_container = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(0.4, 0.35, 0.15, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)
	_ability_container.add_theme_stylebox_override("panel", style)
	_ability_container.custom_minimum_size = Vector2(56.0, 56.0)

	# Anchor bottom-right
	_ability_container.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_ability_container.anchor_left = 1.0
	_ability_container.anchor_top = 1.0
	_ability_container.anchor_right = 1.0
	_ability_container.anchor_bottom = 1.0
	_ability_container.offset_left = -72.0
	_ability_container.offset_top = -72.0
	_ability_container.offset_right = -8.0
	_ability_container.offset_bottom = -8.0

	# Fill bar (shows charge progress)
	_ability_fill = ColorRect.new()
	_ability_fill.color = Color(0.9, 0.8, 0.2, 0.3)
	_ability_fill.anchor_left = 0.0
	_ability_fill.anchor_top = 1.0  # Grows upward
	_ability_fill.anchor_right = 1.0
	_ability_fill.anchor_bottom = 1.0
	_ability_fill.offset_left = 2.0
	_ability_fill.offset_right = -2.0
	_ability_fill.offset_top = 0.0  # Will be set dynamically
	_ability_fill.offset_bottom = -2.0
	_ability_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_container.add_child(_ability_fill)

	# Label
	_ability_label = Label.new()
	_ability_label.text = "WRATH"
	_ability_label.add_theme_font_size_override("font_size", 9)
	_ability_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.35, 1.0))
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ability_label.anchor_left = 0.0
	_ability_label.anchor_top = 0.0
	_ability_label.anchor_right = 1.0
	_ability_label.anchor_bottom = 1.0
	_ability_label.offset_left = 0.0
	_ability_label.offset_top = 0.0
	_ability_label.offset_right = 0.0
	_ability_label.offset_bottom = 0.0
	_ability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_container.add_child(_ability_label)

	# Make the container act as a button via gui_input
	_ability_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_ability_container.gui_input.connect(_on_ability_gui_input)

	add_child(_ability_container)


func _on_ability_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ability_button_pressed.emit()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			ability_button_pressed.emit()


func _update_ability_button() -> void:
	if not _ability_container:
		return

	var charge: float = GameState.ability_charge
	var max_charge: float = GameState.ability_charge_max
	var ratio: float = charge / maxf(max_charge, 1.0)
	var is_full: bool = charge >= max_charge

	# Update fill height (grows from bottom)
	var container_height: float = 52.0  # Approximate inner height
	_ability_fill.offset_top = -2.0 - (container_height * ratio)

	if is_full:
		# Bright gold when ready
		_ability_fill.color = Color(1.0, 0.9, 0.3, 0.5)
		_ability_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))

		# Start pulse if just became full
		if not _ability_was_full:
			_ability_was_full = true
			_start_pulse()
	else:
		# Dim while charging
		_ability_fill.color = Color(0.9, 0.8, 0.2, 0.3)
		_ability_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.35, 1.0))

		# Stop pulse
		if _ability_was_full:
			_ability_was_full = false
			_stop_pulse()

	# Show percentage text while charging, "WRATH" when full
	if is_full:
		_ability_label.text = "WRATH"
	else:
		_ability_label.text = "%d%%" % int(ratio * 100.0)


func _start_pulse() -> void:
	_stop_pulse()
	_ability_pulse_tween = _ability_container.create_tween()
	_ability_pulse_tween.set_loops()
	var style: StyleBoxFlat = _ability_container.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		_ability_pulse_tween.tween_property(style, "border_color", Color(1.0, 0.9, 0.4, 1.0), 0.5)
		_ability_pulse_tween.tween_property(style, "border_color", Color(0.4, 0.35, 0.15, 0.8), 0.5)


func _stop_pulse() -> void:
	if _ability_pulse_tween and _ability_pulse_tween.is_running():
		_ability_pulse_tween.kill()
		_ability_pulse_tween = null
	# Reset border color
	var style: StyleBoxFlat = _ability_container.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(0.4, 0.35, 0.15, 0.8)
