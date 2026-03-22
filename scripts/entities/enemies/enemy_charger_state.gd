class_name EnemyChargerState
extends Node
## Minotaur charge behavior: walk toward player, wind up, charge in locked direction, stun self, cooldown.

enum Phase { WALKING, WINDUP, CHARGING, STUNNED, COOLDOWN }

var _enemy: EnemyBase
var _phase: Phase = Phase.WALKING
var _phase_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO

const WALK_SPEED: float = 35.0
const WINDUP_DISTANCE: float = 180.0
const WINDUP_DURATION: float = 1.0
const CHARGE_SPEED: float = 200.0
const CHARGE_DURATION: float = 0.4
const STUN_DURATION: float = 1.5
const COOLDOWN_DURATION: float = 4.0
const WINDUP_TINT: Color = Color(1.4, 0.6, 0.6)


func enter() -> void:
	_enemy = owner as EnemyBase
	_phase = Phase.WALKING
	_phase_timer = 0.0


func physics_update(delta: float) -> void:
	if _enemy.is_stunned():
		return

	var player: Node2D = _enemy.get_player()
	if not player:
		_enemy.velocity = Vector2.ZERO
		return

	match _phase:
		Phase.WALKING:
			_do_walking(player)
		Phase.WINDUP:
			_do_windup(delta)
		Phase.CHARGING:
			_do_charging(delta)
		Phase.STUNNED:
			_do_stunned(delta)
		Phase.COOLDOWN:
			_do_cooldown(delta, player)


func _do_walking(player: Node2D) -> void:
	var distance: float = _enemy.global_position.distance_to(player.global_position)
	if distance <= WINDUP_DISTANCE:
		_set_phase(Phase.WINDUP)
		_charge_direction = _enemy.global_position.direction_to(player.global_position)
		_enemy.velocity = Vector2.ZERO
		_enemy.sprite.modulate = WINDUP_TINT
		return

	_enemy.move_toward_player(WALK_SPEED)


func _do_windup(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.CHARGING)
		_enemy.sprite.modulate = Color.WHITE


func _do_charging(delta: float) -> void:
	_enemy.velocity = _charge_direction * CHARGE_SPEED
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.STUNNED)
		_enemy.velocity = Vector2.ZERO
		_enemy.apply_stun(STUN_DURATION)


func _do_stunned(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.COOLDOWN)


func _do_cooldown(delta: float, player: Node2D) -> void:
	# Walk toward player during cooldown, but don't trigger a new charge
	_enemy.move_toward_player(WALK_SPEED)
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.WALKING)


func _set_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match new_phase:
		Phase.WINDUP:
			_phase_timer = WINDUP_DURATION
		Phase.CHARGING:
			_phase_timer = CHARGE_DURATION
		Phase.STUNNED:
			_phase_timer = STUN_DURATION
		Phase.COOLDOWN:
			_phase_timer = COOLDOWN_DURATION
