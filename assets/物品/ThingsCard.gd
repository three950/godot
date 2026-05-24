extends CardInfo
class_name ThingsCard
enum 遗物等级 {NO, FIFTH, FORTH, THRID, SECOND, FRIST, SUPER}
enum 稀有度{COMMON,NOTBAD,RARE,UNIQUE}
@export var value: int = 1
@export var 是遗物: 遗物等级 = 遗物等级.NO
@export var 物品稀有度: 稀有度
@export var 添加特性 :String
@export var 可以从哪个场景开出:int
@export var 可以在哪一层被开出:int


@export_group("合成配方")
@export var has_craft_recipe: bool = false
@export var craft_materials: Array[CardInfo] = []
@export var 合成时间: float = 0.0

func _validate_property(property: Dictionary) -> void:
	if property.name == "craft_materials":
		property.usage = PROPERTY_USAGE_DEFAULT if has_craft_recipe else PROPERTY_USAGE_NO_EDITOR
