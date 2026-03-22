class_name AutoAttack
extends Node

@export var projectile_pool: ObjectPool
@export var attack_cooldown: float = 0.8
@export var base_damage: int = 10
@export var attack_range: float = 200.0

var _cooldown_timer: float = 0.0
var _player: Node2D


func _ready() -> void:
	_player = get_parent()


func _process(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_fire_at(target)
			_cooldown_timer = attack_cooldown


func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy: Node2D in enemies:
		if not enemy.visible:
			continue
		var dist: float = _player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest


func _fire_at(target: Node2D) -> void:
	if not projectile_pool:
		return
	var proj: Node = projectile_pool.get_instance()
	if proj and proj.has_method("activate"):
		var direction := _player.global_position.direction_to(target.global_position)
		proj.activate(_player.global_position, direction, base_damage)
