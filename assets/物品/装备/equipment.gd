extends "res://assets/物品/things.gd"
class_name Equipment

@onready var effect_label: Label = $EffectLabel

@export var equipment: EquipmentCard

func get_things_resource() -> ThingsCard:
	return equipment
	
func _ready() -> void:
	super._ready()
	_update_equipment_display()

func _update_equipment_display() -> void:
	# 调用父类通用更新（设置 name, cardname, label, texture, value）
	_update_things_display()
	# 更新装备特有的效果标签
	if equipment and effect_label:
		effect_label.text = EquipmentCard.EquipType.keys()[equipment.equip_type] + " + " + str(equipment.equip_effect)

func set_stats(value: EquipmentCard) -> void:
	equipment = value
	if is_node_ready():
		_update_equipment_display()
