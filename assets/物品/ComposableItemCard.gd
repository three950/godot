class_name ComposableItemCard
extends ItemCard
@export_group("合成配方")
@export var has_craft_recipe: bool = false
@export var craft_materials: Array[String] = []

func _validate_property(property: Dictionary) -> void:
	if property.name == "craft_materials":
		property.usage = PROPERTY_USAGE_DEFAULT if has_craft_recipe else PROPERTY_USAGE_NO_EDITOR
