class_name EquipmentCard
extends ThingsCard

func _init() -> void:
	card_scene = load("res://assets/物品/装备/Equitment.tscn")

enum EquipType{攻击,防御}
@export var equip_type: EquipType = EquipType.攻击
@export var need_power:int = 1#拿起需要多少力量
@export var equip_effect:int=0
