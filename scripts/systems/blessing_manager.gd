class_name BlessingManager
extends Node

@export var available_blessings: Array[BlessingData] = []
@export var choices_per_level: int = 3

# Level-based tracking
var _blessing_levels: Dictionary = {}   # StringName -> int (1-5)
var _blessing_data: Dictionary = {}     # StringName -> BlessingData
var _blessing_timers: Dictionary = {}   # StringName -> float (cooldown countdown)

var _player: Node2D

# Orbital state (Aegis Barrier) — visual nodes that orbit the player
var _orbitals: Array[Dictionary] = []  # [{node, angle, hit_timer}, ...]


func _ready() -> void:
	GameEvents.level_up.connect(_on_level_up)
	GameEvents.blessing_chosen.connect(_on_blessing_chosen)
	GameEvents.run_started.connect(_on_run_started)


func set_player(player: Node2D) -> void:
	_player = player


func _on_run_started() -> void:
	_blessing_levels.clear()
	_blessing_data.clear()
	_blessing_timers.clear()
	# Clear any active orbital visual nodes
	for entry: Dictionary in _orbitals:
		var node: Node2D = entry["node"]
		if is_instance_valid(node):
			node.queue_free()
	_orbitals.clear()


func _process(delta: float) -> void:
	if not _player or not GameState.is_run_active:
		return

	_process_thunder_rings(delta)
	_process_storm_clouds(delta)
	_process_orbitals(delta)


# --- Thunder Ring (AURA, centered on player, periodic pulse) ---

func _process_thunder_rings(delta: float) -> void:
	var bid: StringName = &"zeus_thunder_ring"
	if not _blessing_levels.has(bid):
		return
	var level: int = _blessing_levels[bid]
	var data: BlessingData = _blessing_data[bid]
	var cooldown: float = data.get_stat(level, "cooldown", 1.5) as float

	_blessing_timers[bid] = _blessing_timers.get(bid, 0.0) - delta
	if _blessing_timers[bid] <= 0.0:
		_blessing_timers[bid] = cooldown
		_fire_thunder_ring(data, level)


func _fire_thunder_ring(data: BlessingData, level: int) -> void:
	var damage: int = data.get_stat(level, "damage", 8) as int
	var radius: float = data.get_stat(level, "radius", 60.0) as float
	var knockback: float = data.get_stat(level, "knockback", 0.0) as float
	var pulses: int = data.get_stat(level, "pulses", 1) as int

	for pulse_idx in range(pulses):
		# Stagger pulses slightly if more than one
		if pulse_idx == 0:
			_execute_thunder_pulse(damage, radius, knockback)
		else:
			# Delay subsequent pulses by 0.15s each
			get_tree().create_timer(0.15 * pulse_idx).timeout.connect(
				_execute_thunder_pulse.bind(damage, radius, knockback)
			)


func _execute_thunder_pulse(damage: int, radius: float, knockback: float) -> void:
	if not is_instance_valid(_player):
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node2D in enemies:
		if not enemy.visible:
			continue
		var dist: float = _player.global_position.distance_to(enemy.global_position)
		if dist <= radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(damage)
			# Apply knockback if > 0
			if knockback > 0.0 and enemy is CharacterBody2D:
				var dir: Vector2 = (enemy.global_position - _player.global_position).normalized()
				enemy.velocity += dir * knockback

	# Spawn ring visual
	_spawn_ring_effect(radius)


func _spawn_ring_effect(radius: float) -> void:
	var ring := ThunderRingEffect.new()
	ring.ring_radius = radius
	ring.global_position = _player.global_position
	_player.get_parent().add_child(ring)


# --- Storm Cloud (AURA, spawns at random nearby position) ---

func _process_storm_clouds(delta: float) -> void:
	var bid: StringName = &"zeus_storm_cloud"
	if not _blessing_levels.has(bid):
		return
	var level: int = _blessing_levels[bid]
	var data: BlessingData = _blessing_data[bid]
	var cooldown: float = data.get_stat(level, "cooldown", 3.0) as float

	_blessing_timers[bid] = _blessing_timers.get(bid, 0.0) - delta
	if _blessing_timers[bid] <= 0.0:
		_blessing_timers[bid] = cooldown
		_fire_storm_cloud(data, level)


func _fire_storm_cloud(data: BlessingData, level: int) -> void:
	var damage: int = data.get_stat(level, "damage", 6) as int
	var cloud_count: int = data.get_stat(level, "clouds", 1) as int
	var radius: float = data.get_stat(level, "radius", 35.0) as float
	var duration: float = data.get_stat(level, "duration", 1.5) as float

	for i in range(cloud_count):
		# Spawn at random position 40-100px from player
		var angle := randf() * TAU
		var dist := randf_range(40.0, 100.0)
		var offset := Vector2(cos(angle), sin(angle)) * dist
		var cloud_pos: Vector2 = _player.global_position + offset
		var cloud := StormCloudEffect.new()
		cloud.cloud_damage = damage
		cloud.cloud_radius = radius
		cloud.cloud_duration = duration
		cloud.global_position = cloud_pos
		_player.get_parent().add_child(cloud)


# --- Orbital (Aegis Barrier, rotating around player) ---

func _process_orbitals(delta: float) -> void:
	var bid: StringName = &"zeus_aegis_barrier"
	if not _blessing_levels.has(bid):
		return
	var level: int = _blessing_levels[bid]
	var data: BlessingData = _blessing_data[bid]
	var rotation_speed: float = data.get_stat(level, "rotation_speed", 2.1) as float
	var orbit_radius: float = data.get_stat(level, "orbit_radius", 45.0) as float
	var hit_cooldown: float = data.get_stat(level, "hit_cooldown", 1.0) as float
	var damage: int = data.get_stat(level, "damage", 6) as int

	for entry: Dictionary in _orbitals:
		entry["angle"] = fmod(entry["angle"] + delta * rotation_speed, TAU)
		var node: Node2D = entry["node"]
		if is_instance_valid(node):
			var orbit_pos := Vector2(cos(entry["angle"]), sin(entry["angle"])) * orbit_radius
			node.global_position = _player.global_position + orbit_pos

		# Periodic hit check
		entry["hit_timer"] = entry["hit_timer"] - delta
		if entry["hit_timer"] <= 0.0:
			entry["hit_timer"] = hit_cooldown
			var hit_pos: Vector2 = _player.global_position + Vector2(cos(entry["angle"]), sin(entry["angle"])) * orbit_radius
			_orbital_hit(damage, hit_pos)


func _orbital_hit(damage: int, hit_pos: Vector2) -> void:
	var hit_radius: float = 20.0
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node2D in enemies:
		if not enemy.visible:
			continue
		var dist: float = hit_pos.distance_to(enemy.global_position)
		if dist <= hit_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(damage)
				# Hit flash on enemy
				var orig_mod: Color = enemy.modulate
				enemy.modulate = Color(0.5, 0.7, 1.0, 1.0)
				get_tree().create_timer(0.1).timeout.connect(func() -> void:
					if is_instance_valid(enemy):
						enemy.modulate = orig_mod
				)
			# Spawn hit spark at contact point
			_spawn_orbital_hit_spark(hit_pos)


func _spawn_orbital_hit_spark(pos: Vector2) -> void:
	var spark := AegisHitSpark.new()
	spark.global_position = pos
	_player.get_parent().add_child(spark)


func _spawn_orbital_visual() -> Node2D:
	var orbital := AegisOrbitalEffect.new()
	_player.get_parent().add_child(orbital)
	return orbital


# --- Blessing selection ---

func _on_level_up(_new_level: int) -> void:
	var choices: Array = _pick_random_choices()
	GameEvents.show_level_up_ui.emit(choices)


func _on_blessing_chosen(blessing: Resource) -> void:
	var data: BlessingData = blessing as BlessingData
	if not data:
		return
	var bid: StringName = data.blessing_id

	if _blessing_levels.has(bid):
		# Upgrade existing blessing
		_blessing_levels[bid] = mini(_blessing_levels[bid] + 1, data.max_level)
		_on_blessing_upgraded(data, _blessing_levels[bid])
	else:
		# New blessing
		_blessing_levels[bid] = 1
		_blessing_data[bid] = data
		_blessing_timers[bid] = 0.0
		_activate_blessing(data)

	# Update GameState for UI tracking
	GameState.active_blessings = _get_active_blessings_list()
	GameEvents.hide_level_up_ui.emit()


func _activate_blessing(data: BlessingData) -> void:
	# Called only when a NEW blessing is first acquired (level 1).
	# Set up initial persistent visual/state for ORBITAL types.
	match data.effect_type:
		BlessingData.EffectType.ORBITAL:
			var shields: int = data.get_stat(1, "shields", 2) as int
			for i in range(shields):
				var node: Node2D = _spawn_orbital_visual()
				var angle: float = float(i) * (TAU / float(shields))
				_orbitals.append({
					"node": node,
					"angle": angle,
					"hit_timer": data.get_stat(1, "hit_cooldown", 1.0) as float,
				})
		BlessingData.EffectType.AURA:
			# Timer already set to 0.0 so first tick fires quickly
			pass


func _on_blessing_upgraded(data: BlessingData, new_level: int) -> void:
	# Handle upgrade side effects for specific blessing types.
	if data.effect_type == BlessingData.EffectType.ORBITAL:
		# Adjust orbital count to match new level's shield count
		var target_shields: int = data.get_stat(new_level, "shields", 2) as int
		# Add new orbitals if needed
		while _orbitals.size() < target_shields:
			var node: Node2D = _spawn_orbital_visual()
			_orbitals.append({
				"node": node,
				"angle": 0.0,
				"hit_timer": data.get_stat(new_level, "hit_cooldown", 1.0) as float,
			})
		# Remove excess orbitals if needed (unlikely but safe)
		while _orbitals.size() > target_shields:
			var entry: Dictionary = _orbitals.pop_back()
			var node: Node2D = entry["node"]
			if is_instance_valid(node):
				node.queue_free()
		# Redistribute all orbitals evenly
		var total: int = _orbitals.size()
		for idx in range(total):
			_orbitals[idx]["angle"] = float(idx) * (TAU / float(total))


func _pick_random_choices() -> Array:
	var pool: Array = []

	# Add owned blessings that aren't maxed as upgrade options
	for bid: StringName in _blessing_levels:
		if _blessing_levels[bid] < _blessing_data[bid].max_level:
			pool.append(_blessing_data[bid])

	# Add unowned blessings as new options
	for blessing: BlessingData in available_blessings:
		if not _blessing_levels.has(blessing.blessing_id):
			pool.append(blessing)

	# Shuffle and pick up to choices_per_level
	pool.shuffle()
	return pool.slice(0, mini(choices_per_level, pool.size()))


# --- Getters ---

func get_blessing_level(bid: StringName) -> int:
	return _blessing_levels.get(bid, 0)


func get_blessing_data(bid: StringName) -> BlessingData:
	return _blessing_data.get(bid, null) as BlessingData


func get_active_blessing_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for bid: StringName in _blessing_levels:
		ids.append(bid)
	return ids


func get_active_blessings() -> Array[BlessingData]:
	return _get_active_blessings_list()


func _get_active_blessings_list() -> Array[BlessingData]:
	var result: Array[BlessingData] = []
	for bid: StringName in _blessing_data:
		result.append(_blessing_data[bid])
	return result


# =============================================================================
# Visual Effect Inner Classes
# =============================================================================

# Thunder Ring: expanding ring — bright electric blue pulse, unmissable
class ThunderRingEffect extends Node2D:
	var ring_radius: float = 60.0
	var _current_radius: float = 0.0
	var _alpha: float = 1.0
	var _expand_speed: float = 160.0
	var _flash_alpha: float = 0.5

	func _ready() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		_current_radius += _expand_speed * delta
		# Fade faster as the ring expands past the damage radius
		var fade_speed: float = lerpf(1.2, 2.5, clampf(_current_radius / (ring_radius * 1.5), 0.0, 1.0))
		_alpha -= fade_speed * delta
		_flash_alpha -= 4.0 * delta
		queue_redraw()
		if _alpha <= 0.0:
			queue_free()

	func _draw() -> void:
		# Bright flash fill at the center when ring first fires
		if _flash_alpha > 0.0:
			var flash_color := Color(0.7, 0.85, 1.0, _flash_alpha * 0.35)
			draw_circle(Vector2.ZERO, _current_radius * 0.7, flash_color)

		# Outer ring — bright electric blue, thick
		var color := Color(0.3, 0.7, 1.0, _alpha)
		draw_arc(Vector2.ZERO, _current_radius, 0.0, TAU, 64, color, 5.0)

		# Bright white-blue core line for electric pop
		var core_color := Color(0.8, 0.9, 1.0, _alpha * 0.9)
		draw_arc(Vector2.ZERO, _current_radius, 0.0, TAU, 64, core_color, 2.0)

		# Inner glow ring — wider, softer
		var glow_color := Color(0.4, 0.7, 1.0, _alpha * 0.5)
		draw_arc(Vector2.ZERO, _current_radius * 0.85, 0.0, TAU, 64, glow_color, 8.0)

		# Faint outer halo
		if _current_radius > 10.0:
			var halo_color := Color(0.5, 0.8, 1.0, _alpha * 0.2)
			draw_arc(Vector2.ZERO, _current_radius * 1.1, 0.0, TAU, 64, halo_color, 3.0)


# Storm Cloud: dramatic dark cloud with bright lightning, damages area over duration
class StormCloudEffect extends Node2D:
	var cloud_damage: int = 6
	var cloud_radius: float = 40.0
	var cloud_duration: float = 2.0
	var _time: float = 0.0
	var _flash_timer: float = 0.0
	var _flash_on: bool = false
	var _flash_intensity: float = 0.0
	var _damage_timer: float = 0.0
	var _damage_interval: float = 0.5
	# Stored lightning bolt segments so they persist across frames during a flash
	var _bolt_segments: Array = []  # Array of arrays: [[Vector2, ...], ...]

	func _ready() -> void:
		z_index = 5
		# Deal damage immediately on spawn
		_damage_timer = 0.0
		# Start with a bright flash
		_flash_on = true
		_flash_intensity = 1.0
		_flash_timer = 0.2
		_generate_bolts()

	func _process(delta: float) -> void:
		_time += delta
		_damage_timer -= delta
		_flash_timer -= delta

		# Periodic damage
		if _damage_timer <= 0.0:
			_damage_timer = _damage_interval
			_deal_area_damage()

		# Lightning flash cycling
		if _flash_timer <= 0.0:
			if _flash_on:
				_flash_on = false
				_flash_timer = randf_range(0.1, 0.25)
				_flash_intensity = 0.0
			else:
				_flash_on = true
				_flash_intensity = randf_range(0.8, 1.0)
				_flash_timer = randf_range(0.08, 0.2)
				_generate_bolts()

		# Fade flash intensity during a flash
		if _flash_on:
			_flash_intensity = maxf(_flash_intensity - delta * 2.0, 0.3)

		# Expire
		if _time >= cloud_duration:
			queue_free()

		queue_redraw()

	func _generate_bolts() -> void:
		_bolt_segments.clear()
		var bolt_count: int = randi_range(2, 4)
		var vis_r: float = cloud_radius * 1.5
		for i in range(bolt_count):
			var bolt: Array = []
			# Start from inside cloud body
			var sx: float = randf_range(-vis_r * 0.4, vis_r * 0.4)
			var sy: float = randf_range(-vis_r * 0.6, -vis_r * 0.3)
			bolt.append(Vector2(sx, sy))
			# 2-3 jagged intermediate points
			var segs: int = randi_range(2, 3)
			var prev_x: float = sx
			for j in range(segs):
				var t: float = float(j + 1) / float(segs + 1)
				var jx: float = prev_x + randf_range(-cloud_radius * 0.4, cloud_radius * 0.4)
				var jy: float = lerpf(sy, cloud_radius * 0.3, t) + randf_range(-5.0, 5.0)
				bolt.append(Vector2(jx, jy))
				prev_x = jx
			# End near ground
			bolt.append(Vector2(prev_x + randf_range(-8.0, 8.0), randf_range(cloud_radius * 0.1, cloud_radius * 0.4)))
			_bolt_segments.append(bolt)

	func _deal_area_damage() -> void:
		var enemies := get_tree().get_nodes_in_group("enemies")
		for enemy: Node2D in enemies:
			if not enemy.visible:
				continue
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= cloud_radius:
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(cloud_damage)
					# Flash enemy white briefly on hit
					var orig_mod: Color = enemy.modulate
					enemy.modulate = Color(2.0, 2.0, 2.0, 1.0)
					get_tree().create_timer(0.08).timeout.connect(func() -> void:
						if is_instance_valid(enemy):
							enemy.modulate = orig_mod
					)

	func _draw() -> void:
		var remaining: float = cloud_duration - _time
		var alpha: float = clampf(remaining / 0.5, 0.0, 1.0)
		# Quick fade-in
		var fade_in: float = clampf(_time / 0.15, 0.0, 1.0)
		alpha *= fade_in
		var vis_r: float = cloud_radius * 1.8

		# --- Damage zone on ground ---
		var zone_color := Color(0.15, 0.1, 0.3, 0.35 * alpha)
		draw_circle(Vector2.ZERO, cloud_radius, zone_color)
		var zone_edge := Color(0.4, 0.3, 0.7, 0.5 * alpha)
		draw_arc(Vector2.ZERO, cloud_radius, 0.0, TAU, 48, zone_edge, 1.5)

		# --- Cloud body (large, dark, dramatic) ---
		var cloud_y: float = -vis_r * 0.35
		var dark := Color(0.15, 0.12, 0.25, 0.85 * alpha)
		var mid_dark := Color(0.2, 0.18, 0.35, 0.75 * alpha)
		# Main mass — overlapping circles for puffy shape
		draw_circle(Vector2(0, cloud_y), vis_r * 0.5, dark)
		draw_circle(Vector2(-vis_r * 0.35, cloud_y + 4), vis_r * 0.38, dark)
		draw_circle(Vector2(vis_r * 0.35, cloud_y + 4), vis_r * 0.38, dark)
		draw_circle(Vector2(vis_r * 0.1, cloud_y - vis_r * 0.18), vis_r * 0.3, mid_dark)
		draw_circle(Vector2(-vis_r * 0.15, cloud_y + vis_r * 0.15), vis_r * 0.35, dark)
		draw_circle(Vector2(vis_r * 0.15, cloud_y + vis_r * 0.15), vis_r * 0.35, dark)

		# Cloud lights up during lightning
		if _flash_on:
			var lit := Color(0.5, 0.45, 0.7, 0.4 * _flash_intensity * alpha)
			draw_circle(Vector2(0, cloud_y), vis_r * 0.45, lit)

		# --- Lightning bolts ---
		if _flash_on and _bolt_segments.size() > 0:
			for bolt: Array in _bolt_segments:
				if bolt.size() < 2:
					continue
				var core_color := Color(1.0, 1.0, 1.0, _flash_intensity * alpha)
				var glow_color := Color(0.7, 0.8, 1.0, _flash_intensity * 0.6 * alpha)
				for k in range(bolt.size() - 1):
					var from: Vector2 = bolt[k]
					var to: Vector2 = bolt[k + 1]
					draw_line(from, to, glow_color, 5.0)
					draw_line(from, to, core_color, 2.5)

			# Ground impact flash at bolt tips
			for bolt: Array in _bolt_segments:
				if bolt.size() > 0:
					var tip: Vector2 = bolt[bolt.size() - 1]
					var impact := Color(0.8, 0.85, 1.0, 0.5 * _flash_intensity * alpha)
					draw_circle(tip, 6.0, impact)


# Aegis Barrier orbital: bright glowing shield that orbits the player with trail
class AegisOrbitalEffect extends Node2D:
	var _pulse_time: float = 0.0
	var _trail: Array[Vector2] = []
	var _trail_timer: float = 0.0
	const TRAIL_LENGTH: int = 6
	const TRAIL_INTERVAL: float = 0.03

	func _ready() -> void:
		z_index = 10

	var _redraw_skip: int = 0

	func _process(delta: float) -> void:
		_pulse_time += delta * 5.0
		_redraw_skip += 1
		if _redraw_skip >= 3:
			_redraw_skip = 0
			queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.7 + 0.3 * sin(_pulse_time)
		# Glow
		draw_circle(Vector2.ZERO, 14.0, Color(0.4, 0.6, 1.0, 0.25 * pulse))
		# Core
		draw_circle(Vector2.ZERO, 8.0, Color(0.6, 0.8, 1.0, 0.9 * pulse))
		# Center
		draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.92, 1.0, pulse))


# Hit spark effect when orbital strikes an enemy
class AegisHitSpark extends Node2D:
	var _time: float = 0.0
	const DURATION: float = 0.2

	func _ready() -> void:
		z_index = 11

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
		if _time >= DURATION:
			queue_free()

	func _draw() -> void:
		var t: float = _time / DURATION
		var alpha: float = 1.0 - t
		var size: float = 6.0 + t * 12.0
		# Bright flash
		var flash_color := Color(0.7, 0.85, 1.0, alpha * 0.8)
		draw_circle(Vector2.ZERO, size, flash_color)
		# White core
		var core_color := Color(0.9, 0.95, 1.0, alpha)
		draw_circle(Vector2.ZERO, size * 0.4, core_color)
