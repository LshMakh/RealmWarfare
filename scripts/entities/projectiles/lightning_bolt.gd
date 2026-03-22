extends Area2D

var pool: ObjectPool
var direction: Vector2 = Vector2.ZERO
var speed: float = 250.0
var damage: int = 10
var _lifetime: float = 0.0
var _max_lifetime: float = 2.0
var _released: bool = false

@onready var sprite: Sprite2D = $Sprite2D


class ImpactFlash extends Node2D:
	var _time: float = 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
		if _time > 0.15:
			queue_free()
	func _draw() -> void:
		var alpha: float = 1.0 - (_time / 0.15)
		var radius: float = 4.0 + _time * 40.0
		draw_circle(Vector2.ZERO, radius, Color(0.8, 0.9, 1.0, alpha * 0.6))


func set_pool(p: ObjectPool) -> void:
	pool = p


func reset() -> void:
	direction = Vector2.ZERO
	_lifetime = 0.0
	_released = false
	global_position = Vector2.ZERO
	monitoring = false
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.modulate = Color.WHITE


func activate(pos: Vector2, dir: Vector2, dmg: int) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	_lifetime = 0.0
	_released = false
	rotation = direction.angle()
	monitoring = true
	# Scale sprite based on damage — higher damage = visibly bigger bolt
	if sprite:
		var scale_factor: float = 1.0 + (damage - 10) * 0.05
		sprite.scale = Vector2.ONE * scale_factor
		# Tint toward bright white-blue for higher damage
		var brightness: float = clampf((damage - 10.0) / 30.0, 0.0, 1.0)
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.7, 0.85, 1.0, 1.0), brightness)


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
		_spawn_impact_flash(enemy as Node2D)
		_released = true
		set_deferred("monitoring", false)
		call_deferred("_release")


func _spawn_impact_flash(target: Node2D) -> void:
	var flash := ImpactFlash.new()
	flash.global_position = target.global_position
	get_tree().current_scene.add_child(flash)


func _release() -> void:
	if _released:
		return
	_released = true
	set_deferred("monitoring", false)
	if pool:
		pool.release(self)
	else:
		queue_free()
