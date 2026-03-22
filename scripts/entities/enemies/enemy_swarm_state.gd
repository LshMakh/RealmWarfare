class_name EnemySwarmState
extends Node
## Basic chase toward player. Supports scatter burst on command.

var _enemy: EnemyBase

# --- Scatter ---
var _is_scattering: bool = false
var _scatter_timer: float = 0.0
var _scatter_direction: Vector2 = Vector2.ZERO
const SCATTER_DURATION: float = 0.5


func enter() -> void:
	_enemy = owner as EnemyBase


func physics_update(delta: float) -> void:
	if _enemy.is_stunned():
		return

	if _is_scattering:
		_scatter_timer -= delta
		if _scatter_timer <= 0.0:
			_is_scattering = false
		else:
			_enemy.velocity = _scatter_direction * _enemy.data.speed
			return

	_enemy.move_toward_player()


## Called externally to scatter the enemy in a random direction.
func scatter() -> void:
	_is_scattering = true
	_scatter_timer = SCATTER_DURATION
	_scatter_direction = Vector2.from_angle(randf() * TAU)
