class_name EnemyData
extends Resource

enum BehaviorType { CHASE, ZIGZAG, TANK_SLAM, CHARGER, BOSS }

@export var name: String = ""
@export var max_health: int = 20
@export var speed: float = 40.0
@export var damage: int = 10
@export var xp_reward: int = 1
@export var sprite_texture: Texture2D
@export var is_boss: bool = false
@export var collision_radius: float = 6.0
@export var behavior_type: BehaviorType = BehaviorType.CHASE
