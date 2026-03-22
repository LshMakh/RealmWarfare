extends Label


func show_number(pos: Vector2, amount: int) -> void:
	global_position = pos + Vector2(randf_range(-8, 8), -10)
	text = str(amount)
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	z_index = 100

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", global_position + Vector2(0, -24), 0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
