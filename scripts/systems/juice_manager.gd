class_name JuiceManager
extends Node

var _last_slowmo_ticks: int = 0
const SLOWMO_COOLDOWN_MS: int = 1000
var _is_hitstop_active: bool = false


func hitstop(duration_ms: int = 40) -> void:
	if _is_hitstop_active:
		return
	_is_hitstop_active = true
	Engine.time_scale = 0.0
	# process_always=true so this timer fires even at time_scale 0
	get_tree().create_timer(float(duration_ms) / 1000.0, true, false, true).timeout.connect(
		func() -> void:
			Engine.time_scale = 1.0
			_is_hitstop_active = false
	)


func slowmo(duration_ms: int = 100, time_scale: float = 0.5) -> void:
	if _is_hitstop_active:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_slowmo_ticks < SLOWMO_COOLDOWN_MS:
		return
	_last_slowmo_ticks = now
	Engine.time_scale = time_scale
	get_tree().create_timer(float(duration_ms) / 1000.0, true, false, true).timeout.connect(
		func() -> void:
			if not _is_hitstop_active:
				Engine.time_scale = 1.0
	)


func screen_shake(intensity: float = 3.0, duration: float = 0.1) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var tween: Tween = camera.create_tween()
	var steps: int = maxi(int(duration / 0.02), 1)
	for i: int in steps:
		var offset: Vector2 = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", offset, 0.02)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.02)
