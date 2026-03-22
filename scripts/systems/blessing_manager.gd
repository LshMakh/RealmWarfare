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
	# Spawn at random position 40-100px from player
	var angle := randf() * TAU
	var dist := randf_range(40.0, 100.0)
	var offset := Vector2(cos(angle), sin(angle)) * dist
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
	var hit_radius: float = 20.0
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node2D in enemies:
		if not enemy.visible:
			continue
		var dist: float = hit_pos.distance_to(enemy.global_position)
		if dist <= hit_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(blessing.damage)
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
			_orbitals.append({
				"blessing": blessing,
				"angle": 0.0,
				"node": node,
				"hit_timer": blessing.cooldown,
			})
			# Redistribute all orbitals evenly
			var total: int = _orbitals.size()
			for idx in range(total):
				_orbitals[idx]["angle"] = float(idx) * (TAU / float(total))

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

	func _process(delta: float) -> void:
		_pulse_time += delta * 5.0
		# Record trail positions
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = TRAIL_INTERVAL
			_trail.push_back(global_position)
			if _trail.size() > TRAIL_LENGTH:
				_trail.pop_front()
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.7 + 0.3 * sin(_pulse_time)

		# Draw trail (fading circles at previous positions)
		for i in range(_trail.size()):
			var t: float = float(i) / float(TRAIL_LENGTH)
			var trail_alpha: float = t * 0.25 * pulse
			var trail_pos: Vector2 = _trail[i] - global_position
			var trail_size: float = 4.0 + t * 4.0
			var trail_color := Color(0.4, 0.6, 1.0, trail_alpha)
			draw_circle(trail_pos, trail_size, trail_color)

		# Outer glow (large soft)
		var outer_glow := Color(0.3, 0.5, 1.0, 0.15 * pulse)
		draw_circle(Vector2.ZERO, 18.0, outer_glow)

		# Mid glow
		var mid_glow := Color(0.4, 0.6, 1.0, 0.3 * pulse)
		draw_circle(Vector2.ZERO, 13.0, mid_glow)

		# Shield core (bright white-blue)
		var core_color := Color(0.6, 0.8, 1.0, 0.9 * pulse)
		draw_circle(Vector2.ZERO, 9.0, core_color)

		# Inner bright center
		var center_color := Color(0.85, 0.92, 1.0, pulse)
		draw_circle(Vector2.ZERO, 5.0, center_color)

		# Shield arc (curved shield shape on the leading edge)
		var arc_color := Color(0.8, 0.9, 1.0, 0.8 * pulse)
		draw_arc(Vector2.ZERO, 11.0, -PI * 0.5, PI * 0.5, 12, arc_color, 2.5)

		# Secondary arc (opposite side, dimmer)
		var arc2_color := Color(0.5, 0.7, 1.0, 0.4 * pulse)
		draw_arc(Vector2.ZERO, 11.0, PI * 0.5, PI * 1.5, 12, arc2_color, 1.5)


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
