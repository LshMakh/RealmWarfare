class_name Javelin
extends Area2D
## Satyr ranged projectile. Pooled Area2D that flies in a direction and damages the player on hit.

var pool: ObjectPool
var _direction: Vector2 = Vector2.ZERO
var _speed: float = 120.0
var _damage: int = 8
var _lifetime: float = 2.0
var _timer: float = 0.0
var _active: bool = false


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	_active = false
	_timer = 0.0
	_direction = Vector2.ZERO
	visible = false
	set_deferred("monitoring", false)


func initialize(pos: Vector2, direction: Vector2, damage: int = 8) -> void:
	global_position = pos
	_direction = direction.normalized()
	_damage = damage
	_timer = 0.0
	_active = true
	visible = true
	rotation = _direction.angle()
	set_deferred("monitoring", true)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _direction * _speed * delta
	_timer += delta
	if _timer > _lifetime:
		_release()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body.is_in_group("player"):
		var health: Node = body.get_node_or_null("HealthComponent")
		if health and health.has_method("take_damage"):
			health.take_damage(_damage)
		_release()


func _release() -> void:
	if not _active:
		return
	_active = false
	visible = false
	set_deferred("monitoring", false)
	if pool:
		pool.release(self)
	else:
		queue_free()
