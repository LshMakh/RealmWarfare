class_name HazardManager
extends Node

@export var player: CharacterBody2D

var _lightning_pool: ObjectPool = null
var _crack_pool: ObjectPool = null
var _current_wave: int = 0
var _lightning_timer: float = 0.0
var _crack_timer: float = 0.0
var _active_cracks: Array[Node] = []

const MAX_ACTIVE_CRACKS: int = 6


func set_pools(lightning_pool: ObjectPool, crack_pool: ObjectPool) -> void:
	_lightning_pool = lightning_pool
	_crack_pool = crack_pool


func _ready() -> void:
	GameEvents.wave_started.connect(_on_wave_started)


func _on_wave_started(wave_number: int) -> void:
	_current_wave = wave_number
	# Reset timers on new wave so hazards don't fire immediately
	_lightning_timer = _get_lightning_interval()
	_crack_timer = _get_crack_interval()


func _process(delta: float) -> void:
	if not player or _current_wave == 0:
		return
	if not GameState.is_run_active:
		return
	_process_lightning(delta)
	_process_cracks(delta)


func _process_lightning(delta: float) -> void:
	if not _lightning_pool:
		return

	var interval: float = _get_lightning_interval()
	if interval <= 0.0:
		return

	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = interval
		_spawn_lightning()


func _process_cracks(delta: float) -> void:
	if not _crack_pool:
		return

	var interval: float = _get_crack_interval()
	if interval <= 0.0:
		return

	# Clean up finished cracks from tracking array
	_active_cracks = _active_cracks.filter(func(c: Node) -> bool: return c.visible)

	_crack_timer -= delta
	if _crack_timer <= 0.0:
		_crack_timer = interval
		_spawn_crack()


func _get_lightning_interval() -> float:
	# Lightning spawns from wave 1 onward
	if _current_wave <= 5:
		return 9.0
	elif _current_wave <= 10:
		return 6.0
	elif _current_wave <= 15:
		return 4.0
	elif _current_wave <= 20:
		return 2.5
	return 2.5


func _get_crack_interval() -> float:
	# Cracks only start at wave 12
	if _current_wave < 12:
		return 0.0
	elif _current_wave <= 15:
		return 12.0
	elif _current_wave <= 20:
		return 8.0
	return 8.0


func _spawn_lightning() -> void:
	var strike: Node = _lightning_pool.get_instance()
	if not strike or not strike.has_method("initialize"):
		return

	# Random offset 200-400px from player
	var angle: float = randf() * TAU
	var dist: float = randf_range(200.0, 400.0)
	var offset := Vector2(cos(angle), sin(angle)) * dist
	var spawn_pos: Vector2 = player.global_position + offset

	# Scale damage slightly with wave
	var damage: int = 15 + _current_wave
	strike.initialize(spawn_pos, damage)
	GameEvents.hazard_spawned.emit("lightning", spawn_pos)


func _spawn_crack() -> void:
	# Enforce max active cracks — release oldest if at limit
	if _active_cracks.size() >= MAX_ACTIVE_CRACKS:
		var oldest: Node = _active_cracks.pop_front()
		if oldest and oldest.visible and oldest.has_method("force_finish"):
			oldest.force_finish()

	var crack: Node = _crack_pool.get_instance()
	if not crack or not crack.has_method("initialize"):
		return

	# Spawn within 200px of player
	var angle: float = randf() * TAU
	var dist: float = randf_range(50.0, 200.0)
	var offset := Vector2(cos(angle), sin(angle)) * dist
	var spawn_pos: Vector2 = player.global_position + offset

	crack.initialize(spawn_pos)
	_active_cracks.append(crack)
	GameEvents.hazard_spawned.emit("crack", spawn_pos)
