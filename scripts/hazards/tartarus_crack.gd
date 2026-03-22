class_name TartarusCrack
extends Area2D

var pool: ObjectPool
var _direction: Vector2 = Vector2.RIGHT
var _current_length: float = 10.0
var _lifetime: float = 0.0
var _grow_timer: float = 0.0
var _damage_timer: float = 0.0
var _active: bool = false
var _fading: bool = false
var _collision_shape: CollisionShape2D = null
var _rect_shape: RectangleShape2D = null
var _jitter_values: PackedFloat32Array = PackedFloat32Array()
var _last_segment_count: int = 0

const MAX_LENGTH: float = 175.0
const GROW_DURATION: float = 5.0
const GROW_SPEED: float = 25.0  # ~165px over 5s starting from 10px -> ~175px total
const TOTAL_LIFETIME: float = 15.0
const FADE_DURATION: float = 0.5
const PLAYER_DPS: float = 10.0
const ENEMY_DPS: float = 5.0
const DAMAGE_TICK: float = 0.5
const CRACK_WIDTH: float = 6.0


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	_direction = Vector2.RIGHT
	_current_length = 10.0
	_lifetime = 0.0
	_grow_timer = 0.0
	_damage_timer = 0.0
	_active = false
	_fading = false
	_last_segment_count = 0
	_jitter_values.clear()
	visible = false
	modulate = Color.WHITE
	rotation = 0.0


func initialize(pos: Vector2) -> void:
	global_position = pos
	_active = true
	_fading = false
	_lifetime = 0.0
	_grow_timer = GROW_DURATION
	_damage_timer = DAMAGE_TICK
	_current_length = 10.0
	visible = true
	modulate = Color.WHITE

	# Pick a random direction and orient the node
	var angle: float = randf() * TAU
	_direction = Vector2(cos(angle), sin(angle))
	rotation = angle

	# Cache collision shape references — create a unique shape per instance
	# so resizing one doesn't affect other pooled cracks
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape:
		if not _rect_shape:
			_rect_shape = RectangleShape2D.new()
			_collision_shape.shape = _rect_shape

	_jitter_values.clear()
	_last_segment_count = 0
	_update_collision_shape()
	_update_jitter()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return

	_lifetime += delta

	# Grow phase
	if _grow_timer > 0.0:
		_grow_timer -= delta
		_current_length = minf(_current_length + GROW_SPEED * delta, MAX_LENGTH)
		_update_collision_shape()
		_update_jitter()
		queue_redraw()

	# Damage tick
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer += DAMAGE_TICK
		_apply_damage()

	# Fade out near end of lifetime
	if not _fading and _lifetime >= TOTAL_LIFETIME - FADE_DURATION:
		_fading = true
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(_finish)

	# Safety: force finish if lifetime exceeded
	if _lifetime >= TOTAL_LIFETIME + 0.5:
		_finish()


func _update_jitter() -> void:
	var segments: int = maxi(int(_current_length / 12.0), 2)
	if segments != _last_segment_count:
		# Only regenerate when segment count changes (crack grows)
		_last_segment_count = segments
		_jitter_values.resize(segments + 1)
		_jitter_values[0] = 0.0  # Start point — no jitter
		for i: int in range(1, segments):
			_jitter_values[i] = randf_range(-3.0, 3.0)
		_jitter_values[segments] = 0.0  # End point — no jitter


func _update_collision_shape() -> void:
	if not _rect_shape or not _collision_shape:
		return
	# The crack extends along local +X (since we rotated the node)
	# Rectangle centered at half-length along X
	_rect_shape.size = Vector2(_current_length, CRACK_WIDTH)
	_collision_shape.position = Vector2(_current_length * 0.5, 0.0)


func _apply_damage() -> void:
	for body: Node2D in get_overlapping_bodies():
		var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
		if not health:
			continue
		if body.is_in_group("player"):
			var tick_damage: int = int(PLAYER_DPS * DAMAGE_TICK)
			health.take_damage(maxi(tick_damage, 1))
		elif body.is_in_group("enemies"):
			var tick_damage: int = int(ENEMY_DPS * DAMAGE_TICK)
			health.take_damage(maxi(tick_damage, 1))


func force_finish() -> void:
	_finish()


func _finish() -> void:
	if not _active:
		return
	_active = false
	visible = false
	if pool:
		pool.release(self)


func _draw() -> void:
	if not _active:
		return
	# Draw crack as a jagged line along local +X using pre-computed jitter
	var segments: int = maxi(int(_current_length / 12.0), 2)
	var step: float = _current_length / float(segments)

	# Core dark purple line
	var core_color := Color(0.3, 0.0, 0.4, 0.9)
	# Glow color
	var glow_color := Color(0.6, 0.1, 0.8, 0.4)

	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)

	for i: int in range(1, segments):
		var x: float = step * float(i)
		var jitter: float = _jitter_values[i] if i < _jitter_values.size() else 0.0
		points.append(Vector2(x, jitter))

	points.append(Vector2(_current_length, 0.0))

	if points.size() >= 2:
		draw_polyline(points, glow_color, 5.0)
		draw_polyline(points, core_color, 2.0)
