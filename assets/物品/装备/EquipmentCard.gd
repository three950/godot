class_name EquipmentCard
extends ThingsCard
@export var card_scene:PackedScene = load("res://assets/物品/装备/Equitment.tscn")

@export_group("装备数据")
@export var need_power: int = 1 # 拿起并发挥装备效果需要的力量。
@export var attack: int = 0 # 装备提供的攻击力加成。
@export var weapon: WeaponCard
@export var armor: ArmorCard


func is_weapon() -> bool:
	# 简单按子 Resource 是否存在区分槽位；近战/远程等细分只放在 WeaponCard 内。
	return self is WeaponCard or weapon != null


func is_armor() -> bool:
	return self is ArmorCard or armor != null


func get_slot_name() -> String:
	if is_weapon():
		return "weapon"
	if is_armor():
		return "armor"
	return "weapon"


func get_need_power() -> int:
	# 力量需求属于所有装备的通用数据，不下放到武器/防具子类型。
	return need_power


func get_effect_value() -> int:
	# 当前装备数值统一用 attack 字段承载；子 Resource 只描述装备种类差异。
	return attack


func can_be_used_by_power(power: int) -> bool:
	# 沿用旧逻辑：力量必须严格大于装备需求才会生效。
	return get_need_power() < power


func get_effect_label_text() -> String:
	if is_weapon():
		return "攻击 + " + str(attack)
	if is_armor():
		return "防御 + " + str(attack)
	return ""
