extends Node2D

@onready var player: CharacterBody2D = $EntityLayer/Player
@onready var joystick: VirtualJoystick = $UILayer/VirtualJoystick
@onready var hud = $UILayer/HUD
@onready var wave_manager: WaveManager = $Systems/WaveManager
@onready var auto_attack: AutoAttack = $EntityLayer/Player/AutoAttack
@onready var enemy_pool: ObjectPool = $EntityLayer/EnemyPool
@onready var projectile_pool: ObjectPool = $EntityLayer/ProjectilePool
@onready var xp_pool: ObjectPool = $EntityLayer/XPPool
@onready var blessing_manager: BlessingManager = $Systems/BlessingManager
@onready var level_up_ui: CanvasLayer = $UILayer/LevelUpUI
@onready var column_manager: ColumnManager = $ColumnManager
@onready var hazard_manager: HazardManager = $Systems/HazardManager
@onready var lightning_pool: ObjectPool = $EntityLayer/LightningPool
@onready var crack_pool: ObjectPool = $EntityLayer/CrackPool
@onready var active_ability: ActiveAbility = $Systems/ActiveAbility
@onready var discovery_tracker: DiscoveryTracker = $Systems/DiscoveryTracker


func _ready() -> void:
	GameState.start_new_run()

	# Apply Favor bonuses AFTER start_new_run resets everything
	var bonuses: Dictionary = FavorManager.get_active_bonuses()
	GameState.damage_bonus = bonuses.get("damage_pct", 0.0) / 100.0
	GameState.speed_bonus = bonuses.get("speed_pct", 0.0) / 100.0
	GameState.xp_bonus = bonuses.get("xp_pct", 0.0) / 100.0
	var hp_bonus: int = bonuses.get("max_hp", 0) as int
	if hp_bonus > 0:
		player.health_component.max_health += hp_bonus
		player.health_component.current_health = player.health_component.max_health
	var cd_pct: float = bonuses.get("cooldown_pct", 0.0) as float
	if cd_pct > 0.0:
		auto_attack.attack_cooldown *= (1.0 - cd_pct / 100.0)

	# Wire up discovery tracker
	discovery_tracker.set_favor_manager(FavorManager)

	# Connect joystick to player
	joystick.joystick_input.connect(player.set_joystick_direction)

	# Connect player health to HUD
	hud.set_player_health(player.health_component)

	# Wire up wave manager
	wave_manager.set_enemy_pool("skeleton", enemy_pool)
	wave_manager.set_enemy_pool("harpy", enemy_pool)
	wave_manager.set_enemy_pool("minotaur", enemy_pool)
	wave_manager.set_enemy_pool("cyclops", enemy_pool)
	wave_manager.set_enemy_pool("satyr", enemy_pool)
	wave_manager.set_enemy_pool("gorgon", enemy_pool)
	wave_manager.xp_pool = xp_pool
	wave_manager.player = player
	wave_manager.enemy_lookup = {
		"skeleton": preload("res://data/enemies/skeleton_data.tres"),
		"harpy": preload("res://data/enemies/harpy_data.tres"),
		"minotaur": preload("res://data/enemies/minotaur_data.tres"),
		"cyclops": preload("res://data/enemies/cyclops_data.tres"),
		"satyr": preload("res://data/enemies/satyr_data.tres"),
		"gorgon": preload("res://data/enemies/gorgon_data.tres"),
	}
	wave_manager.wave_table = [
		preload("res://data/waves/olympus/wave_01.tres"),
		preload("res://data/waves/olympus/wave_02.tres"),
		preload("res://data/waves/olympus/wave_03.tres"),
		preload("res://data/waves/olympus/wave_04.tres"),
		preload("res://data/waves/olympus/wave_05.tres"),
		preload("res://data/waves/olympus/wave_06.tres"),
		preload("res://data/waves/olympus/wave_07.tres"),
		preload("res://data/waves/olympus/wave_08.tres"),
		preload("res://data/waves/olympus/wave_09.tres"),
		preload("res://data/waves/olympus/wave_10.tres"),
		preload("res://data/waves/olympus/wave_11.tres"),
		preload("res://data/waves/olympus/wave_12.tres"),
		preload("res://data/waves/olympus/wave_13.tres"),
		preload("res://data/waves/olympus/wave_14.tres"),
		preload("res://data/waves/olympus/wave_15.tres"),
		preload("res://data/waves/olympus/wave_16.tres"),
		preload("res://data/waves/olympus/wave_17.tres"),
		preload("res://data/waves/olympus/wave_18.tres"),
		preload("res://data/waves/olympus/wave_19.tres"),
		preload("res://data/waves/olympus/wave_20.tres"),
	]
	wave_manager.boss_data = preload("res://data/enemies/cerberus_data.tres")
	wave_manager.crack_pool = crack_pool
	wave_manager.powerup_scene = preload("res://scenes/entities/pickups/powerup.tscn")
	wave_manager.powerup_data_list = [
		preload("res://data/pickups/ambrosia.tres"),
		preload("res://data/pickups/hermes_wings.tres"),
		preload("res://data/pickups/zeus_wrath.tres"),
	]
	wave_manager._entity_layer = $EntityLayer

	# Wire up auto-attack
	auto_attack.projectile_pool = projectile_pool
	auto_attack.set_blessing_manager(blessing_manager)

	# Wire up level-up UI
	level_up_ui.set_blessing_manager(blessing_manager)

	# Wire up blessing manager
	blessing_manager.set_player(player)
	blessing_manager.set_projectile_pool(projectile_pool)
	blessing_manager.available_blessings = [
		preload("res://data/blessings/zeus_lightning_bolt.tres"),
		preload("res://data/blessings/zeus_thunder_ring.tres"),
		preload("res://data/blessings/zeus_storm_cloud.tres"),
		preload("res://data/blessings/zeus_chain_lightning.tres"),
		preload("res://data/blessings/zeus_aegis_barrier.tres"),
	]

	# Wire up active ability
	active_ability.player = player
	active_ability.set_blessing_manager(blessing_manager)
	hud.ability_button_pressed.connect(active_ability.activate)

	# Wire up hazard manager
	hazard_manager.player = player
	hazard_manager.set_pools(lightning_pool, crack_pool)

	# Wire up column manager
	column_manager.player = player

	# Wire hurtbox health reference
	player.hurtbox.health = player.health_component

	# Connect player death
	GameEvents.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	GameState.end_run()
	# Calculate personal bests and stash discovery data for post-run screen
	discovery_tracker.check_personal_bests()
	GameState.set_meta("last_run_discoveries", discovery_tracker.get_run_discoveries())
	GameState.set_meta("last_run_personal_bests", discovery_tracker.get_run_personal_bests())
	FavorManager.save_profile()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/run/post_run.tscn")
