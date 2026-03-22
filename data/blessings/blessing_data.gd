class_name BlessingData
extends Resource

@export var blessing_id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var pantheon: String = "greek"
@export var tier: int = 1

enum EffectType { PROJECTILE, AURA, ORBITAL, PASSIVE }
@export var effect_type: EffectType = EffectType.PROJECTILE

@export var damage: int = 10
@export var cooldown: float = 1.0
@export var duration: float = 0.0
@export var radius: float = 0.0
@export var projectile_speed: float = 250.0
@export var projectile_count: int = 1

# Level system
@export var max_level: int = 5
@export var level_stats: Array[Dictionary] = []  ## Per-level stats, index 0 = level 1
@export var level_descriptions: Array[String] = []  ## Short description per level


func get_stat(level: int, stat_name: String, default_value: Variant = 0) -> Variant:
	var idx: int = clampi(level - 1, 0, level_stats.size() - 1)
	if idx < level_stats.size() and level_stats[idx].has(stat_name):
		return level_stats[idx][stat_name]
	return default_value
