class_name EnemyDiverState
extends Node
## Harpy dive-bomb behavior: approach in arc, pause, dive at locked target, retreat, cooldown.

enum Phase { APPROACH, PAUSE, DIVE, RETREAT, COOLDOWN }

var _enemy: EnemyBase
var _phase: Phase = Phase.APPROACH
var _phase_timer: float = 0.0
var _dive_target: Vector2 = Vector2.ZERO

const APPROACH_SPEED: float = 80.0
const APPROACH_DISTANCE: float = 220.0
const PAUSE_DURATION: float = 0.3
const DIVE_SPEED: float = 150.0
const DIVE_DURATION: float = 0.5
const RETREAT_SPEED: float = 100.0
const RETREAT_DISTANCE: float = 300.0
const COOLDOWN_DURATION: float = 3.0


func enter() -> void:
	_enemy = get_parent() as EnemyBase
	_phase = Phase.APPROACH
	_phase_timer = 0.0


func physics_update(delta: float) -> void:
	if _enemy.is_stunned():
		return

	var player: Node2D = _enemy.get_player()
	if not player:
		_enemy.velocity = Vector2.ZERO
		return

	match _phase:
		Phase.APPROACH:
			_do_approach(player)
		Phase.PAUSE:
			_do_pause(delta)
		Phase.DIVE:
			_do_dive(delta)
		Phase.RETREAT:
			_do_retreat(player)
		Phase.COOLDOWN:
			_do_cooldown(delta)


func _do_approach(player: Node2D) -> void:
	var to_player: Vector2 = player.global_position - _enemy.global_position
	var distance: float = to_player.length()

	if distance <= APPROACH_DISTANCE:
		_set_phase(Phase.PAUSE)
		_dive_target = player.global_position
		_enemy.velocity = Vector2.ZERO
		return

	# Wide arc: add perpendicular component
	var direction: Vector2 = to_player.normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var arc_direction: Vector2 = (direction + perpendicular * 0.5).normalized()
	_enemy.velocity = arc_direction * APPROACH_SPEED


func _do_pause(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.DIVE)


func _do_dive(delta: float) -> void:
	var direction: Vector2 = (_dive_target - _enemy.global_position).normalized()
	_enemy.velocity = direction * DIVE_SPEED
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.RETREAT)


func _do_retreat(player: Node2D) -> void:
	var to_player: Vector2 = player.global_position - _enemy.global_position
	var distance: float = to_player.length()

	if distance >= RETREAT_DISTANCE:
		_set_phase(Phase.COOLDOWN)
		_enemy.velocity = Vector2.ZERO
		return

	var away: Vector2 = -to_player.normalized()
	_enemy.velocity = away * RETREAT_SPEED


func _do_cooldown(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.APPROACH)


func _set_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match new_phase:
		Phase.PAUSE:
			_phase_timer = PAUSE_DURATION
		Phase.DIVE:
			_phase_timer = DIVE_DURATION
		Phase.COOLDOWN:
			_phase_timer = COOLDOWN_DURATION
