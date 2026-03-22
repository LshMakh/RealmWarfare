extends Node2D

const ARENA_W: float = 800.0
const ARENA_H: float = 600.0
const HALF_W: float = 400.0
const HALF_H: float = 300.0
const TILE_SIZE: float = 32.0

const BASE_COLOR := Color(0.85, 0.82, 0.75)
const GRID_COLOR := Color(0.75, 0.72, 0.65, 0.35)
const MEDALLION_COLOR := Color(0.72, 0.58, 0.32, 0.25)
const MEDALLION_INNER_COLOR := Color(0.72, 0.58, 0.32, 0.15)
const PILLAR_COLOR := Color(0.78, 0.76, 0.72)
const PILLAR_SHADOW := Color(0.3, 0.28, 0.25, 0.3)
const EDGE_DARK := Color(0.1, 0.08, 0.06, 0.18)
const CLOUD_COLOR := Color(1.0, 1.0, 1.0, 0.06)

var _cloud_positions: Array[Vector2] = []
var _cloud_sizes: Array[Vector2] = []
var _cloud_speeds: Array[float] = []

func _ready() -> void:
	z_index = -10
	_init_clouds()

func _init_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(5):
		var x: float = rng.randf_range(-HALF_W, HALF_W)
		var y: float = rng.randf_range(-HALF_H, -HALF_H * 0.3)
		_cloud_positions.append(Vector2(x, y))
		_cloud_sizes.append(Vector2(rng.randf_range(60.0, 120.0), rng.randf_range(18.0, 35.0)))
		_cloud_speeds.append(rng.randf_range(4.0, 12.0))

var _redraw_counter: int = 0


func _process(delta: float) -> void:
	for i in range(_cloud_positions.size()):
		_cloud_positions[i].x += _cloud_speeds[i] * delta
		if _cloud_positions[i].x > HALF_W + 130.0:
			_cloud_positions[i].x = -HALF_W - 130.0
	_redraw_counter += 1
	if _redraw_counter >= 6:
		_redraw_counter = 0
		queue_redraw()

func _draw() -> void:
	_draw_base()
	_draw_grid()
	_draw_edge_darkening()
	_draw_medallion()
	_draw_pillars()
	_draw_clouds()

func _draw_base() -> void:
	draw_rect(Rect2(-HALF_W, -HALF_H, ARENA_W, ARENA_H), BASE_COLOR)

func _draw_grid() -> void:
	var x: float = -HALF_W
	while x <= HALF_W:
		draw_line(Vector2(x, -HALF_H), Vector2(x, HALF_H), GRID_COLOR, 1.0)
		x += TILE_SIZE
	var y: float = -HALF_H
	while y <= HALF_H:
		draw_line(Vector2(-HALF_W, y), Vector2(HALF_W, y), GRID_COLOR, 1.0)
		y += TILE_SIZE

func _draw_edge_darkening() -> void:
	var edge_w: float = 48.0
	# Top edge
	draw_rect(Rect2(-HALF_W, -HALF_H, ARENA_W, edge_w), EDGE_DARK)
	# Bottom edge
	draw_rect(Rect2(-HALF_W, HALF_H - edge_w, ARENA_W, edge_w), EDGE_DARK)
	# Left edge
	draw_rect(Rect2(-HALF_W, -HALF_H, edge_w, ARENA_H), EDGE_DARK)
	# Right edge
	draw_rect(Rect2(HALF_W - edge_w, -HALF_H, edge_w, ARENA_H), EDGE_DARK)

func _draw_medallion() -> void:
	var center := Vector2.ZERO
	# Outer ring
	draw_arc(center, 140.0, 0.0, TAU, 96, MEDALLION_COLOR, 3.0)
	# Inner ring
	draw_arc(center, 100.0, 0.0, TAU, 72, MEDALLION_INNER_COLOR, 2.0)
	# Inner filled circle for subtle warmth
	draw_circle(center, 60.0, Color(0.72, 0.58, 0.32, 0.06))
	# Small decorative cross lines inside medallion
	var tick_color := Color(0.72, 0.58, 0.32, 0.12)
	for angle_i in range(8):
		var angle: float = angle_i * TAU / 8.0
		var inner_pt := center + Vector2.from_angle(angle) * 105.0
		var outer_pt := center + Vector2.from_angle(angle) * 135.0
		draw_line(inner_pt, outer_pt, tick_color, 1.5)

func _draw_pillars() -> void:
	var pillar_radius: float = 10.0
	var shadow_offset := Vector2(3.0, 4.0)
	var margin: float = 50.0
	# Positions along the perimeter
	var positions: Array[Vector2] = [
		Vector2(-HALF_W + margin, -HALF_H + margin),
		Vector2(0.0, -HALF_H + margin),
		Vector2(HALF_W - margin, -HALF_H + margin),
		Vector2(-HALF_W + margin, 0.0),
		Vector2(HALF_W - margin, 0.0),
		Vector2(-HALF_W + margin, HALF_H - margin),
		Vector2(0.0, HALF_H - margin),
		Vector2(HALF_W - margin, HALF_H - margin),
		Vector2(-HALF_W + margin, -HALF_H * 0.5),
		Vector2(HALF_W - margin, -HALF_H * 0.5),
	]
	for pos in positions:
		# Shadow
		draw_circle(pos + shadow_offset, pillar_radius, PILLAR_SHADOW)
		# Pillar base
		draw_circle(pos, pillar_radius, PILLAR_COLOR)
		# Highlight
		draw_circle(pos + Vector2(-2.0, -2.0), pillar_radius * 0.5, Color(0.9, 0.88, 0.85, 0.6))

func _draw_clouds() -> void:
	for i in range(_cloud_positions.size()):
		var pos: Vector2 = _cloud_positions[i]
		var sz: Vector2 = _cloud_sizes[i]
		# Draw an ellipse using a scaled circle approach via draw_set_transform
		draw_set_transform(pos, 0.0, Vector2(sz.x / sz.y, 1.0))
		draw_circle(Vector2.ZERO, sz.y, CLOUD_COLOR)
	# Reset transform
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
