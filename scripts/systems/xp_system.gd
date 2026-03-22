class_name XPSystem
extends Node


func _ready() -> void:
	GameEvents.xp_collected.connect(_on_xp_collected)


func _on_xp_collected(amount: int) -> void:
	var boosted: int = roundi(float(amount) * (1.0 + GameState.xp_bonus))
	GameState.add_xp(boosted)
