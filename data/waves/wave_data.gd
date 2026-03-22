class_name WaveData
extends Resource

# WARNING: Do not reorder — .tres files reference these by integer value
enum SpawnPattern { RING, DIRECTIONAL, PINCER, AMBUSH }

@export var wave_number: int = 1
@export var enemy_composition: Dictionary = {}  # {"skeleton": 4, "harpy": 2}
@export var spawn_pattern: SpawnPattern = SpawnPattern.RING
@export var spawn_count_min: int = 6
@export var spawn_count_max: int = 8
@export var sub_wave_count: int = 3
@export var sub_wave_interval: float = 2.0
@export var wave_timeout: float = 45.0
@export var breather_duration: float = 2.5
