class_name WaveManager
extends Node

enum WaveState { IDLE, SPAWNING, ACTIVE, BREATHER, BOSS, DONE }

@export var xp_pool: ObjectPool
@export var player: CharacterBody2D
@export var boss_data: EnemyData
@export var spawn_radius: float = 300.0
@export var max_active_enemies: int = 120
@export var boss_trickle_interval: float = 4.0
@export var boss_trickle_count: int = 2
@export var crack_pool: ObjectPool

@export var powerup_scene: PackedScene
@export var powerup_drop_chance: float = 0.015
var powerup_data_list: Array = []
var _entity_layer: Node

# Multi-pool support — set from run.gd via set_enemy_pool()
var _enemy_pools: Dictionary = {}  # String -> ObjectPool

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


func set_enemy_pool(enemy_name: String, pool: ObjectPool) -> void:
	_enemy_pools[enemy_name] = pool


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

	# Check for mini-boss at this wave
	_check_mini_boss(_current_wave_data.wave_number)

	# Calculate spawn count and sub-wave batching
	_total_spawn_count = randi_range(_current_wave_data.spawn_count_min, _current_wave_data.spawn_count_max)
	var total_active: int = _get_total_active_enemies()
	_total_spawn_count = maxi(mini(_total_spawn_count, max_active_enemies - total_active), 1)
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

	# Wave timeout: auto-advance, stragglers marked
	if _wave_timer >= _current_wave_data.wave_timeout:
		_wave_enemies_remaining = 0
		_end_wave()


func _end_wave() -> void:
	_mark_current_enemies_as_stragglers()
	GameEvents.wave_cleared.emit(_current_wave_data.wave_number)
	_breather_timer = _get_breather_duration(_current_wave_data.wave_number)
	_state = WaveState.BREATHER


func _process_breather(delta: float) -> void:
	_breather_timer -= delta
	if _breather_timer <= 0.0:
		_state = WaveState.IDLE  # IDLE triggers _start_next_wave on next frame


# --- Breather scaling ---

func _get_breather_duration(wave_number: int) -> float:
	if wave_number <= 5:
		return 2.5
	if wave_number <= 10:
		return 2.0
	if wave_number <= 15:
		return 1.5
	return 1.0


# --- Straggler despawn ---

func _mark_current_enemies_as_stragglers() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("mark_wave_advanced"):
			enemy.mark_wave_advanced()


# --- Mini-boss spawning ---

func _check_mini_boss(wave_number: int) -> void:
	if wave_number == 10:
		_spawn_elite("minotaur", 2.0)
	elif wave_number == 15:
		_spawn_elite("cyclops", 2.0)


func _spawn_elite(enemy_name: String, hp_multiplier: float) -> void:
	var pool: ObjectPool = _enemy_pools.get(enemy_name) as ObjectPool
	if not pool:
		return
	var data: EnemyData = enemy_lookup.get(enemy_name) as EnemyData
	if not data:
		return
	var enemy: Node = pool.get_instance()
	if not enemy:
		return
	if enemy is EnemyBase:
		enemy.initialize(data, player)
		# Override HP for elite
		var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.max_health = int(data.max_health * hp_multiplier)
			health.current_health = health.max_health
			# Track mini-boss kill
			if not health.died.is_connected(_on_mini_boss_died):
				health.died.connect(_on_mini_boss_died, CONNECT_ONE_SHOT)
		# Scale up visually
		enemy.scale = Vector2(1.5, 1.5)
		# Position
		enemy.global_position = player.global_position + Vector2(spawn_radius, 0).rotated(randf() * TAU)
		_wave_enemies_remaining += 1


func _on_mini_boss_died() -> void:
	GameState.mini_boss_kills += 1


# --- Boss ---

func _spawn_boss() -> void:
	var skeleton_pool: ObjectPool = _enemy_pools.get("skeleton") as ObjectPool
	if not boss_data or _enemy_pools.is_empty():
		return
	_boss_spawned = true
	_boss_trickle_timer = boss_trickle_interval
	# Use skeleton pool for boss (same base_enemy scene)
	var pool: ObjectPool = skeleton_pool if skeleton_pool else _enemy_pools.values().front() as ObjectPool
	if not pool:
		return
	var boss: Node = pool.get_instance()
	if boss is EnemyBase:
		var spawn_pos := _get_spawn_position(WaveData.SpawnPattern.RING, 0, 1)
		boss.global_position = spawn_pos
		boss.initialize(boss_data, player)
		# Wire boss behavior pools and enemy data for summoning
		var harpy_pool: ObjectPool = _enemy_pools.get("harpy") as ObjectPool
		var minotaur_pool: ObjectPool = _enemy_pools.get("minotaur") as ObjectPool
		boss.set_boss_pools(
			skeleton_pool if skeleton_pool else null,
			harpy_pool if harpy_pool else null,
			minotaur_pool if minotaur_pool else null,
			crack_pool if crack_pool else null,
		)
		var skel_data: EnemyData = enemy_lookup.get("skeleton") as EnemyData
		var harpy_data: EnemyData = enemy_lookup.get("harpy") as EnemyData
		var mino_data: EnemyData = enemy_lookup.get("minotaur") as EnemyData
		boss.set_boss_enemy_data(
			skel_data if skel_data else null,
			harpy_data if harpy_data else null,
			mino_data if mino_data else null,
		)
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
		var skeleton_pool: ObjectPool = _enemy_pools.get("skeleton") as ObjectPool
		if skeleton_data and skeleton_pool:
			for i in range(boss_trickle_count):
				if _get_total_active_enemies() >= max_active_enemies:
					break
				var enemy: Node = skeleton_pool.get_instance()
				if enemy is EnemyBase:
					var spawn_pos := _get_spawn_position(WaveData.SpawnPattern.RING, i, boss_trickle_count)
					enemy.global_position = spawn_pos
					enemy.initialize(skeleton_data, player)


# --- Spawning ---

func _spawn_batch(count: int) -> void:
	if _enemy_pools.is_empty() or not player or not _current_wave_data:
		return

	# Build weighted enemy list from composition
	var enemy_list: Array[Dictionary] = _build_enemy_list()
	if enemy_list.is_empty():
		return

	var total_active: int = _get_total_active_enemies()
	var capped_count: int = mini(count, max_active_enemies - total_active)

	for i in range(capped_count):
		var entry: Dictionary = enemy_list[randi() % enemy_list.size()]
		var data: EnemyData = entry["data"] as EnemyData
		var enemy_name: String = entry["name"] as String
		var pool: ObjectPool = _enemy_pools.get(enemy_name) as ObjectPool
		if not pool:
			continue
		var enemy_instance: Node = pool.get_instance()
		if enemy_instance is EnemyBase:
			var spawn_pos := _get_spawn_position(_current_wave_data.spawn_pattern, i, capped_count)
			enemy_instance.global_position = spawn_pos
			enemy_instance.initialize(data, player)
			_wave_enemies_remaining += 1


func _build_enemy_list() -> Array[Dictionary]:
	# Convert composition dictionary {"skeleton": 4, "harpy": 2} into a weighted
	# flat list [{"name": "skeleton", "data": ...}, ...] for pool-aware spawning
	var list: Array[Dictionary] = []
	for key: String in _current_wave_data.enemy_composition:
		var data: EnemyData = enemy_lookup.get(key) as EnemyData
		if not data:
			push_error("WaveManager: unknown enemy key '%s' in wave %d" % [key, _current_wave_data.wave_number])
			continue
		var weight: int = int(_current_wave_data.enemy_composition[key])
		for _w in range(weight):
			list.append({"name": key, "data": data})
	return list


# --- Pool helpers ---

func _get_total_active_enemies() -> int:
	var total: int = 0
	# Track unique pools to avoid double-counting shared pools
	var counted_pools: Array[ObjectPool] = []
	for pool: ObjectPool in _enemy_pools.values():
		if pool not in counted_pools:
			total += pool.active_count()
			counted_pools.append(pool)
	return total


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
