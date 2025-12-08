extends "res://assets/物品/things.gd"
class_name Recource

@onready var food_label: Label = $FoodLabel

@export var recource: ResourceCard

func get_things_resource() -> ThingsCard:
	return recource
	
func _ready() -> void:
	super._ready()
	_update_resource_display()

func _update_resource_display() -> void:
	# 调用父类通用更新（设置 name, cardname, label, texture, value）
	_update_things_display()
	# 更新资源特有的营养值标签
	if recource and food_label:
		food_label.text = str(recource.nutrition)

func set_stats(value: ResourceCard) -> void:
	recource = value
	if is_node_ready():
		_update_resource_display()
