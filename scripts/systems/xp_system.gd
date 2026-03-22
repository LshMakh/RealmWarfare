class_name XPSystem
extends Node


func _ready() -> void:
	GameEvents.xp_collected.connect(_on_xp_collected)


func _on_xp_collected(amount: int) -> void:
	GameState.add_xp(amount)
