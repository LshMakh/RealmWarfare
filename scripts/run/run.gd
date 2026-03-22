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


func _ready() -> void:
	GameState.start_new_run()

	# Connect joystick to player
	joystick.joystick_input.connect(player.set_joystick_direction)

	# Connect player health to HUD
	hud.set_player_health(player.health_component)

	# Wire up wave manager
	wave_manager.enemy_pool = enemy_pool
	wave_manager.xp_pool = xp_pool
	wave_manager.player = player
	wave_manager.enemy_types = [
		preload("res://data/enemies/harpy_data.tres"),
		preload("res://data/enemies/cyclops_data.tres"),
		preload("res://data/enemies/minotaur_data.tres"),
		preload("res://data/enemies/skeleton_data.tres"),
	]
	wave_manager.boss_data = preload("res://data/enemies/cerberus_data.tres")
	wave_manager.powerup_scene = preload("res://scenes/entities/pickups/powerup.tscn")
	wave_manager.powerup_data_list = [
		preload("res://data/pickups/ambrosia.tres"),
		preload("res://data/pickups/hermes_wings.tres"),
		preload("res://data/pickups/zeus_wrath.tres"),
	]
	wave_manager._entity_layer = $EntityLayer

	# Wire up auto-attack
	auto_attack.projectile_pool = projectile_pool

	# Wire up blessing manager
	blessing_manager.set_player(player)
	blessing_manager.available_blessings = [
		preload("res://data/blessings/zeus_lightning_bolt.tres"),
		preload("res://data/blessings/zeus_thunder_ring.tres"),
		preload("res://data/blessings/zeus_storm_cloud.tres"),
		preload("res://data/blessings/zeus_chain_lightning.tres"),
		preload("res://data/blessings/zeus_aegis_barrier.tres"),
	]

	# Wire hurtbox health reference
	player.hurtbox.health = player.health_component

	# Connect player death
	GameEvents.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	GameState.end_run()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/run/post_run.tscn")
