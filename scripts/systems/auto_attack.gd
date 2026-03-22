class_name AutoAttack
extends Node

@export var projectile_pool: ObjectPool
@export var attack_cooldown: float = 0.8
@export var base_damage: int = 10
@export var attack_range: float = 200.0

var _cooldown_timer: float = 0.0
var _player: Node2D
var _bonus_damage: int = 0
var _bonus_projectiles: int = 0
var _cooldown_reduction: float = 0.0


func _ready() -> void:
	_player = get_parent()
	GameEvents.blessing_chosen.connect(_on_blessing_chosen)


func _process(delta: float) -> void:
	var effective_cooldown: float = max(attack_cooldown - _cooldown_reduction, 0.15)
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_fire_at(target)
			_cooldown_timer = effective_cooldown


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
	var total_damage: int = base_damage + _bonus_damage
	var total_projectiles: int = 1 + _bonus_projectiles
	var base_dir := _player.global_position.direction_to(target.global_position)

	for i in range(total_projectiles):
		var proj: Node = projectile_pool.get_instance()
		if proj and proj.has_method("activate"):
			var spread: float = 0.0
			if total_projectiles > 1:
				# Spread projectiles in a fan pattern
				spread = deg_to_rad(15.0) * (i - (total_projectiles - 1) / 2.0)
			var dir := base_dir.rotated(spread)
			proj.activate(_player.global_position, dir, total_damage)


func _on_blessing_chosen(blessing: BlessingData) -> void:
	if blessing.effect_type == BlessingData.EffectType.PROJECTILE:
		_bonus_damage += blessing.damage
		_bonus_projectiles += blessing.projectile_count - 1
		_cooldown_reduction += 0.15
