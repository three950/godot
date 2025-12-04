extends CardInfo
class_name ThingsCard
enum 遗物等级 {NO, FIFTH, FORTH, THRID, SECOND, FRIST, SUPER}

@export var value: int = 1
@export var 是遗物: 遗物等级 = 遗物等级.NO

@export_group("合成配方")
@export var has_craft_recipe: bool = false
@export var craft_materials: Array[String] = []
@export var 合成时间: float = 0.0
func _validate_property(property: Dictionary) -> void:
	if property.name == "craft_materials":
		property.usage = PROPERTY_USAGE_DEFAULT if has_craft_recipe else PROPERTY_USAGE_NO_EDITOR
