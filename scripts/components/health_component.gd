class_name HealthComponent
extends Node

signal health_changed(new_health: int, max_health: int)
signal damage_received(amount: int)
signal died

@export var max_health: int = 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	damage_received.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
