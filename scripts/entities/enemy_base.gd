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

# --- Behavior state ---
var _behavior_time: float = 0.0

# Zigzag (Harpy)
const ZIGZAG_AMPLITUDE := 30.0
const ZIGZAG_FREQUENCY := 6.0

# Tank Slam (Cyclops)
enum SlamPhase { CHASING, TELEGRAPH, SLAMMING }
var _slam_phase: SlamPhase = SlamPhase.CHASING
var _slam_timer: float = 0.0
const SLAM_CHASE_INTERVAL := 3.0
const SLAM_TELEGRAPH_DURATION := 1.0
const SLAM_RADIUS := 50.0
const SLAM_DAMAGE := 25
var _slam_indicator: Node2D = null

# Charger (Minotaur)
enum ChargePhase { APPROACHING, WINDING_UP, CHARGING, STUNNED }
var _charge_phase: ChargePhase = ChargePhase.APPROACHING
var _charge_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO
const CHARGE_TRIGGER_DISTANCE := 120.0
const CHARGE_WINDUP_DURATION := 0.4
const CHARGE_DURATION := 0.5
const CHARGE_STUN_DURATION := 0.8
const CHARGE_SPEED_MULTIPLIER := 3.0

# Boss (Cerberus)
var _boss_phase: int = 0
var _boss_speed_multiplier: float = 1.0
var _boss_direction: Vector2 = Vector2.RIGHT
var _fire_breath_timer: float = 0.0
var _fire_breath_cooldown: float = 1.5
var _fire_breath_active: bool = false
var _fire_breath_elapsed: float = 0.0
const FIRE_BREATH_DURATION := 0.6
var _fire_breath_angle: float = PI / 4.0
const FIRE_BREATH_RANGE := 80.0
var _telegraph_active: bool = false
var _telegraph_elapsed: float = 0.0
const TELEGRAPH_DURATION := 0.5
var _aoe_pulse_timer: float = 0.0
const AOE_PULSE_COOLDOWN := 0.8
var _aoe_pulse_active: bool = false
var _aoe_pulse_elapsed: float = 0.0
const AOE_PULSE_DURATION := 0.3
const AOE_PULSE_RADIUS := 60.0
var _minion_spawn_timer: float = 0.0
var _boss_damage_dealt_this_pulse: bool = false


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
	# Reset behavior state
	_behavior_time = 0.0
	_slam_phase = SlamPhase.CHASING
	_slam_timer = 0.0
	_charge_phase = ChargePhase.APPROACHING
	_charge_timer = 0.0
	_charge_direction = Vector2.ZERO
	if _slam_indicator:
		_slam_indicator.queue_free()
		_slam_indicator = null
	# Boss initialization
	_boss_phase = 0
	_fire_breath_timer = 0.0
	_fire_breath_active = false
	_telegraph_active = false
	_aoe_pulse_active = false
	_aoe_pulse_timer = 0.0
	_minion_spawn_timer = 0.0
	_boss_speed_multiplier = 1.0
	_boss_direction = Vector2.RIGHT
	_fire_breath_angle = PI / 4.0
	_fire_breath_cooldown = 1.5
	_boss_damage_dealt_this_pulse = false
	if data.is_boss:
		scale = Vector2(1.8, 1.8)
		_boss_phase = 1
		_fire_breath_timer = 2.0
		_minion_spawn_timer = 5.0
		health_component.health_changed.connect(_on_boss_health_changed)


func reset() -> void:
	# Disconnect boss signal before clearing data
	if data and data.is_boss and health_component.health_changed.is_connected(_on_boss_health_changed):
		health_component.health_changed.disconnect(_on_boss_health_changed)
	data = null
	_player = null
	_dying = false
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	_behavior_time = 0.0
	_slam_phase = SlamPhase.CHASING
	_slam_timer = 0.0
	_charge_phase = ChargePhase.APPROACHING
	_charge_timer = 0.0
	_charge_direction = Vector2.ZERO
	if _slam_indicator:
		_slam_indicator.queue_free()
		_slam_indicator = null
	_boss_phase = 0
	_fire_breath_active = false
	_telegraph_active = false
	_aoe_pulse_active = false
	_boss_damage_dealt_this_pulse = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _player or not data or _dying:
		return
	_behavior_time += delta
	match data.behavior_type:
		EnemyData.BehaviorType.CHASE:
			_behavior_chase()
		EnemyData.BehaviorType.ZIGZAG:
			_behavior_zigzag()
		EnemyData.BehaviorType.TANK_SLAM:
			_behavior_tank_slam(delta)
		EnemyData.BehaviorType.CHARGER:
			_behavior_charger(delta)
		EnemyData.BehaviorType.BOSS:
			_behavior_boss(delta)
			return  # Boss handles its own move_and_slide
	move_and_slide()
	sprite.flip_h = velocity.x < 0


func _behavior_chase() -> void:
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * data.speed


func _behavior_zigzag() -> void:
	var direction := global_position.direction_to(_player.global_position)
	var perpendicular := Vector2(-direction.y, direction.x)
	var offset := sin(_behavior_time * ZIGZAG_FREQUENCY) * ZIGZAG_AMPLITUDE
	velocity = (direction * data.speed) + (perpendicular * offset)


func _behavior_tank_slam(delta: float) -> void:
	match _slam_phase:
		SlamPhase.CHASING:
			var direction := global_position.direction_to(_player.global_position)
			velocity = direction * data.speed
			_slam_timer += delta
			if _slam_timer >= SLAM_CHASE_INTERVAL:
				_slam_timer = 0.0
				_slam_phase = SlamPhase.TELEGRAPH
				velocity = Vector2.ZERO
				_show_slam_telegraph()
		SlamPhase.TELEGRAPH:
			velocity = Vector2.ZERO
			_slam_timer += delta
			if _slam_timer >= SLAM_TELEGRAPH_DURATION:
				_slam_timer = 0.0
				_slam_phase = SlamPhase.SLAMMING
				_execute_slam()
		SlamPhase.SLAMMING:
			velocity = Vector2.ZERO
			_slam_timer += delta
			if _slam_timer >= 0.2:
				_slam_timer = 0.0
				_slam_phase = SlamPhase.CHASING


func _show_slam_telegraph() -> void:
	# Draw a red circle that grows during telegraph
	if _slam_indicator:
		_slam_indicator.queue_free()
	_slam_indicator = Node2D.new()
	_slam_indicator.z_index = -1
	add_child(_slam_indicator)
	_slam_indicator.set_meta("radius", SLAM_RADIUS)
	_slam_indicator.draw.connect(_draw_slam_indicator)
	_slam_indicator.queue_redraw()
	# Animate the indicator growing
	_slam_indicator.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(_slam_indicator, "scale", Vector2.ONE, SLAM_TELEGRAPH_DURATION)
	# Flash the sprite to telegraph the slam
	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(1.5, 0.3, 0.3, 1), 0.15)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	flash_tween.set_loops(3)


func _draw_slam_indicator() -> void:
	if _slam_indicator:
		var radius: float = _slam_indicator.get_meta("radius", SLAM_RADIUS)
		_slam_indicator.draw_circle(Vector2.ZERO, radius, Color(1, 0, 0, 0.25))
		_slam_indicator.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0, 0, 0.6), 1.5)


func _execute_slam() -> void:
	# Remove telegraph indicator
	if _slam_indicator:
		_slam_indicator.queue_free()
		_slam_indicator = null
	# Brief visual flash on slam impact
	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(1.5, 0.3, 0.3, 1), 0.05)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	# Damage the player if within slam radius
	if _player and global_position.distance_to(_player.global_position) <= SLAM_RADIUS:
		var player_health: HealthComponent = _player.get_node_or_null("HealthComponent")
		if player_health:
			player_health.take_damage(SLAM_DAMAGE)
	# Spawn a brief visual effect ring
	_spawn_slam_ring()


func _spawn_slam_ring() -> void:
	var ring := Node2D.new()
	ring.global_position = global_position
	ring.z_index = -1
	get_tree().current_scene.add_child(ring)
	ring.set_meta("radius", SLAM_RADIUS)
	ring.draw.connect(func() -> void:
		var r: float = ring.get_meta("radius", SLAM_RADIUS)
		ring.draw_circle(Vector2.ZERO, r, Color(1, 0.2, 0.2, 0.3))
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 0, 0, 0.8), 2.0)
	)
	ring.queue_redraw()
	var tween := ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)


func _behavior_charger(delta: float) -> void:
	match _charge_phase:
		ChargePhase.APPROACHING:
			var direction := global_position.direction_to(_player.global_position)
			velocity = direction * data.speed
			var dist := global_position.distance_to(_player.global_position)
			if dist <= CHARGE_TRIGGER_DISTANCE:
				_charge_phase = ChargePhase.WINDING_UP
				_charge_timer = 0.0
				_charge_direction = direction
				velocity = Vector2.ZERO
				# Wind-up visual: enemy flashes and braces
				var tween := create_tween()
				tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5, 1), 0.1)
				tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.3, 1), 0.1)
				tween.set_loops(2)
		ChargePhase.WINDING_UP:
			velocity = Vector2.ZERO
			_charge_timer += delta
			if _charge_timer >= CHARGE_WINDUP_DURATION:
				_charge_phase = ChargePhase.CHARGING
				_charge_timer = 0.0
				# Lock direction and charge
				velocity = _charge_direction * data.speed * CHARGE_SPEED_MULTIPLIER
				sprite.modulate = Color(1.5, 0.8, 0.5, 1)
		ChargePhase.CHARGING:
			# Keep charging in the locked direction (no tracking)
			velocity = _charge_direction * data.speed * CHARGE_SPEED_MULTIPLIER
			_charge_timer += delta
			if _charge_timer >= CHARGE_DURATION:
				_charge_phase = ChargePhase.STUNNED
				_charge_timer = 0.0
				velocity = Vector2.ZERO
				sprite.modulate = Color(0.6, 0.6, 0.8, 1)
		ChargePhase.STUNNED:
			velocity = Vector2.ZERO
			_charge_timer += delta
			if _charge_timer >= CHARGE_STUN_DURATION:
				_charge_phase = ChargePhase.APPROACHING
				_charge_timer = 0.0
				sprite.modulate = Color.WHITE


# --- Boss behavior ---

func _behavior_boss(delta: float) -> void:
	_boss_direction = global_position.direction_to(_player.global_position)

	if _telegraph_active:
		velocity = Vector2.ZERO
		_telegraph_elapsed += delta
		var flash := absf(sin(_telegraph_elapsed * 16.0))
		sprite.modulate = Color(1.0, 0.6 * flash + 0.4, 0.2 * flash, 1.0)
		if _telegraph_elapsed >= TELEGRAPH_DURATION:
			_telegraph_active = false
			sprite.modulate = _boss_base_color()
			_start_fire_breath()
	elif _fire_breath_active:
		velocity = Vector2.ZERO
		_fire_breath_elapsed += delta
		_deal_fire_breath_damage()
		queue_redraw()
		if _fire_breath_elapsed >= FIRE_BREATH_DURATION:
			_fire_breath_active = false
			_fire_breath_timer = _fire_breath_cooldown
			queue_redraw()
	else:
		velocity = _boss_direction * data.speed * _boss_speed_multiplier
		move_and_slide()
		sprite.flip_h = velocity.x < 0

	# Fire breath cooldown (phases 1 and 2)
	if not _fire_breath_active and not _telegraph_active and _boss_phase <= 2:
		_fire_breath_timer -= delta
		if _fire_breath_timer <= 0.0:
			_telegraph_active = true
			_telegraph_elapsed = 0.0

	# Phase 2+: minion spawn hint
	if _boss_phase >= 2:
		_minion_spawn_timer -= delta
		if _minion_spawn_timer <= 0.0:
			_minion_spawn_timer = 5.0
			GameEvents.enemy_killed.emit(global_position)

	# Phase 3: AoE pulse
	if _boss_phase >= 3:
		if not _aoe_pulse_active:
			_aoe_pulse_timer -= delta
			if _aoe_pulse_timer <= 0.0:
				_aoe_pulse_active = true
				_aoe_pulse_elapsed = 0.0
				_boss_damage_dealt_this_pulse = false
				queue_redraw()
		else:
			_aoe_pulse_elapsed += delta
			_deal_aoe_pulse_damage()
			queue_redraw()
			if _aoe_pulse_elapsed >= AOE_PULSE_DURATION:
				_aoe_pulse_active = false
				_aoe_pulse_timer = AOE_PULSE_COOLDOWN
				queue_redraw()


func _boss_base_color() -> Color:
	if _boss_phase >= 3:
		return Color(1.4, 0.4, 0.4, 1.0)
	return Color.WHITE


func _on_boss_health_changed(_new_health: int, _max_health: int) -> void:
	if not data or not data.is_boss or _dying:
		return
	var hp_pct := float(health_component.current_health) / float(health_component.max_health)
	var old_phase := _boss_phase
	if hp_pct <= 0.25:
		_boss_phase = 3
	elif hp_pct <= 0.50:
		_boss_phase = 2
	else:
		_boss_phase = 1
	if _boss_phase != old_phase:
		_on_boss_phase_changed()


func _on_boss_phase_changed() -> void:
	match _boss_phase:
		2:
			_boss_speed_multiplier = 1.5
			_fire_breath_angle = PI / 3.0
			_fire_breath_cooldown = 1.2
		3:
			_boss_speed_multiplier = 2.0
			sprite.modulate = Color(1.4, 0.4, 0.4, 1.0)
			_aoe_pulse_timer = 0.3
			_fire_breath_active = false
			_telegraph_active = false


func _start_fire_breath() -> void:
	_fire_breath_active = true
	_fire_breath_elapsed = 0.0
	queue_redraw()


func _deal_fire_breath_damage() -> void:
	if not _player:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > FIRE_BREATH_RANGE:
		return
	var to_player := global_position.direction_to(_player.global_position)
	var angle_to_player := _boss_direction.angle_to(to_player)
	if absf(angle_to_player) <= _fire_breath_angle:
		var player_health: HealthComponent = _player.get_node_or_null("HealthComponent")
		if player_health:
			player_health.take_damage(data.damage)
			GameEvents.player_damaged.emit(data.damage)


func _deal_aoe_pulse_damage() -> void:
	if not _player or _boss_damage_dealt_this_pulse:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= AOE_PULSE_RADIUS:
		var player_health: HealthComponent = _player.get_node_or_null("HealthComponent")
		if player_health:
			var pulse_damage := int(data.damage * 0.5)
			player_health.take_damage(pulse_damage)
			GameEvents.player_damaged.emit(pulse_damage)
			_boss_damage_dealt_this_pulse = true


func _draw() -> void:
	if not data or not data.is_boss or _dying:
		return
	# Fire breath cone visual
	if _fire_breath_active:
		var progress := _fire_breath_elapsed / FIRE_BREATH_DURATION
		var alpha := 0.6 * (1.0 - progress)
		var color := Color(1.0, 0.5, 0.1, alpha)
		var center_angle := _boss_direction.angle()
		var r := FIRE_BREATH_RANGE * progress
		draw_arc(Vector2.ZERO, r, center_angle - _fire_breath_angle,
			center_angle + _fire_breath_angle, 16, color, r * 0.4)
		var inner_color := Color(1.0, 0.8, 0.2, alpha * 0.8)
		draw_arc(Vector2.ZERO, r * 0.5, center_angle - _fire_breath_angle * 0.6,
			center_angle + _fire_breath_angle * 0.6, 12, inner_color, r * 0.2)
	# AoE pulse ring visual
	if _aoe_pulse_active:
		var progress := _aoe_pulse_elapsed / AOE_PULSE_DURATION
		var radius := AOE_PULSE_RADIUS * progress
		var alpha := 0.4 * (1.0 - progress)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.15, 0.1, alpha), 3.0)
		draw_arc(Vector2.ZERO, radius * 0.6, 0, TAU, 24, Color(1.0, 0.3, 0.2, alpha * 0.5), 5.0)


func _on_hit(from_hitbox: HitboxComponent) -> void:
	_flash_hit()
	_spawn_damage_number(from_hitbox.damage)


func _flash_hit() -> void:
	if _dying:
		return
	var restore_color := Color.WHITE
	if data and data.is_boss:
		restore_color = _boss_base_color()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", restore_color, 0.05)


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
	# Clean up behavior visuals
	if _slam_indicator:
		_slam_indicator.queue_free()
		_slam_indicator = null
	_fire_breath_active = false
	_aoe_pulse_active = false
	_telegraph_active = false
	queue_redraw()
	# Play death effect then release
	if data and data.is_boss:
		call_deferred("_play_boss_death_effect")
	else:
		call_deferred("_play_death_effect")


func _play_death_effect() -> void:
	GameEvents.enemy_killed.emit(global_position)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_handle_death)


func _play_boss_death_effect() -> void:
	GameEvents.enemy_killed.emit(global_position)
	GameEvents.boss_died.emit(global_position)
	# White flash
	sprite.modulate = Color(10, 10, 10, 1)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(_boss_screen_shake)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0).set_delay(0.2)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 1.0).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_handle_death)


func _boss_screen_shake() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var shake_tween := create_tween()
	shake_tween.tween_property(camera, "offset", Vector2(8, -6), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2(-6, 8), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2(6, -4), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2(-4, 4), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2(2, -2), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func _handle_death() -> void:
	if pool:
		pool.release(self)
	else:
		queue_free()
