class_name ActiveAbility
extends Node

@export var player: CharacterBody2D

var _blessing_manager: Node = null
var _is_active: bool = false


func set_blessing_manager(bm: Node) -> void:
	_blessing_manager = bm


# --- Activation ---

func activate() -> void:
	if _is_active:
		return
	if not GameState.use_ability():
		return  # Not fully charged (use_ability emits active_ability_used signal)

	_is_active = true

	# Hitstop on activation
	if has_node("/root/JuiceManager"):
		get_node("/root/JuiceManager").hitstop(120)
		get_node("/root/JuiceManager").screen_shake(5.0, 0.3)

	# Aegis Barrier: player invulnerable during 3s storm
	if _has_blessing(&"zeus_aegis_barrier") and player:
		_grant_player_invulnerability(3.2)

	# Initial knockback wave
	var knockback_force: float = 50.0
	# Thunder Ring: increased knockback force
	if _has_blessing(&"zeus_thunder_ring"):
		knockback_force = 100.0
	_knockback_all_enemies(knockback_force)

	# Lightning storm over 3 seconds
	_start_lightning_storm()


# --- Knockback wave ---

func _knockback_all_enemies(force: float) -> void:
	if not player:
		return
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and (enemy as Node2D).visible and enemy.has_method("apply_knockback"):
			var dir: Vector2 = player.global_position.direction_to((enemy as Node2D).global_position)
			enemy.apply_knockback(dir, force)


# --- Lightning storm ---

func _start_lightning_storm() -> void:
	var bolt_count: int = _get_bolt_count()
	var bolt_damage: int = _get_bolt_damage()
	var interval: float = 3.0 / float(bolt_count)

	for i: int in bolt_count:
		get_tree().create_timer(interval * float(i)).timeout.connect(
			func() -> void: _spawn_wrath_bolt(bolt_damage)
		)

	# End ability after storm
	get_tree().create_timer(3.2).timeout.connect(func() -> void: _is_active = false)


func _spawn_wrath_bolt(damage: int) -> void:
	if not player:
		return
	# Random position on screen around player
	var offset: Vector2 = Vector2(randf_range(-200.0, 200.0), randf_range(-150.0, 150.0))
	var pos: Vector2 = player.global_position + offset

	var hit_enemies: Array[Node2D] = []

	# Deal damage to enemies near the bolt
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and (enemy as Node2D).visible:
			var dist: float = pos.distance_to((enemy as Node2D).global_position)
			if dist < 50.0:
				var health: Node = enemy.get_node_or_null("HealthComponent")
				if health and health.has_method("take_damage"):
					health.take_damage(damage)
				# Stun briefly
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(0.3)
				hit_enemies.append(enemy as Node2D)

	# Chain Lightning: each bolt chains to 2 nearby enemies
	if _has_blessing(&"zeus_chain_lightning"):
		_chain_to_nearby(pos, damage, hit_enemies)

	# Storm Cloud: bolts leave lingering damage zones for 2s
	if _has_blessing(&"zeus_storm_cloud"):
		_spawn_lingering_zone(pos, damage)

	# Visual: brief flash at bolt position
	_spawn_bolt_visual(pos)


# --- Chain Lightning extension ---

func _chain_to_nearby(origin: Vector2, damage: int, already_hit: Array[Node2D]) -> void:
	var chain_damage: int = maxi(damage / 2, 1)
	var chains_remaining: int = 2

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if chains_remaining <= 0:
			break
		if enemy is Node2D and (enemy as Node2D).visible:
			var enemy_2d: Node2D = enemy as Node2D
			if already_hit.has(enemy_2d):
				continue
			var dist: float = origin.distance_to(enemy_2d.global_position)
			if dist < 100.0:
				var health: Node = enemy.get_node_or_null("HealthComponent")
				if health and health.has_method("take_damage"):
					health.take_damage(chain_damage)
				chains_remaining -= 1


# --- Storm Cloud lingering zone ---

func _spawn_lingering_zone(pos: Vector2, base_damage: int) -> void:
	var zone_dps: int = maxi(base_damage / 4, 1)
	var zone_duration: float = 2.0
	var zone_radius: float = 40.0
	var elapsed: float = 0.0
	var tick_interval: float = 0.5

	# Create a visual for the zone
	var visual: Node2D = Node2D.new()
	visual.global_position = pos
	visual.z_index = 5
	get_tree().current_scene.add_child(visual)

	var rect: ColorRect = ColorRect.new()
	rect.size = Vector2(zone_radius * 2.0, zone_radius * 2.0)
	rect.position = Vector2(-zone_radius, -zone_radius)
	rect.color = Color(0.8, 0.8, 0.2, 0.25)
	visual.add_child(rect)

	# Tick damage at intervals
	while elapsed < zone_duration:
		var timer: SceneTreeTimer = get_tree().create_timer(tick_interval)
		elapsed += tick_interval
		var current_elapsed: float = elapsed
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(visual):
				return
			for enemy: Node in get_tree().get_nodes_in_group("enemies"):
				if enemy is Node2D and (enemy as Node2D).visible:
					var dist: float = pos.distance_to((enemy as Node2D).global_position)
					if dist < zone_radius:
						var health: Node = enemy.get_node_or_null("HealthComponent")
						if health and health.has_method("take_damage"):
							health.take_damage(zone_dps)
			# Fade out on last tick
			if current_elapsed >= zone_duration:
				var fade_tween: Tween = visual.create_tween()
				fade_tween.tween_property(rect, "modulate:a", 0.0, 0.3)
				fade_tween.tween_callback(visual.queue_free)
		)


# --- Aegis Barrier invulnerability ---

func _grant_player_invulnerability(duration: float) -> void:
	if not player:
		return
	var hurtbox: Node = player.get_node_or_null("HurtboxComponent")
	if not hurtbox:
		return
	hurtbox._invincible = true
	hurtbox._invincibility_timer = duration
	# Also set the player-level timer for visual feedback
	if "_invincible_timer" in player:
		player._invincible_timer = duration


# --- Build scaling ---

func _get_bolt_count() -> int:
	var base: int = 12
	# Lightning Bolt: +3 bolts
	if _has_blessing(&"zeus_lightning_bolt"):
		base += 3
	return base


func _get_bolt_damage() -> int:
	var base: int = 40
	return base


func _has_blessing(bid: StringName) -> bool:
	return _blessing_manager != null and _blessing_manager.get_blessing_level(bid) > 0


# --- Bolt visual ---

func _spawn_bolt_visual(pos: Vector2) -> void:
	var visual: Node2D = Node2D.new()
	visual.global_position = pos
	visual.z_index = 50
	get_tree().current_scene.add_child(visual)
	# Draw a bright flash
	var rect: ColorRect = ColorRect.new()
	rect.size = Vector2(6.0, 40.0)
	rect.position = Vector2(-3.0, -20.0)
	rect.color = Color(1.0, 1.0, 0.8, 0.9)
	visual.add_child(rect)
	# Expand and fade
	var tween: Tween = visual.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(rect, "size:x", 12.0, 0.3)
	tween.tween_callback(visual.queue_free)
