class_name BlessingManager
extends Node

@export var available_blessings: Array[BlessingData] = []
@export var choices_per_level: int = 3

var _active_blessings: Array[BlessingData] = []
var _player: Node2D

# Thunder Ring state
var _thunder_rings: Array[BlessingData] = []
var _thunder_ring_timers: Array[float] = []

# Storm Cloud state
var _storm_clouds: Array[BlessingData] = []
var _storm_cloud_timers: Array[float] = []

# Orbital state (Aegis Barrier)
var _orbitals: Array[Dictionary] = []  # {blessing, angle, node, hit_timer}


func _ready() -> void:
	GameEvents.level_up.connect(_on_level_up)
	GameEvents.blessing_chosen.connect(_on_blessing_chosen)


func set_player(player: Node2D) -> void:
	_player = player


func _process(delta: float) -> void:
	if not _player or not GameState.is_run_active:
		return

	_process_thunder_rings(delta)
	_process_storm_clouds(delta)
	_process_orbitals(delta)


# --- Thunder Ring (AURA, centered on player, periodic pulse) ---

func _process_thunder_rings(delta: float) -> void:
	for i in range(_thunder_rings.size()):
		_thunder_ring_timers[i] -= delta
		if _thunder_ring_timers[i] <= 0.0:
			_thunder_ring_timers[i] = _thunder_rings[i].cooldown
			_fire_thunder_ring(_thunder_rings[i])


func _fire_thunder_ring(blessing: BlessingData) -> void:
	# Deal damage to enemies in radius
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node2D in enemies:
		if not enemy.visible:
			continue
		var dist: float = _player.global_position.distance_to(enemy.global_position)
		if dist <= blessing.radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(blessing.damage)

	# Spawn ring visual
	_spawn_ring_effect(blessing.radius)


func _spawn_ring_effect(radius: float) -> void:
	var ring := ThunderRingEffect.new()
	ring.ring_radius = radius
	ring.global_position = _player.global_position
	_player.get_parent().add_child(ring)


# --- Storm Cloud (AURA, spawns at random nearby position) ---

func _process_storm_clouds(delta: float) -> void:
	for i in range(_storm_clouds.size()):
		_storm_cloud_timers[i] -= delta
		if _storm_cloud_timers[i] <= 0.0:
			_storm_cloud_timers[i] = _storm_clouds[i].cooldown
			_fire_storm_cloud(_storm_clouds[i])


func _fire_storm_cloud(blessing: BlessingData) -> void:
	var offset := Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
	var cloud_pos: Vector2 = _player.global_position + offset
	var cloud := StormCloudEffect.new()
	cloud.cloud_damage = blessing.damage
	cloud.cloud_radius = blessing.radius
	cloud.cloud_duration = blessing.duration
	cloud.global_position = cloud_pos
	_player.get_parent().add_child(cloud)


# --- Orbital (Aegis Barrier, rotating around player) ---

func _process_orbitals(delta: float) -> void:
	for entry: Dictionary in _orbitals:
		var blessing: BlessingData = entry["blessing"]
		entry["angle"] = fmod(entry["angle"] + delta * 3.0, TAU)
		var node: Node2D = entry["node"]
		if is_instance_valid(node):
			var orbit_pos := Vector2(cos(entry["angle"]), sin(entry["angle"])) * blessing.radius
			node.global_position = _player.global_position + orbit_pos

		# Periodic hit check
		entry["hit_timer"] = entry["hit_timer"] - delta
		if entry["hit_timer"] <= 0.0:
			entry["hit_timer"] = blessing.cooldown
			_orbital_hit(blessing, _player.global_position + Vector2(cos(entry["angle"]), sin(entry["angle"])) * blessing.radius)


func _orbital_hit(blessing: BlessingData, hit_pos: Vector2) -> void:
	var hit_radius: float = 16.0
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node2D in enemies:
		if not enemy.visible:
			continue
		var dist: float = hit_pos.distance_to(enemy.global_position)
		if dist <= hit_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(blessing.damage)


func _spawn_orbital_visual(blessing: BlessingData) -> Node2D:
	var orbital := AegisOrbitalEffect.new()
	_player.get_parent().add_child(orbital)
	return orbital


# --- Blessing selection ---

func _on_level_up(_new_level: int) -> void:
	var choices: Array = _pick_random_choices()
	GameEvents.show_level_up_ui.emit(choices)


func _on_blessing_chosen(blessing: BlessingData) -> void:
	_active_blessings.append(blessing)
	GameState.active_blessings = _active_blessings

	match blessing.effect_type:
		BlessingData.EffectType.AURA:
			if blessing.blessing_id == &"zeus_storm_cloud":
				_storm_clouds.append(blessing)
				_storm_cloud_timers.append(blessing.cooldown * 0.5)  # First one fires sooner
			else:
				# Thunder Ring
				_thunder_rings.append(blessing)
				_thunder_ring_timers.append(blessing.cooldown * 0.5)
		BlessingData.EffectType.ORBITAL:
			var node: Node2D = _spawn_orbital_visual(blessing)
			var angle: float = _orbitals.size() * (TAU / 3.0)  # Space orbitals evenly
			_orbitals.append({
				"blessing": blessing,
				"angle": angle,
				"node": node,
				"hit_timer": blessing.cooldown,
			})

	GameEvents.hide_level_up_ui.emit()


func _pick_random_choices() -> Array:
	# Collect active blessing IDs to filter duplicates
	var active_ids: Array[StringName] = []
	for b: BlessingData in _active_blessings:
		if b.blessing_id != &"":
			active_ids.append(b.blessing_id)

	# Build fresh pool excluding already-active blessings
	var pool: Array = []
	for b: BlessingData in available_blessings:
		if b.blessing_id not in active_ids:
			pool.append(b)

	var choices: Array = []
	# Draw from unique pool first
	var unique_pool: Array = pool.duplicate()
	for i in range(mini(choices_per_level, unique_pool.size())):
		var idx: int = randi() % unique_pool.size()
		choices.append(unique_pool[idx])
		unique_pool.remove_at(idx)

	# If not enough unique choices, fill remaining slots with upgrades
	if choices.size() < choices_per_level and _active_blessings.size() > 0:
		var upgrade_pool: Array = []
		for b: BlessingData in available_blessings:
			if b.blessing_id in active_ids:
				upgrade_pool.append(b)
		upgrade_pool.shuffle()
		for b: BlessingData in upgrade_pool:
			if choices.size() >= choices_per_level:
				break
			choices.append(b)

	return choices


func get_active_blessings() -> Array[BlessingData]:
	return _active_blessings


# =============================================================================
# Visual Effect Inner Classes
# =============================================================================

# Thunder Ring: expanding ring that fades out
class ThunderRingEffect extends Node2D:
	var ring_radius: float = 60.0
	var _current_radius: float = 0.0
	var _alpha: float = 1.0
	var _expand_speed: float = 200.0
	var _fade_speed: float = 3.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_current_radius += _expand_speed * delta
		_alpha -= _fade_speed * delta
		queue_redraw()
		if _alpha <= 0.0:
			queue_free()

	func _draw() -> void:
		var color := Color(0.4, 0.6, 1.0, _alpha)
		var ring_width: float = 3.0
		draw_arc(Vector2.ZERO, _current_radius, 0.0, TAU, 32, color, ring_width)
		# Inner glow
		var glow_color := Color(0.6, 0.8, 1.0, _alpha * 0.4)
		draw_arc(Vector2.ZERO, _current_radius * 0.9, 0.0, TAU, 32, glow_color, ring_width * 2.0)


# Storm Cloud: dark rectangle with lightning flashes, damages area over duration
class StormCloudEffect extends Node2D:
	var cloud_damage: int = 6
	var cloud_radius: float = 40.0
	var cloud_duration: float = 2.0
	var _time: float = 0.0
	var _flash_timer: float = 0.0
	var _flash_on: bool = false
	var _damage_timer: float = 0.0
	var _damage_interval: float = 0.5

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_time += delta
		_damage_timer -= delta
		_flash_timer -= delta

		# Periodic damage
		if _damage_timer <= 0.0:
			_damage_timer = _damage_interval
			_deal_area_damage()

		# Lightning flash
		if _flash_timer <= 0.0:
			_flash_timer = randf_range(0.15, 0.4)
			_flash_on = not _flash_on
			queue_redraw()

		# Fade out at end
		if _time >= cloud_duration:
			queue_free()
		else:
			queue_redraw()

	func _deal_area_damage() -> void:
		var enemies := get_tree().get_nodes_in_group("enemies")
		for enemy: Node2D in enemies:
			if not enemy.visible:
				continue
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= cloud_radius:
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(cloud_damage)

	func _draw() -> void:
		var remaining: float = cloud_duration - _time
		var alpha: float = clampf(remaining / 0.5, 0.0, 1.0)

		# Cloud shadow on ground
		var shadow_color := Color(0.2, 0.2, 0.3, 0.4 * alpha)
		draw_circle(Vector2.ZERO, cloud_radius, shadow_color)

		# Cloud body (above)
		var cloud_color := Color(0.3, 0.3, 0.5, 0.6 * alpha)
		draw_circle(Vector2(0, -20), cloud_radius * 0.7, cloud_color)
		draw_circle(Vector2(-12, -18), cloud_radius * 0.5, cloud_color)
		draw_circle(Vector2(12, -18), cloud_radius * 0.5, cloud_color)

		# Lightning flash
		if _flash_on:
			var flash_color := Color(0.8, 0.9, 1.0, 0.7 * alpha)
			# Jagged lightning bolt from cloud to ground
			var start := Vector2(randf_range(-8.0, 8.0), -15.0)
			var mid := Vector2(randf_range(-12.0, 12.0), -5.0)
			var end_pt := Vector2(randf_range(-6.0, 6.0), 5.0)
			draw_line(start, mid, flash_color, 2.0)
			draw_line(mid, end_pt, flash_color, 2.0)


# Aegis Barrier orbital: small glowing shield that orbits the player
class AegisOrbitalEffect extends Node2D:
	var _pulse_time: float = 0.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_pulse_time += delta * 4.0
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.8 + 0.2 * sin(_pulse_time)
		# Shield core
		var core_color := Color(0.3, 0.5, 1.0, 0.8 * pulse)
		draw_circle(Vector2.ZERO, 8.0, core_color)
		# Shield glow
		var glow_color := Color(0.5, 0.7, 1.0, 0.3 * pulse)
		draw_circle(Vector2.ZERO, 12.0, glow_color)
		# Shield edge arc
		var edge_color := Color(0.7, 0.85, 1.0, 0.6 * pulse)
		draw_arc(Vector2.ZERO, 10.0, -PI * 0.3, PI * 0.3, 8, edge_color, 2.0)
