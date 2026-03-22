class_name AutoAttack
extends Node

@export var projectile_pool: ObjectPool
@export var attack_cooldown: float = 0.8
@export var base_damage: int = 10
@export var attack_range: float = 200.0

var _cooldown_timer: float = 0.0
var _player: Node2D
var _blessing_manager: Node = null


func _ready() -> void:
	_player = get_parent()


func set_blessing_manager(bm: Node) -> void:
	_blessing_manager = bm


func _process(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer > 0.0:
		return

	var bolt_damage: int = base_damage
	var bolt_cooldown: float = attack_cooldown

	if _blessing_manager:
		var bolt_level: int = _blessing_manager.get_blessing_level(&"zeus_lightning_bolt")
		if bolt_level > 0:
			var bolt_data: BlessingData = _blessing_manager.get_blessing_data(&"zeus_lightning_bolt")
			if bolt_data:
				bolt_damage = bolt_data.get_stat(bolt_level, "damage", base_damage) as int
				var cd_reduction: float = bolt_data.get_stat(bolt_level, "cooldown_reduction", 0.0) as float
				bolt_cooldown = maxf(attack_cooldown - cd_reduction, 0.15)

	_cooldown_timer = bolt_cooldown

	var target: Node2D = _find_nearest_enemy()
	if target:
		_fire_at(target, bolt_damage)


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


func _fire_at(target: Node2D, damage: int) -> void:
	if not projectile_pool:
		return
	var dir: Vector2 = _player.global_position.direction_to(target.global_position)
	var proj: Node = projectile_pool.get_instance()
	if proj and proj.has_method("activate"):
		proj.activate(_player.global_position, dir, damage)
