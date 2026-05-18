extends "res://assets/card.gd"
class_name BuildingCard

@export var building_layer: int = 0
@export var capacity: int = 1
@export var hp_restore_per_night: int = 5
@export var requires_food: bool = true
@export var requires_water: bool = true
@export var accept_value_only: bool = false
var resting_characters: Array[CharacterCard] = []


func set_building_stats(layer: int, cap: int, hp_restore: int, need_food: bool = true, need_water: bool = true) -> void:
	building_layer = layer
	capacity = cap
	hp_restore_per_night = hp_restore
	requires_food = need_food
	requires_water = need_water
