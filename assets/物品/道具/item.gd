extends "res://assets/物品/things.gd"
class_name Item
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var value_label: Label = $ValueLabel

@export var item: ItemCard
	
func _ready() -> void:
	super._ready()
	_update_item_card()

func _update_item_card() -> void:
	if item == null:
		return
	label.text = item.name
	texture_rect.texture = item.portrait
	value_label.text = str(item.value)

func get_value() -> int:
	return item.value if item else 0
