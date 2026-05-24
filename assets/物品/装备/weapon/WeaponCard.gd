class_name WeaponCard
extends EquipmentCard

enum WeaponType {close, remote}

@export var weapon_type: WeaponType = WeaponType.close # 这里只记录武器子类型；数值字段在 EquipmentCard。
