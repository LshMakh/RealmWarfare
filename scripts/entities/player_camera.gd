extends Camera2D


func _ready() -> void:
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
