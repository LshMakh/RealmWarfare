class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var pool_size: int = 50

var _available: Array[Node] = []
var _all: Array[Node] = []


func _ready() -> void:
	for i in range(pool_size):
		_create_instance()


func _create_instance() -> Node:
	var instance: Node = pooled_scene.instantiate()
	add_child(instance)
	instance.visible = false
	instance.set_process(false)
	instance.set_physics_process(false)
	_set_collisions_disabled(instance, true)
	if instance.has_method("set_pool"):
		instance.set_pool(self)
	_available.append(instance)
	_all.append(instance)
	return instance


func get_instance() -> Node:
	var instance: Node
	if _available.is_empty():
		instance = _create_instance()
		_available.erase(instance)
	else:
		instance = _available.pop_back()
	instance.visible = true
	instance.set_process(true)
	instance.set_physics_process(true)
	_set_collisions_disabled(instance, false)
	return instance


func release(instance: Node) -> void:
	instance.visible = false
	instance.set_process(false)
	instance.set_physics_process(false)
	_set_collisions_disabled(instance, true)
	if instance.has_method("reset"):
		instance.reset()
	_available.append(instance)


func _set_collisions_disabled(node: Node, disabled: bool) -> void:
	if node is Area2D:
		node.set_deferred("monitorable", not disabled)
		node.set_deferred("monitoring", not disabled)
	for child in node.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)
		if child.get_child_count() > 0:
			_set_collisions_disabled(child, disabled)


func active_count() -> int:
	return _all.size() - _available.size()
