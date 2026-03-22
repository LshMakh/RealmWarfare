extends Area2D

var pool: ObjectPool
var direction: Vector2 = Vector2.ZERO
var speed: float = 250.0
var damage: int = 10
var _lifetime: float = 0.0
var _max_lifetime: float = 2.0
var _released: bool = false


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	direction = Vector2.ZERO
	_lifetime = 0.0
	_released = false
	global_position = Vector2.ZERO
	monitoring = false


func activate(pos: Vector2, dir: Vector2, dmg: int) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	_lifetime = 0.0
	_released = false
	rotation = direction.angle()
	monitoring = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime += delta
	if _lifetime >= _max_lifetime:
		_release()


func _on_area_entered(area: Area2D) -> void:
	if _released:
		return
	if area is HurtboxComponent:
		var enemy: Node = area.get_parent()
		if not enemy.visible or not enemy.is_in_group("enemies"):
			return
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(damage)
		_released = true
		set_deferred("monitoring", false)
		call_deferred("_release")


func _release() -> void:
	if _released:
		return
	_released = true
	set_deferred("monitoring", false)
	if pool:
		pool.release(self)
	else:
		queue_free()
