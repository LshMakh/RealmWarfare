class_name EnemySlamState
extends Node
## Cyclops ranged + melee behavior: approach with boulder throws, telegraph slam at close range.

enum Phase { APPROACHING, TELEGRAPH, SLAMMING, RECOVERY }

var _enemy: EnemyBase
var _phase: Phase = Phase.APPROACHING
var _phase_timer: float = 0.0
var _throw_cooldown: float = 0.0

const APPROACH_SPEED: float = 25.0
const THROW_INTERVAL: float = 3.0
const THROW_MIN_DISTANCE: float = 150.0
const SLAM_TRIGGER_DISTANCE: float = 150.0
const TELEGRAPH_DURATION: float = 1.0
const SLAM_RADIUS: float = 70.0
const RECOVERY_DURATION: float = 3.0
const TELEGRAPH_TINT: Color = Color(1.4, 0.6, 0.6)


func enter() -> void:
	_enemy = get_parent() as EnemyBase
	_phase = Phase.APPROACHING
	_phase_timer = 0.0
	_throw_cooldown = THROW_INTERVAL


func physics_update(delta: float) -> void:
	if _enemy.is_stunned():
		return

	var player: Node2D = _enemy.get_player()
	if not player:
		_enemy.velocity = Vector2.ZERO
		return

	match _phase:
		Phase.APPROACHING:
			_do_approaching(delta, player)
		Phase.TELEGRAPH:
			_do_telegraph(delta)
		Phase.SLAMMING:
			_do_slamming(player)
		Phase.RECOVERY:
			_do_recovery(delta)


func _do_approaching(delta: float, player: Node2D) -> void:
	var distance: float = _enemy.global_position.distance_to(player.global_position)

	# Check if close enough to slam
	if distance < SLAM_TRIGGER_DISTANCE:
		_set_phase(Phase.TELEGRAPH)
		_enemy.velocity = Vector2.ZERO
		_enemy.sprite.modulate = TELEGRAPH_TINT
		return

	# Boulder throw cooldown
	_throw_cooldown -= delta
	if _throw_cooldown <= 0.0 and distance > THROW_MIN_DISTANCE:
		_throw_boulder()
		_throw_cooldown = THROW_INTERVAL

	_enemy.move_toward_player(APPROACH_SPEED)


func _do_telegraph(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_enemy.sprite.modulate = Color.WHITE
		_set_phase(Phase.SLAMMING)


func _do_slamming(player: Node2D) -> void:
	# Check if player is in slam radius
	var distance: float = _enemy.global_position.distance_to(player.global_position)
	if distance <= SLAM_RADIUS:
		# Placeholder: damage is handled by hitbox component in the scene
		# TODO: Task 4b — spawn cracked ground effect
		pass

	_enemy.velocity = Vector2.ZERO
	_set_phase(Phase.RECOVERY)


func _do_recovery(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.APPROACHING)
		_throw_cooldown = THROW_INTERVAL


func _throw_boulder() -> void:
	# Placeholder for boulder projectile — Task 4b
	print("[EnemySlamState] Boulder thrown (placeholder)")


func _set_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match new_phase:
		Phase.TELEGRAPH:
			_phase_timer = TELEGRAPH_DURATION
		Phase.RECOVERY:
			_phase_timer = RECOVERY_DURATION
