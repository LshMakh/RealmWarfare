extends Area2D

var pool: ObjectPool
var value: int = 1
var _magnet_target: Node2D = null
var _magnet_speed: float = 200.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	value = 1
	_magnet_target = null
	global_position = Vector2.ZERO


func activate(pos: Vector2, xp_value: int, player: Node2D) -> void:
	global_position = pos
	value = xp_value
	_magnet_target = player


func _physics_process(delta: float) -> void:
	if not _magnet_target:
		return
	var dist := global_position.distance_to(_magnet_target.global_position)
	if dist < 50.0:
		var direction := global_position.direction_to(_magnet_target.global_position)
		global_position += direction * _magnet_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameEvents.xp_collected.emit(value)
		if pool:
			pool.release(self)
		else:
			queue_free()
