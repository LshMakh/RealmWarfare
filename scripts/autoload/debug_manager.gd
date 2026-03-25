extends Node

## Debug manager — keyboard shortcuts + overlay for testing.
## Auto-disables in export builds via OS.is_debug_build().
## References are set by run.gd at run start.

# Run references (set/cleared per run)
var _player: CharacterBody2D = null
var _wave_manager: WaveManager = null
var _blessing_manager: BlessingManager = null

# Debug state
var _god_mode: bool = false
var _speed_index: int = 0
var _overlay_visible: bool = true
const SPEED_OPTIONS: Array[float] = [1.0, 2.0, 4.0]

# Overlay nodes
var _canvas_layer: CanvasLayer = null
var _label: Label = null


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func set_run_references(player: CharacterBody2D, wave_manager: WaveManager, blessing_manager: BlessingManager) -> void:
	_player = player
	_wave_manager = wave_manager
	_blessing_manager = blessing_manager


func clear_run_references() -> void:
	_player = null
	_wave_manager = null
	_blessing_manager = null
	_god_mode = false
	_speed_index = 0
	Engine.time_scale = 1.0


# --- Overlay ---

func _build_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 120
	add_child(_canvas_layer)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -4.0
	panel.offset_top = 4.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_canvas_layer.add_child(panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4, 1.0))
	panel.add_child(_label)


func _process(_delta: float) -> void:
	if _god_mode and _player and is_instance_valid(_player):
		_player.hurtbox._invincible = true

	if _overlay_visible and _label:
		_update_overlay()


func _update_overlay() -> void:
	var lines: PackedStringArray = PackedStringArray()

	lines.append("=== DEBUG ===")
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	lines.append("God: %s  Speed: %.0fx" % ["ON" if _god_mode else "OFF", SPEED_OPTIONS[_speed_index]])

	if GameState.is_run_active:
		lines.append("")
		if _player and is_instance_valid(_player):
			lines.append("HP: %d/%d" % [_player.health_component.current_health, _player.health_component.max_health])
		lines.append("Lv: %d  XP: %d/%d" % [GameState.player_level, GameState.player_xp, GameState.xp_to_next_level])
		lines.append("Kills: %d" % GameState.kills)
		lines.append("Charge: %.0f/%.0f" % [GameState.ability_charge, GameState.ability_charge_max])

		if _wave_manager:
			lines.append("")
			lines.append("Wave: %d  [%s]" % [GameState.current_wave, _wave_state_name()])
			lines.append("Enemies: %d" % _wave_manager._get_total_active_enemies())

		if _blessing_manager:
			var ids: Array[StringName] = _blessing_manager.get_active_blessing_ids()
			if ids.size() > 0:
				lines.append("")
				lines.append("Blessings:")
				for bid: StringName in ids:
					var level: int = _blessing_manager.get_blessing_level(bid)
					var short_name: String = str(bid).replace("zeus_", "")
					lines.append("  %s Lv%d" % [short_name, level])

		lines.append("")
		lines.append("Favor: %d" % GameState.favor)
	else:
		lines.append("")
		lines.append("Favor: %d" % GameState.favor)
		lines.append("Not in run")

	lines.append("")
	lines.append("F1:God F2:Heal F3:+XP")
	lines.append("F4:SkipWave F5:Boss")
	lines.append("F6:+Bless F7:MaxBless")
	lines.append("F8:Charge F9:+Favor")
	lines.append("F10:KillAll F11:Speed")
	lines.append("F12:Overlay")

	_label.text = "\n".join(lines)


func _wave_state_name() -> String:
	if not _wave_manager:
		return "???"
	match _wave_manager._state:
		WaveManager.WaveState.IDLE:
			return "IDLE"
		WaveManager.WaveState.SPAWNING:
			return "SPAWNING"
		WaveManager.WaveState.ACTIVE:
			return "ACTIVE"
		WaveManager.WaveState.BREATHER:
			return "BREATHER"
		WaveManager.WaveState.BOSS:
			return "BOSS"
		WaveManager.WaveState.DONE:
			return "DONE"
	return "???"


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match (event as InputEventKey).keycode:
		KEY_F1:
			_toggle_god_mode()
		KEY_F2:
			_heal_full()
		KEY_F3:
			_grant_xp()
		KEY_F4:
			_skip_wave()
		KEY_F5:
			_skip_to_boss()
		KEY_F6:
			_cycle_blessing()
		KEY_F7:
			_max_blessings()
		KEY_F8:
			_fill_ability()
		KEY_F9:
			_grant_favor()
		KEY_F10:
			_kill_all_enemies()
		KEY_F11:
			_cycle_speed()
		KEY_F12:
			_toggle_overlay()


# --- Actions ---

func _toggle_god_mode() -> void:
	if not _player or not is_instance_valid(_player):
		return
	_god_mode = not _god_mode
	_player.hurtbox._invincible = _god_mode
	print("[DEBUG] God mode: %s" % ("ON" if _god_mode else "OFF"))


func _heal_full() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var health: HealthComponent = _player.health_component
	health.heal(health.max_health)
	print("[DEBUG] Healed to full")


func _grant_xp() -> void:
	if not GameState.is_run_active:
		return
	GameState.add_xp(500)
	print("[DEBUG] +500 XP (level %d)" % GameState.player_level)


func _skip_wave() -> void:
	if not _wave_manager or not GameState.is_run_active:
		return
	_wave_manager._wave_enemies_remaining = 0
	_wave_manager._breather_timer = 0.0
	_wave_manager._sub_waves_remaining = 0
	_wave_manager._state = WaveManager.WaveState.IDLE
	print("[DEBUG] Skipped to next wave")


func _skip_to_boss() -> void:
	if not _wave_manager or not GameState.is_run_active:
		return
	_wave_manager._wave_enemies_remaining = 0
	_wave_manager._sub_waves_remaining = 0
	_wave_manager._current_wave_index = _wave_manager.wave_table.size() - 1
	_wave_manager._state = WaveManager.WaveState.IDLE
	print("[DEBUG] Skipping to boss")


func _cycle_blessing() -> void:
	if not _blessing_manager or not GameState.is_run_active:
		return
	var available: Array[BlessingData] = _blessing_manager.available_blessings
	if available.is_empty():
		return

	# Grant first unowned blessing
	for blessing: BlessingData in available:
		if _blessing_manager.get_blessing_level(blessing.blessing_id) == 0:
			GameEvents.blessing_chosen.emit(blessing)
			print("[DEBUG] Granted %s Lv1" % blessing.name)
			return

	# All owned — upgrade first non-maxed
	for blessing: BlessingData in available:
		var level: int = _blessing_manager.get_blessing_level(blessing.blessing_id)
		if level < blessing.max_level:
			GameEvents.blessing_chosen.emit(blessing)
			print("[DEBUG] Upgraded %s to Lv%d" % [blessing.name, level + 1])
			return

	print("[DEBUG] All blessings maxed")


func _max_blessings() -> void:
	if not _blessing_manager or not GameState.is_run_active:
		return
	var available: Array[BlessingData] = _blessing_manager.available_blessings
	for blessing: BlessingData in available:
		var current_level: int = _blessing_manager.get_blessing_level(blessing.blessing_id)
		while current_level < blessing.max_level:
			GameEvents.blessing_chosen.emit(blessing)
			current_level += 1
	print("[DEBUG] All blessings maxed to Lv5")


func _fill_ability() -> void:
	if not GameState.is_run_active:
		return
	GameState.ability_charge = GameState.ability_charge_max
	print("[DEBUG] Ability fully charged")


func _grant_favor() -> void:
	GameState.favor += 500
	FavorManager.save_profile()
	print("[DEBUG] +500 Favor (total: %d)" % GameState.favor)


func _kill_all_enemies() -> void:
	var killed: int = 0
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.visible and enemy.has_node("HealthComponent"):
			var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
			if health.current_health > 0:
				health.take_damage(99999)
				killed += 1
	print("[DEBUG] Killed %d enemies" % killed)


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_OPTIONS.size()
	Engine.time_scale = SPEED_OPTIONS[_speed_index]
	print("[DEBUG] Game speed: %.0fx" % SPEED_OPTIONS[_speed_index])


func _toggle_overlay() -> void:
	_overlay_visible = not _overlay_visible
	if _canvas_layer:
		_canvas_layer.visible = _overlay_visible
	print("[DEBUG] Overlay: %s" % ("ON" if _overlay_visible else "OFF"))
