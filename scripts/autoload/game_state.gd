extends Node

# Current run state
var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = 10
var kills: int = 0
var run_time: float = 0.0
var active_blessings: Array[Resource] = []
var is_run_active: bool = false


func start_new_run() -> void:
	player_level = 1
	player_xp = 0
	xp_to_next_level = 10
	kills = 0
	run_time = 0.0
	active_blessings.clear()
	is_run_active = true
	GameEvents.run_started.emit()


func end_run() -> void:
	is_run_active = false
	var result := {
		"kills": kills,
		"time": run_time,
		"level": player_level,
	}
	GameEvents.run_ended.emit(result)


func add_xp(amount: int) -> void:
	player_xp += amount
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = _calculate_xp_threshold(player_level)
		GameEvents.level_up.emit(player_level)


func _calculate_xp_threshold(level: int) -> int:
	# XP curve: 10, 15, 22, 33, 50, ...
	return int(10 * pow(1.5, level - 1))
