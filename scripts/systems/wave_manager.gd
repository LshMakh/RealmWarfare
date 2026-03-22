class_name WaveManager
extends Node

enum WaveState { IDLE, SPAWNING, ACTIVE, BREATHER, BOSS, DONE }

@export var enemy_pool: ObjectPool
@export var xp_pool: ObjectPool
@export var player: CharacterBody2D
@export var boss_data: EnemyData
@export var spawn_radius: float = 300.0
@export var max_active_enemies: int = 100
@export var boss_trickle_interval: float = 4.0
@export var boss_trickle_count: int = 2

@export var powerup_scene: PackedScene
@export var powerup_drop_chance: float = 0.015
var powerup_data_list: Array = []
var _entity_layer: Node

# Wave table and enemy lookup — set from run.gd
var wave_table: Array = []  # Array of WaveData
var enemy_lookup: Dictionary = {}  # {"skeleton": EnemyData, ...}

# State machine
var _state: WaveState = WaveState.IDLE
var _current_wave_index: int = -1
var _current_wave_data: WaveData = null
var _run_time: float = 0.0

# Sub-wave spawning
var _sub_waves_remaining: int = 0
var _sub_wave_timer: float = 0.0
var _enemies_per_sub_wave: int = 0
var _sub_wave_remainder: int = 0  # extra enemies for final sub-wave
var _total_spawn_count: int = 0

# Wave tracking
var _wave_enemies_remaining: int = 0
var _wave_timer: float = 0.0  # time since wave started (for timeout)
var _breather_timer: float = 0.0

# Boss trickle
var _boss_spawned: bool = false
var _boss_trickle_timer: float = 0.0


func _ready() -> void:
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.boss_died.connect(_on_boss_died)


func _process(delta: float) -> void:
	if not GameState.is_run_active:
		return

	_run_time += delta

	match _state:
		WaveState.IDLE:
			_start_next_wave()
		WaveState.SPAWNING:
			_process_spawning(delta)
		WaveState.ACTIVE:
			_process_active(delta)
		WaveState.BREATHER:
			_process_breather(delta)
		WaveState.BOSS:
			_process_boss(delta)
		WaveState.DONE:
			pass


# --- State transitions ---

func _start_next_wave() -> void:
	_current_wave_index += 1
	if _current_wave_index >= wave_table.size():
		_spawn_boss()
		return

	_current_wave_data = wave_table[_current_wave_index] as WaveData
	GameState.current_wave = _current_wave_data.wave_number
	GameEvents.wave_started.emit(_current_wave_data.wave_number)

	# Calculate spawn count and sub-wave batching
	_total_spawn_count = randi_range(_current_wave_data.spawn_count_min, _current_wave_data.spawn_count_max)
	_total_spawn_count = maxi(mini(_total_spawn_count, max_active_enemies - enemy_pool.active_count()), 1)
	_sub_waves_remaining = maxi(_current_wave_data.sub_wave_count, 1)
	_enemies_per_sub_wave = _total_spawn_count / _sub_waves_remaining
	_sub_wave_remainder = _total_spawn_count % _sub_waves_remaining
	_sub_wave_timer = 0.0  # spawn first batch immediately
	_wave_enemies_remaining = 0
	_wave_timer = 0.0
	_state = WaveState.SPAWNING


func _process_spawning(delta: float) -> void:
	_wave_timer += delta
	_sub_wave_timer -= delta

	if _sub_wave_timer <= 0.0 and _sub_waves_remaining > 0:
		var batch_size: int = _enemies_per_sub_wave
		# Add remainder to final sub-wave
		if _sub_waves_remaining == 1:
			batch_size += _sub_wave_remainder
		_spawn_batch(batch_size)
		_sub_waves_remaining -= 1
		_sub_wave_timer = _current_wave_data.sub_wave_interval

	# All sub-waves dispatched — transition to ACTIVE
	if _sub_waves_remaining <= 0:
		_state = WaveState.ACTIVE


func _process_active(delta: float) -> void:
	_wave_timer += delta

	# Wave cleared: all enemies dead
	if _wave_enemies_remaining <= 0:
		_end_wave()
		return

	# Wave timeout: auto-advance, stragglers ignored
	if _wave_timer >= _current_wave_data.wave_timeout:
		_wave_enemies_remaining = 0
		_end_wave()


func _end_wave() -> void:
	GameEvents.wave_cleared.emit(_current_wave_data.wave_number)
	_breather_timer = _current_wave_data.breather_duration
	_state = WaveState.BREATHER


func _process_breather(delta: float) -> void:
	_breather_timer -= delta
	if _breather_timer <= 0.0:
		_state = WaveState.IDLE  # IDLE triggers _start_next_wave on next frame


func _spawn_boss() -> void:
	if not boss_data or not enemy_pool:
		return
	_boss_spawned = true
	_boss_trickle_timer = boss_trickle_interval
	var boss: Node = enemy_pool.get_instance()
	if boss is EnemyBase:
		var spawn_pos := _get_spawn_position(WaveData.SpawnPattern.RING, 0, 1)
		boss.global_position = spawn_pos
		boss.initialize(boss_data, player)
		GameEvents.boss_spawned.emit(boss)
	_state = WaveState.BOSS


func _process_boss(delta: float) -> void:
	if not _boss_spawned:
		return

	# Trickle skeletons during boss fight
	_boss_trickle_timer -= delta
	if _boss_trickle_timer <= 0.0:
		_boss_trickle_timer = boss_trickle_interval
		var skeleton_data: EnemyData = enemy_lookup.get("skeleton") as EnemyData
		if skeleton_data and enemy_pool:
			for i in range(boss_trickle_count):
				if enemy_pool.active_count() >= max_active_enemies:
					break
				var enemy: Node = enemy_pool.get_instance()
				if enemy is EnemyBase:
					var spawn_pos := _get_spawn_position(WaveData.SpawnPattern.RING, i, boss_trickle_count)
					enemy.global_position = spawn_pos
					enemy.initialize(skeleton_data, player)


# --- Spawning ---

func _spawn_batch(count: int) -> void:
	if not enemy_pool or not player or not _current_wave_data:
		return

	# Build weighted enemy list from composition
	var enemy_list: Array[EnemyData] = _build_enemy_list()
	if enemy_list.is_empty():
		return

	var capped_count: int = mini(count, max_active_enemies - enemy_pool.active_count())

	for i in range(capped_count):
		var enemy_instance: Node = enemy_pool.get_instance()
		if enemy_instance is EnemyBase:
			var data: EnemyData = enemy_list[randi() % enemy_list.size()]
			var spawn_pos := _get_spawn_position(_current_wave_data.spawn_pattern, i, capped_count)
			enemy_instance.global_position = spawn_pos
			enemy_instance.initialize(data, player)
			_wave_enemies_remaining += 1


func _build_enemy_list() -> Array[EnemyData]:
	# Convert composition dictionary {"skeleton": 4, "harpy": 2} into a weighted
	# flat list [skeleton, skeleton, skeleton, skeleton, harpy, harpy]
	var list: Array[EnemyData] = []
	for key: String in _current_wave_data.enemy_composition:
		var data: EnemyData = enemy_lookup.get(key) as EnemyData
		if not data:
			push_error("WaveManager: unknown enemy key '%s' in wave %d" % [key, _current_wave_data.wave_number])
			continue
		var weight: int = int(_current_wave_data.enemy_composition[key])
		for _w in range(weight):
			list.append(data)
	return list


# --- Spawn patterns ---

func _get_spawn_position(pattern: WaveData.SpawnPattern, index: int, total: int) -> Vector2:
	if not player:
		return Vector2.ZERO

	match pattern:
		WaveData.SpawnPattern.RING:
			return _spawn_ring(index, total)
		WaveData.SpawnPattern.DIRECTIONAL:
			return _spawn_directional(index, total)
		WaveData.SpawnPattern.PINCER:
			return _spawn_pincer(index, total)
		WaveData.SpawnPattern.AMBUSH:
			return _spawn_ambush(index, total)
	return _spawn_ring(index, total)


func _spawn_ring(index: int, total: int) -> Vector2:
	var angle: float
	if total > 1:
		angle = (float(index) / float(total)) * TAU + randf_range(-0.2, 0.2)
	else:
		angle = randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset


func _spawn_directional(_index: int, _total: int) -> Vector2:
	# All enemies from one direction, within a ~60° arc
	# Use a persistent angle per wave so all sub-waves come from the same side
	var base_angle: float = fmod(float(_current_wave_index) * 2.3, TAU)  # deterministic but varied per wave
	var spread: float = PI / 3.0  # 60° arc
	var angle: float = base_angle + randf_range(-spread * 0.5, spread * 0.5)
	var dist: float = spawn_radius + randf_range(-20.0, 20.0)
	var offset := Vector2(cos(angle), sin(angle)) * dist
	return player.global_position + offset


func _spawn_pincer(index: int, total: int) -> Vector2:
	# Two clusters from opposite sides
	var base_angle: float = fmod(float(_current_wave_index) * 1.7, TAU)
	var side: float = base_angle if index % 2 == 0 else base_angle + PI
	var spread: float = PI / 6.0  # 30° spread per side
	var angle: float = side + randf_range(-spread, spread)
	var dist: float = spawn_radius + randf_range(-15.0, 15.0)
	var offset := Vector2(cos(angle), sin(angle)) * dist
	return player.global_position + offset


func _spawn_ambush(_index: int, _total: int) -> Vector2:
	# Ring but at 60% radius — enemies appear closer
	var angle := randf() * TAU
	var dist: float = spawn_radius * 0.6
	var offset := Vector2(cos(angle), sin(angle)) * dist
	return player.global_position + offset


# --- Kill tracking & drops ---

func _on_enemy_killed(pos: Vector2, xp_value: int) -> void:
	GameState.kills += 1
	_wave_enemies_remaining = maxi(_wave_enemies_remaining - 1, 0)

	# Chance to spawn a powerup
	if powerup_scene and powerup_data_list.size() > 0 and randf() < powerup_drop_chance:
		_spawn_powerup(pos)

	if xp_pool:
		var gem: Node = xp_pool.get_instance()
		if gem and gem.has_method("activate"):
			gem.activate(pos, xp_value, player)


func _spawn_powerup(pos: Vector2) -> void:
	var pickup: Node = powerup_scene.instantiate()
	var data: Resource = powerup_data_list[randi() % powerup_data_list.size()]
	if _entity_layer:
		_entity_layer.add_child(pickup)
	else:
		add_child(pickup)
	if pickup.has_method("initialize"):
		pickup.initialize(data, pos)


func _on_boss_died(pos: Vector2) -> void:
	_state = WaveState.DONE
	# Drop 10x XP gems in a burst pattern around the boss death position
	if not xp_pool or not player:
		return
	var boss_xp: int = boss_data.xp_reward if boss_data else 20
	for i in range(10):
		var gem: Node = xp_pool.get_instance()
		if gem and gem.has_method("activate"):
			var offset := Vector2(cos(i * TAU / 10.0), sin(i * TAU / 10.0)) * 20.0
			gem.activate(pos + offset, boss_xp, player)
