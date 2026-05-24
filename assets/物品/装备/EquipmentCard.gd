class_name EquipmentCard
extends ThingsCard
@export var card_scene:PackedScene = load("res://assets/物品/装备/Equitment.tscn")

@export_group("装备数据")
@export var need_power: int = 1 # 拿起并发挥装备效果需要的力量。
@export var attack: int = 0 # 装备提供的攻击力加成。
@export var DEF: int = 0 # 装备提供的防御力加成。

func get_need_power() -> int:
	# 力量需求属于所有装备的通用数据，不下放到武器/防具子类型。
	return need_power


func can_be_used_by_power(power: int) -> bool:
	# 沿用旧逻辑：力量必须严格大于装备需求才会生效。
	return get_need_power() < power


func get_effect_label_text() -> String:
	var effect_texts: Array[String] = []
	if attack != 0:
		effect_texts.append(_format_bonus_text("攻击", attack))
	if DEF != 0:
		effect_texts.append(_format_bonus_text("防御", DEF))
	return "\n".join(effect_texts)


func _format_bonus_text(label_name: String, value: int) -> String:
	if value > 0:
		return label_name + " + " + str(value)
	return label_name + " - " + str(abs(value))
