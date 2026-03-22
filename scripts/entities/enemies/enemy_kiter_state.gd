class_name EnemyKiterState
extends Node
## Satyr ranged kiter: maintains preferred distance, strafes, throws javelins on cooldown.

var _enemy: EnemyBase
var _javelin_cooldown: float = 0.0
var _strafe_sign: float = 1.0

const PREFERRED_DISTANCE: float = 200.0
const RETREAT_THRESHOLD: float = 150.0
const APPROACH_THRESHOLD: float = 230.0
const RETREAT_SPEED: float = 70.0
const APPROACH_SPEED: float = 50.0
const STRAFE_SPEED: float = 25.0
const JAVELIN_INTERVAL: float = 2.5


func enter() -> void:
	_enemy = get_parent() as EnemyBase
	_javelin_cooldown = JAVELIN_INTERVAL
	# Randomize initial strafe direction
	_strafe_sign = 1.0 if randf() > 0.5 else -1.0


func physics_update(delta: float) -> void:
	if _enemy.is_stunned():
		return

	var player: Node2D = _enemy.get_player()
	if not player:
		_enemy.velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - _enemy.global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized() if distance > 0.0 else Vector2.ZERO

	# Movement based on distance
	if distance < RETREAT_THRESHOLD:
		# Too close — retreat
		_enemy.velocity = -direction * RETREAT_SPEED
	elif distance > APPROACH_THRESHOLD:
		# Too far — approach
		_enemy.velocity = direction * APPROACH_SPEED
	else:
		# In sweet spot — strafe perpendicular
		var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
		_enemy.velocity = perpendicular * _strafe_sign * STRAFE_SPEED

	# Javelin cooldown
	_javelin_cooldown -= delta
	if _javelin_cooldown <= 0.0:
		_throw_javelins()
		_javelin_cooldown = JAVELIN_INTERVAL


func _throw_javelins() -> void:
	# Placeholder for javelin projectile — Task 4b
	print("[EnemyKiterState] Javelin thrown (placeholder)")
