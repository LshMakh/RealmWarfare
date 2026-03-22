class_name ColumnManager
extends Node2D

@export var player: CharacterBody2D
@export var column_spacing: float = 200.0
@export var max_columns: int = 20
@export var recycle_distance: float = 800.0

## Collapse hazard settings
@export var collapse_damage: int = 25
@export var collapse_radius: float = 50.0
@export var collapse_telegraph_duration: float = 2.0

var _columns: Array[StaticBody2D] = []
var _occupied_cells: Dictionary = {}  # Vector2i -> StaticBody2D
var _current_wave: int = 0
var _collapse_timer: float = 0.0
var _viewport_size: Vector2 = Vector2(640.0, 360.0)

## Column visual dimensions
const COLUMN_WIDTH: float = 12.0
const COLUMN_HEIGHT: float = 24.0
const COLUMN_COLOR := Color(0.85, 0.82, 0.75)
const COLUMN_HIGHLIGHT := Color(0.92, 0.90, 0.86)
const COLUMN_SHADOW := Color(0.65, 0.62, 0.55)

## Obstacle physics layer (layer 4 = bit 3 = value 8)
const OBSTACLE_LAYER: int = 8


func _ready() -> void:
	GameEvents.wave_started.connect(_on_wave_started)
	_viewport_size = get_viewport_rect().size
	for i in max_columns:
		var col: StaticBody2D = _create_column()
		col.visible = false
		col.set_process(false)
		col.set_physics_process(false)
		add_child(col)
		# Disable collision until placed
		_set_column_collision(col, true)
		_columns.append(col)


func _create_column() -> StaticBody2D:
	var col: StaticBody2D = StaticBody2D.new()
	col.collision_layer = OBSTACLE_LAYER
	col.collision_mask = 0

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(COLUMN_WIDTH, COLUMN_HEIGHT)
	shape.shape = rect
	shape.disabled = true  # Start disabled, enabled when placed
	col.add_child(shape)

	# Create a marble-like placeholder sprite
	var img: Image = Image.create(int(COLUMN_WIDTH), int(COLUMN_HEIGHT), false, Image.FORMAT_RGBA8)
	# Base color fill
	img.fill(COLUMN_COLOR)
	# Left highlight strip (2px)
	for y in range(int(COLUMN_HEIGHT)):
		for x in range(2):
			img.set_pixel(x, y, COLUMN_HIGHLIGHT)
	# Right shadow strip (2px)
	for y in range(int(COLUMN_HEIGHT)):
		for x in range(int(COLUMN_WIDTH) - 2, int(COLUMN_WIDTH)):
			img.set_pixel(x, y, COLUMN_SHADOW)
	# Top cap (darker line)
	for x in range(int(COLUMN_WIDTH)):
		img.set_pixel(x, 0, COLUMN_SHADOW)
	# Bottom cap
	for x in range(int(COLUMN_WIDTH)):
		img.set_pixel(x, int(COLUMN_HEIGHT) - 1, COLUMN_SHADOW)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.name = "Sprite"
	col.add_child(sprite)

	return col


# --- Grid helpers ---

func _get_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / column_spacing)),
		int(floor(world_pos.y / column_spacing))
	)


func _cell_has_column(cell: Vector2i) -> bool:
	# Deterministic pseudo-random: ~33% of cells get columns
	var h: int = absi(hash(cell))
	return h % 3 == 0


func _cell_to_world(cell: Vector2i) -> Vector2:
	# Offset within the cell so columns don't sit on a perfect grid
	var h: int = hash(cell)
	var offset_x: float = fmod(absf(float(h & 0xFFFF)), column_spacing * 0.6)
	var offset_y: float = fmod(absf(float((h >> 16) & 0xFFFF)), column_spacing * 0.6)
	return Vector2(
		cell.x * column_spacing + offset_x,
		cell.y * column_spacing + offset_y
	)


# --- Main loop ---

func _process(delta: float) -> void:
	if not player:
		return
	_recycle_distant()
	_fill_nearby()
	_process_collapses(delta)


# --- Recycling ---

func _recycle_distant() -> void:
	var player_pos: Vector2 = player.global_position
	var cells_to_remove: Array[Vector2i] = []

	for cell: Vector2i in _occupied_cells:
		var col: StaticBody2D = _occupied_cells[cell] as StaticBody2D
		if not col:
			cells_to_remove.append(cell)
			continue
		var dist: float = col.global_position.distance_to(player_pos)
		if dist > recycle_distance:
			col.visible = false
			col.set_process(false)
			col.set_physics_process(false)
			# Disable collision shape
			_set_column_collision(col, true)
			cells_to_remove.append(cell)

	for cell: Vector2i in cells_to_remove:
		_occupied_cells.erase(cell)


func _fill_nearby() -> void:
	var player_pos: Vector2 = player.global_position
	var center_cell: Vector2i = _get_cell(player_pos)
	# How many cells to check in each direction (based on recycle distance)
	var cell_range: int = int(ceil(recycle_distance / column_spacing))

	for dx in range(-cell_range, cell_range + 1):
		for dy in range(-cell_range, cell_range + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)

			# Already has a column placed
			if _occupied_cells.has(cell):
				continue

			# Deterministic check: does this cell get a column?
			if not _cell_has_column(cell):
				continue

			var world_pos: Vector2 = _cell_to_world(cell)
			var dist: float = world_pos.distance_to(player_pos)

			# Only place columns within screen-ish range but outside a safe zone near center
			if dist > recycle_distance or dist < 60.0:
				continue

			# Find an available (hidden) column from the pool
			var col: StaticBody2D = _get_available_column()
			if not col:
				return  # No columns available

			col.global_position = world_pos
			col.visible = true
			col.set_process(true)
			col.set_physics_process(true)
			_set_column_collision(col, false)
			col.modulate = Color.WHITE
			col.scale = Vector2.ONE
			_occupied_cells[cell] = col


func _get_available_column() -> StaticBody2D:
	for col: StaticBody2D in _columns:
		if not col.visible:
			return col
	return null


func _set_column_collision(col: StaticBody2D, disabled: bool) -> void:
	# Enable or disable the collision shape
	var shape: CollisionShape2D = col.get_child(0) as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", disabled)


# --- Collapse hazard ---

func _on_wave_started(wave_number: int) -> void:
	_current_wave = wave_number
	# Reset collapse timer so first collapse doesn't fire immediately
	var interval: float = _get_collapse_interval()
	if interval > 0.0 and _collapse_timer <= 0.0:
		_collapse_timer = interval


func _get_collapse_interval() -> float:
	if _current_wave < 6:
		return -1.0
	if _current_wave <= 10:
		return 17.5
	if _current_wave <= 15:
		return 12.5
	return 8.5


func _process_collapses(delta: float) -> void:
	var interval: float = _get_collapse_interval()
	if interval < 0.0:
		return
	_collapse_timer -= delta
	if _collapse_timer <= 0.0:
		_collapse_timer = interval
		_collapse_nearest_column()


func _collapse_nearest_column() -> void:
	if not player:
		return

	var player_pos: Vector2 = player.global_position
	var best_col: StaticBody2D = null
	var best_dist: float = INF

	# Find the nearest visible column to the player (but not too close, min 40px)
	for cell: Vector2i in _occupied_cells:
		var col: StaticBody2D = _occupied_cells[cell] as StaticBody2D
		if not col or not col.visible:
			continue
		var dist: float = col.global_position.distance_to(player_pos)
		if dist > 40.0 and dist < best_dist:
			best_dist = dist
			best_col = col

	if not best_col:
		return

	# Telegraph: shake for 2 seconds, then collapse
	GameEvents.hazard_spawned.emit("column_collapse", best_col.global_position)
	_start_collapse_telegraph(best_col)


func _start_collapse_telegraph(col: StaticBody2D) -> void:
	# Shake the column as a telegraph warning
	var original_pos: Vector2 = col.global_position
	var tween: Tween = create_tween()

	# Shake phase: rapid small offsets over the telegraph duration
	var shake_steps: int = int(collapse_telegraph_duration / 0.05)
	for i in shake_steps:
		var shake_x: float = randf_range(-2.0, 2.0)
		var shake_y: float = randf_range(-1.0, 1.0)
		tween.tween_property(col, "global_position",
			original_pos + Vector2(shake_x, shake_y), 0.05)

	# Return to original then execute collapse
	tween.tween_property(col, "global_position", original_pos, 0.02)
	tween.tween_callback(_execute_collapse.bind(col, original_pos))


func _execute_collapse(col: StaticBody2D, collapse_pos: Vector2) -> void:
	if not col or not col.visible:
		return

	# Deal damage in the fall zone
	_deal_collapse_damage(collapse_pos)

	# Collapse visual: squash and fade
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(col, "scale", Vector2(1.5, 0.2), 0.3)
	tween.tween_property(col, "modulate:a", 0.0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(_finalize_collapse.bind(col))


func _deal_collapse_damage(pos: Vector2) -> void:
	# Damage everything in a radius: enemies and player
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = collapse_radius
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	# Check all physics layers (player layer 1, enemy layer 2)
	query.collision_mask = 1 | 2

	var results: Array[Dictionary] = space_state.intersect_shape(query, 32)
	for result: Dictionary in results:
		var body: Object = result.get("collider")
		if body and body is Node:
			var node: Node = body as Node
			# Try to find a HealthComponent on the node
			var health: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
			if health:
				health.take_damage(collapse_damage)


func _finalize_collapse(col: StaticBody2D) -> void:
	# Remove from tracking and hide for recycling
	for cell: Vector2i in _occupied_cells:
		if _occupied_cells[cell] == col:
			_occupied_cells.erase(cell)
			break
	col.visible = false
	col.set_process(false)
	col.set_physics_process(false)
	_set_column_collision(col, true)
	col.modulate = Color.WHITE
	col.scale = Vector2.ONE


# --- Public API for Minotaur interaction ---

func destroy_column(col: Node2D) -> void:
	if not col is StaticBody2D:
		return
	# Remove from tracking
	for cell: Vector2i in _occupied_cells:
		if _occupied_cells[cell] == col:
			_occupied_cells.erase(cell)
			break
	# Destruction visual
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(col, "scale", Vector2(1.3, 0.1), 0.2)
	tween.tween_property(col, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		col.visible = false
		col.set_process(false)
		col.set_physics_process(false)
		_set_column_collision(col, true)
		col.modulate = Color.WHITE
		col.scale = Vector2.ONE
	)
