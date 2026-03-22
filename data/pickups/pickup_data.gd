class_name PickupData
extends Resource

enum EffectType { HEAL, MAGNET, BOMB }

@export var pickup_id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var effect_type: EffectType = EffectType.HEAL
@export var value: float = 0.0
@export var color: Color = Color.WHITE
@export var glow_color: Color = Color.WHITE
