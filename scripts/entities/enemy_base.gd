class_name EnemyBase
extends CharacterBody2D

var data: EnemyData
var pool: ObjectPool
var _player: Node2D = null
var _dying: bool = false
var _active_behavior: Node = null
var _behavior_cache: Dictionary = {}  # BehaviorType int -> Node

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

const DamageNumber := preload("res://scripts/effects/damage_number.gd")

# --- Knockback ---
var _knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_DECAY: float = 10.0

# --- Stun ---
var _is_stunned: bool = false
var _stun_timer: float = 0.0
var _stun_damage_multiplier: float = 1.5

# --- Straggler tracking ---
var _alive_time: float = 0.0
var _wave_advanced: bool = false
const STRAGGLER_TIMEOUT: float = 30.0
const STRAGGLER_FADE_DURATION: float = 0.5

# --- Cluster fields (set by spawner for swarm behavior) ---
var cluster_id: int = -1
var is_cluster_leader: bool = false

# --- Damage number throttle ---
var _last_damage_number_time: float = 0.0
const DAMAGE_NUMBER_COOLDOWN := 0.3

# --- Flash tween ---
var _flash_tween: Tween = null


func _ready() -> void:
	add_to_group("enemies")
	health_component.died.connect(_on_died)
	health_component.damage_received.connect(_on_damage_received)
	hurtbox.hit.connect(_on_hit)
	hurtbox.health = health_component


# --- Pool interface ---

func set_pool(p: ObjectPool) -> void:
	pool = p


func initialize(enemy_data: EnemyData, player: Node2D) -> void:
	data = enemy_data
	_player = player
	_dying = false
	health_component.max_health = data.max_health
	health_component.current_health = data.max_health
	hitbox.damage = data.damage
	modulate = Color.WHITE
	scale = Vector2.ONE
	if data.sprite_texture:
		sprite.texture = data.sprite_texture
	sprite.scale = data.sprite_scale
	sprite.flip_h = data.flip_default
	# Boss scaling
	if data.is_boss:
		scale = Vector2(1.8, 1.8)
	# Reset knockback
	_knockback_velocity = Vector2.ZERO
	# Reset stun
	_is_stunned = false
	_stun_timer = 0.0
	# Reset straggler
	_alive_time = 0.0
	_wave_advanced = false
	# Reset cluster
	cluster_id = -1
	is_cluster_leader = false
	# Attach / activate behavior node
	_setup_behavior()


func reset() -> void:
	data = null
	_player = null
	_dying = false
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	# Reset knockback
	_knockback_velocity = Vector2.ZERO
	# Reset stun
	_is_stunned = false
	_stun_timer = 0.0
	# Reset straggler
	_alive_time = 0.0
	_wave_advanced = false
	# Reset cluster
	cluster_id = -1
	is_cluster_leader = false
	# Deactivate all cached behaviors (cached nodes stay for reuse)
	for state: Node in _behavior_cache.values():
		state.set_process(false)
		state.set_physics_process(false)
	_active_behavior = null


# --- Physics ---

func _physics_process(delta: float) -> void:
	if _dying:
		return

	# Straggler check
	if _wave_advanced:
		_alive_time += delta
		if _alive_time > STRAGGLER_TIMEOUT:
			_start_straggler_despawn()
			return

	# Stun processing
	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_is_stunned = false
			sprite.modulate = Color.WHITE
		return  # Don't move while stunned

	# Knockback
	if _knockback_velocity.length_squared() > 1.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return

	# Behavior update (delegated to cached child node)
	if _active_behavior and _active_behavior.has_method("physics_update"):
		_active_behavior.physics_update(delta)

	# Sprite flip (invert if default is already flipped)
	if velocity.x != 0:
		var facing_left: bool = velocity.x < 0
		sprite.flip_h = facing_left if not data.flip_default else not facing_left

	move_and_slide()


# --- Knockback ---

func apply_knockback(direction: Vector2, force: float) -> void:
	_knockback_velocity = direction.normalized() * force


# --- Stun ---

func apply_stun(duration: float) -> void:
	_is_stunned = true
	_stun_timer = duration
	sprite.modulate = Color(0.7, 0.7, 1.0)


func is_stunned() -> bool:
	return _is_stunned


# --- Straggler ---

func mark_wave_advanced() -> void:
	_wave_advanced = true
	_alive_time = 0.0  # Reset timer from this point


func _start_straggler_despawn() -> void:
	_dying = true
	velocity = Vector2.ZERO
	hurtbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, STRAGGLER_FADE_DURATION)
	tween.tween_callback(_handle_death)


# --- Movement helper ---

func move_toward_player(speed_override: float = -1.0) -> void:
	if not _player:
		return
	var direction := global_position.direction_to(_player.global_position)
	var spd: float = speed_override if speed_override > 0.0 else data.speed
	velocity = direction * spd


# --- Behavior node access ---

func get_player() -> Node2D:
	return _player


func set_projectile_pools(javelin_pool: ObjectPool, boulder_pool: ObjectPool) -> void:
	if _active_behavior and _active_behavior.has_method("set_javelin_pool"):
		_active_behavior.set_javelin_pool(javelin_pool)
	if _active_behavior and _active_behavior.has_method("set_boulder_pool"):
		_active_behavior.set_boulder_pool(boulder_pool)


func set_boss_pools(skeleton: ObjectPool, harpy: ObjectPool, minotaur: ObjectPool, crack: ObjectPool) -> void:
	if _active_behavior and _active_behavior.has_method("set_pools"):
		_active_behavior.set_pools(skeleton, harpy, minotaur)
	if _active_behavior and _active_behavior.has_method("set_crack_pool"):
		_active_behavior.set_crack_pool(crack)


func set_boss_enemy_data(skeleton: EnemyData, harpy: EnemyData, minotaur: EnemyData) -> void:
	if _active_behavior and _active_behavior.has_method("set_enemy_data"):
		_active_behavior.set_enemy_data(skeleton, harpy, minotaur)


# --- Behavior wiring ---

func _setup_behavior() -> void:
	# Deactivate all cached behaviors
	for state: Node in _behavior_cache.values():
		state.set_process(false)
		state.set_physics_process(false)

	var bt: int = data.behavior_type

	if not _behavior_cache.has(bt):
		var state: Node = _create_behavior(bt)
		if state:
			state.name = "BehaviorState_%d" % bt
			add_child(state)
			_behavior_cache[bt] = state

	var active: Node = _behavior_cache.get(bt)
	if active:
		active.set_process(true)
		active.set_physics_process(true)
		if active.has_method("enter"):
			active.enter()
	_active_behavior = active


func _create_behavior(bt: int) -> Node:
	match bt:
		EnemyData.BehaviorType.SWARM:
			return EnemySwarmState.new()
		EnemyData.BehaviorType.DIVER:
			return EnemyDiverState.new()
		EnemyData.BehaviorType.CHARGER:
			return EnemyChargerState.new()
		EnemyData.BehaviorType.TANK_SLAM:
			return EnemySlamState.new()
		EnemyData.BehaviorType.KITER:
			return EnemyKiterState.new()
		EnemyData.BehaviorType.ZONER:
			return EnemyZonerState.new()
		EnemyData.BehaviorType.BOSS:
			return CerberusBoss.new()
	return null


# --- Damage & hit feedback ---

func _on_hit(_from_hitbox: HitboxComponent) -> void:
	# Visual feedback handled by _on_damage_received for all damage sources
	pass


func _on_damage_received(amount: int) -> void:
	_flash_hit()
	# Throttle damage numbers to avoid lag from AoE spam
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_number_time >= DAMAGE_NUMBER_COOLDOWN:
		_last_damage_number_time = now
		_spawn_damage_number(amount)
	# Apply knockback scaled by damage
	if _player:
		var dir: Vector2 = _player.global_position.direction_to(global_position)
		var force: float = clampf(float(amount) * 1.5, 10.0, 30.0)
		apply_knockback(dir, force)


func _flash_hit() -> void:
	if _dying:
		return
	if _flash_tween and _flash_tween.is_running():
		return
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)


func _spawn_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	var label := Label.new()
	label.set_script(DamageNumber)
	get_tree().current_scene.add_child(label)
	# Scale font size based on damage value
	var font_size: int = 8
	if amount >= 30:
		font_size = 14
	elif amount >= 15:
		font_size = 11
	label.show_number(global_position, amount, font_size)


# --- Death ---

func _on_died() -> void:
	if _dying:
		return
	_dying = true
	# Disable collisions immediately so enemy stops dealing/taking damage
	hurtbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	velocity = Vector2.ZERO
	if data and data.is_boss:
		call_deferred("_play_boss_death_sequence")
	else:
		call_deferred("_play_death_effect")


func _play_death_effect() -> void:
	var xp: int = data.xp_reward if data else 0
	GameEvents.enemy_killed.emit(global_position, xp)
	# Screen shake on death (light)
	if has_node("/root/JuiceManager"):
		get_node("/root/JuiceManager").screen_shake(1.5, 0.05)
	_spawn_death_particles()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_handle_death)


func _spawn_death_particles() -> void:
	for i: int in 6:
		var particle: ColorRect = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.color = sprite.modulate if sprite.modulate != Color.WHITE else Color(0.8, 0.3, 0.3)
		particle.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		get_tree().current_scene.add_child(particle)
		var dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var tween: Tween = particle.create_tween()
		tween.tween_property(particle, "global_position", particle.global_position + dir * 30.0, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)


func _play_boss_death_sequence() -> void:
	GameEvents.enemy_killed.emit(global_position, data.xp_reward)
	# Hitstop for dramatic pause
	if has_node("/root/JuiceManager"):
		get_node("/root/JuiceManager").hitstop(150)
	# Dramatic collapse tween
	var tween := create_tween()
	tween.tween_interval(0.2)  # Wait for hitstop to finish
	# Flash white
	tween.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	# Collapse animation
	tween.tween_property(sprite, "scale", Vector2(2.0, 0.5), 0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_boss_death_cleanup)


func _boss_death_cleanup() -> void:
	var death_pos: Vector2 = global_position
	GameEvents.boss_died.emit(death_pos)
	# Stun all remaining enemies briefly
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy is Node2D and enemy.visible and enemy.has_method("apply_stun"):
			enemy.apply_stun(1.0)
	# After 1s, kill all remaining visible enemies
	get_tree().create_timer(1.0).timeout.connect(_chain_kill_enemies)
	_handle_death()


func _chain_kill_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or not (enemy as Node2D).visible:
			continue
		var health: Node = enemy.get_node_or_null("HealthComponent")
		if health and health.has_method("take_damage"):
			health.take_damage(99999)


func _handle_death() -> void:
	if pool:
		pool.release(self)
	else:
		queue_free()
