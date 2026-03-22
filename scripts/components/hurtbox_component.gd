class_name HurtboxComponent
extends Area2D

signal hit(hitbox: HitboxComponent)

@export var health: HealthComponent

var _invincible: bool = false
var _invincibility_timer: float = 0.0
@export var invincibility_duration: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _invincible:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			_invincible = false


func _on_area_entered(area: Area2D) -> void:
	if _invincible:
		return
	if area is HitboxComponent:
		var hitbox := area as HitboxComponent
		if health:
			health.take_damage(hitbox.damage)
		hit.emit(hitbox)
		if invincibility_duration > 0.0:
			_invincible = true
			_invincibility_timer = invincibility_duration
