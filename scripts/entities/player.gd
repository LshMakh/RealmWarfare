extends CharacterBody2D

@export var speed: float = 120.0

var _joystick_direction: Vector2 = Vector2.ZERO

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	health_component.died.connect(_on_died)
	hurtbox.hit.connect(_on_hit)


func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joystick_direction != Vector2.ZERO:
		input_dir = _joystick_direction
	velocity = input_dir.normalized() * speed
	move_and_slide()
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0


func set_joystick_direction(direction: Vector2) -> void:
	_joystick_direction = direction


func _on_died() -> void:
	GameEvents.player_died.emit()


func _on_hit(_hitbox: HitboxComponent) -> void:
	var damage: int = _hitbox.damage
	GameEvents.player_damaged.emit(damage)
	_flash_hit()
	# Slowmo on big hits (>15% max HP)
	if damage > 0 and health_component.max_health > 0:
		var pct: float = float(damage) / float(health_component.max_health)
		if pct > 0.15 and has_node("/root/JuiceManager"):
			get_node("/root/JuiceManager").slowmo(100, 0.5)


func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
