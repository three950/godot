extends "res://assets/物品/ThingsCard.gd"
class_name ItemCard

func _init() -> void:
	card_scene = load("res://assets/物品/道具/item.tscn")

@export var 特殊效果 :String
