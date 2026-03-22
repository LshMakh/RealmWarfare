class_name BlessingData
extends Resource

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
