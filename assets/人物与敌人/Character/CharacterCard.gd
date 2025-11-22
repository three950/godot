class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int


func set_POW(value: int) -> void:
	POW = value
func set_ATK(value: int) -> void:
	ATK = POW

@export_group("左右手")
@export var left: String = ""
@export var right: String = ""

@export_group("背包")
@export var slot_1: String = ""
@export var slot_2: String = ""
@export var slot_3: String = ""
@export var slot_4: String = ""
@export var slot_5: String = ""
@export var slot_6: String = ""
