extends Node

# Run lifecycle
signal run_started
signal run_ended(result: Dictionary)

# Combat
signal enemy_killed(position: Vector2)
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

# Pickups
signal powerup_collected(pickup_data: Resource, position: Vector2)

# UI
signal show_level_up_ui(choices: Array)
signal hide_level_up_ui
