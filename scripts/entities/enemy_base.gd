class_name EnemyBase
extends CharacterBody2D

var data: EnemyData
var pool: ObjectPool
var _player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: HitboxComponent = $HitboxComponent


func _ready() -> void:
	add_to_group("enemies")
	health_component.died.connect(_on_died)


func set_pool(p: ObjectPool) -> void:
	pool = p


func initialize(enemy_data: EnemyData, player: Node2D) -> void:
	data = enemy_data
	_player = player
	health_component.max_health = data.max_health
	health_component.current_health = data.max_health
	hitbox.damage = data.damage
	if data.sprite_texture:
		sprite.texture = data.sprite_texture


func reset() -> void:
	data = null
	_player = null
	velocity = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	if not _player or not data:
		return
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * data.speed
	move_and_slide()
	sprite.flip_h = velocity.x < 0


func _on_died() -> void:
	GameEvents.enemy_killed.emit(global_position)
	if pool:
		pool.release(self)
	else:
		queue_free()
