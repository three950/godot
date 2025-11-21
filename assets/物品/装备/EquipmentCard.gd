class_name EquipmentCard
extends ComposableItemCard
enum EquipType{武器,防具}
@export var equip_type: EquipType = EquipType.武器
@export var need_power:int = 1#拿起需要多少力量
@export var ATK:int=0
@export var DEF:int=0
