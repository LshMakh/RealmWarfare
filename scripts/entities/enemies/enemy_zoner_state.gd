class_name EnemyZonerState
extends Node
## Gorgon stationary beam behavior: setup, sweep beam in 45-degree arc, pause, repeat.

enum Phase { SETUP, SWEEPING, PAUSE }

var _enemy: EnemyBase
var _phase: Phase = Phase.SETUP
var _phase_timer: float = 0.0

# --- Beam state ---
var _beam_angle: float = 0.0
var _beam_active: bool = false
var _sweep_start_angle: float = 0.0
var _sweep_end_angle: float = 0.0
var _sweep_direction: float = 1.0  # 1.0 = forward, -1.0 = backward
var _sweeps_done: int = 0

const SETUP_DURATION: float = 1.0
const SWEEP_ARC: float = deg_to_rad(45.0)
const SWEEP_SPEED: float = deg_to_rad(15.0)
const PAUSE_DURATION: float = 2.0
const BEAM_RANGE: float = 200.0
const BEAM_HIT_TOLERANCE: float = deg_to_rad(5.0)


func enter() -> void:
	_enemy = get_parent() as EnemyBase
	_phase = Phase.SETUP
	_phase_timer = SETUP_DURATION
	_beam_active = false
	_sweeps_done = 0


func physics_update(delta: float) -> void:
	# Gorgon is always stationary
	_enemy.velocity = Vector2.ZERO

	if _enemy.is_stunned():
		_beam_active = false
		return

	var player: Node2D = _enemy.get_player()
	if not player:
		return

	match _phase:
		Phase.SETUP:
			_do_setup(delta, player)
		Phase.SWEEPING:
			_do_sweeping(delta, player)
		Phase.PAUSE:
			_do_pause(delta)


func _do_setup(delta: float, player: Node2D) -> void:
	_beam_active = false
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		# Start sweep aimed at player offset by -22.5 degrees
		var angle_to_player: float = _enemy.global_position.angle_to_point(player.global_position)
		_sweep_start_angle = angle_to_player - SWEEP_ARC * 0.5
		_sweep_end_angle = angle_to_player + SWEEP_ARC * 0.5
		_beam_angle = _sweep_start_angle
		_sweep_direction = 1.0
		_sweeps_done = 0
		_beam_active = true
		_set_phase(Phase.SWEEPING)


func _do_sweeping(delta: float, player: Node2D) -> void:
	_beam_active = true

	# Advance beam angle
	_beam_angle += _sweep_direction * SWEEP_SPEED * delta

	# Check if we've reached the end of current sweep direction
	if _sweep_direction > 0.0 and _beam_angle >= _sweep_end_angle:
		_beam_angle = _sweep_end_angle
		_sweep_direction = -1.0
		_sweeps_done += 1
	elif _sweep_direction < 0.0 and _beam_angle <= _sweep_start_angle:
		_beam_angle = _sweep_start_angle
		_sweep_direction = 1.0
		_sweeps_done += 1

	# After one full back-and-forth (2 sweeps), go to pause
	if _sweeps_done >= 2:
		_beam_active = false
		_set_phase(Phase.PAUSE)
		return

	# Check beam hit on player
	_check_beam_hit(player, delta)


func _do_pause(delta: float) -> void:
	_beam_active = false
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_phase(Phase.SETUP)


func _check_beam_hit(player: Node2D, delta: float) -> void:
	var to_player: Vector2 = player.global_position - _enemy.global_position
	var distance: float = to_player.length()
	if distance > BEAM_RANGE:
		return

	var angle_to_player: float = to_player.angle()
	var angle_diff: float = abs(_normalize_angle(_beam_angle - angle_to_player))
	if angle_diff <= BEAM_HIT_TOLERANCE:
		if player.has_method("apply_petrification"):
			player.apply_petrification(delta)


func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


## Returns the current beam angle in radians. Used by visual rendering.
func get_beam_angle() -> float:
	return _beam_angle


## Returns whether the beam is currently active. Used by visual rendering.
func is_beam_active() -> bool:
	return _beam_active


func _set_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match new_phase:
		Phase.SETUP:
			_phase_timer = SETUP_DURATION
		Phase.PAUSE:
			_phase_timer = PAUSE_DURATION
