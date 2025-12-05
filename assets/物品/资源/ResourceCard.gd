extends "res://assets/物品/ThingsCard.gd"
class_name ResourceCard

func _init() -> void:
	card_scene = load("res://assets/物品/资源/recource.tscn")

@export var nutrition: int = 0  # 营养值（食物类）
