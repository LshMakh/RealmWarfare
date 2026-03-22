class_name StateMachine
extends Node

@export var initial_state: State = null

@onready var state: State = initial_state if initial_state else get_child(0) as State


func _ready() -> void:
	for state_node: State in find_children("*", "State"):
		state_node.finished.connect(_transition_to)
	await owner.ready
	state.enter("")


func _unhandled_input(event: InputEvent) -> void:
	state.handle_input(event)


func _process(delta: float) -> void:
	state.update(delta)


func _physics_process(delta: float) -> void:
	state.physics_update(delta)


func _transition_to(target_path: String, data: Dictionary = {}) -> void:
	if not has_node(target_path):
		printerr(owner.name + ": State " + target_path + " does not exist.")
		return
	var prev := state.name
	state.exit()
	state = get_node(target_path)
	state.enter(prev, data)
