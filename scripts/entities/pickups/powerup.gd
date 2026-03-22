extends Area2D

var data: PickupData
var _bob_time: float = 0.0
var _visual: Node2D


func initialize(pickup_data: PickupData, pos: Vector2) -> void:
	data = pickup_data
	global_position = pos
	_visual = $Visual
	_visual.queue_redraw()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_visual = $Visual


func _process(delta: float) -> void:
	_bob_time += delta * 3.0
	if _visual:
		_visual.position.y = sin(_bob_time) * 2.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not data:
		queue_free()
		return

	match data.effect_type:
		PickupData.EffectType.HEAL:
			_apply_heal(body)
		PickupData.EffectType.MAGNET:
			_apply_magnet()
		PickupData.EffectType.BOMB:
			_apply_bomb()

	GameEvents.powerup_collected.emit(data, global_position)
	queue_free()


func _apply_heal(player: Node2D) -> void:
	var health_comp: HealthComponent = player.health_component
	if health_comp:
		var heal_amount: int = int(health_comp.max_health * data.value)
		health_comp.heal(heal_amount)
	_flash_player(player, Color(0.2, 1.0, 0.2, 1.0))


func _apply_magnet() -> void:
	GameState.magnet_active = true
	# Create a timer in the scene tree to expire the effect
	# Connect to a lambda so it works after this node is freed
	var duration: float = data.value
	get_tree().create_timer(duration).timeout.connect(
		func() -> void: GameState.magnet_active = false
	)


func _apply_bomb() -> void:
	var damage: int = int(data.value)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var health_comp: HealthComponent = enemy.get_node_or_null("HealthComponent")
		if health_comp:
			health_comp.take_damage(damage)
	_screen_flash()


func _flash_player(player: Node2D, color: Color) -> void:
	var sprite: Node = player.get_node_or_null("Sprite2D")
	if not sprite:
		return
	var tween := player.create_tween()
	tween.tween_property(sprite, "modulate", color, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _screen_flash() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().current_scene.add_child(canvas_layer)

	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 0.9, 0.7)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(canvas_layer.queue_free)
