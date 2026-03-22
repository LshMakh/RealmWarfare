extends Node

# Run lifecycle
signal run_started
signal run_ended(result: Dictionary)

# Combat
signal enemy_killed(position: Vector2, xp_value: int)
signal player_damaged(amount: int)
signal player_died

# Progression
signal xp_collected(amount: int)
signal level_up(new_level: int)
signal blessing_choices_ready(choices: Array)
signal blessing_chosen(blessing: Resource)

# Boss
signal boss_spawned(enemy: Node2D)
signal boss_died(position: Vector2)

# Waves
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

# Pickups
signal powerup_collected(pickup_data: Resource, position: Vector2)

# Abilities
signal active_ability_used

# Discoveries & progression
signal discovery_made(discovery_id: String, discovery_name: String)
signal personal_best_broken(category: String, value: float)

# Environment
signal hazard_spawned(hazard_type: String, position: Vector2)

# UI
signal show_level_up_ui(choices: Array)
signal hide_level_up_ui
