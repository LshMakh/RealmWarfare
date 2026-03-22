extends Node

# Current run state
var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = 8
var kills: int = 0
var run_time: float = 0.0
var current_wave: int = 0
var active_blessings: Array[BlessingData] = []
var is_run_active: bool = false
var magnet_active: bool = false
var boss_killed: bool = false
var mini_boss_kills: int = 0

# Ability charge
var ability_charge: float = 0.0
var ability_charge_max: float = 100.0

# Meta-currency
var favor: int = 0

# Unscaled time tracking (immune to hitstop / Engine.time_scale)
var _run_start_ticks: int = 0

# XP curve thresholds (level 1 -> 2 uses index 0, etc.)
const XP_THRESHOLDS: Array[int] = [8, 12, 16, 22, 30, 40, 52, 66, 82, 100, 120, 142, 166, 192]


func _ready() -> void:
	GameEvents.boss_died.connect(_on_boss_died)


func _process(_delta: float) -> void:
	if is_run_active:
		run_time = float(Time.get_ticks_msec() - _run_start_ticks) / 1000.0


func start_new_run() -> void:
	player_level = 1
	player_xp = 0
	xp_to_next_level = XP_THRESHOLDS[0]
	kills = 0
	run_time = 0.0
	current_wave = 0
	active_blessings.clear()
	magnet_active = false
	boss_killed = false
	mini_boss_kills = 0
	ability_charge = 0.0
	is_run_active = true
	_run_start_ticks = Time.get_ticks_msec()
	GameEvents.run_started.emit()


func end_run() -> void:
	is_run_active = false
	var result: Dictionary = {
		"kills": kills,
		"time": run_time,
		"level": player_level,
		"wave": current_wave,
		"boss_killed": boss_killed,
		"mini_boss_kills": mini_boss_kills,
	}
	GameEvents.run_ended.emit(result)


func add_xp(amount: int) -> void:
	player_xp += amount
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = _calculate_xp_threshold(player_level)
		GameEvents.level_up.emit(player_level)


func add_ability_charge(amount: float) -> void:
	ability_charge = minf(ability_charge + amount, ability_charge_max)


func use_ability() -> bool:
	if ability_charge < ability_charge_max:
		return false
	ability_charge = 0.0
	GameEvents.active_ability_used.emit()
	return true


func _on_boss_died(_pos: Vector2) -> void:
	boss_killed = true


func _calculate_xp_threshold(level: int) -> int:
	var idx: int = level - 1  # level 1 -> index 0
	if idx < XP_THRESHOLDS.size():
		return XP_THRESHOLDS[idx]
	# Beyond the table: last threshold + 30 per extra level
	var extra_levels: int = idx - XP_THRESHOLDS.size() + 1
	return XP_THRESHOLDS[XP_THRESHOLDS.size() - 1] + 30 * extra_levels
