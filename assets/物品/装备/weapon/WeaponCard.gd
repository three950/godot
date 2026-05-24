class_name WeaponCard
extends Resource

enum WeaponType {近战, 远程}

@export var weapon_type: WeaponType = WeaponType.近战 # 这里只记录武器子类型；数值字段在 EquipmentCard。
