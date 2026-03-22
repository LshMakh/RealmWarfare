class_name DiscoveryTracker
extends Node

var _favor_manager: FavorManager = null
var _run_discoveries: Array[String] = []
var _run_personal_bests: Array[String] = []


func set_favor_manager(fm: FavorManager) -> void:
	_favor_manager = fm


func _ready() -> void:
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.active_ability_used.connect(_on_ability_used)
	GameEvents.wave_started.connect(_on_wave_started)


func reset_for_run() -> void:
	_run_discoveries.clear()
	_run_personal_bests.clear()


func _check_discovery(id: String, display_name: String) -> void:
	if not _favor_manager:
		return
	if _favor_manager._discoveries.has(id):
		return
	_favor_manager._discoveries[id] = true
	_run_discoveries.append(display_name)
	GameEvents.discovery_made.emit(id, display_name)


func _on_enemy_killed(_pos: Vector2, _xp_value: int) -> void:
	# Track milestone kills
	if GameState.kills == 100:
		_check_discovery("kills_100", "100 Kills")
	elif GameState.kills == 500:
		_check_discovery("kills_500", "500 Kills")


func _on_ability_used() -> void:
	_check_discovery("first_wrath", "First Wrath of Olympus")


func _on_wave_started(wave: int) -> void:
	if wave == 10:
		_check_discovery("wave_10", "Reached Wave 10")
	elif wave == 15:
		_check_discovery("wave_15", "Reached Wave 15")
	elif wave == 20:
		_check_discovery("wave_20", "Reached Wave 20")


func check_personal_bests() -> void:
	if not _favor_manager:
		return
	var bests: Dictionary = _favor_manager._personal_bests

	if GameState.kills > (bests.get("kills", 0) as int):
		bests["kills"] = GameState.kills
		_run_personal_bests.append("New kill record: %d" % GameState.kills)

	if GameState.current_wave > (bests.get("wave", 0) as int):
		bests["wave"] = GameState.current_wave
		_run_personal_bests.append("New wave record: %d" % GameState.current_wave)

	if GameState.player_level > (bests.get("level", 0) as int):
		bests["level"] = GameState.player_level
		_run_personal_bests.append("New level record: %d" % GameState.player_level)


func get_run_discoveries() -> Array[String]:
	return _run_discoveries


func get_run_personal_bests() -> Array[String]:
	return _run_personal_bests
