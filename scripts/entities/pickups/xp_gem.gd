extends Area2D

enum GemState { BURST, IDLE, MAGNETIZED }

# Tier thresholds: [min_xp, scale, Color]
const TIER_DATA: Array[Dictionary] = [
	{ "min_xp": 1, "scale": 0.6, "color": Color(0.4, 0.6, 1.0) },
	{ "min_xp": 3, "scale": 1.0, "color": Color(0.3, 0.9, 0.3) },
	{ "min_xp": 8, "scale": 1.4, "color": Color(1.0, 0.85, 0.0) },
	{ "min_xp": 25, "scale": 1.8, "color": Color(1.0, 0.95, 0.5) },
]

const BURST_DURATION: float = 0.3
const MAGNET_RANGE: float = 80.0
const MAGNET_ACCEL: float = 400.0
const BURST_SPEED_MIN: float = 50.0
const BURST_SPEED_MAX: float = 150.0

var pool: ObjectPool
var value: int = 1

var _state: int = GemState.BURST
var _magnet_target: Node2D = null
var _magnet_speed: float = 0.0
var _burst_velocity: Vector2 = Vector2.ZERO
var _burst_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	value = 1
	_state = GemState.BURST
	_magnet_target = null
	_magnet_speed = 0.0
	_burst_velocity = Vector2.ZERO
	_burst_timer = 0.0
	global_position = Vector2.ZERO
	scale = Vector2.ONE
	modulate = Color.WHITE
	monitoring = true


func activate(pos: Vector2, xp_value: int, player: Node2D) -> void:
	global_position = pos
	value = xp_value
	_magnet_target = player
	monitoring = true

	# Determine tier from xp_value (highest matching tier wins)
	var tier_idx: int = 0
	for i: int in range(TIER_DATA.size()):
		if xp_value >= TIER_DATA[i]["min_xp"]:
			tier_idx = i

	var tier: Dictionary = TIER_DATA[tier_idx]
	var s: float = tier["scale"]
	scale = Vector2(s, s)
	modulate = tier["color"]

	# Start BURST state with random outward velocity
	var angle: float = randf() * TAU
	var speed: float = randf_range(BURST_SPEED_MIN, BURST_SPEED_MAX)
	_burst_velocity = Vector2.from_angle(angle) * speed
	_burst_timer = 0.0
	_magnet_speed = 0.0
	_state = GemState.BURST


func _physics_process(delta: float) -> void:
	match _state:
		GemState.BURST:
			_process_burst(delta)
		GemState.IDLE:
			_process_idle()
		GemState.MAGNETIZED:
			_process_magnetized(delta)


func _process_burst(delta: float) -> void:
	_burst_timer += delta
	global_position += _burst_velocity * delta
	_burst_velocity = _burst_velocity.lerp(Vector2.ZERO, 0.1)
	if _burst_timer >= BURST_DURATION:
		_state = GemState.IDLE


func _process_idle() -> void:
	if not _magnet_target:
		return
	if not is_instance_valid(_magnet_target):
		return
	var dist: float = global_position.distance_to(_magnet_target.global_position)
	if GameState.magnet_active or dist < MAGNET_RANGE:
		_magnet_speed = 200.0
		_state = GemState.MAGNETIZED


func _process_magnetized(delta: float) -> void:
	if not _magnet_target or not is_instance_valid(_magnet_target):
		_state = GemState.IDLE
		return
	_magnet_speed += MAGNET_ACCEL * delta
	var direction: Vector2 = global_position.direction_to(_magnet_target.global_position)
	global_position += direction * _magnet_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _state == GemState.BURST:
		return
	if body.is_in_group("player"):
		GameEvents.xp_collected.emit(value)
		set_deferred("monitoring", false)
		call_deferred("_release")


func _release() -> void:
	if pool:
		pool.release(self)
	else:
		queue_free()
