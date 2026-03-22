extends Node2D

@export var draw_color: Color = Color.WHITE
@export var glow_color: Color = Color.WHITE


func _draw() -> void:
	var parent: Node = get_parent()
	if parent and parent.data:
		draw_color = parent.data.color
		glow_color = parent.data.glow_color

	# Outer glow
	draw_circle(Vector2.ZERO, 8.0, Color(glow_color, 0.3))
	# Main circle
	draw_circle(Vector2.ZERO, 5.0, draw_color)
	# Inner highlight
	draw_circle(Vector2(-1.5, -1.5), 2.0, Color(1.0, 1.0, 1.0, 0.5))
