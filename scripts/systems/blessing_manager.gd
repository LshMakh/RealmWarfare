class_name BlessingManager
extends Node

@export var available_blessings: Array[BlessingData] = []
@export var choices_per_level: int = 3

var _active_blessings: Array[BlessingData] = []


func _ready() -> void:
	GameEvents.level_up.connect(_on_level_up)
	GameEvents.blessing_chosen.connect(_on_blessing_chosen)


func _on_level_up(_new_level: int) -> void:
	var choices: Array = _pick_random_choices()
	GameEvents.show_level_up_ui.emit(choices)


func _on_blessing_chosen(blessing: BlessingData) -> void:
	_active_blessings.append(blessing)
	GameState.active_blessings = _active_blessings
	GameEvents.hide_level_up_ui.emit()


func _pick_random_choices() -> Array:
	var pool: Array = available_blessings.duplicate()
	var choices: Array = []
	for i in range(mini(choices_per_level, pool.size())):
		var idx: int = randi() % pool.size()
		choices.append(pool[idx])
		pool.remove_at(idx)
	return choices


func get_active_blessings() -> Array[BlessingData]:
	return _active_blessings
