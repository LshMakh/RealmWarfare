extends CharacterBody2D

@export var speed: float = 120.0

var _joystick_direction: Vector2 = Vector2.ZERO

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var sprite: Sprite2D = $Sprite2D

# --- Petrification ---
var _petrification: float = 0.0
var _petrify_root_timer: float = 0.0
var _petrified_this_frame: bool = false
const PETRIFY_RATE: float = 0.67  # reaches 1.0 in ~1.5s
const PETRIFY_DECAY: float = 0.5  # decays at 50%/s when not in beam

# --- Invincibility (level-up flash) ---
var _invincible_timer: float = 0.0

# --- Hit flash ---
var _flash_tween: Tween = null


func _ready() -> void:
	add_to_group("player")
	health_component.died.connect(_on_died)
	hurtbox.hit.connect(_on_hit)
	GameEvents.level_up.connect(_on_level_up)


func _physics_process(delta: float) -> void:
	# --- Petrification decay (only when not actively being petrified) ---
	if _petrified_this_frame:
		_petrified_this_frame = false
	else:
		_petrification = maxf(_petrification - PETRIFY_DECAY * delta, 0.0)

	# --- Root timer decay ---
	_petrify_root_timer = maxf(_petrify_root_timer - delta, 0.0)

	# --- Invincibility timer decay ---
	if _invincible_timer > 0.0:
		_invincible_timer = maxf(_invincible_timer - delta, 0.0)
		if _invincible_timer <= 0.0:
			hurtbox._invincible = false

	# --- Movement ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joystick_direction != Vector2.ZERO:
		input_dir = _joystick_direction
	velocity = input_dir.normalized() * speed * _get_speed_multiplier()
	move_and_slide()
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	# --- Petrification visual (only when not flashing from a hit) ---
	if not _is_flash_active():
		_update_petrification_visual()


func set_joystick_direction(direction: Vector2) -> void:
	_joystick_direction = direction


# --- Petrification ---

func apply_petrification(delta: float) -> void:
	_petrified_this_frame = true
	_petrification = minf(_petrification + PETRIFY_RATE * delta, 1.0)
	if _petrification >= 1.0:
		_petrify_root_timer = 1.0
		_petrification = 0.0


func _get_speed_multiplier() -> float:
	if _petrify_root_timer > 0.0:
		return 0.0
	return 1.0 - _petrification


func _update_petrification_visual() -> void:
	if _petrify_root_timer > 0.0:
		# Fully rooted — grey stone tint
		sprite.modulate = Color(0.5, 0.5, 0.55, 1.0)
	elif _petrification > 0.0:
		# Partially petrified — blend toward stone
		var p: float = _petrification
		sprite.modulate = Color(1.0 - p * 0.5, 1.0 - p * 0.5, 1.0 - p * 0.3, 1.0)
	else:
		sprite.modulate = Color.WHITE


# --- Level-up flash + invincibility ---

func _on_level_up(_new_level: int) -> void:
	_invincible_timer = 0.5
	hurtbox._invincible = true
	hurtbox._invincibility_timer = 0.5
	_spawn_power_flash()
	_knockback_nearby_enemies()


func _spawn_power_flash() -> void:
	# White flash on the sprite, then back to normal
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	# Screen shake for impact
	if has_node("/root/JuiceManager"):
		get_node("/root/JuiceManager").screen_shake(3.0, 0.15)


func _knockback_nearby_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D:
			var enemy_node: Node2D = enemy as Node2D
			var dist: float = global_position.distance_to(enemy_node.global_position)
			if dist < 150.0 and enemy.has_method("apply_knockback"):
				var dir: Vector2 = global_position.direction_to(enemy_node.global_position)
				enemy.apply_knockback(dir, 100.0)


# --- Damage handling ---

func _on_died() -> void:
	GameEvents.player_died.emit()


func _on_hit(hitbox: HitboxComponent) -> void:
	var damage: int = hitbox.damage
	GameEvents.player_damaged.emit(damage)
	_flash_hit()
	# Directional damage indicator
	_show_damage_direction(hitbox)
	# Slowmo on big hits (>15% max HP)
	if damage > 0 and health_component.max_health > 0:
		var pct: float = float(damage) / float(health_component.max_health)
		if pct > 0.15 and has_node("/root/JuiceManager"):
			get_node("/root/JuiceManager").slowmo(100, 0.5)


func _flash_hit() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _is_flash_active() -> bool:
	return _flash_tween != null and _flash_tween.is_running()


# --- Directional damage indicator ---

func _show_damage_direction(hitbox: HitboxComponent) -> void:
	var source_pos: Vector2 = hitbox.global_position
	var dir: Vector2 = (source_pos - global_position).normalized()
	# Create a colored panel on the screen edge closest to the damage source
	var indicator: ColorRect = ColorRect.new()
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.color = Color(1.0, 0.1, 0.1, 0.4)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	# Size and position based on direction
	var thickness: float = 16.0
	if absf(dir.x) > absf(dir.y):
		# Horizontal — left or right edge
		indicator.size = Vector2(thickness, viewport_size.y)
		if dir.x > 0:
			indicator.position = Vector2(viewport_size.x - thickness, 0.0)
		else:
			indicator.position = Vector2(0.0, 0.0)
	else:
		# Vertical — top or bottom edge
		indicator.size = Vector2(viewport_size.x, thickness)
		if dir.y > 0:
			indicator.position = Vector2(0.0, viewport_size.y - thickness)
		else:
			indicator.position = Vector2(0.0, 0.0)
	# Add to CanvasLayer so it stays in screen space
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	canvas_layer.add_child(indicator)
	# Fade out and cleanup
	var tween: Tween = indicator.create_tween()
	tween.tween_property(indicator, "color:a", 0.0, 0.3)
	tween.tween_callback(canvas_layer.queue_free)
