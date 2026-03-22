class_name WaveManager
extends Node

@export var enemy_pool: ObjectPool
@export var xp_pool: ObjectPool
@export var player: CharacterBody2D

@export var enemy_types: Array[EnemyData] = []
@export var boss_data: EnemyData

@export var initial_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.4
@export var spawn_ramp_rate: float = 0.02
@export var initial_enemies_per_spawn: int = 2
@export var max_enemies_per_spawn: int = 8
@export var spawn_radius: float = 300.0
@export var max_active_enemies: int = 100
@export var boss_spawn_time: float = 180.0

var _spawn_timer: float = 0.0
var _run_time: float = 0.0
var _current_interval: float = 0.0
var _boss_spawned: bool = false


func _ready() -> void:
	_current_interval = initial_spawn_interval
	GameEvents.enemy_killed.connect(_on_enemy_killed)


func _process(delta: float) -> void:
	if not GameState.is_run_active:
		return

	_run_time += delta
	GameState.run_time = _run_time

	_current_interval = max(
		initial_spawn_interval - (_run_time * spawn_ramp_rate),
		min_spawn_interval
	)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_wave()
		_spawn_timer = _current_interval

	if not _boss_spawned and _run_time >= boss_spawn_time:
		_spawn_boss()


func _spawn_wave() -> void:
	if not enemy_pool or not player:
		return

	var count := min(
		_enemies_for_current_time(),
		max_active_enemies - enemy_pool.active_count()
	)

	for i in range(count):
		var enemy_instance := enemy_pool.get_instance()
		if enemy_instance is EnemyBase:
			var data: EnemyData = enemy_types[randi() % enemy_types.size()]
			var spawn_pos := _random_spawn_position()
			enemy_instance.global_position = spawn_pos
			enemy_instance.initialize(data, player)


func _spawn_boss() -> void:
	if not boss_data or not enemy_pool:
		return
	_boss_spawned = true
	var boss := enemy_pool.get_instance()
	if boss is EnemyBase:
		var spawn_pos := _random_spawn_position()
		boss.global_position = spawn_pos
		boss.initialize(boss_data, player)


func _enemies_for_current_time() -> int:
	var progress := _run_time / boss_spawn_time
	return int(lerp(float(initial_enemies_per_spawn), float(max_enemies_per_spawn), clamp(progress, 0.0, 1.0)))


func _random_spawn_position() -> Vector2:
	if not player:
		return Vector2.ZERO
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset


func _on_enemy_killed(pos: Vector2) -> void:
	GameState.kills += 1
	if xp_pool:
		var gem := xp_pool.get_instance()
		if gem and gem.has_method("activate"):
			gem.activate(pos, 1, player)
