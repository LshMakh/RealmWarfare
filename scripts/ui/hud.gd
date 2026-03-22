extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var timer_label: Label = $TopLeft/TimerLabel
@onready var kill_label: Label = $TopRight/KillLabel


func _ready() -> void:
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.level_up.connect(_on_level_up)


func _process(_delta: float) -> void:
	if GameState.is_run_active:
		var mins := int(GameState.run_time) / 60
		var secs := int(GameState.run_time) % 60
		timer_label.text = "%d:%02d" % [mins, secs]
		kill_label.text = "Kills: %d" % GameState.kills


func set_player_health(health_component: HealthComponent) -> void:
	hp_bar.max_value = health_component.max_health
	hp_bar.value = health_component.current_health
	health_component.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: int, max_health: int) -> void:
	hp_bar.max_value = max_health
	hp_bar.value = new_health


func _on_player_damaged(_amount: int) -> void:
	pass


func _on_level_up(new_level: int) -> void:
	level_label.text = "Lv. %d" % new_level
