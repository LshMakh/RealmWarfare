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
	if GameState.magnet_active or dist < 80.0:
		var direction := global_position.direction_to(_magnet_target.global_position)
		var pull_speed: float
		if GameState.magnet_active:
			pull_speed = 500.0
		else:
			pull_speed = _magnet_speed * (1.0 + (80.0 - dist) / 80.0 * 2.0)
		global_position += direction * pull_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameEvents.xp_collected.emit(value)
		set_deferred("monitoring", false)
		call_deferred("_release")


func _release() -> void:
	if pool:
		pool.release(self)
	else:
		queue_free()
