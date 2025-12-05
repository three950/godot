extends "res://assets/物品/things.gd"
class_name Equipment
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var value_label: Label = $ValueLabel
@onready var effect_label: Label = $EffectLabel

@export var equipment: EquipmentCard
	
func _ready() -> void:
	super._ready()
	_update_item_card()

func _update_item_card() -> void:
	if equipment == null:
		return
	label.text = equipment.name
	texture_rect.texture = equipment.portrait
	value_label.text = str(equipment.value)
	effect_label.text = EquipmentCard.EquipType.keys()[equipment.equip_type] + " + " + str(equipment.equip_effect)

func get_value() -> int:
	return equipment.value if equipment else 0
func set_stats(value:EquipmentCard)-> void:
	equipment = value
