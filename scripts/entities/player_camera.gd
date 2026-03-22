extends Camera2D

var _shake_strength: float = 0.0
var _shake_decay: float = 0.0


func _ready() -> void:
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	GameEvents.player_damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	if _shake_strength > 0.0:
		offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
		_shake_strength = max(_shake_strength - _shake_decay * delta, 0.0)
	else:
		offset = Vector2.ZERO


func shake(strength: float = 3.0, duration: float = 0.2) -> void:
	_shake_strength = strength
	_shake_decay = strength / duration


func _on_player_damaged(_amount: int) -> void:
	shake(4.0, 0.25)
