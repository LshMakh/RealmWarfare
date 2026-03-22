extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var xp_bar: ProgressBar = $TopLeft/XPBar
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var timer_label: Label = $TopLeft/TimerLabel
@onready var kill_label: Label = $TopRight/KillLabel
@onready var blessing_bar: HBoxContainer = $BlessingBar
@onready var boss_bar_container: VBoxContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $BossBarContainer/BossHPBar

var _boss_health_component: HealthComponent = null


func _ready() -> void:
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.level_up.connect(_on_level_up)
	GameEvents.xp_collected.connect(_on_xp_collected)
	GameEvents.blessing_chosen.connect(_on_blessing_chosen)
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_died.connect(_on_boss_died)


func _process(_delta: float) -> void:
	if GameState.is_run_active:
		var mins := int(GameState.run_time) / 60
		var secs := int(GameState.run_time) % 60
		timer_label.text = "%d:%02d" % [mins, secs]
		kill_label.text = "Kills: %d" % GameState.kills
		xp_bar.max_value = GameState.xp_to_next_level
		xp_bar.value = GameState.player_xp


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
