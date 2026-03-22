class_name EnemyBase
extends CharacterBody2D

var data: EnemyData
var pool: ObjectPool
var _player: Node2D = null
var _dying: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

const DamageNumber := preload("res://scripts/effects/damage_number.gd")


func _ready() -> void:
	add_to_group("enemies")
	health_component.died.connect(_on_died)
	hurtbox.hit.connect(_on_hit)
	hurtbox.health = health_component


func set_pool(p: ObjectPool) -> void:
	pool = p


func initialize(enemy_data: EnemyData, player: Node2D) -> void:
	data = enemy_data
	_player = player
	_dying = false
	health_component.max_health = data.max_health
	health_component.current_health = data.max_health
	hitbox.damage = data.damage
	modulate = Color.WHITE
	scale = Vector2.ONE
	if data.sprite_texture:
		sprite.texture = data.sprite_texture


func reset() -> void:
	data = null
	_player = null
	_dying = false
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	scale = Vector2.ONE
	sprite.modulate = Color.WHITE


func _physics_process(_delta: float) -> void:
	if not _player or not data or _dying:
		return
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * data.speed
	move_and_slide()
	sprite.flip_h = velocity.x < 0


func _on_hit(from_hitbox: HitboxComponent) -> void:
	_flash_hit()
	_spawn_damage_number(from_hitbox.damage)


func _flash_hit() -> void:
	if _dying:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)


func _spawn_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	var label := Label.new()
	label.set_script(DamageNumber)
	get_tree().current_scene.add_child(label)
	label.show_number(global_position, amount)


func _on_died() -> void:
	if _dying:
		return
	_dying = true
	# Disable collisions immediately so enemy stops dealing/taking damage
	hurtbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	velocity = Vector2.ZERO
	# Play death effect then release
	call_deferred("_play_death_effect")


func _play_death_effect() -> void:
	GameEvents.enemy_killed.emit(global_position)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_handle_death)


func _handle_death() -> void:
	if pool:
		pool.release(self)
	else:
		queue_free()
