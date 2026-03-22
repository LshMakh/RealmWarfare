class_name VirtualJoystick
extends Control

signal joystick_input(direction: Vector2)

@export var deadzone: float = 0.15
@export var clamp_zone: float = 75.0

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO

@onready var _base: TextureRect = $Base
@onready var _tip: TextureRect = $Tip


func _ready() -> void:
	_base.visible = false
	_tip.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			if _is_in_joystick_zone(event.position):
				_touch_index = event.index
				_center = event.position
				_base.global_position = _center - _base.size / 2.0
				_tip.global_position = _center - _tip.size / 2.0
				_base.visible = true
				_tip.visible = true
		elif not event.pressed and event.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			var diff: Vector2 = event.position - _center
			diff = diff.limit_length(clamp_zone)
			_tip.global_position = _center + diff - _tip.size / 2.0
			_output = diff / clamp_zone
			if _output.length() < deadzone:
				_output = Vector2.ZERO
			joystick_input.emit(_output)


func get_output() -> Vector2:
	return _output


func _is_in_joystick_zone(pos: Vector2) -> bool:
	return pos.x < get_viewport_rect().size.x * 0.4


func _reset() -> void:
	_touch_index = -1
	_output = Vector2.ZERO
	_base.visible = false
	_tip.visible = false
	joystick_input.emit(Vector2.ZERO)
