extends Node2D

## Tiling marble-floor background that follows the player for an infinite feel.
## Draws a repeating tile pattern centered on the camera/player position.

const TILE_SIZE: float = 32.0
## How many tiles to draw around the camera in each direction
const TILE_RANGE: int = 12

const BASE_COLOR := Color(0.85, 0.82, 0.75)
const GRID_COLOR := Color(0.75, 0.72, 0.65, 0.35)
const MEDALLION_COLOR := Color(0.72, 0.58, 0.32, 0.25)
const MEDALLION_INNER_COLOR := Color(0.72, 0.58, 0.32, 0.15)
const CLOUD_COLOR := Color(1.0, 1.0, 1.0, 0.06)

var _cloud_offsets: Array[Vector2] = []
var _cloud_sizes: Array[Vector2] = []
var _cloud_speeds: Array[float] = []
var _cloud_time: float = 0.0

var _camera_pos: Vector2 = Vector2.ZERO
var _redraw_counter: int = 0


func _ready() -> void:
	z_index = -10
	_init_clouds()


func _init_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(8):
		_cloud_offsets.append(Vector2(
			rng.randf_range(-200.0, 200.0),
			rng.randf_range(-160.0, -40.0)
		))
		_cloud_sizes.append(Vector2(
			rng.randf_range(60.0, 120.0),
			rng.randf_range(18.0, 35.0)
		))
		_cloud_speeds.append(rng.randf_range(4.0, 12.0))


func _process(delta: float) -> void:
	_cloud_time += delta

	# Track camera position for drawing
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		_camera_pos = camera.global_position

	_redraw_counter += 1
	if _redraw_counter >= 6:
		_redraw_counter = 0
		queue_redraw()


func _draw() -> void:
	_draw_tiled_base()
	_draw_tiled_grid()
	_draw_medallion()
	_draw_clouds()


func _draw_tiled_base() -> void:
	# Draw a large rect centered on camera, big enough to fill the viewport + buffer
	var half_extent: float = TILE_RANGE * TILE_SIZE
	var rect := Rect2(
		_camera_pos.x - half_extent,
		_camera_pos.y - half_extent,
		half_extent * 2.0,
		half_extent * 2.0
	)
	draw_rect(rect, BASE_COLOR)


func _draw_tiled_grid() -> void:
	# Calculate the grid-aligned start position
	var half_extent: float = TILE_RANGE * TILE_SIZE
	var start_x: float = floor((_camera_pos.x - half_extent) / TILE_SIZE) * TILE_SIZE
	var start_y: float = floor((_camera_pos.y - half_extent) / TILE_SIZE) * TILE_SIZE
	var end_x: float = _camera_pos.x + half_extent
	var end_y: float = _camera_pos.y + half_extent

	# Vertical lines
	var x: float = start_x
	while x <= end_x:
		draw_line(
			Vector2(x, _camera_pos.y - half_extent),
			Vector2(x, _camera_pos.y + half_extent),
			GRID_COLOR, 1.0
		)
		x += TILE_SIZE

	# Horizontal lines
	var y: float = start_y
	while y <= end_y:
		draw_line(
			Vector2(_camera_pos.x - half_extent, y),
			Vector2(_camera_pos.x + half_extent, y),
			GRID_COLOR, 1.0
		)
		y += TILE_SIZE


func _draw_medallion() -> void:
	# Draw the medallion at world origin (0,0) — only visible when near spawn
	var center := Vector2.ZERO
	var dist_to_camera: float = center.distance_to(_camera_pos)
	if dist_to_camera > 500.0:
		return  # Too far away, skip drawing

	# Outer ring
	draw_arc(center, 140.0, 0.0, TAU, 96, MEDALLION_COLOR, 3.0)
	# Inner ring
	draw_arc(center, 100.0, 0.0, TAU, 72, MEDALLION_INNER_COLOR, 2.0)
	# Inner filled circle
	draw_circle(center, 60.0, Color(0.72, 0.58, 0.32, 0.06))
	# Decorative tick marks
	var tick_color := Color(0.72, 0.58, 0.32, 0.12)
	for angle_i in range(8):
		var angle: float = angle_i * TAU / 8.0
		var inner_pt := center + Vector2.from_angle(angle) * 105.0
		var outer_pt := center + Vector2.from_angle(angle) * 135.0
		draw_line(inner_pt, outer_pt, tick_color, 1.5)


func _draw_clouds() -> void:
	# Clouds scroll relative to camera position for ambient effect
	for i in range(_cloud_offsets.size()):
		var base_offset: Vector2 = _cloud_offsets[i]
		var speed: float = _cloud_speeds[i]
		var sz: Vector2 = _cloud_sizes[i]

		# Clouds move over time and follow the camera loosely
		var cloud_x: float = _camera_pos.x + base_offset.x + speed * _cloud_time
		# Wrap clouds horizontally within a range around the camera
		var wrap_range: float = 400.0
		cloud_x = _camera_pos.x + fmod(cloud_x - _camera_pos.x + wrap_range, wrap_range * 2.0) - wrap_range

		var cloud_y: float = _camera_pos.y + base_offset.y
		var pos := Vector2(cloud_x, cloud_y)

		draw_set_transform(pos, 0.0, Vector2(sz.x / sz.y, 1.0))
		draw_circle(Vector2.ZERO, sz.y, CLOUD_COLOR)

	# Reset transform
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
