extends "res://assets/物品/things.gd"
class_name Recource
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var value_label: Label = $ValueLabel
@onready var food_label: Label = $FoodLabel

@export var recource: ResourceCard
	
func _ready() -> void:
	super._ready()
	_update_item_card()

func _update_item_card() -> void:
	if recource == null:
		return
	name = recource.name
	cardname = recource.name
	label.text = recource.name
	texture_rect.texture = recource.portrait
	value_label.text = str(recource.value)
	food_label.text = str(recource.nutrition)

func get_value() -> int:
	return recource.value if recource else 0
func set_stats(value:ResourceCard)-> void:
	recource = value
