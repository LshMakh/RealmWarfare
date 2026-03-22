class_name LightningStrike
extends Area2D

var pool: ObjectPool
var _damage: int = 15
var _timer: float = 0.0
var _radius: float = 50.0
var _phase: int = 0  # 0=inactive, 1=telegraph, 2=strike, 3=done
var _telegraph_duration: float = 1.5


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	_phase = 0
	_timer = 0.0
	_damage = 15
	visible = false
	modulate = Color.WHITE


func initialize(pos: Vector2, damage: int) -> void:
	global_position = pos
	_damage = damage
	_phase = 1
	_timer = _telegraph_duration
	_radius = 50.0
	visible = true
	modulate = Color(1.0, 1.0, 0.3, 0.3)
	queue_redraw()


func _process(delta: float) -> void:
	if _phase == 1:
		_timer -= delta
		modulate.a = lerpf(0.3, 0.8, 1.0 - _timer / _telegraph_duration)
		queue_redraw()
		if _timer <= 0.0:
			_strike()


func _strike() -> void:
	_phase = 2
	modulate = Color(1.0, 1.0, 0.8, 1.0)
	queue_redraw()
	# Damage everything in radius
	for body: Node2D in get_overlapping_bodies():
		var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.take_damage(_damage)
	# Fade out
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_finish)


func _finish() -> void:
	_phase = 3
	visible = false
	if pool:
		pool.release(self)


func _draw() -> void:
	if _phase == 1:
		# Telegraph: yellow circle with pulsing fill
		draw_circle(Vector2.ZERO, _radius, Color(1.0, 1.0, 0.3, modulate.a * 0.3))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(1.0, 1.0, 0.3, modulate.a), 2.0)
	elif _phase == 2:
		# Strike flash: bright white-yellow circle
		draw_circle(Vector2.ZERO, _radius, Color(1.0, 1.0, 0.9, 0.6))
